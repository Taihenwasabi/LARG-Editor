/// 统一翻译入口。**业务代码只调 [t]**，不直接读任何 JSON / 加载器。
///
/// 查表优先级（严格）：
/// 1. 若传了 `module:`，先查该模块表当前语言。
/// 2. 查全局表当前语言。
/// 3. 查全局表源语言 [LocaleCodes.source]（`en`）。
/// 4. 返回 key 本身（不崩、不空）。
/// 5. 最后做插值 / 复数 / 上下文替换。
///
/// Key 规范：**英文点分层级**，如 `login.title`、`login.button.submit`。
/// 不再兼容中文 key。
///
/// 上下文（context）：允许 `t('open', context: 'button')` 命中 `open@button`；
/// 若上下文键未命中，回落到无 context 的 `open`。
///
/// 语言切换：`await I18n.instance.switchTo(newLang)`（SettingsController 里调）。
library;

import 'package:larg_editor/i18n/locale.dart';
import 'package:larg_editor/i18n/plural.dart';
import 'package:larg_editor/i18n/table_loader.dart';

export 'package:larg_editor/i18n/locale.dart' show LocaleCodes;

/// 全局翻译单例。
class I18n {
  I18n._();

  static final I18n instance = I18n._();

  final TableLoader _loader = TableLoader();

  String _lang = LocaleCodes.source;

  /// 当前语言代码（`en` / `zh-CN` / `ja`）。
  String get lang => _lang;

  /// 加载器（供高级用法：远程热更新灌表、注册模块目录）。
  TableLoader get loader => _loader;

  /// 启动时调用：加载当前语言 + 源语言的全局表。
  Future<void> init([String? lang]) async {
    _lang = LocaleCodes.normalize(lang ?? _lang);
    // 并行加载源语言 + 当前语言（若不同）
    final futures = <Future<void>>[_loader.loadGlobal(LocaleCodes.source)];
    if (_lang != LocaleCodes.source) {
      futures.add(_loader.loadGlobal(_lang));
    }
    await Future.wait(futures);
  }

  /// 切换语言：清缓存 → 重新加载源 + 目标语言全局表。
  Future<void> switchTo(String lang) async {
    final next = LocaleCodes.normalize(lang);
    if (next == _lang && _loader.peekGlobal(next) != null) return;
    _lang = next;
    // 保留源表 & 目标表在缓存里（其它语言清空，节省内存）
    await init(next);
  }

  /// 注册模块 i18n 目录（结尾带 `/`），后续 `t(key, module: name)` 首次会自动懒加载。
  void registerModule(String module, String assetDir) =>
      _loader.registerModule(module, assetDir);

  /// 显式预热某模块的翻译（推荐在打开对应页面前 await 一次，避免首帧回落 en）。
  Future<void> ensureModule(String module) => _loader.loadModule(module, _lang);
}

/// 全局翻译函数（业务代码用这个）。
///
/// 用法：
/// ```dart
/// t('login.title');
/// t('login.welcome', args: {'name': 'Tom'});
/// t('cart.items', args: {'n': 3}, count: 3);
/// t('checkout.title', module: 'checkout');
/// t('open', context: 'button');
/// ```
String t(
  String key, {
  Map<String, Object?>? args,
  int? count,
  String? module,
  String? context,
}) {
  final i18n = I18n.instance;
  final lang = i18n.lang;
  final loader = i18n.loader;

  String? raw;
  // 1) 模块表（当前语言）
  if (module != null) {
    raw = _lookup(loader.peekModule(module, lang), key, context);
    // 1b) 模块表（源语言）——若模块作者只写了 en，也能命中
    raw ??= _lookup(
      loader.peekModule(module, LocaleCodes.source),
      key,
      context,
    );
  }
  // 2) 全局表（当前语言）
  raw ??= _lookup(loader.peekGlobal(lang), key, context);
  // 3) 全局表（源语言 en）
  raw ??= _lookup(loader.peekGlobal(LocaleCodes.source), key, context);
  // 4) 兜底：key 本身（不崩、不空白）
  final template = raw ?? key;
  // 5) 插值 / 复数
  return interpolate(template, args, count: count, lang: lang);
}

/// 在表 [tbl] 中按 `key@context` → `key` 顺序查找。
String? _lookup(Map<String, String>? tbl, String key, String? context) {
  if (tbl == null) return null;
  if (context != null) {
    final ctxHit = tbl['$key@$context'];
    if (ctxHit != null) return ctxHit;
  }
  return tbl[key];
}
