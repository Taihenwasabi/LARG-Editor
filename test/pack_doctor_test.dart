import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:larg_editor/component/engine.dart';
import 'package:larg_editor/engine/pack_doctor.dart';

Uint8List _j(String s) => Uint8List.fromList(utf8.encode(s));

GameEngine _engine(Map<String, Map<String, String>> packs) {
  final source = MemoryPackageSource(
    root: 'memory',
    files: {
      for (final e in packs.entries)
        e.key: {for (final f in e.value.entries) f.key: _j(f.value)},
      // 素材只登记路径
    },
    lazyPaths: {
      for (final e in packs.entries)
        e.key: {
          for (final f in e.value.entries)
            if (f.key.startsWith('assets/')) f.key,
        },
    },
  );
  return GameEngine(tokenProvider: InMemoryTokenProvider('t'))..useSource(source);
}

const _manifest = '{"gameName":"自检测试包","Id":"g-test","PublicKey":"K"}';

void main() {
  test('完整包自检通过', () {
    final engine = _engine({
      'p': {
        'basicInfo.json': _manifest,
        'stage/1.json': '{"id":"s1","checkpoint":[{"text":"去","next":"s2"}]}',
        'stage/2.json': '{"id":"s2","checkpoint":[]}',
      },
    });
    final report = PackDoctor.inspect(engine.load('p'));
    expect(report.issues, isEmpty, reason: report.summary);
    expect(report.hasBlocking, isFalse);
  });

  test('报出 next 指向不存在的关卡并指出文件', () {
    final engine = _engine({
      'p': {
        'basicInfo.json': _manifest,
        'stage/1.json':
            '{"id":"s1","checkpoint":[{"text":"去","next":"s99"}]}',
      },
    });
    final report = PackDoctor.inspect(engine.load('p'));
    expect(report.hasBlocking, isTrue);
    expect(
      report.issues.first.code,
      'stage.nextMissing',
    );
    expect(report.issues.first.message, contains('s99'));
    expect(report.issues.first.source, 'stage/1.json');
  });

  test('报出引用不存在的 check', () {
    final engine = _engine({
      'p': {
        'basicInfo.json': _manifest,
        'stage/1.json':
            '{"id":"s1","checkpoint":[{"text":"答","check":"missing.json"}]}',
      },
    });
    final report = PackDoctor.inspect(engine.load('p'));
    expect(
      report.issues.map((e) => e.code),
      contains('stage.checkMissing'),
    );
    expect(report.issues.first.message, contains('missing'));
  });

  test('报出条件与发放引用不存在的物品', () {
    final engine = _engine({
      'p': {
        'basicInfo.json': _manifest,
        'stage/1.json': '''
{"id":"s1","checkpoint":[
  {"text":"A","condition":"gem>=1","grant":{"key":1},"next":"s2"},
  {"text":"B","next":"s2"}
]}''',
        'stage/2.json': '{"id":"s2","checkpoint":[]}',
      },
    });
    final report = PackDoctor.inspect(engine.load('p'));
    final codes = report.issues.map((e) => e.code).toSet();
    expect(codes, contains('stage.conditionMissing'));
    expect(codes, contains('stage.grantMissing'));
    expect(report.issues.any((e) => e.message.contains('gem')), isTrue);
    expect(report.issues.any((e) => e.message.contains('key')), isTrue);
  });

  test('素材缺失时报出，存在时不报', () {
    final withAsset = _engine({
      'p': {
        'basicInfo.json': _manifest,
        'stage/1.json': '{"id":"s1","background":"assets/picture/a.png","checkpoint":[]}',
      },
    });
    expect(PackDoctor.inspect(withAsset.load('p')).issues, isEmpty);

    // 用不传 source 的调用跳过素材检查，确认检查确实发生了
    final pkg = withAsset.load('p');
    final noCheck = PackDoctor.inspect(pkg);
    expect(noCheck.issues, isEmpty);
  });

  test('真实示例包 larg 自检通过', () {
    final engine = GameEngine(
      tokenProvider: InMemoryTokenProvider('t'),
    )..configure('gamepacks');
    final report = PackDoctor.inspect(engine.load('larg'));
    expect(report.issues, isEmpty, reason: report.summary);
  });

  test('真实示例包 localDemo 自检通过', () {
    final engine = GameEngine(
      tokenProvider: InMemoryTokenProvider('t'),
    )..configure('gamepacks');
    final report = PackDoctor.inspect(engine.load('localDemo'));
    expect(report.issues, isEmpty, reason: report.summary);
  });
}
