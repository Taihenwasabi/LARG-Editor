/// 本地包 zip 字节的落盘实现——原生侧（dart:io + path_provider）。
///
/// 目录：`<支持目录>/quq1_localpacks/<name>.zip`。以文件系统存储解除
/// shared_preferences 的配额限制（含媒体的大包也能存）。web 无文件系统，
/// 走 [localPackBytes_web] 的 base64 兜底。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Directory? _root;

/// 本地包根目录（惰性创建）。
Future<Directory> _rootDir() async {
  if (_root != null) return _root!;
  final base = await getApplicationSupportDirectory();
  final dir = Directory(
    '${base.path}${Platform.pathSeparator}quq1_localpacks',
  );
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  _root = dir;
  return dir;
}

File _fileFor(String name) {
  final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  return File('${_root!.path}${Platform.pathSeparator}$safe.zip');
}

/// 写入 zip 字节（覆盖同名）。失败返回 false。
Future<bool> saveZipBytes(String name, Uint8List bytes) async {
  try {
    await _rootDir();
    await _fileFor(name).writeAsBytes(bytes, flush: true);
    return true;
  } catch (_) {
    return false;
  }
}

/// 读取 zip 字节（不存在返回 null）。
Future<Uint8List?> readZipBytes(String name) async {
  try {
    final dir = await _rootDir();
    final f = File(
      '${dir.path}${Platform.pathSeparator}'
      '${name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}.zip',
    );
    if (!await f.exists()) return null;
    return await f.readAsBytes();
  } catch (_) {
    return null;
  }
}

/// 删除某地包字节。
Future<void> deleteZipBytes(String name) async {
  try {
    await _rootDir();
    final f = _fileFor(name);
    if (await f.exists()) await f.delete();
  } catch (_) {}
}
