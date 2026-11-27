/// 语言管理：支持的语言、别名规范化、Locale 转换。
///
/// 语言代码规范（遵循 BCP 47）：
/// - 源语言：`en`
/// - 目标语言：`zh-CN`、`ja`
///
/// 兼容：旧版持久化里存的是 `zh`——视为 `zh-CN` 的别名，读取时统一归一化。
/// 支持列表不硬编码于业务代码，任何扩展只需 [supported] 增项 + 补一份 JSON。
library;

import 'package:flutter/material.dart';

/// 语言常量与工具。
class LocaleCodes {
  LocaleCodes._();

  /// 源语言（fallback 终点，也是查不到时的兜底语言）。
  static const String source = 'en';

  /// 当前项目支持的语言列表（顺序即 UI 展示顺序）。
  static const List<String> supported = ['en', 'zh-CN', 'ja'];

  /// 别名表：把旧代码里可能出现的写法归一化到标准码。
  static const Map<String, String> _aliases = {
    'zh': 'zh-CN',
    'zh_CN': 'zh-CN',
    'zh-Hans': 'zh-CN',
    'en-US': 'en',
    'en_GB': 'en',
  };

  /// 把任意输入归一化到 [supported] 中的标准码；无法识别返回 [source]。
  static String normalize(String? input) {
    if (input == null || input.isEmpty) return source;
    if (supported.contains(input)) return input;
    final mapped = _aliases[input];
    if (mapped != null && supported.contains(mapped)) return mapped;
    // 前缀匹配：`zh_TW` → `zh-CN`；`ja-JP` → `ja`
    final base = input.split(RegExp('[-_]')).first;
    if (supported.contains(base)) return base;
    final aliased = _aliases[base];
    if (aliased != null && supported.contains(aliased)) return aliased;
    return source;
  }

  /// 转 [Locale]（供 MaterialApp.locale 使用）。
  static Locale toLocale(String code) {
    final parts = code.split('-');
    if (parts.length >= 2) {
      return Locale(parts.first, parts.sublist(1).join('-'));
    }
    return Locale(code);
  }

  /// 供 MaterialApp.supportedLocales 使用。
  static List<Locale> get locales => supported.map(toLocale).toList();
}
