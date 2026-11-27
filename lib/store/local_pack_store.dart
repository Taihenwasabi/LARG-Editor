/// 本地游戏包仓库（编辑器「保存」/zip 导入的落地处）。
///
/// 把编辑器导出的一份游戏包（zip 字节）持久化，并维护一份轻量索引
/// （包名 / 显示名 / 简介），供主页列出并标注「本地」、以及点击时回灌给
/// 引擎游玩。zip **字节**经 [localPackBytes] 跨平台落盘：原生侧用
/// path_provider 写真实文件（不受配额限制），web 退回 base64 存储。
/// 索引很小，统一存于 shared_preferences。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:larg_editor/store/local_pack_bytes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 本地包索引条目（列表展示用，不含媒体字节）。
class LocalPackEntry {
  final String id; // 游戏 id（引擎加载键 + zip 字节存储键，唯一）
  final String displayName; // 游戏名
  final String introduction; // 简介

  const LocalPackEntry({
    required this.id,
    required this.displayName,
    required this.introduction,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'introduction': introduction,
  };

  factory LocalPackEntry.fromJson(Map<String, dynamic> j) => LocalPackEntry(
    id: (j['id'] ?? j['name'] ?? '').toString(),
    displayName: (j['displayName'] ?? '').toString(),
    introduction: (j['introduction'] ?? '').toString(),
  );
}

/// 本地包读写门面（全静态）。
class LocalPackStore {
  LocalPackStore._();

  static const String _indexKey = 'localPacks.index';

  /// 仓库变更信号（保存 / 删除后自增）：PackCatalog 监听后自动重扫，
  /// 使「本地」页在编辑器保存、zip 导入、删除后即时刷新，无需重进。
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  /// 保存一份 zip 到本地库（按游戏 id 覆盖同名/同 id）。写入失败（配额等）返回 false。
  static Future<bool> saveZip(
    String id,
    Uint8List zipBytes, {
    required String displayName,
    required String introduction,
  }) async {
    final ok = await saveZipBytes(id, zipBytes);
    if (!ok) return false;
    final prefs = await SharedPreferences.getInstance();
    final list = await _readIndex(prefs);
    list.removeWhere((e) => e.id == id);
    list.insert(
      0,
      LocalPackEntry(
        id: id,
        displayName: displayName,
        introduction: introduction,
      ),
    );
    await _writeIndex(prefs, list);
    changes.value++;
    return true;
  }

  /// 列出全部本地包（按保存时间倒序）。
  static Future<List<LocalPackEntry>> list() async {
    final prefs = await SharedPreferences.getInstance();
    return _readIndex(prefs);
  }

  /// 读取某本地包的 zip 字节（不存在返回 null）。
  static Future<Uint8List?> loadZip(String id) => readZipBytes(id);

  /// 删除一个本地包（字节 + 索引）。
  static Future<void> remove(String id) async {
    await deleteZipBytes(id);
    final prefs = await SharedPreferences.getInstance();
    final list = await _readIndex(prefs);
    list.removeWhere((e) => e.id == id);
    await _writeIndex(prefs, list);
    changes.value++;
  }

  static Future<List<LocalPackEntry>> _readIndex(SharedPreferences prefs) async {
    final raw = prefs.getString(_indexKey);
    if (raw == null) return <LocalPackEntry>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => LocalPackEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return <LocalPackEntry>[];
  }

  static Future<void> _writeIndex(
    SharedPreferences prefs,
    List<LocalPackEntry> list,
  ) async {
    await prefs.setString(
      _indexKey,
      jsonEncode([for (final e in list) e.toJson()]),
    );
  }
}
