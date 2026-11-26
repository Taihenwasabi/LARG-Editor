/// 包「来源」验证机制（占位）。
///
/// 目标：区分**官方游戏包**（随 App 打进 assets / 经服务端签名授权）与
/// **本地游戏包**（编辑器导出、用户 zip 导入）。当前仅为占位：
/// - 用一个官方包名白名单做最朴素判定；
/// - 真实接入时，改为校验包内 `PublicKey` 签名 / 后端下发的授权清单
///   （可复用 [LicenseVerifier] 的思路），其余调用点无需改动。
///
/// 保持纯 Dart，不引 flutter 依赖，与引擎核心一致。
library;

/// 包来源。
enum PackageProvenance {
  /// 官方包（不做特殊标注）。
  official,

  /// 本地包（主页显示时标注「本地」）。
  local,
}

/// 来源验证器抽象（依赖注入点）。
abstract class ProvenanceVerifier {
  PackageProvenance verify(String packageName);
}

/// 占位实现：以官方包名白名单判定；不在名单内的一律视为本地。
///
/// TODO(security): 接入真实签名校验——按包内 PublicKey / 后端授权清单判定官方，
/// 而不是硬编码名单。届时仅需替换本实现，注入点不变。
class AllowListProvenanceVerifier implements ProvenanceVerifier {
  final Set<String> officialPackages;

  const AllowListProvenanceVerifier(this.officialPackages);

  @override
  PackageProvenance verify(String packageName) =>
      officialPackages.contains(packageName)
      ? PackageProvenance.official
      : PackageProvenance.local;
}
