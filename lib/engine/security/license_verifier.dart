/// 资格（License）校验：PublicKey 抽象 + 演示实现，以及 token 注入接口。
///
/// 引擎核心保持纯 Dart：token 不由核心直接读取，而是通过依赖注入的
/// [TokenProvider] 接入——App 层用 shared_preferences 实现，自检脚本用内存
/// 实现。这样核心逻辑可用 `dart run` 独立跑起来验证，无需启动整个 App。
library;

/// 资格校验结果。
class LicenseResult {
  final bool ok;

  /// 状态串，用于汇总日志（OK / FAILED）。
  final String status;

  /// 说明信息。
  final String detail;

  const LicenseResult({
    required this.ok,
    required this.status,
    required this.detail,
  });

  @override
  String toString() => '$status ($detail)';
}

/// token 提供器抽象（依赖注入点）。
///
/// 核心只依赖此接口，不关心 token 从哪来。App 层实现基于 shared_preferences
/// 的持久化版本；自检脚本实现内存版本。
abstract class TokenProvider {
  /// 读取当前 token；无则返回 null。
  String? getToken();

  /// 写入 token（null 表示清除）。
  void setToken(String? token);
}

/// 内存版 TokenProvider，供自检脚本 / 测试使用（核心零依赖）。
class InMemoryTokenProvider implements TokenProvider {
  String? _token;

  InMemoryTokenProvider([this._token]);

  @override
  String? getToken() => _token;

  @override
  void setToken(String? token) => _token = token;
}

/// 资格校验器抽象。日后接入真 RSA/ECDSA 签名校验时替换实现即可。
abstract class LicenseVerifier {
  LicenseResult verify({
    required String packageName,
    required String publicKey,
    TokenProvider? tokenProvider,
  });
}

/// 演示实现：仅做"公钥非空"这类最低限度检查，不做真实密码学校验。
///
/// 目的：让全链路能跑通并打印可读日志；真 RSA 校验日后可换成
/// 另一个 [LicenseVerifier] 实现而不影响其它模块。
class DemoLicenseVerifier implements LicenseVerifier {
  const DemoLicenseVerifier();

  @override
  LicenseResult verify({
    required String packageName,
    required String publicKey,
    TokenProvider? tokenProvider,
  }) {
    if (publicKey.trim().isEmpty) {
      return const LicenseResult(
        ok: false,
        status: 'FAILED',
        detail: '缺少 PublicKey',
      );
    }
    final masked = publicKey.length > 8
        ? '${publicKey.substring(0, 8)}...'
        : publicKey;
    final hasToken = (tokenProvider?.getToken() ?? '').isNotEmpty;
    return LicenseResult(
      ok: true,
      status: 'OK',
      detail: 'PublicKey=$masked → OK(演示实现${hasToken ? ', 已带token' : ''})',
    );
  }
}
