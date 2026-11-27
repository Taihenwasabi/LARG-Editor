/// 游戏包 zip 的解包 / 打包——引擎侧唯一实现（纯 Dart，零 flutter 依赖）。
///
/// **安全边界在这里**：编辑器与 CLI 都经这一份，不各写一套。
///
/// ## 威胁与对策
/// 1. **zip-slip（路径穿越）**：恶意 zip 的条目名可能含 `..` 或绝对路径。
///    对策：解包时逐条校验路径段，任何含 `..` 的段、绝对路径、盘符一律拒绝
///    （抛 [PackageFormatException]），不静默跳过——静默跳过会让用户以为包是好的。
/// 2. **zip bomb（解压炸弹）**：压缩比极高的条目会把内存打满。
///    对策：解包前检查声明大小，解包中累计实际字节，超上限即中止。
/// 3. **条目数炸弹**：海量小条目耗 CPU。
///    对策：条目数上限。
///
/// ## 打包侧
/// 根目录名（包名）与条目键都经 [sanitizePathSegment] / [sanitizeRelativePath]
/// 净化，保证导出的 zip 不含穿越路径——避免本工具生成的包反过来伤害别人。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'engine_exception.dart';

/// 解包后允许的条目总数上限。
const int kMaxZipEntries = 20000;

/// 解包后允许的总字节上限（256 MiB）。
const int kMaxZipTotalBytes = 256 * 1024 * 1024;

/// 单个条目允许的最大字节上限（64 MiB）。
const int kMaxZipEntryBytes = 64 * 1024 * 1024;

/// 把包名净化成可安全用作 zip 根目录名的一段。
///
/// 去掉路径分隔符与 Windows 非法字符，`.`/`..` 退化成占位名。
String sanitizePathSegment(String raw) {
  var s = raw.trim();
  s = s.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  // 去掉所有「点段」（. / .. 及其组合），避免残留 ..
  final parts = s.split('_').where((p) {
    final t = p.trim();
    return t.isNotEmpty && t != '.' && t != '..';
  }).toList();
  s = parts.join('_');
  if (s.isEmpty) return 'pack';
  return s;
}

