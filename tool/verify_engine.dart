/// 引擎自检脚本（开发工具）。
///
/// 运行：`dart run tool/verify_engine.dart`（默认扫工作区 `gamepacks`）
/// 或 `dart run tool/verify_engine.dart <根目录>`。
///
/// 引擎核心是纯 Dart，因此无需启动 Flutter 即可验证解析全链路。
library;

import 'package:larg_editor/component/engine.dart';

void main(List<String> args) {
  final root = args.isNotEmpty ? args.first : 'gamepacks';

  final engine = GameEngine(
    tokenProvider: InMemoryTokenProvider('self-check-token'),
  );
  engine.configure(root);

  final packages = engine.listPackages();
  if (packages.isEmpty) {
    EngineLog.warn('根目录下没有任何游戏包（需含 basicInfo.json 的子目录）');
    return;
  }

  var okCount = 0;
  for (final name in packages) {
    try {
      final pkg = engine.load(name);
      _printDetail(pkg);
      okCount++;
    } on EngineException catch (e) {
      EngineLog.log('❌ $name 解析失败 | $e');
    } catch (e, st) {
      EngineLog.log('❌ $name 意外错误 | $e');
      EngineLog.step('$st');
    }
  }

  EngineLog.log('自检结束：成功 $okCount / 共 ${packages.length} 个包');
}

void _printDetail(GamePackage pkg) {
  EngineLog.step('— 明细 ${pkg.name} —');
  for (final stage in pkg.stages) {
    EngineLog.step(
      'stage ${stage.id}: ${stage.lines.length} 行台词, '
      '${stage.checkpoints.length} 个选项',
      indent: 2,
    );
    for (final cp in stage.checkpoints) {
      EngineLog.step('· $cp', indent: 3);
    }
  }
  for (final entry in pkg.checks.entries) {
    EngineLog.step(
      'check ${entry.key}: type=${entry.value.type} '
      'verify=${entry.value.verify} params=${entry.value.params}',
      indent: 2,
    );
  }
  for (final asset in pkg.assets) {
    if (asset.info != null) {
      EngineLog.step('asset ${asset.fileName}: ${asset.info}', indent: 2);
    }
  }
}
