/// 游戏包加载编排者（PackageLoader）。
///
/// 分步调用：来源扫描 → manifest → license → stage → check → assets → 组装
/// [GamePackage]。每步一个小方法（非巨函数），并在关键节点打日志，便于观察。
library;

import 'engine_exception.dart';
import 'engine_log.dart';
import 'model/check.dart';
import 'model/game_package.dart';
import 'model/manifest.dart';
import 'model/asset_ref.dart';
import 'model/stage.dart';
import 'model/story_item.dart';
import 'parse/asset_resolver.dart';
import 'parse/check_parser.dart';
import 'parse/item_parser.dart';
import 'parse/manifest_parser.dart';
import 'parse/stage_parser.dart';
import 'security/license_verifier.dart';
import 'source/package_source.dart';

/// 编排一次完整的游戏包加载。
class PackageLoader {
  final PackageSource source;
  final LicenseVerifier licenseVerifier;
  final TokenProvider? tokenProvider;

  PackageLoader({
    required this.source,
    this.licenseVerifier = const DemoLicenseVerifier(),
    this.tokenProvider,
  });

  /// 列出根目录下所有可用包名。
  List<String> listPackages() {
    final names = source.scanPackages();
    EngineLog.log('扫描包... 发现 ${names.length} 个'
        '${names.isEmpty ? '' : ': ${names.join(', ')}'}');
    return names;
  }

  /// 加载指定包，返回完整的 [GamePackage]。
  GamePackage load(String packageName) {
    final sw = Stopwatch()..start();
    EngineLog.section('加载 $packageName');

    if (!source.packageExists(packageName)) {
      throw PackageNotFoundException(packageName, '包目录不存在: $packageName');
    }

    final manifest = _parseManifest(packageName);
    final license = _verifyLicense(packageName, manifest);
    final stages = _parseStages(packageName);
    final checks = _parseChecks(packageName);
    final items = ItemParser.parse(source, packageName);
    final assets = _resolveAssets(packageName);
    _validateReferences(packageName, stages, checks, items);

    sw.stop();
    final pkg = GamePackage(
      name: packageName,
      rootPath: source.root,
      manifest: manifest,
      stages: stages,
      checks: checks,
      items: items,
      assets: assets,
      license: license,
      elapsedMs: sw.elapsedMilliseconds,
    );
    EngineLog.log(pkg.summary().toString());
    return pkg;
  }

  // ---- 每一步一个小方法 ----

  Manifest _parseManifest(String packageName) =>
      ManifestParser.parse(source, packageName);

  LicenseResult _verifyLicense(String packageName, Manifest manifest) {
    final result = licenseVerifier.verify(
      packageName: packageName,
      publicKey: manifest.publicKey,
      tokenProvider: tokenProvider,
    );
    EngineLog.log('License: ${result.detail}');
    return result;
  }

  List<Stage> _parseStages(String packageName) =>
      StageParser.parse(source, packageName);

  Map<String, Check> _parseChecks(String packageName) =>
      CheckParser.parse(source, packageName);

  List<AssetRef> _resolveAssets(String packageName) =>
      AssetResolver.resolve(source, packageName);

  /// 交叉校验：关卡引用的 check 是否都存在（仅告警，不阻断）。
  void _validateReferences(
    String packageName,
    List<Stage> stages,
    Map<String, Check> checks,
    Map<String, StoryItem> items,
  ) {
    for (final stage in stages) {
      for (final cp in stage.checkpoints) {
        final ref = cp.check;
        if (ref != null) {
          final id = normalizeCheckId(ref);
          if (!checks.containsKey(id)) {
            EngineLog.warn('${stage.id} 引用的 check "$ref" 未在 check/ 中找到');
          }
        }
        for (final id in cp.grant.keys) {
          if (!items.containsKey(id)) {
            EngineLog.warn(
              '${stage.id} 的发放项 "$id" 未在 item/ 中定义，将被忽略',
            );
          }
        }
        for (final id in _conditionItemIds(cp.condition)) {
          if (!items.containsKey(id)) {
            EngineLog.warn(
              '${stage.id} 的条件引用了未定义的物品 "$id"，该选项永远不会出现',
            );
          }
        }
      }
    }
  }

  /// 取出条件表达式里引用的物品 id（供交叉校验告警）。
  static List<String> _conditionItemIds(String? condition) {
    final text = condition?.trim() ?? '';
    if (text.isEmpty) return const [];
    return [
      for (final part in text.split('&&'))
        part.split(RegExp(r'(>=|<=|==|!=|>|<)')).first.trim(),
    ].where((e) => e.isNotEmpty).toList();
  }

  /// 归一化 check 引用：去掉可能的 `.json` 扩展名。
  static String normalizeCheckId(String ref) {
    final lower = ref.toLowerCase();
    return lower.endsWith('.json') ? ref.substring(0, ref.length - 5) : ref;
  }
}
