/// 国际化文案工具：参数插值、复数、上下文。
///
/// 支持：
/// - 简单插值：`"Welcome, {name}"` + `args: {'name':'Tom'}` → `"Welcome, Tom"`
/// - ICU 复数：`"{count, plural, =0 {No items} one {1 item} other {# items}}"`
///   配合 `count: 3` → `"3 items"`；`#` 会被替换为数字
/// - 上下文：`"open@button"` / `"open@door"`（查表时 `context` 命中的键优先）
///
/// 语言复数规则（简化版，够本项目用）：
/// - en：`one` 当且仅当 n==1，其它走 `other`
/// - zh-CN / ja：只有 `other`（无单复数变化）
library;

/// ICU 复数选择类别（按语言归类，够本项目用的最简版）。
String pluralCategory(String lang, num n) {
  switch (lang) {
    case 'en':
      return n == 1 ? 'one' : 'other';
    case 'zh-CN':
    case 'zh':
    case 'ja':
    default:
      return 'other';
  }
}

/// 从模板中提取 `{...}` 占位并做插值 / 复数展开。
///
/// 语法：
/// - `{name}` → args['name']
/// - `{count, plural, =0 {..} one {..} other {..}}` → 依 [lang]/[count] 选分支
/// - 未提供的占位保留原样，不崩、不空
String interpolate(
  String template,
  Map<String, Object?>? args, {
  int? count,
  String lang = 'en',
}) {
  final sb = StringBuffer();
  var i = 0;
  while (i < template.length) {
    final ch = template[i];
    if (ch == '{') {
      final end = _matchBrace(template, i);
      if (end < 0) {
        sb.write(ch);
        i++;
        continue;
      }
      final inner = template.substring(i + 1, end);
      sb.write(_resolveToken(inner, args, count, lang));
      i = end + 1;
    } else {
      sb.write(ch);
      i++;
    }
  }
  return sb.toString();
}

/// 找到与 [start] 处 `{` 匹配的 `}`（考虑嵌套），失败返回 -1。
int _matchBrace(String s, int start) {
  var depth = 0;
  for (var i = start; i < s.length; i++) {
    if (s[i] == '{') {
      depth++;
    } else if (s[i] == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

/// 解析 `{...}` 内部（无外层花括号）的表达式。
String _resolveToken(
  String token,
  Map<String, Object?>? args,
  int? count,
  String lang,
) {
  // plural: `count, plural, <options>`
  final pluralMatch = RegExp(r'^(\w+)\s*,\s*plural\s*,\s*(.+)$', dotAll: true)
      .firstMatch(token);
  if (pluralMatch != null) {
    final varName = pluralMatch.group(1)!;
    final optionsSrc = pluralMatch.group(2)!;
    final n = args != null && args[varName] is num
        ? (args[varName] as num)
        : (varName == 'count' && count != null ? count : null);
    if (n == null) return '';
    final branches = _parsePluralBranches(optionsSrc);
    final pick =
        branches['=$n'] ?? branches[pluralCategory(lang, n)] ?? branches['other'];
    if (pick == null) return '';
    // `#` 替换为数字（ICU 语义）
    return pick.replaceAll('#', _fmtNum(n));
  }
  // 简单插值：{name}
  final key = token.trim();
  if (args != null && args.containsKey(key)) {
    return args[key]?.toString() ?? '';
  }
  if (key == 'count' && count != null) return '$count';
  // 未命中：保留 `{key}` 原样，避免破坏文案
  return '{$key}';
}

/// 解析 `=0 {a} one {b} other {c}` → `{'=0':'a', 'one':'b', 'other':'c'}`。
Map<String, String> _parsePluralBranches(String src) {
  final out = <String, String>{};
  var i = 0;
  while (i < src.length) {
    while (i < src.length && (src[i] == ' ' || src[i] == '\n' || src[i] == '\t')) {
      i++;
    }
    final keyStart = i;
    while (i < src.length && src[i] != ' ' && src[i] != '{' && src[i] != '}') {
      i++;
    }
    final key = src.substring(keyStart, i).trim();
    if (key.isEmpty) break;
    while (i < src.length && src[i] == ' ') {
      i++;
    }
    if (i >= src.length || src[i] != '{') break;
    final end = _matchBrace(src, i);
    if (end < 0) break;
    out[key] = src.substring(i + 1, end);
    i = end + 1;
  }
  return out;
}

String _fmtNum(num n) =>
    n is int || n == n.roundToDouble() ? n.toInt().toString() : '$n';
