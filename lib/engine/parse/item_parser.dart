/// Item 解析器：`item/*.json` → `Map<id, StoryItem>`。
///
/// 剧情物品（道具与数值）由包声明，id 取文件名去扩展名；关卡分支用 id
/// 引用它（`grant` 发放、`condition` 判定）。空文件跳过并告警。
library;

import 'dart:convert';

import '../engine_exception.dart';
import '../engine_log.dart';
import '../model/story_item.dart';
import '../source/package_source.dart';

class ItemParser {
  ItemParser._();

  static const String itemDir = 'item';

  static Map<String, StoryItem> parse(PackageSource source, String packageName) {
    final files = source
        .listFiles(packageName, itemDir)
        .where((p) => p.toLowerCase().endsWith('.json'))
        .toList()
      ..sort();

    final items = <String, StoryItem>{};
    for (final path in files) {
      final fileName = path.split('/').last;
      final text = source.readText(packageName, path);
      if (text.trim().isEmpty) {
        EngineLog.warn('item/$fileName 为空文件，跳过');
        continue;
      }
      final dot = fileName.lastIndexOf('.');
      final fallbackId = dot > 0 ? fileName.substring(0, dot) : fileName;
      final dynamic decoded;
      try {
        decoded = jsonDecode(text);
      } on FormatException catch (e) {
        throw PackageFormatException(
          'item JSON 非法（请先修正为合法 JSON）: ${e.message}',
          source: path,
        );
      }
      if (decoded is! Map<String, dynamic>) {
        throw PackageFormatException('item JSON 顶层应为对象', source: path);
      }
      final item = StoryItem.fromJson(decoded, fallbackId: fallbackId);
      items[item.id] = item;
    }

    EngineLog.log('item x${items.length}: ${items.keys.join(',')}');
    return items;
  }
}
