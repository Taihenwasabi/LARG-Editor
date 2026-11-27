import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:larg_editor/component/engine.dart';
import 'package:larg_editor/engine/engine_exception.dart';
import 'package:larg_editor/engine/package_io.dart';

Uint8List _bytes(List<int> v) => Uint8List.fromList(v);

/// 构造一个 zip（内存），条目名 → 内容。
Uint8List _makeZip(Map<String, List<int>> entries) {
  final archive = Archive();
  for (final e in entries.entries) {
    archive.addFile(ArchiveFile(e.key, e.value.length, e.value));  }
  final encoded = ZipEncoder().encode(archive);
  return encoded is Uint8List
      ? encoded
      : Uint8List.fromList(encoded ?? <int>[]);
}

void main() {
  group('路径净化', () {
    test('sanitizePathSegment 去掉路径分隔符与非法字符', () {
      expect(sanitizePathSegment('a/b'), 'a_b');
      expect(sanitizePathSegment(r'a\b'), 'a_b');
      expect(sanitizePathSegment('a:b*c?d"e<f>g|h'), 'a_b_c_d_e_f_g_h');
      expect(sanitizePathSegment('  名字  '), '名字');
    });

    test('sanitizePathSegment 不允许 . 与 .. 逃逸', () {
      expect(sanitizePathSegment('..'), 'pack');
      expect(sanitizePathSegment('.'), 'pack');
      expect(sanitizePathSegment('../../evil'), 'evil');
      expect(sanitizePathSegment('../../evil').contains('..'), isFalse);
      expect(sanitizePathSegment(''), 'pack');
    });

    test('sanitizeRelativePath 拒绝穿越与绝对路径', () {
      expect(sanitizeRelativePath('stage/1.json'), 'stage/1.json');
      expect(sanitizeRelativePath(r'stage\1.json'), 'stage/1.json');
      expect(sanitizeRelativePath('./stage/1.json'), 'stage/1.json');
      expect(sanitizeRelativePath('../evil.json'), isNull);
      expect(sanitizeRelativePath('stage/../../evil.json'), isNull);
      expect(sanitizeRelativePath('/etc/passwd'), isNull);
      expect(sanitizeRelativePath(r'C:\Windows\evil.json'), isNull);
      expect(sanitizeRelativePath(''), isNull);
      expect(sanitizeRelativePath('///'), isNull);
    });
  });

  group('解包安全性', () {
    test('正常 zip 能解开，剥掉首层包根目录', () {
      final zip = _makeZip({
        'myPack/basicInfo.json': utf8.encode('{"gameName":"x"}'),
        'myPack/stage/1.json': utf8.encode('{"id":"s1"}'),
      });
      final files = unpackZipBytes(zip);
      expect(files.keys.toSet(), {'basicInfo.json', 'stage/1.json'});
      expect(utf8.decode(files['stage/1.json']!), '{"id":"s1"}');
    });

    test('zip 内直接是文件（无包根目录）时原样保留', () {
      final zip = _makeZip({
        'basicInfo.json': utf8.encode('{"gameName":"x"}'),
        'stage/1.json': utf8.encode('{"id":"s1"}'),
      });
      final files = unpackZipBytes(zip);
      expect(files.keys.toSet(), {'basicInfo.json', 'stage/1.json'});
    });

    test('条目名含 .. 时拒绝整个包（不静默跳过）', () {
      final zip = _makeZip({
        'pack/basicInfo.json': utf8.encode('{}'),
        'pack/../../evil.txt': utf8.encode('pwned'),
      });
      expect(
        () => unpackZipBytes(zip),
        throwsA(
          isA<PackageFormatException>().having(
            (e) => e.message,
            'message',
            contains('非法路径'),
          ),
        ),
      );
    });

    test('条目名是绝对路径时拒绝', () {
      final zip = _makeZip({
        'pack/basicInfo.json': utf8.encode('{}'),
        '/etc/passwd': utf8.encode('x'),
      });
      expect(() => unpackZipBytes(zip), throwsA(isA<PackageFormatException>()));
    });

    test('条目名含盘符时拒绝', () {
      final zip = _makeZip({
        'pack/basicInfo.json': utf8.encode('{}'),
        r'C:\evil.txt': utf8.encode('x'),
      });
      expect(() => unpackZipBytes(zip), throwsA(isA<PackageFormatException>()));
    });

    test('不是合法 zip 时报可读错误', () {
      expect(
        () => unpackZipBytes(utf8.encode('this is not a zip')),
        throwsA(
          isA<PackageFormatException>().having(
            (e) => e.message,
            'message',
            contains('无法解析'),
          ),
        ),
      );
    });
  });

  group('打包安全性', () {
    test('根目录名含 .. 时被净化，不产生穿越路径条目', () {
      final zip = packToZipBytes(
        {'basicInfo.json': utf8.encode('{}')},
        rootName: '../../evil',
      );
      final files = unpackZipBytes(zip);
      expect(files.keys, contains('basicInfo.json'));
      // 名字里不能残留路径分隔或 ..
      for (final k in files.keys) {
        expect(k.contains('..'), isFalse);
      }
    });

    test('条目键含 .. 时抛错（不静默丢内容）', () {
      expect(
        () => packToZipBytes({'../evil.json': utf8.encode('{}')}),
        throwsA(
          isA<PackageFormatException>().having(
            (e) => e.message,
            'message',
            contains('非法'),
          ),
        ),
      );
    });

    test('导出条目名都不含 .. 与绝对路径', () {
      final zip = packToZipBytes({
        'basicInfo.json': utf8.encode('{}'),
        'stage/1.json': utf8.encode('{"id":"s1"}'),
        'assets/picture/a.png': utf8.encode('png'),
      }, rootName: 'myPack');
      final archive = ZipDecoder().decodeBytes(zip);
      for (final f in archive) {
        expect(f.name.startsWith('/'), isFalse);
        expect(f.name.contains('..'), isFalse);
        expect(f.name.startsWith('myPack/'), isTrue);
      }
    });
  });

  group('往返无损', () {
    test('打包再解包，内容完全一致', () {
      final original = <String, List<int>>{
        'basicInfo.json': utf8.encode('{"gameName":"往返测试","Id":"g-x"}'),
        'stage/1启程.json': utf8.encode('{"id":"s1","lines":[{"text":"开场"}]}'),
        'check/check1.json': utf8.encode('{"type":"text_answer"}'),
        'item/gem.json': utf8.encode('{"id":"gem"}'),
        'assets/picture/a.png': _bytes([1, 2, 3, 4, 5]),
        'assets/audio/b.wav': _bytes(List.generate(1000, (i) => i % 256)),
      };
      final zip = packToZipBytes(original, rootName: 'roundTrip');
      final back = unpackZipBytes(zip);
      expect(back.keys.toSet(), original.keys.toSet());
      for (final e in original.entries) {
        expect(back[e.key], e.value, reason: e.key);
      }
    });

    test('中文文件名往返不乱码', () {
      final original = <String, List<int>>{
        'stage/1启程.json': utf8.encode('{"id":"s1"}'),
        'assets/picture/夜班分拣库.png': _bytes([1, 2, 3]),
        'basicInfo.json': utf8.encode('{}'),
      };
      final zip = packToZipBytes(original, rootName: '中文包名');
      final back = unpackZipBytes(zip);
      expect(back['stage/1启程.json'], original['stage/1启程.json']);
    });

    test('空包也能打包解包', () {
      final zip = packToZipBytes({}, rootName: 'empty');
      expect(unpackZipBytes(zip), isEmpty);
    });
  });
}
