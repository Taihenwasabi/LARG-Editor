/// mp4（ISO-BMFF）容器解析器。
///
/// 遍历 box 树（ftyp/moov/mdat…），从 moov>mvhd 取整体时长，从每个
/// moov>trak>mdia 取轨道类型(vide/soun)、编码(avc1/mp4a)、分辨率/采样率，
/// 并记录 mdat 大小。**不解码视频帧**，实际播放交由运行时播放器组件。
library;

import 'dart:typed_data';

import '../engine_exception.dart';
import '../model/asset_info.dart';

/// 一个 box 的位置信息。
class _Box {
  final String type; // 4CC
  final int contentStart; // 头部之后（内容起点，独占）
  final int end; // box 结束（独占）
  const _Box(this.type, this.contentStart, this.end);
}

/// mp4 容器解析器。
class Mp4Parser {
  Mp4Parser._();

  /// 解析 mp4 字节流，产出 [Mp4Info]。
  static Mp4Info parse(Uint8List bytes) {
    final bd = ByteData.sublistView(bytes);
    final top = _children(bytes, bd, 0, bytes.length);
    if (top.isEmpty) {
      throw const PackageFormatException('mp4 无法识别任何 box，非法');
    }

    var majorBrand = '?';
    var mdatSize = 0;
    var durationSeconds = 0.0;
    final tracks = <Mp4Track>[];

    for (final box in top) {
      switch (box.type) {
        case 'ftyp':
          majorBrand = _fourcc(bytes, box.contentStart);
        case 'mdat':
          mdatSize = box.end - (box.contentStart - 8);
        case 'moov':
          _parseMoov(bytes, bd, box, tracks);
          final mvhd = _findFirst(bytes, bd, box, 'mvhd');
          if (mvhd != null) durationSeconds = _headerDuration(bytes, bd, mvhd);
      }
    }

    return Mp4Info(
      majorBrand: majorBrand,
      durationSeconds: durationSeconds,
      tracks: tracks,
      mdatSize: mdatSize,
    );
  }

  /// 解析 moov 下的每个 trak。
  static void _parseMoov(
    Uint8List bytes,
    ByteData bd,
    _Box moov,
    List<Mp4Track> tracks,
  ) {
    for (final child in _children(bytes, bd, moov.contentStart, moov.end)) {
      if (child.type != 'trak') continue;
      final hdlr = _findFirst(bytes, bd, child, 'hdlr');
      final stsd = _findFirst(bytes, bd, child, 'stsd');
      final handlerType = hdlr == null ? '' : _fourcc(bytes, hdlr.contentStart + 8);
      tracks.add(_parseTrack(bytes, bd, handlerType, stsd));
    }
  }

  /// 由 handler 类型 + stsd 首个样本条目还原一条轨道信息。
  static Mp4Track _parseTrack(
    Uint8List bytes,
    ByteData bd,
    String handlerType,
    _Box? stsd,
  ) {
    var codec = '';
    var width = 0;
    var height = 0;
    var sampleRate = 0;
    var channels = 0;

    if (stsd != null) {
      // stsd 内容: version/flags(4) + entry_count(4) + entries...
      final entryStart = stsd.contentStart + 8;
      if (entryStart + 8 <= stsd.end) {
        codec = _fourcc(bytes, entryStart + 4); // 条目 box 的 4CC
        final dataStart = entryStart + 8; // 跳过条目 box 头(size+format)
        if (handlerType == 'vide') {
          width = _u16(bytes, bd, dataStart + 24);
          height = _u16(bytes, bd, dataStart + 26);
        } else if (handlerType == 'soun') {
          channels = _u16(bytes, bd, dataStart + 16);
          // samplerate 为 16.16 定点，高 16 位才是整数 Hz
          sampleRate = _u32(bytes, bd, dataStart + 24) >> 16;
        }
      }
    }

    final type = switch (handlerType) {
      'vide' => 'vide',
      'soun' => 'soun',
      _ => handlerType.isEmpty ? 'unkn' : handlerType,
    };
    return Mp4Track(
      type: type,
      codec: codec,
      width: width,
      height: height,
      sampleRate: sampleRate,
      channels: channels,
    );
  }

  /// mvhd/mdhd 的时长（秒）：version 0 用 32 位字段，version 1 用 64 位。
  static double _headerDuration(Uint8List bytes, ByteData bd, _Box box) {
    final version = _u8(bytes, box.contentStart);
    if (version == 1) {
      final timescale = _u32(bytes, bd, box.contentStart + 20);
      final duration = _u64(bytes, bd, box.contentStart + 24);
      return timescale == 0 ? 0 : duration / timescale;
    }
    final timescale = _u32(bytes, bd, box.contentStart + 12);
    final duration = _u32(bytes, bd, box.contentStart + 16);
    return timescale == 0 ? 0 : duration / timescale;
  }

  /// 列出 [start,end) 内的同级 box。
  static List<_Box> _children(
    Uint8List bytes,
    ByteData bd,
    int start,
    int end,
  ) {
    final result = <_Box>[];
    var off = start;
    while (off + 8 <= end) {
      var size = _u32(bytes, bd, off);
      final type = _fourcc(bytes, off + 4);
      var headerEnd = off + 8;
      if (size == 1) {
        // 64 位 largesize
        size = _u64(bytes, bd, off + 8);
        headerEnd = off + 16;
      } else if (size == 0) {
        size = end - off; // 延伸到父级末尾
      }
      if (size < 8) break; // 防御：非法 box 大小
      final boxEnd = off + size > end ? end : off + size;
      result.add(_Box(type, headerEnd, boxEnd));
      off = off + size;
    }
    return result;
  }

  /// 在 box 子树内递归查找首个指定类型的 box。
  static _Box? _findFirst(
    Uint8List bytes,
    ByteData bd,
    _Box box,
    String type,
  ) {
    for (final child in _children(bytes, bd, box.contentStart, box.end)) {
      if (child.type == type) return child;
      final deep = _findFirst(bytes, bd, child, type);
      if (deep != null) return deep;
    }
    return null;
  }

  // ---- 边界安全的基础读取 ----

  static int _u8(Uint8List b, int o) => (o >= 0 && o < b.length) ? b[o] : 0;

  static int _u16(Uint8List b, ByteData bd, int o) =>
      (o >= 0 && o + 2 <= b.length) ? bd.getUint16(o, Endian.big) : 0;

  static int _u32(Uint8List b, ByteData bd, int o) =>
      (o >= 0 && o + 4 <= b.length) ? bd.getUint32(o, Endian.big) : 0;

  static int _u64(Uint8List b, ByteData bd, int o) =>
      (o >= 0 && o + 8 <= b.length) ? bd.getUint64(o, Endian.big) : 0;

  /// 读取 4 字节 ASCII fourcc。
  static String _fourcc(Uint8List b, int o) {
    if (o < 0 || o + 4 > b.length) return '';
    final sb = StringBuffer();
    for (var i = 0; i < 4; i++) {
      final c = b[o + i];
      sb.writeCharCode(c == 0 ? 0x20 : c);
    }
    return sb.toString().trim();
  }
}
