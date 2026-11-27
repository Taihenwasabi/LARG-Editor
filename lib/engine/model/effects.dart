/// 特效声明模型（PACK_FORMAT v2）。
///
/// 设计立场（见 `桌面UI与特效规划.md` §9）：
/// - 声明式：特效是包 JSON 的一部分，不是代码。
/// - 可忽略：不认识的取值一律降级为"无特效"，旧引擎读新包不崩，新引擎读旧包不变。
/// - 组合式：触发器 × 目标 × 动作，封闭词表，不发明私有 DSL。
library;

/// 触发器（封闭集合；未知值 → null，静默跳过）。
enum FxTrigger {
  enter,
  exit,
  tap,
  idle,
  transitionIn,
  transitionOut;

  static FxTrigger? parse(String raw) {
    for (final v in FxTrigger.values) {
      if (v.name == raw) return v;
    }
    return null;
  }
}

/// 动作（v1 八种，全 transform/opacity 级；未知值 → null）。
enum FxType {
  fade,
  slide,
  pop,
  shake,
  flash,
  panZoom,
  typewriter,
  tint;

  static FxType? parse(String raw) {
    for (final v in FxType.values) {
      if (v.name == raw) return v;
    }
    return null;
  }
}

/// 缓动曲线（v1 四种）。
enum FxEase {
  linear,
  outQuad,
  outCubic,
  inOut;

  static FxEase parse(String raw) {
    for (final v in FxEase.values) {
      if (v.name == raw) return v;
    }
    return FxEase.outCubic;
  }
}

/// 目标：`text` / `background` / `screen` / `media` / `sprite:<slot>`。
class FxTarget {
  final String raw;

  const FxTarget._(this.raw);

  factory FxTarget.parse(String raw) => FxTarget._(raw.trim().toLowerCase());

  static const FxTarget text = FxTarget._('text');
  static const FxTarget background = FxTarget._('background');
  static const FxTarget screen = FxTarget._('screen');
  static const FxTarget media = FxTarget._('media');

  bool get isSprite => raw.startsWith('sprite:');
  String? get spriteSlot => isSprite && raw.length > 7 ? raw.substring(7) : null;

  /// 是否在封闭词表内（doctor 用）。
  bool get isValid =>
      raw == 'text' ||
      raw == 'background' ||
      raw == 'screen' ||
      raw == 'media' ||
      isSprite;
}

/// 一条特效声明。
class FxSpec {
  final FxTrigger? trigger;
  final FxTarget target;
  final FxType? type;
  final int durationMs;
  final int delayMs;
  final FxEase ease;

  /// 动作参数（intensity / from / to / cps …），原样保留供渲染层取用。
  final Map<String, dynamic> params;

  const FxSpec({
    required this.trigger,
    required this.target,
    required this.type,
    required this.durationMs,
    required this.delayMs,
    required this.ease,
    required this.params,
  });

  factory FxSpec.fromJson(Map<String, dynamic> j) {
    final rawTarget = (j['target'] ?? '').toString();
    final rawDuration = j['duration'];
    final rawDelay = j['delay'];
    return FxSpec(
      trigger: FxTrigger.parse((j['on'] ?? 'enter').toString()),
      target: FxTarget.parse(rawTarget),
      type: FxType.parse((j['type'] ?? '').toString()),
      durationMs: rawDuration is num ? rawDuration.toInt() : 300,
      delayMs: rawDelay is num ? rawDelay.toInt() : 0,
      ease: FxEase.parse((j['ease'] ?? 'outCubic').toString()),
      params: {
        for (final e in j.entries)
          if (!const {'on', 'target', 'type', 'duration', 'delay', 'ease'}
              .contains(e.key))
          e.key: e.value,
      },
    );
  }

  /// 是否可渲染（触发与动作都在词表内）。未知值静默跳过。
  bool get isRenderable => trigger != null && type != null && target.isValid;

  int paramInt(String key, int fallback) {
    final v = params[key];
    return v is num ? v.toInt() : fallback;
  }

  double paramDouble(String key, double fallback) {
    final v = params[key];
    return v is num ? v.toDouble() : fallback;
  }
}

/// 解析一组 fx 声明（JSON 数组）。非法元素静默跳过，不抛错——
/// 包的正文中出现不认识的特效不该让整个包读不出来。
List<FxSpec> parseFxList(dynamic raw) {
  if (raw is! List) return const [];
  final out = <FxSpec>[];
  for (final e in raw) {
    if (e is Map<String, dynamic>) {
      out.add(FxSpec.fromJson(e));
    } else if (e is Map) {
      out.add(FxSpec.fromJson(Map<String, dynamic>.from(e)));
    }
  }
  return out;
}
