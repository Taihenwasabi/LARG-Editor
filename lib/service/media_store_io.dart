/// 媒体落盘——原生实现（真实文件系统 + path_provider）。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// 把字节写成临时文件，返回绝对路径（供 video_player 以 file 方式播放）。
/// [fileName] 会被清洗为安全字符，规避非 ASCII / 空格引发的原生路径坑。
Future<String?> writeTempMedia(String fileName, Uint8List bytes) async {
  final base = await getTemporaryDirectory();
  final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final path = '${base.path}${Platform.pathSeparator}$stamp-$safe';
  final f = File(path);
  await f.writeAsBytes(bytes, flush: true);
  return f.path;
}

/// 缓存目录：`<支持目录>/quq1_media_cache/`。
Future<Directory> _cacheRoot() async {
  final base = await getApplicationSupportDirectory();
  final dir = Directory(
    '${base.path}${Platform.pathSeparator}quq1_media_cache',
  );
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

/// 持久化一份编辑器媒体字节（相对包路径为键），重开 App 后仍在。
Future<void> cacheMedia(String relKey, Uint8List bytes) async {
  final root = await _cacheRoot();
  final file = File('${root.path}${Platform.pathSeparator}$relKey');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
}

/// 读回缓存的媒体字节；不存在返回 null。
Future<Uint8List?> loadCachedMedia(String relKey) async {
  final root = await _cacheRoot();
  final file = File('${root.path}${Platform.pathSeparator}$relKey');
  if (await file.exists()) return file.readAsBytes();
  return null;
}
