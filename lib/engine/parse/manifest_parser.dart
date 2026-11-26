/// Manifest 解析器：`basicInfo.json` → [Manifest]。
///
/// 不做容错解析：直接 `jsonDecode`，数据须为合法 JSON（否则抛
/// [PackageFormatException]，提示先修正源文件）。
library;

import 'dart:convert';

import '../engine_exception.dart';
import '../engine_log.dart';
import '../model/manifest.dart';
import '../source/package_source.dart';

/// 解析游戏包清单。
class ManifestParser {
  ManifestParser._();

  /// 清单文件名。
  static const String manifestFileName = 'basicInfo.json';

  static Manifest parse(PackageSource source, String packageName) {
    if (!source.fileExists(packageName, manifestFileName)) {
      throw PackageNotFoundException(
        packageName,
        '缺少清单文件 $manifestFileName',
      );
    }
    final text = source.readText(packageName, manifestFileName);
    EngineLog.log('读取 manifest: $manifestFileName (${text.length} 字符)');

    final decoded = _decodeJson(text, manifestFileName);
    final manifest = Manifest.fromJson(decoded);

    EngineLog.log('manifest: $manifest');
    EngineLog.step('Introduction: ${manifest.introduction}');
    EngineLog.step('createTime=${manifest.createTime} '
        'PublicKey=${_mask(manifest.publicKey)}');
    for (final b in manifest.buttonCoordinates) {
      EngineLog.step('button $b');
    }
    return manifest;
  }

  /// 统一 JSON 解码，把底层异常转成引擎异常。
  static Map<String, dynamic> _decodeJson(String text, String source) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        throw PackageFormatException(
          'JSON 顶层应为对象，实际为 ${decoded.runtimeType}',
          source: source,
        );
      }
      return decoded;
    } on FormatException catch (e) {
      throw PackageFormatException(
        'JSON 非法（本项目不做容错，请先修正为合法 JSON）: ${e.message}',
        source: source,
      );
    }
  }

  static String _mask(String key) {
    if (key.isEmpty) return '(空)';
    return key.length > 8 ? '${key.substring(0, 8)}...' : key;
  }
}