/// 净化一条包内相对路径（`/` 分隔）。
///
/// 返回 null 表示这条路径不安全，调用方应当拒绝。
String? sanitizeRelativePath(String raw) {
  var s = raw.replaceAll(r'\', '/');
  if (s.isEmpty) return null;
  // 绝对路径与盘符
  if (s.startsWith('/')) return null;
  if (RegExp(r'^[A-Za-z]:').hasMatch(s)) return null;
  final segments = <String>[];
  for (final seg in s.split('/')) {
    if (seg.isEmpty || seg == '.') continue;
    if (seg == '..') return null;
    segments.add(seg);
  }
  if (segments.isEmpty) return null;
  return segments.join('/');
}

/// 解包 zip → 「相对包根路径 → 字节」。
///
/// 约定：zip 内首层目录视为包根被剥掉（`pack/stage/1.json` → `stage/1.json`）；
/// 若首层就是 `basicInfo.json`（无根目录），则原样保留。
///
/// 抛 [PackageFormatException] 的情况：条目名非法（路径穿越 / 绝对路径）、
/// 条目数超限、声明大小超限、解包后总字节超限。
Map<String, Uint8List> unpackZipBytes(List<int> zipBytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(zipBytes);
  } catch (e) {
    throw PackageFormatException('压缩包无法解析：$e');
  }

  if (archive.length > kMaxZipEntries) {
    throw PackageFormatException(
      '压缩包条目过多（${archive.length} 个，上限 $kMaxZipEntries 个）',
    );
  }

  // 第一遍：只看名字，确定是否要剥掉首层目录。
  final rawNames = <String>[];
  for (final f in archive) {
    if (!f.isFile) continue;
    rawNames.add(f.name.replaceAll(r'\', '/'));
  }
  final stripRoot = _shouldStripRoot(rawNames);

  final files = <String, Uint8List>{};
  var total = 0;
  for (final f in archive) {
    if (!f.isFile) continue;
    var name = f.name.replaceAll(r'\', '/');
    if (stripRoot) {
      final slash = name.indexOf('/');
      if (slash < 0) continue;
      name = name.substring(slash + 1);
    }
    final safe = sanitizeRelativePath(name);
    if (safe == null) {
      throw PackageFormatException(
        '压缩包含非法路径「${f.name}」（不允许 .. 或绝对路径）',
      );
    }
    final content = f.content;
    final size = content is List<int> ? content.length : 0;
    if (size > kMaxZipEntryBytes) {
      throw PackageFormatException(
        '压缩包内单个文件过大（$safe，${_mb(size)}，上限 ${_mb(kMaxZipEntryBytes)}）',
      );
    }
    total += size;
    if (total > kMaxZipTotalBytes) {
      throw PackageFormatException(
        '压缩包解压后过大（超过 ${_mb(kMaxZipTotalBytes)}），已中止',
      );
    }
    files[safe] = content is List<int>
        ? Uint8List.fromList(content)
        : Uint8List(0);
  }
  return files;
}

/// 打包：条目（相对包根路径 → 字节）→ zip 字节。
///
/// 根目录名经 [sanitizePathSegment] 净化；条目键经 [sanitizeRelativePath]
/// 净化，非法键直接抛错（不静默丢弃内容）。
Uint8List packToZipBytes(
  Map<String, List<int>> entries, {
  String rootName = 'pack',
}) {
  // 调用方可能已经在键里带了包根目录（如编辑器的 toArchiveEntries）。
  // 若所有键共享同一个首层目录且其中有 basicInfo.json，就不再重复加一层。
  final effectiveRoot = _existingRoot(entries.keys) ?? sanitizePathSegment(rootName);
  final prefix = '$effectiveRoot/';
  final archive = Archive();
  for (final entry in entries.entries) {
    final safe = sanitizeRelativePath(entry.key);
    if (safe == null) {
      throw PackageFormatException('包内路径非法：「${entry.key}」');
    }
    final name = safe.startsWith(prefix) ? safe : '$effectiveRoot/$safe';
    final bytes = entry.value;
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }
  final encoded = ZipEncoder().encode(archive);
  if (encoded == null) {
    throw const PackageFormatException('压缩包生成失败');
  }
  return encoded is Uint8List ? encoded : Uint8List.fromList(encoded);
}

/// 首层是否只是包根目录（需要剥掉）。
///
/// 判据：所有条目都有首层目录，且剥掉首层后能找到 `basicInfo.json`。
bool _shouldStripRoot(List<String> names) {
  if (names.isEmpty) return false;
  final tops = <String>{};
  var allHaveRoot = true;
  for (final n in names) {
    final slash = n.indexOf('/');
    if (slash <= 0) {
      allHaveRoot = false;
      break;
    }
    tops.add(n.substring(0, slash));
  }
  if (!allHaveRoot || tops.length != 1) return false;
  final top = tops.first;
  return names.any(
    (n) => n.substring(top.length + 1).toLowerCase() == 'basicinfo.json',
  );
}

/// 若所有键都共享同一个首层目录，且该目录下能找到 basicInfo.json，返回该目录名。
String? _existingRoot(Iterable<String> keys) {
  final list = keys.toList();
  if (list.isEmpty) return null;
  final tops = <String>{};
  for (final k in list) {
    final slash = k.indexOf('/');
    if (slash <= 0) return null;
    tops.add(k.substring(0, slash));
  }
  if (tops.length != 1) return null;
  final top = tops.first;
  return list.any(
    (k) => k.substring(top.length + 1).toLowerCase() == 'basicinfo.json',
  )
      ? top
      : null;
}

String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

/// UTF-8 编码便捷方法（打包用）。
List<int> encodeUtf8(String text) => utf8.encode(text);
