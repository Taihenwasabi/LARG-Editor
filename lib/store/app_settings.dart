/// AI 裁判配置：只保存用户自己在设置里填的 OpenAI 兼容接口参数。
///
/// 无后端、无内置密钥：不填就只用本地判定，任何提交都不会离机。
library;

import 'package:shared_preferences/shared_preferences.dart';

/// 一个厂商预设：名称 + 默认接口地址 + 可选模型清单。
class AiProviderPreset {
  final String id;
  final String label;
  final String baseUrl;
  final List<String> models;

  const AiProviderPreset({
    required this.id,
    required this.label,
    required this.baseUrl,
    required this.models,
  });
}

/// 内置的常用厂商（都是 OpenAI 兼容协议）。
const List<AiProviderPreset> kAiProviders = [
  AiProviderPreset(
    id: 'deepseek',
    label: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com',
    models: ['deepseek-chat'],
  ),
  AiProviderPreset(
    id: 'openai',
    label: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
    models: ['gpt-4o-mini', 'gpt-4o'],
  ),
  AiProviderPreset(
    id: 'dashscope',
    label: '阿里云百炼',
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    models: ['qwen-plus', 'qwen-turbo'],
  ),
  AiProviderPreset(
    id: 'moonshot',
    label: 'Moonshot',
    baseUrl: 'https://api.moonshot.cn/v1',
    models: ['moonshot-v1-8k'],
  ),
  AiProviderPreset(
    id: 'ollama',
    label: '本地 Ollama',
    baseUrl: 'http://127.0.0.1:11434/v1',
    models: ['qwen2.5'],
  ),
  AiProviderPreset(
    id: 'custom',
    label: '自定义',
    baseUrl: '',
    models: [],
  ),
];

/// AI 配置（内存态 + 持久化）。
class AiConfig {
  String providerId;
  String baseUrl;
  String model;
  String apiKey;
  int connectTimeoutSeconds;
  int receiveTimeoutSeconds;
  int maxTextSegments;
  int maxSegmentChars;

  AiConfig({
    this.providerId = 'deepseek',
    this.baseUrl = 'https://api.deepseek.com',
    this.model = 'deepseek-chat',
    this.apiKey = '',
    this.connectTimeoutSeconds = 20,
    this.receiveTimeoutSeconds = 60,
    this.maxTextSegments = 1,
    this.maxSegmentChars = 100,
  });

  bool get ready =>
      apiKey.trim().isNotEmpty &&
      baseUrl.trim().isNotEmpty &&
      model.trim().isNotEmpty;

  /// 聊天补全地址：兼容填了 /v1 与没填 /v1 两种写法。
  String get chatEndpoint {
    var base = baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.endsWith('/chat/completions')) return base;
    return '$base/chat/completions';
  }

  String get modelsEndpoint {
    var base = baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return '$base/models';
  }

  AiConfig copy() => AiConfig(
    providerId: providerId,
    baseUrl: baseUrl,
    model: model,
    apiKey: apiKey,
    connectTimeoutSeconds: connectTimeoutSeconds,
    receiveTimeoutSeconds: receiveTimeoutSeconds,
    maxTextSegments: maxTextSegments,
    maxSegmentChars: maxSegmentChars,
  );
}

/// 设置中心：AI 配置 + 语言（当前只做中文）。
class AppSettings {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  static const String _kProvider = 'ai.provider';
  static const String _kBaseUrl = 'ai.baseUrl';
  static const String _kModel = 'ai.model';
  static const String _kApiKey = 'ai.apiKey';
  static const String _kConnect = 'ai.connectSeconds';
  static const String _kReceive = 'ai.receiveSeconds';
  static const String _kSegments = 'ai.maxSegments';
  static const String _kSegmentChars = 'ai.maxSegmentChars';

  final AiConfig ai = AiConfig();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    ai
      ..providerId = prefs.getString(_kProvider) ?? ai.providerId
      ..baseUrl = prefs.getString(_kBaseUrl) ?? ai.baseUrl
      ..model = prefs.getString(_kModel) ?? ai.model
      ..apiKey = prefs.getString(_kApiKey) ?? ai.apiKey
      ..connectTimeoutSeconds = prefs.getInt(_kConnect) ?? ai.connectTimeoutSeconds
      ..receiveTimeoutSeconds = prefs.getInt(_kReceive) ?? ai.receiveTimeoutSeconds
      ..maxTextSegments = prefs.getInt(_kSegments) ?? ai.maxTextSegments
      ..maxSegmentChars = prefs.getInt(_kSegmentChars) ?? ai.maxSegmentChars;
  }

  Future<void> saveAi() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProvider, ai.providerId);
    await prefs.setString(_kBaseUrl, ai.baseUrl);
    await prefs.setString(_kModel, ai.model);
    await prefs.setString(_kApiKey, ai.apiKey);
    await prefs.setInt(_kConnect, ai.connectTimeoutSeconds);
    await prefs.setInt(_kReceive, ai.receiveTimeoutSeconds);
    await prefs.setInt(_kSegments, ai.maxTextSegments);
    await prefs.setInt(_kSegmentChars, ai.maxSegmentChars);
  }

  /// 切换厂商时带出默认地址与模型（用户仍可覆盖）。
  void applyProvider(String id, {bool keepKey = true}) {
    final preset = kAiProviders.firstWhere(
      (p) => p.id == id,
      orElse: () => kAiProviders.last,
    );
    ai.providerId = preset.id;
    ai.baseUrl = preset.baseUrl;
    ai.model = preset.models.isEmpty ? '' : preset.models.first;
    if (!keepKey) ai.apiKey = '';
  }
}
