// ignore_for_file: avoid_print

/// 引擎统一日志助手。
///
/// 所有解析步骤通过 [EngineLog] 打印，带统一 `[Engine]` 前缀，可全局开关
/// （默认开）。核心保持纯 Dart，只用 `print`，不依赖 flutter。
library;

/// 引擎日志开关与前缀工具。
class EngineLog {
  EngineLog._();

  /// 是否输出日志，默认开（满足"解析全程 print 日志"）。
  static bool enabled = true;

  /// 统一前缀。
  static const String prefix = '[Engine]';

  /// 输出一行普通日志。
  static void log(String message) {
    if (enabled) print('$prefix $message');
  }

  /// 输出带缩进的子步骤日志（用于逐项列举 stage/asset 等）。
  static void step(String message, {int indent = 1}) {
    if (enabled) print('$prefix ${'  ' * indent}$message');
  }

  /// 输出分隔线，标记一个包的加载开始。
  static void section(String title) {
    if (enabled) print('$prefix ── $title ──');
  }

  /// 输出警告（仍带前缀，便于在日志流中辨识）。
  static void warn(String message) {
    if (enabled) print('$prefix ⚠️ $message');
  }
}
