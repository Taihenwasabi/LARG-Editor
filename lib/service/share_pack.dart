/// 「转发」分享门面——按平台条件导出实现。
///
/// - 原生（Windows/macOS/Linux）：走 [share_pack_io.dart]，调起系统分享面板；
///   Windows/Linux 无系统分享面板时返回 false，由上层回退「另存为」。
library;

export 'share_pack_io.dart';
