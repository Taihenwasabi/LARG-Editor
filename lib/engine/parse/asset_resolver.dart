/// 资源解析器：扫描 `assets/`，按扩展名分派，汇总 [AssetRef] 列表。
///
/// - glb / mp4：调用结构化解析器，产出容器与元数据（见 glb_parser/mp4_parser）；
/// - png / wav：轻量读取头信息（尺寸 / 采样率）；
/// - 其它（fbx / txt 等）：仅登记路径与字节数，不深解析。
///
/// 单个资源解析失败只告警、不中断整包加载（资源问题不应导致包不可用）。
library;

import 'dart:typed_data';

import '../engine_log.dart';
import '../model/asset_info.dart';
import '../model/asset_ref.dart';
import '../source/package_source.dart';
import 'glb_parser.dart';
import 'mp4_parser.dart';

/// 扫描并解析游戏包资源。
class AssetResolver {
  AssetResolver._();

  /// 资源根目录（相对包根）。
  static const String assetsDir = 'assets';

  static List<AssetRef> resolve(PackageSource source, String packageName) {
    final paths = source.listFiles(packageName, assetsDir);
    final refs = <AssetRef>[];

    for (final path in paths) {
      final fileName = path.split('/').last;
      final ext = _extOf(fileName);
      final category = AssetRef.categoryOf(ext);
      final size = source.fileSize(packageName, path);

      AssetInfo? info;
      // 仅对需要结构化解析的类型读取字节，避免为 fbx 等大文件无谓读盘
      if (_needsBytes(ext) && size > 0) {
        try {
          final bytes = source.readBytes(packageName, path);
          info = _parseBytes(ext, bytes);
        } catch (e) {
          EngineLog.warn('资源解析失败 $path: $e（仅登记，不中断）');
        }
      }

      refs.add(
        AssetRef(
          relativePath: path,
          fileName: fileName,
          extension: ext,
          category: category,
          sizeBytes: size,
          info: info,
        ),
      );
    }

    EngineLog.log('asset x${refs.length}:');
    for (final r in refs) {
      EngineLog.step('$r');
    }
    return refs;
  }

  static bool _needsBytes(String ext) =>
      const {'glb', 'mp4', 'png', 'wav'}.contains(ext);

  static AssetInfo? _parseBytes(String ext, Uint8List bytes) {
    switch (ext) {
      case 'glb':
        return GlbParser.parse(bytes);
      case 'mp4':
        return Mp4Parser.parse(bytes);
      case 'png':
        return _parsePng(bytes);
      case 'wav':
        return _parseWav(bytes);
      default:
        return null;
    }
  }

  /// png：8 字节签名后紧跟 IHDR，宽在高前，均为大端 32 位。
  static PngInfo? _parsePng(Uint8List b) {
    if (b.length < 24) return null;
    final bd = ByteData.sublistView(b);
    // 校验 png 签名
    const sig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    for (var i = 0; i < sig.length; i++) {
      if (b[i] != sig[i]) return null;
    }
    final width = bd.getUint32(16, Endian.big);
    final height = bd.getUint32(20, Endian.big);
    return PngInfo(width: width, height: height);
  }

  /// wav：RIFF 容器，遍历子块取 "fmt " 与 "data"。
  static WavInfo? _parseWav(Uint8List b) {
    if (b.length < 12) return null;
    final bd = ByteData.sublistView(b);
    if (_tag(b, 0) != 'RIFF' || _tag(b, 8) != 'WAVE') return null;

    var channels = 0;
    var sampleRate = 0;
    var bits = 0;
    var byteRate = 0;
    var dataSize = 0;

    var off = 12;
    while (off + 8 <= b.length) {
      final id = _tag(b, off);
      final size = bd.getUint32(off + 4, Endian.little);
      final data = off + 8;
      if (id == 'fmt ') {
        channels = bd.getUint16(data + 2, Endian.little);
        sampleRate = bd.getUint32(data + 4, Endian.little);
        byteRate = bd.getUint32(data + 8, Endian.little);
        bits = bd.getUint16(data + 14, Endian.little);
      } else if (id == 'data') {
        dataSize = size;
      }
      // 子块按 2 字节对齐
      off = data + size + (size.isOdd ? 1 : 0);
    }

    final duration = byteRate == 0 ? 0.0 : dataSize / byteRate;
    return WavInfo(
      channels: channels,
      sampleRate: sampleRate,
      bitsPerSample: bits,
      durationSeconds: duration,
    );
  }

  static String _tag(Uint8List b, int o) {
    if (o < 0 || o + 4 > b.length) return '';
    return String.fromCharCodes(b.sublist(o, o + 4));
  }

  static String _extOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  }
}
