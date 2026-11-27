/// 游戏包自检——引擎侧唯一实现（纯 Dart，零 flutter 依赖）。
///
/// 对应 [PACK_FORMAT.md] 的「导出前自检清单」。**CLI 与编辑器 UI 共用这一份**，
/// 不各写一套判定。
///
/// 自检做的是**引用完整性**检查：结构合法性由解析器负责（JSON 不合法会直接
/// 抛 [PackageFormatException]），自检查的是「引用了不存在的东西」这类
/// 解析器看不出来、但玩家一玩就断的问题。
library;

import 'model/game_package.dart';
import 'source/package_source.dart';

/// 自检问题的一条。
class PackIssue {
  /// 问题码（稳定标识，供 UI 做本地化与分类）。
  final String code;

  /// 出问题的文件相对路径（若可知）。
  final String? source;

  /// 说明（人话，直接可展示）。
  final String message;

  const PackIssue(this.code, this.message, {this.source});
}

/// 自检结果。
class PackReport {
  final List<PackIssue> issues;

  /// 是否有阻断性问题（引用缺失 / 素材缺失 —— 玩家会卡住）。
  bool get hasBlocking => issues.isNotEmpty;

  const PackReport(this.issues);

  /// 通过时返回 null，否则返回第一条问题的可读描述。
  String? get summary =>
      issues.isEmpty ? null : '${issues.length} 个问题：${issues.first.message}';
}

/// 游戏包自检器。
class PackDoctor {
  PackDoctor._();

  /// 检查一个已加载的游戏包。
  ///
  /// [source] 用于核对素材路径是否真实存在；为空时跳过素材存在性检查。
  static PackReport inspect(GamePackage pkg, {PackageSource? source}) {
    final issues = <PackIssue>[];

    _checkManifest(pkg, issues);
    _checkStageLinks(pkg, issues);
    _checkCheckLinks(pkg, issues);
    _checkItemLinks(pkg, issues);
    if (source != null) {
      _checkAssets(pkg, source, issues);
    }

    return PackReport(issues);
  }

  static void _checkManifest(GamePackage pkg, List<PackIssue> issues) {
    final m = pkg.manifest;
    if (m.gameName.trim().isEmpty) {
      issues.add(const PackIssue('manifest.name', '包名（gameName）不能为空'));
    }
    if (m.id.trim().isEmpty) {
      issues.add(
        const PackIssue('manifest.id', '包 id（Id）为空，正式发布前建议补上'),
      );
    }
  }

  static void _checkStageLinks(GamePackage pkg, List<PackIssue> issues) {
    for (final stage in pkg.stages) {
      for (final cp in stage.checkpoints) {
        final next = cp.next;
        if (next == null || next.trim().isEmpty) continue;
        if (pkg.stageById(next) != null) continue;
        issues.add(
          PackIssue(
            'stage.nextMissing',
            '关卡「${stage.id}」的选项「${cp.text}」要跳到不存在的关卡「$next」',
            source: 'stage/${stage.sourceFile}',
          ),
        );
      }
    }
  }

  static void _checkCheckLinks(GamePackage pkg, List<PackIssue> issues) {
    for (final stage in pkg.stages) {
      for (final cp in stage.checkpoints) {
        final ref = cp.check;
        if (ref == null || ref.trim().isEmpty) continue;
        final id = _stripExt(ref);
        if (pkg.checks.containsKey(id)) continue;
        issues.add(
          PackIssue(
            'stage.checkMissing',
            '关卡「${stage.id}」的选项「${cp.text}」引用了不存在的校验「$ref」',
            source: 'stage/${stage.sourceFile}',
          ),
        );
      }
    }
  }

  static void _checkItemLinks(GamePackage pkg, List<PackIssue> issues) {
    for (final stage in pkg.stages) {
      for (final cp in stage.checkpoints) {
        if (cp.grant.isNotEmpty) {
          for (final itemId in cp.grant.keys) {
            if (pkg.items.containsKey(itemId)) continue;
            issues.add(
              PackIssue(
                'stage.grantMissing',
                '关卡「${stage.id}」要发放不存在的物品「$itemId」',
                source: 'stage/${stage.sourceFile}',
              ),
            );
          }
        }
        final cond = cp.condition;
        if (cond == null || cond.trim().isEmpty) continue;
        for (final itemId in _conditionItemIds(cond)) {
          if (pkg.items.containsKey(itemId)) continue;
          issues.add(
            PackIssue(
              'stage.conditionMissing',
              '关卡「${stage.id}」的条件引用了不存在的物品「$itemId」',
              source: 'stage/${stage.sourceFile}',
            ),
          );
        }
      }
    }
  }

  static void _checkAssets(
    GamePackage pkg,
    PackageSource source,
    List<PackIssue> issues,
  ) {
    final seen = <String>{};
    for (final stage in pkg.stages) {
      _checkAssetRef(
        pkg,
        source,
        issues,
        seen,
        stage.background,
        'stage/${stage.sourceFile}',
        '关卡背景',
      );
      _checkAssetRef(
        pkg,
        source,
        issues,
        seen,
        stage.bgm,
        'stage/${stage.sourceFile}',
        '关卡音乐',
      );
      for (final line in stage.lines) {
        final where = 'stage/${stage.sourceFile}';
        _checkAssetRef(pkg, source, issues, seen, line.background, where, '台词背景');
        _checkAssetRef(pkg, source, issues, seen, line.image, where, '台词图片');
        _checkAssetRef(pkg, source, issues, seen, line.audio, where, '台词音频');
        _checkAssetRef(pkg, source, issues, seen, line.video, where, '台词视频');
        for (final sprite in line.sprites) {
          _checkAssetRef(
            pkg,
            source,
            issues,
            seen,
            sprite.asset,
            where,
            '立绘',
          );
        }
      }
    }
    for (final item in pkg.items.values) {
      if (item.asset.isEmpty) continue;
      _checkAssetRef(
        pkg,
        source,
        issues,
        seen,
        item.asset,
        'item/${item.id}.json',
        '物品素材',
      );
    }
  }

  static void _checkAssetRef(
    GamePackage pkg,
    PackageSource source,
    List<PackIssue> issues,
    Set<String> seen,
    String? path,
    String sourceFile,
    String label,
  ) {
    final p = path?.trim() ?? '';
    if (p.isEmpty) return;
    if (!seen.add(p)) return;
    if (source.fileExists(pkg.name, p)) return;
    issues.add(
      PackIssue(
        'asset.missing',
        '$label 引用的素材「$p」不存在',
        source: sourceFile,
      ),
    );
  }

  static String _stripExt(String ref) {
    final slash = ref.lastIndexOf('/');
    var s = slash >= 0 ? ref.substring(slash + 1) : ref;
    final dot = s.lastIndexOf('.');
    if (dot > 0) s = s.substring(0, dot);
    return s;
  }

  /// 从条件表达式里取出物品 id（形如 `map>=1 && gem==2`）。
  static List<String> _conditionItemIds(String condition) {
    final out = <String>[];
    for (final part in condition.split('&&')) {
      final m = RegExp(r'^\s*([^\s<>=!]+)').firstMatch(part);
      if (m != null) out.add(m.group(1)!);
    }
    return out;
  }
}
