/// Stage 解析器：`stage/*.json` → `List<Stage>`。
///
/// 按文件名数字前缀排序；空文件（0 字节 / 全空白）跳过并告警（占位关卡）；
/// 非法 JSON 直接抛 [PackageFormatException]（不做容错）。
library;

import 'dart:convert';

import '../engine_exception.dart';
import '../engine_log.dart';
import '../model/effects.dart';
import '../model/stage.dart';
import '../source/package_source.dart';

/// 解析剧情关卡。
class StageParser {
  StageParser._();

  /// 关卡目录（相对包根）。
  static const String stageDir = 'stage';

  static List<Stage> parse(PackageSource source, String packageName) {
    final files = source
        .listFiles(packageName, stageDir)
        .where((p) => p.toLowerCase().endsWith('.json'))
        .toList();

    // 按文件名数字前缀稳定排序
    files.sort((a, b) {
      final oa = _leadingNumber(a);
      final ob = _leadingNumber(b);
      if (oa != ob) return oa.compareTo(ob);
      return a.compareTo(b);
    });

    final stages = <Stage>[];
    for (final path in files) {
      final fileName = path.split('/').last;
      final text = source.readText(packageName, path);
      if (text.trim().isEmpty) {
        EngineLog.warn('stage/$fileName 为空文件，跳过（占位关卡）');
        continue;
      }
      stages.add(_parseOne(text, fileName, path));
    }

    EngineLog.log('stage x${stages.length}:');
    for (final s in stages) {
      EngineLog.step('$s [file=${s.sourceFile}]');
    }
    return stages;
  }

  static Stage _parseOne(String text, String fileName, String path) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (e) {
      throw PackageFormatException(
        'stage JSON 非法（请先修正为合法 JSON）: ${e.message}',
        source: path,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw PackageFormatException('stage JSON 顶层应为对象', source: path);
    }

    final base = _baseName(fileName);
    final id = (decoded['id'] ?? base).toString();

    final lines = <StageLine>[];
    final rawLines = decoded['lines'];
    if (rawLines is List) {
      for (final item in rawLines) {
        if (item is Map<String, dynamic>) {
          lines.add(StageLine.fromJson(item, index: lines.length));
        }
      }
    }

    final checkpoints = <Checkpoint>[];
    final rawCp = decoded['checkpoint'];
    if (rawCp is List) {
      for (final item in rawCp) {
        if (item is Map<String, dynamic>) {
          checkpoints.add(Checkpoint.fromJson(item));
        }
      }
    }

    return Stage(
      id: id,
      order: _leadingNumber(path),
      sourceFile: fileName,
      lines: lines,
      checkpoints: checkpoints,
      background: decoded['background']?.toString(),
      bgm: decoded['bgm']?.toString(),
      transitionIn: _transitionFx(decoded['fx'], 'transitionIn'),
      transitionOut: _transitionFx(decoded['fx'], 'transitionOut'),
    );
  }

  static List<FxSpec> _transitionFx(dynamic fx, String key) {
    if (fx is! Map) return const [];
    return parseFxList(fx[key]);
  }

  /// 去掉扩展名。
  static String _baseName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot > 0 ? fileName.substring(0, dot) : fileName;
  }

  /// 取「文件名」的数字前缀（只看最后一段路径，目录名不参与）。
  /// 无数字前缀则返回一个大数排到末尾。
  static int _leadingNumber(String path) {
    final fileName = path.split('/').last;
    final match = RegExp(r'^(\d+)').firstMatch(fileName);
    return match == null ? 1 << 30 : int.parse(match.group(1)!);
  }
}
