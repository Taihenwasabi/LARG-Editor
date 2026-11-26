/// Check 解析器：`check/*.json` → `Map<id, Check>`。
///
/// 只认声明式 JSON；id 取文件名去扩展名（如 `check1`）。关卡里的
/// `check:"check1.json"` 或 `check:"check1"` 由 loader 归一化后与此 id 匹配。
/// 空文件跳过并告警；非法 JSON 抛 [PackageFormatException]（不做容错）。
library;

import 'dart:convert';

import '../engine_exception.dart';
import '../engine_log.dart';
import '../model/check.dart';
import '../source/package_source.dart';

/// 解析校验声明。
class CheckParser {
  CheckParser._();

  /// 校验目录（相对包根）。
  static const String checkDir = 'check';

  static Map<String, Check> parse(PackageSource source, String packageName) {
    final files = source
        .listFiles(packageName, checkDir)
        .where((p) => p.toLowerCase().endsWith('.json'))
        .toList()
      ..sort();

    final checks = <String, Check>{};
    for (final path in files) {
      final fileName = path.split('/').last;
      final text = source.readText(packageName, path);
      if (text.trim().isEmpty) {
        EngineLog.warn('check/$fileName 为空文件，跳过');
        continue;
      }
      final id = _baseName(fileName);
      checks[id] = _parseOne(text, id, path);
    }

    EngineLog.log('check x${checks.length}: '
        '${checks.values.map((c) => c.toString()).join(' ')}');
    return checks;
  }

  static Check _parseOne(String text, String id, String path) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (e) {
      throw PackageFormatException(
        'check JSON 非法（请先修正为合法 JSON）: ${e.message}',
        source: path,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw PackageFormatException(
        'check JSON 顶层应为对象（形如 {"type":...,"verify":...}）',
        source: path,
      );
    }
    return Check.fromJson(id, decoded);
  }

  static String _baseName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot > 0 ? fileName.substring(0, dot) : fileName;
  }
}
