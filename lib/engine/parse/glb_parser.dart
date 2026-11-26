/// glTF 二进制容器（.glb）解析器。
///
/// 只解析"容器结构与场景图元数据"：12 字节头（magic/version/length）+ 分块
/// （JSON chunk / BIN chunk），并从 JSON chunk 统计 scenes/nodes/meshes/
/// materials/textures/animations/images 的数量与名字。**不解码顶点二进制缓冲**，
/// 实际渲染交由运行时 3D 组件。
library;

import 'dart:convert';
import 'dart:typed_data';

import '../engine_exception.dart';
import '../model/asset_info.dart';

/// glb 容器解析器。
class GlbParser {
  GlbParser._();

  /// 小端 magic：ASCII "glTF"。
  static const int _magic = 0x46546C67;

  /// 分块类型："JSON"。
  static const int _chunkJson = 0x4E4F534A;

  /// 分块类型："BIN\0"。
  static const int _chunkBin = 0x004E4942;

  /// 解析 glb 字节流，产出 [GlbInfo]。
  static GlbInfo parse(Uint8List bytes) {
    if (bytes.length < 12) {
      throw const PackageFormatException('glb 不足 12 字节头，非法');
    }
    final bd = ByteData.sublistView(bytes);
    final magic = bd.getUint32(0, Endian.little);
    if (magic != _magic) {
      throw PackageFormatException(
        'glb magic 不符: 0x${magic.toRadixString(16)} (应为 0x46546c67)',
      );
    }
    final version = bd.getUint32(4, Endian.little);
    final totalLength = bd.getUint32(8, Endian.little);

    var offset = 12;
    var hasJson = false;
    var hasBin = false;
    var jsonLen = 0;
    var binLen = 0;
    Map<String, dynamic>? gltf;

    // 遍历分块：每块 = chunkLength(4) + chunkType(4) + data(chunkLength)
    while (offset + 8 <= bytes.length) {
      final chunkLength = bd.getUint32(offset, Endian.little);
      final chunkType = bd.getUint32(offset + 4, Endian.little);
      final dataStart = offset + 8;
      final dataEnd = dataStart + chunkLength;
      if (chunkType == _chunkJson) {
        hasJson = true;
        jsonLen = chunkLength;
        final safeEnd = dataEnd > bytes.length ? bytes.length : dataEnd;
        final text = utf8.decode(
          bytes.sublist(dataStart, safeEnd),
          allowMalformed: true,
        );
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) gltf = decoded;
      } else if (chunkType == _chunkBin) {
        hasBin = true;
        binLen = chunkLength;
      }
      if (chunkLength <= 0) break; // 防御：异常块长
      offset = dataEnd;
    }

    return GlbInfo(
      version: version,
      totalLength: totalLength,
      actualLength: bytes.length,
      hasJsonChunk: hasJson,
      hasBinChunk: hasBin,
      jsonChunkLength: jsonLen,
      binChunkLength: binLen,
      sceneCount: _count(gltf, 'scenes'),
      nodeCount: _count(gltf, 'nodes'),
      meshCount: _count(gltf, 'meshes'),
      materialCount: _count(gltf, 'materials'),
      textureCount: _count(gltf, 'textures'),
      animationCount: _count(gltf, 'animations'),
      imageCount: _count(gltf, 'images'),
      meshNames: _names(gltf, 'meshes'),
      materialNames: _names(gltf, 'materials'),
      animationNames: _names(gltf, 'animations'),
      lengthConsistent: totalLength == bytes.length,
    );
  }

  static int _count(Map<String, dynamic>? gltf, String key) {
    final v = gltf?[key];
    return v is List ? v.length : 0;
  }

  static List<String> _names(Map<String, dynamic>? gltf, String key) {
    final v = gltf?[key];
    if (v is! List) return const [];
    final result = <String>[];
    for (final item in v) {
      if (item is Map && item['name'] != null) {
        result.add(item['name'].toString());
      }
    }
    return result;
  }
}
