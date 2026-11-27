/// OpenAI 兼容接口调用（仅 AI 裁判使用）。
///
/// 只打用户在设置里填的地址；不内置任何密钥、不上报调用内容。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:larg_editor/store/app_settings.dart';

class AiCallException implements Exception {
  final String message;

  const AiCallException(this.message);

  @override
  String toString() => message;
}

class AiChatApi {
  AiChatApi._();

  static final AiChatApi instance = AiChatApi._();

  AiConfig get _config => AppSettings.instance.ai;

  Future<List<String>> fetchModels() async {
    final config = _config;
    try {
      final res = await Dio(_options(config)).get(config.modelsEndpoint);
      final data = res.data;
      if (data is! Map) return const [];
      final models = data['data'];
      if (models is! List) return const [];
      return models
          .map((e) => e is Map ? e['id']?.toString() ?? '' : '')
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (e) {
      throw AiCallException(_dioMessage(e));
    }
  }

  Future<String> complete({
    required String prompt,
    List<Uint8List> images = const [],
    List<Uint8List> audio = const [],
  }) async {
    final config = _config;
    final content = <Map<String, dynamic>>[
      {'type': 'text', 'text': prompt},
      for (final image in images)
        {
          'type': 'image_url',
          'image_url': {
            'url': 'data:image/webp;base64,${base64Encode(image)}',
            'detail': 'low',
          },
        },
      for (final wav in audio)
        {
          'type': 'input_audio',
          'input_audio': {'data': base64Encode(wav), 'format': 'wav'},
        },
    ];

    try {
      final res = await Dio(_options(config)).post(
        config.chatEndpoint,
        data: {
          'model': config.model,
          'temperature': 0,
          'messages': [
            {'role': 'user', 'content': content},
          ],
        },
      );
      final data = res.data;
      if (data is! Map) throw const AiCallException('AI 返回不是对象');
      final choices = data['choices'];
      if (choices is! List || choices.isEmpty) {
        throw const AiCallException('AI 返回缺少 choices');
      }
      final first = choices.first;
      final message = first is Map ? first['message'] : null;
      final text = message is Map ? message['content'] : null;
      if (text is! String || text.trim().isEmpty) {
        throw const AiCallException('AI 返回空内容');
      }
      return text;
    } on DioException catch (e) {
      throw AiCallException(_dioMessage(e));
    }
  }

  /// 测试连接：发一句 ping，返回耗时（毫秒）。
  Future<int> testConnection() async {
    final config = _config;
    final watch = Stopwatch()..start();
    try {
      final res = await Dio(_options(config)).post(
        config.chatEndpoint,
        data: {
          'model': config.model,
          'temperature': 0,
          'messages': [
            {'role': 'user', 'content': 'ping'},
          ],
        },
      );
      final code = res.statusCode ?? 0;
      if (code < 200 || code >= 300) throw AiCallException('HTTP $code');
      return watch.elapsedMilliseconds;
    } on DioException catch (e) {
      throw AiCallException(_dioMessage(e));
    }
  }

  Future<Uint8List> fetchBytes(String url) async {
    try {
      final res = await Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 120),
          responseType: ResponseType.bytes,
          validateStatus: (code) => code != null && code < 400,
        ),
      ).get<List<int>>(url);
      final data = res.data ?? const <int>[];
      if (data.isEmpty) throw const AiCallException('返回内容为空');
      return Uint8List.fromList(data);
    } on DioException catch (e) {
      throw AiCallException(_dioMessage(e));
    }
  }

  static BaseOptions _options(AiConfig config) {
    final receive = config.receiveTimeoutSeconds;
    return BaseOptions(
      connectTimeout: Duration(seconds: config.connectTimeoutSeconds),
      sendTimeout: Duration(seconds: receive),
      receiveTimeout: Duration(seconds: receive),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (config.apiKey.isNotEmpty) 'Authorization': 'Bearer ${config.apiKey}',
      },
      validateStatus: (code) => code != null && code < 400,
    );
  }

  static String _dioMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final error = data['error'];
      if (error is Map && error['message'] is String) {
        return error['message'] as String;
      }
      if (data['message'] is String) return data['message'] as String;
    }
    if (e.response?.statusCode != null) return 'HTTP ${e.response!.statusCode}';
    if (e.type == DioExceptionType.connectionTimeout) return '连接超时，检查接口地址';
    if (e.type == DioExceptionType.receiveTimeout) return '等待回复超时';
    if (e.type == DioExceptionType.connectionError) return '连不上接口，检查网络或地址';
    return 'AI 请求失败：${e.message ?? e.type.name}';
  }
}
