/// 特效求值器：纯 Dart、无 flutter 依赖。
///
/// 给一条特效 + 当前经过的毫秒，算出当前的变换值（缩放/位移/透明度等）。
/// 抽成纯函数是分布式设计：求值逻辑只写一份，编辑器预览 / 玩家端 / 网页导出
/// 共用；UI 层只负责把 [FxFrame] 画出来。
library;

import 'model/effects.dart';

/// 一帧特效的变换快照。渲染层据此施力，字段语义统一：
/// - opacity: 0..1，缺省 1
/// - scale: 倍率，缺省 1
/// - offsetX / offsetY: 逻辑像素偏移，缺省 0
/// - textReveal: 已显示的字符数，<0 表示不适用
class FxFrame {
  final double opacity;
  final double scale;
  final double offsetX;
  final double offsetY;
  final int textReveal;
  final bool active;

  const FxFrame({
    this.opacity = 1,
    this.scale = 1,
    this.offsetX = 0,
    this.offsetY = 0,
    this.textReveal = -1,
    this.active = false,
  });
}

/// 按缓动曲线把 0..1 的进度映射成 0..1。
double _ease(FxEase ease, double t) {
  final x = t.clamp(0.0, 1.0);
  return switch (ease) {
    FxEase.linear => x,
    FxEase.outQuad => 1 - (1 - x) * (1 - x),
    FxEase.outCubic => 1 - (1 - x) * (1 - x) * (1 - x),
    FxEase.inOut => x < 0.5 ? 2 * x * x : 1 - 2 * (1 - x) * (1 - x),
  };
}

/// 求一条特效在 [elapsedMs] 时的帧。
///
/// [elapsedMs] < delay → 未开始（返回空帧）；> delay+duration → 结束态
/// （保留最终变换，例如 fade 留 opacity=1、slide 留到位），不回弹。
FxFrame evaluate(FxSpec fx, int elapsedMs) {
  if (!fx.isRenderable) return const FxFrame();
  final t = (elapsedMs - fx.delayMs) / (fx.durationMs <= 0 ? 1 : fx.durationMs);
  if (t < 0) return const FxFrame();
  final p = _ease(fx.ease, t);
  switch (fx.type!) {
    case FxType.fade:
      return FxFrame(opacity: p, active: t < 1);
    case FxType.slide:
      final dist = fx.paramDouble('distance', 24);
      final from = fx.params['from']?.toString() ?? 'bottom';
      final off = (1 - p) * dist;
      return FxFrame(
        offsetX: from == 'left' ? -off : from == 'right' ? off : 0,
        offsetY: from == 'top' ? -off : from == 'bottom' ? off : 0,
        active: t < 1,
      );
    case FxType.pop:
      final fromScale = fx.paramDouble('from', 0.6);
      return FxFrame(
        scale: fromScale + (1 - fromScale) * p,
        active: t < 1,
      );
    case FxType.shake:
      // 振荡衰减：sin(频率 × t) × (1-t) × 强度
      final intensity = fx.paramDouble('intensity', 6);
      final cycles = fx.paramDouble('cycles', 4);
      final wave = _sinApprox(cycles * p * 6.2831853);
      final amp = (1 - p) * intensity;
      return FxFrame(offsetX: wave * amp, active: t < 1);
    case FxType.flash:
      // 前 40% 白闪到峰值，后 60% 回落（用线性时间比例，避免缓动让峰值偏移）
      final raw = (elapsedMs - fx.delayMs) / (fx.durationMs <= 0 ? 1 : fx.durationMs);
      final v = raw < 0.4 ? raw / 0.4 : 1 - (raw - 0.4) / 0.6;
      return FxFrame(opacity: v.clamp(0.0, 1.0), active: t < 1);
    case FxType.panZoom:
      final to = fx.paramDouble('to', 1.06);
      final from = fx.paramDouble('from', 1.0);
      return FxFrame(scale: from + (to - from) * p, active: t < 1);
    case FxType.typewriter:
      final cps = fx.paramInt('cps', 18);
      final chars = (elapsedMs / 1000 * cps).floor();
      return FxFrame(textReveal: chars, active: elapsedMs < 1000 / cps * 999);
    case FxType.tint:
      // 颜色叠加强度用 opacity 表达，具体色值由 UI 按 params['color'] 取
      return FxFrame(opacity: p, active: t < 1);
  }
}

/// 轻量 sin 近似（避免 dart:math 依赖；精度足够做抖动）。
double _sinApprox(double x) {
  // 归一到 [-π, π]
  var a = x % 6.2831853;
  if (a > 3.14159265) a -= 6.2831853;
  if (a < -3.14159265) a += 6.2831853;
  // 三次近似：sin(a) ≈ a - a³/6（|a|≤π 误差可接受）
  return a - a * a * a / 6;
}

/// 合成一组特效在同一时刻的帧（依次叠加变换，取最保守值）。
FxFrame evaluateAll(Iterable<FxSpec> fx, int elapsedMs) {
  var opacity = 1.0;
  var scale = 1.0;
  var dx = 0.0;
  var dy = 0.0;
  var reveal = -1;
  var active = false;
  for (final spec in fx) {
    final f = evaluate(spec, elapsedMs);
    opacity *= f.opacity;
    scale *= f.scale;
    dx += f.offsetX;
    dy += f.offsetY;
    if (f.textReveal >= 0) reveal = f.textReveal;
    active = active || f.active;
  }
  return FxFrame(
    opacity: opacity.clamp(0.0, 1.0),
    scale: scale,
    offsetX: dx,
    offsetY: dy,
    textReveal: reveal,
    active: active,
  );
}

/// 是否应启用动效减弱：只保留 fade 与 typewriter（其余静默跳过）。
bool shouldRender(FxSpec fx, bool reduceMotion) {
  if (!fx.isRenderable) return false;
  if (!reduceMotion) return true;
  return fx.type == FxType.fade || fx.type == FxType.typewriter;
}
