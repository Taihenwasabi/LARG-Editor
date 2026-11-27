/// 选择游戏包文件夹——原生实现（dart:io + file_picker）。
///
/// 调起系统目录选择器，递归读入所选目录下的全部文件，键为**相对所选目录**的
/// POSIX 风格路径（`/` 分隔），供上层做结构探测与 JSON 校验。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// 文件夹导入结果。
class PackFolderPick {
  /// 当前平台是否支持文件夹导入（Web 为 false）。
  final bool supported;

  /// 用户是否取消选择。
  final bool canceled;

  /// 所选文件夹名（作为包名）。
  final String rootName;

  /// 相对路径（`/` 分隔）→ 文件字节。
  final Map<String, Uint8List> files;

  const PackFolderPick({
    required this.supported,
    required this.canceled,
    required this.rootName,
    required this.files,
  });
}

/// 弹目录选择器并把整个文件夹读入内存。
Future<PackFolderPick> pickPackFolder({String? dialogTitle}) async {
  final dirPath = await FilePicker.platform.getDirectoryPath(
    dialogTitle: dialogTitle ?? 'Select game pack folder',
  );
  if (dirPath == null) {
    return const PackFolderPick(
      supported: true,
      canceled: true,
      rootName: '',
      files: {},
    );
  }

  final dir = Directory(dirPath);
  final baseLen = dir.path.length;
  final sep = Platform.pathSeparator;
  final files = <String, Uint8List>{};
  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    var rel = entity.path.substring(baseLen);
    if (rel.startsWith(sep)) rel = rel.substring(sep.length);
    rel = rel.replaceAll(sep, '/');
    if (rel.isEmpty) continue;
    try {
      files[rel] = await entity.readAsBytes();
    } catch (_) {
      // 读不动的文件（占用/权限）跳过，不阻断整包导入。
    }
  }

  return PackFolderPick(
    supported: true,
    canceled: false,
    rootName: _baseName(dir.path),
    files: files,
  );
}

/// 取路径末段目录名（去掉结尾分隔符）。
String _baseName(String p) {
  var s = p;
  while (s.length > 1 && (s.endsWith('/') || s.endsWith(r'\'))) {
    s = s.substring(0, s.length - 1);
  }
  final i = s.lastIndexOf(RegExp(r'[\\/]'));
  return i >= 0 ? s.substring(i + 1) : s;
}
