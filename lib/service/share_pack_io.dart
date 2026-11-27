/// 「转发」分享——原生实现（dart:io + share_plus）。
///
/// 把 zip 字节写到临时目录，再调起系统分享面板。仅 Android/iOS/macOS 有原生
/// 分享面板；Windows/Linux 返回 false 交上层回退「另存为」。任何异常也返回
/// false，保证调用方总能走安全兜底。
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<bool> shareZip(String fileName, Uint8List bytes) async {
  final p = defaultTargetPlatform;
  final hasSheet =
      p == TargetPlatform.android ||
      p == TargetPlatform.iOS ||
      p == TargetPlatform.macOS;
  if (!hasSheet) return false;
  try {
    final dir = await getTemporaryDirectory();
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final f = File('${dir.path}${Platform.pathSeparator}$safe');
    await f.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(f.path)], subject: safe);
    return true;
  } catch (_) {
    return false;
  }
}
