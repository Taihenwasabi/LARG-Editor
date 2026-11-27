/// 包媒体「按字节」渲染接缝。
///
/// 本地导入 / 编辑器保存的游戏包，其媒体（图/音/视频）随 zip 全量注入
/// [MemoryPackageSource]，但**不在** Flutter asset bundle 里，故 `Image.asset` /
/// asset 控制器取不到 → 黑屏。这里统一提供：
/// - [packMediaBytes]：命中内存则返回字节（本地包），否则 null（官方包）；
/// - [loadPackMediaBytes]：先内存、再回退 `rootBundle`（音/视频用）；
/// - [packImageProvider] / [PackImage]：有字节走 memory，否则走 asset（图片用）。
///
/// 让官方包与本地包在**同一套调用**下一致工作，调用点无需关心来源。
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:larg_editor/store/game_packages.dart';

/// 内存中已持有的本地包媒体字节；官方包 / 非包资源返回 null。
Uint8List? packMediaBytes(String assetKey) => GamePackages.tryMediaBytes(assetKey);

/// 取媒体字节：优先内存（本地包），否则回退 asset bundle（官方包）。
Future<Uint8List> loadPackMediaBytes(String assetKey) async {
  final mem = GamePackages.tryMediaBytes(assetKey);
  if (mem != null) return mem;
  final bd = await rootBundle.load(assetKey);
  return bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
}

/// 图片 [ImageProvider]：优先内存字节，否则 asset。供 PhotoView 等直接消费。
ImageProvider packImageProvider(String assetKey) {
  final b = GamePackages.tryMediaBytes(assetKey);
  return b != null ? MemoryImage(b) : AssetImage(assetKey);
}

/// 跨官方 / 本地包都能显示的图片：有内存字节用 [Image.memory]，否则 [Image.asset]。
class PackImage extends StatelessWidget {
  final String assetKey;
  final BoxFit fit;
  final double? width;
  final double? height;
  final ImageErrorWidgetBuilder? errorBuilder;

  const PackImage({
    super.key,
    required this.assetKey,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final b = GamePackages.tryMediaBytes(assetKey);
    if (b != null) {
      return Image.memory(
        b,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: errorBuilder,
      );
    }
    return Image.asset(
      assetKey,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: errorBuilder,
    );
  }
}
