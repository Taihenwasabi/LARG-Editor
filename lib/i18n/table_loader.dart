/// 全局表 & 模块表加载器。
///
/// 全局表固定路径：`lib/i18n/tables/<lang>.json`。
/// 模块表按注册路径懒加载：`registerModule(name, dir)` 后，
/// 首次 `t(key, module: name)` 会读 `<dir><lang>.json`（若不存在则静默跳过）。
///
/// JSON 支持两种写法：
/// - 扁平：`{"login.title": "Sign In", ...}`
/// - 嵌套：`{"login": {"title": "Sign In", ...}}`（读入时自动展平为点分键）
library;

import 'dart:convert';

import 'package:flutter/services.dart';

/// 单张表的内存结构：key → 值。
typedef TranslationTable = Map<String, String>;

/// 加载器：负责 IO、缓存、语言切换清缓存、远程热更新入口。
class TableLoader {
  TableLoader();

  /// 全局表缓存：lang → 已展平的 map。
  final Map<String, TranslationTable> _global = {};

  /// 模块表缓存：module → lang → 已展平的 map。
  final Map<String, Map<String, TranslationTable>> _modules = {};

  /// 模块的资产目录（注册后 `t(key, module: x)` 才知道去哪找）。
  final Map<String, String> _moduleDirs = {};

  /// 全局表目录（相对项目根，Flutter 资源键）。
  static const String globalDir = 'lib/i18n/tables/';

  /// 已读取过的全局表语言集合（避免重复 IO；即使表为空也算读过）。
  final Set<String> _globalLoaded = <String>{};

  /// 已读取过的 (module, lang) 组合。
  final Set<String> _moduleLoaded = <String>{};

  /// 载入全局表；已缓存则直接返回。缺失语言不抛异常，返回空表。
  Future<TranslationTable> loadGlobal(String lang) async {
    if (_globalLoaded.contains(lang)) return _global[lang] ?? const {};
    final raw = await _readAsset('$globalDir$lang.json');
    _global[lang] = _flatten(raw);
    _globalLoaded.add(lang);
    // ignore: avoid_print
    print('[i18n] 全局表 $lang 就绪：展平后 ${_global[lang]!.length} 个 key');
    return _global[lang]!;
  }

  /// 注册模块的 i18n 目录（结尾必须带 `/`），并预热当前语言的表。
  void registerModule(String module, String assetDir) {
    _moduleDirs[module] = assetDir;
  }

  /// 懒加载某模块某语言的表；未注册或文件缺失返回空表。
  Future<TranslationTable> loadModule(String module, String lang) async {
    final dir = _moduleDirs[module];
    if (dir == null) return const {};
    final tag = '$module#$lang';
    if (_moduleLoaded.contains(tag)) return _modules[module]?[lang] ?? const {};
    final raw = await _readAsset('$dir$lang.json');
    _modules.putIfAbsent(module, () => {})[lang] = _flatten(raw);
    _moduleLoaded.add(tag);
    return _modules[module]![lang]!;
  }

  /// 立即获取（可能未加载）——`t()` 保持同步的关键。
  /// 调用方应先通过 [loadGlobal] / [loadModule] 预热；未预热的返回 null。
  TranslationTable? peekGlobal(String lang) => _global[lang];

  /// 同上，针对模块。
  TranslationTable? peekModule(String module, String lang) =>
      _modules[module]?[lang];

  /// 语言切换：清全局缓存 + 标记所有模块表过期。
  /// 下次调用 `loadGlobal/loadModule` 会重新拉取。
  void invalidateAll() {
    _global.clear();
    _globalLoaded.clear();
    _modules.clear();
    _moduleLoaded.clear();
  }

  /// 远程热更新入口（占位）：外部拿到与 JSON 同结构的 Map 后灌入内存。
  void overrideGlobal(String lang, Map<String, dynamic> nestedOrFlat) {
    _global[lang] = _flatten(nestedOrFlat);
    _globalLoaded.add(lang);
  }

  /// 从 rootBundle 读 JSON；不存在或解析失败返回空 map（不抛），
  /// 但**必 print 错误源**：静默空表会让界面悄悄回落 en，排查无能见度。
  Future<Map<String, dynamic>> _readAsset(String key) async {
    try {
      final s = await rootBundle.loadString(key);
      final parsed = jsonDecode(s);
      if (parsed is Map<String, dynamic>) {
        // ignore: avoid_print
        print('[i18n] 加载成功：$key（顶层分组 ${parsed.length} 个）');
        return parsed;
      }
      // ignore: avoid_print
      print('[i18n] 加载失败：$key 内容不是 JSON 对象（实际：${parsed.runtimeType}）');
      return const {};
    } catch (e) {
      // ignore: avoid_print
      print('[i18n] 加载失败：$key → $e '
          '（若是新增的表，需完全重启 flutter run 重新打包 assets）');
      return const {};
    }
  }

  /// 把（可能嵌套的）JSON 展平为点分键。
  TranslationTable _flatten(Map<String, dynamic> src) {
    final out = <String, String>{};
    void walk(String prefix, dynamic node) {
      if (node is Map) {
        node.forEach((k, v) {
          final key = prefix.isEmpty ? '$k' : '$prefix.$k';
          walk(key, v);
        });
      } else if (node is String) {
        out[prefix] = node;
      } else if (node != null) {
        out[prefix] = node.toString();
      }
    }

    walk('', src);
    return out;
  }
}
