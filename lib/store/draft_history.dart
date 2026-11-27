/// 编辑器「编辑历史」——一组手动保存的草稿快照（仅 JSON 文本，不含媒体字节）。
///
/// 与自动去抖草稿（单槽 `editor.draft`）不同，这里是用户点「保存」时显式落下的
/// 多份历史，按包名归并、时间倒序，供「最近项目」列表回看并载入继续编辑。存于
/// shared_preferences（文本量小）；媒体字节仍依赖磁盘缓存，过期后可能需重新导入。
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 一条编辑历史（草稿快照元数据 + 草稿 JSON）。
class DraftEntry {
  final String id; // 归并键（一般为包名）
  final String title; // 显示名（游戏名 / 包名）
  final String subtitle; // 副标题（简介）
  final int savedAt; // 保存时间（ms since epoch）
  final String json; // 草稿 JSON（EditablePack.toDraftJson 产物）

  const DraftEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.savedAt,
    required this.json,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'savedAt': savedAt,
    'json': json,
  };

  factory DraftEntry.fromJson(Map<String, dynamic> j) => DraftEntry(
    id: (j['id'] ?? '').toString(),
    title: (j['title'] ?? '').toString(),
    subtitle: (j['subtitle'] ?? '').toString(),
    savedAt: (j['savedAt'] as num?)?.toInt() ?? 0,
    json: (j['json'] ?? '').toString(),
  );
}

/// 编辑历史读写门面（全静态）。
class DraftHistory {
  DraftHistory._();

  static const String _indexKey = 'editor.draft.history';
  static const int _max = 12;

  /// 保存一份草稿到历史：同 id 覆盖并置顶，超出 [_max] 丢弃最旧。
  static Future<void> upsert(DraftEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await _read(prefs);
    list.removeWhere((e) => e.id == entry.id);
    list.insert(0, entry);
    if (list.length > _max) list.removeRange(_max, list.length);
    await _write(prefs, list);
  }

  /// 列出全部历史（按保存时间倒序）。
  static Future<List<DraftEntry>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final list = await _read(prefs);
    list.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return list;
  }

  /// 删除一条历史。
  static Future<void> remove(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await _read(prefs);
    list.removeWhere((e) => e.id == id);
    await _write(prefs, list);
  }

  static Future<List<DraftEntry>> _read(SharedPreferences prefs) async {
    final raw = prefs.getString(_indexKey);
    if (raw == null) return <DraftEntry>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => DraftEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return <DraftEntry>[];
  }

  static Future<void> _write(
    SharedPreferences prefs,
    List<DraftEntry> list,
  ) async {
    await prefs.setString(
      _indexKey,
      jsonEncode([for (final e in list) e.toJson()]),
    );
  }
}
