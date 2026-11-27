/// AI 判定结果的解析（契约：decision / texts / reasons / items / voice）。
///
/// 这是与 AI 的**唯一契约**，从 quq1 原样移植，两边必须一致。
/// 解析失败一律抛 [AiResponseFormatException]，由界面展示可读原因。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:larg_editor/api/ai_chat.dart';
import 'package:larg_editor/model/game_item.dart';

class AiGeneratedItem {
  final GameItemKind kind;
  final String name;
  final String mime;
  final Uint8List bytes;

  const AiGeneratedItem({
    required this.kind,
    required this.name,
    required this.mime,
    required this.bytes,
  });
}

class AiVerdict {
  final bool passed;
  final List<String> texts;
  final Uint8List? voice;
  final List<AiGeneratedItem> items;
  final List<String> reasons;

  const AiVerdict({
    required this.passed,
    required this.texts,
    required this.voice,
    required this.items,
    this.reasons = const [],
  });
}

class _DecodedContent {
  final Uint8List bytes;
  final String mime;

  const _DecodedContent(this.bytes, this.mime);
}

class AiResponseFormatException implements Exception {
  final String message;

  const AiResponseFormatException(this.message);

  @override
  String toString() => message;
}

class AiVerdictParser {
  static Future<AiVerdict> parse(String raw, {int maxTextSegments = 1}) async {
    final data = _decodeJsonObject(raw);
    final decision = data['decision'];
    if (decision != 'yes' && decision != 'no') {
      throw const AiResponseFormatException('AI 返回的 decision 不是 yes/no');
    }

    final reasons = <String>[];
    final rawReasons = data['reasons'];
    if (rawReasons is List) {
      for (final e in rawReasons) {
        final value = e is String ? e.trim() : '';
        if (value.isEmpty) continue;
        reasons.add(value.length > 200 ? value.substring(0, 200) : value);
        if (reasons.length >= 10) break;
      }
    }

    final maxSegments = maxTextSegments.clamp(1, 10);
    final rawTexts = data['texts'];
    final texts = <String>[];
    if (rawTexts != null) {
      if (rawTexts is! List || rawTexts.length > maxSegments) {
        throw AiResponseFormatException('texts 最多 $maxSegments 段');
      }
      for (final e in rawTexts) {
        final value = e is String ? e.trim() : '';
        if (value.isEmpty || value.length >= 100) {
          throw const AiResponseFormatException('每段文字必须少于 100 字');
        }
        texts.add(value);
      }
    }

    Uint8List? voice;
    final rawVoice = data['voice'];
    if (rawVoice != null) {
      voice = (await _decodeContent(rawVoice, 'audio/wav')).bytes;
    }

    final items = <AiGeneratedItem>[];
    final rawItems = data['items'];
    if (rawItems != null) {
      if (rawItems is! List) {
        throw const AiResponseFormatException('items 必须是数组');
      }
      for (final entry in rawItems) {
        if (entry is! Map) continue;
        final kind = _kindOf(entry['kind']);
        final name = (entry['name'] ?? '').toString().trim();
        final content = entry['content'];
        if (kind == null || name.isEmpty || content == null) {
          throw const AiResponseFormatException('items 字段不完整');
        }
        final decoded = await _decodeItemContent(kind, content);
        items.add(
          AiGeneratedItem(
            kind: kind,
            name: name,
            mime: decoded.mime,
            bytes: decoded.bytes,
          ),
        );
      }
    }

    return AiVerdict(
      passed: decision == 'yes',
      texts: texts,
      voice: voice,
      items: items,
      reasons: reasons,
    );
  }

  static Map<String, dynamic> _decodeJsonObject(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      final firstBreak = text.indexOf('\n');
      if (firstBreak > 0) text = text.substring(firstBreak + 1);
      if (text.endsWith('```')) text = text.substring(0, text.length - 3);
      text = text.trim();
    }
    final dynamic value;
    try {
      value = jsonDecode(text);
    } on FormatException {
      throw const AiResponseFormatException('AI 返回的不是合法 JSON');
    }
    if (value is! Map<String, dynamic>) {
      throw const AiResponseFormatException('AI 响应必须是 JSON 对象');
    }
    return value;
  }

  static GameItemKind? _kindOf(Object? value) {
    for (final kind in GameItemKind.values) {
      if (kind.name == value) return kind;
    }
    return null;
  }

  static Future<_DecodedContent> _decodeItemContent(
    GameItemKind kind,
    Object? content,
  ) async {
    if (kind == GameItemKind.text) {
      final value = content is String ? content.trim() : '';
      if (value.isEmpty) {
        throw const AiResponseFormatException('文本物品内容不能为空');
      }
      return _DecodedContent(
        Uint8List.fromList(utf8.encode(value)),
        'text/plain',
      );
    }
    return _decodeContent(content, _mimeOf(kind));
  }

  static Future<_DecodedContent> _decodeContent(
    Object? content,
    String defaultMime,
  ) async {
    final value = content is String ? content.trim() : '';
    if (value.isEmpty) throw const AiResponseFormatException('内容不能为空');
    final dataMatch = RegExp(r'^data:([^;]+);base64,').firstMatch(value);
    if (dataMatch != null) {
      return _DecodedContent(
        base64Decode(value.substring(dataMatch.end)),
        dataMatch.group(1) ?? defaultMime,
      );
    }
    if (value.startsWith('http://') || value.startsWith('https://')) {
      final bytes = await AiChatApi.instance.fetchBytes(value);
      return _DecodedContent(bytes, _mimeFromUrl(value, defaultMime));
    }
    return _DecodedContent(base64Decode(value), defaultMime);
  }

  static String _mimeFromUrl(String url, String defaultMime) {
    final path = (Uri.tryParse(url)?.path ?? '').toLowerCase();
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return defaultMime;
    return _extMimes[path.substring(dot + 1)] ?? defaultMime;
  }

  static const Map<String, String> _extMimes = {
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'webp': 'image/webp',
    'gif': 'image/gif',
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'm4a': 'audio/mp4',
    'aac': 'audio/aac',
    'ogg': 'audio/ogg',
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'webm': 'video/webm',
    'm4v': 'video/x-m4v',
  };

  static String _mimeOf(GameItemKind kind) => switch (kind) {
    GameItemKind.text => 'text/plain',
    GameItemKind.image => 'image/png',
    GameItemKind.audio => 'audio/wav',
    GameItemKind.video => 'video/mp4',
  };
}
