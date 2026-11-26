/// 游戏包解析汇总（PackageSummary）。
///
/// 一次 load() 完成后的浓缩结果，用于日志末行的 ✅/❌ 汇总与前端展示。
library;

/// 解析汇总。
class PackageSummary {
  final String packageName;
  final bool success;
  final int stageCount;
  final int checkCount;
  final int assetCount;
  final String licenseStatus; // OK / FAILED / ...
  final int elapsedMs;
  final String? errorMessage; // 失败时的原因

  const PackageSummary({
    required this.packageName,
    required this.success,
    required this.stageCount,
    required this.checkCount,
    required this.assetCount,
    required this.licenseStatus,
    required this.elapsedMs,
    this.errorMessage,
  });

  @override
  String toString() {
    final flag = success ? '✅' : '❌';
    final base = '$flag $packageName 解析${success ? '成功' : '失败'} | '
        'stages=$stageCount checks=$checkCount assets=$assetCount '
        'license=$licenseStatus | ${elapsedMs}ms';
    return success ? base : '$base | err=$errorMessage';
  }
}
