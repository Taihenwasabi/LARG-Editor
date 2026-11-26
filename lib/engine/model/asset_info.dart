/// 资源元数据模型（AssetInfo 家族）。
///
/// 引擎只解析二进制容器的"结构与元数据"，不解码/渲染：
/// - [GlbInfo]：glTF 二进制容器（12 字节头 + JSON/BIN 分块）里的场景图统计；
/// - [Mp4Info]：ISO-BMFF box 树里的时长/轨道/编码/分辨率；
/// - [PngInfo]/[WavInfo]：轻量头信息（尺寸/采样率）。
///
/// 真正把模型画出来、把视频播出来，是运行时组件（渲染器/播放器）的职责。
library;

/// 资源元数据的公共基类。
abstract class AssetInfo {
  /// 资源类别标签，用于日志与分派（glb/mp4/png/wav）。
  String get kind;
}

/// glTF 二进制（.glb）容器与场景图元数据。
class GlbInfo implements AssetInfo {
  @override
  String get kind => 'glb';

  final int version; // glTF 版本，通常为 2
  final int totalLength; // 头部声明的总长度
  final int actualLength; // 文件实际字节数
  final bool hasJsonChunk;
  final bool hasBinChunk;
  final int jsonChunkLength;
  final int binChunkLength;

  // 场景图统计（来自 JSON chunk）
  final int sceneCount;
  final int nodeCount;
  final int meshCount;
  final int materialCount;
  final int textureCount;
  final int animationCount;
  final int imageCount;
  final List<String> meshNames;
  final List<String> materialNames;
  final List<String> animationNames;

  /// 头部声明长度与实际文件长度是否一致。
  final bool lengthConsistent;

  const GlbInfo({
    required this.version,
    required this.totalLength,
    required this.actualLength,
    required this.hasJsonChunk,
    required this.hasBinChunk,
    required this.jsonChunkLength,
    required this.binChunkLength,
    required this.sceneCount,
    required this.nodeCount,
    required this.meshCount,
    required this.materialCount,
    required this.textureCount,
    required this.animationCount,
    required this.imageCount,
    required this.meshNames,
    required this.materialNames,
    required this.animationNames,
    required this.lengthConsistent,
  });

  @override
  String toString() =>
      'glTF v$version, ${totalLength}B, meshes=$meshCount '
      'materials=$materialCount animations=$animationCount '
      'hasBin=$hasBinChunk${lengthConsistent ? '' : ' (长度不符!)'}';
}

/// mp4（ISO-BMFF）里的一条轨道。
class Mp4Track {
  final String type; // vide | soun | 其它
  final String codec; // avc1 | mp4a | ...
  final int width;
  final int height;
  final int sampleRate; // 音频采样率（Hz），视频为 0
  final int channels; // 音频声道数，视频为 0

  const Mp4Track({
    required this.type,
    required this.codec,
    this.width = 0,
    this.height = 0,
    this.sampleRate = 0,
    this.channels = 0,
  });

  @override
  String toString() {
    if (type == 'vide') return 'video $codec ${width}x$height';
    if (type == 'soun') return 'audio $codec ${sampleRate}Hz/${channels}ch';
    return '$type $codec';
  }
}

/// mp4 容器元数据。
class Mp4Info implements AssetInfo {
  @override
  String get kind => 'mp4';

  final String majorBrand; // ftyp 主品牌，如 mp42 / isom
  final double durationSeconds; // 来自 moov>mvhd 的时长（秒）
  final List<Mp4Track> tracks;
  final int mdatSize; // 媒体数据 box 的字节数

  const Mp4Info({
    required this.majorBrand,
    required this.durationSeconds,
    required this.tracks,
    required this.mdatSize,
  });

  @override
  String toString() {
    final t = tracks.map((e) => e.toString()).join(', ');
    return 'ftyp=$majorBrand dur=${durationSeconds.toStringAsFixed(1)}s '
        'tracks=${tracks.length}[$t]';
  }
}

/// png 头信息（IHDR）。
class PngInfo implements AssetInfo {
  @override
  String get kind => 'png';

  final int width;
  final int height;

  const PngInfo({required this.width, required this.height});

  @override
  String toString() => '${width}x$height';
}

/// wav 头信息（fmt 子块）。
class WavInfo implements AssetInfo {
  @override
  String get kind => 'wav';

  final int channels;
  final int sampleRate;
  final int bitsPerSample;
  final double durationSeconds;

  const WavInfo({
    required this.channels,
    required this.sampleRate,
    required this.bitsPerSample,
    required this.durationSeconds,
  });

  @override
  String toString() =>
      '${sampleRate}Hz/${channels}ch/${bitsPerSample}bit '
      '${durationSeconds.toStringAsFixed(1)}s';
}
