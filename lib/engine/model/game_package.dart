/// 游戏包（GamePackage）聚合根模型。
///
/// 由 package_loader 编排各解析器组装而成，是一个包被完整加载后的内存表示：
/// 清单 + 关卡列表 + 校验表 + 资源清单 + 资格校验结果。
library;

import '../security/license_verifier.dart';
import 'asset_ref.dart';
import 'check.dart';
import 'manifest.dart';
import 'package_summary.dart';
import 'stage.dart';
import 'story_item.dart';

/// 一个完整加载的游戏包。
class GamePackage {
  /// 包名（目录名，如 `jubenyouEg2`）。
  final String name;

  /// 包根目录绝对路径。
  final String rootPath;

  final Manifest manifest;
  final List<Stage> stages;

  /// 校验表：key 为 check id（如 `check1`）。
  final Map<String, Check> checks;

  /// 剧情物品表（道具与数值）：key 为 item id，来自 `item/*.json`。
  final Map<String, StoryItem> items;

  final List<AssetRef> assets;
  final LicenseResult license;

  /// 加载耗时（毫秒），用于汇总日志。
  final int elapsedMs;

  const GamePackage({
    required this.name,
    required this.rootPath,
    required this.manifest,
    required this.stages,
    required this.checks,
    this.items = const {},
    required this.assets,
    required this.license,
    required this.elapsedMs,
  });

  /// 物品 id → 显示名；未声明时原样返回 id（保证不崩、且拼错可见）。
  String itemName(String id) => items[id]?.name ?? id;

  /// 依据 id 查找关卡。
  Stage? stageById(String id) {
    for (final s in stages) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// 生成汇总。
  PackageSummary summary() => PackageSummary(
    packageName: name,
    success: true,
    stageCount: stages.length,
    checkCount: checks.length,
    assetCount: assets.length,
    licenseStatus: license.status,
    elapsedMs: elapsedMs,
  );
}
