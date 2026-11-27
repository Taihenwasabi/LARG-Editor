/// 视频控制器工厂——非 web 平台实现（Android/iOS/Windows/macOS/Linux）。
///
/// 策略：**读资源字节 → 写临时文件 → `VideoPlayerController.file`**，规避
/// `VideoPlayerController.asset` 对含空格 / 非 ASCII 名、以及大文件在部分平台
/// 抽取失败的问题；若临时文件方式仍失败（例如编码不支持），**探测式回退**到
/// `.asset`，两者任一能播即播。落盘经 `service/mediaStore` 这层可迁移接口。
library;

import 'dart:io';

import 'package:larg_editor/component/pack_media.dart';
import 'package:larg_editor/service/media_store.dart';
import 'package:video_player/video_player.dart';

/// 依据资源键创建并初始化视频控制器。
Future<VideoPlayerController> createVideoController(String assetKey) async {
  // 首选：字节 → 临时文件 → file 控制器
  try {
    // 本地包媒体优先内存字节；官方包回退 rootBundle（loadPackMediaBytes）。
    final bytes = await loadPackMediaBytes(assetKey);
    final name = assetKey.split('/').last;
    final path = await writeTempMedia(name, bytes);
    if (path != null) {
      final c = VideoPlayerController.file(File(path));
      await c.initialize();
      // ignore: avoid_print
      print('[video][io] 临时文件方式初始化成功：$path');
      return c;
    }
  } catch (e) {
    // ignore: avoid_print
    print('[video][io] 临时文件方式失败，回退 asset：$e');
  }
  // 回退：直接 asset 控制器（若也失败则抛给上层展示失败占位）
  final controller = VideoPlayerController.asset(assetKey);
  await controller.initialize();
  return controller;
}
