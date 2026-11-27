import 'package:flutter_test/flutter_test.dart';
import 'package:larg_editor/component/engine.dart';

FxSpec _fx(String type, {int duration = 400, Map<String, dynamic> extra = const {}}) {
  return FxSpec.fromJson({
    'on': 'enter',
    'target': 'screen',
    'type': type,
    'duration': duration,
    ...extra,
  });
}

void main() {
  test('fade：从透明到不透明，结束态保留', () {
    final fx = _fx('fade', duration: 400);
    expect(evaluate(fx, 0).opacity, 0);
    final mid = evaluate(fx, 200);
    expect(mid.opacity, greaterThan(0));
    expect(mid.opacity, lessThan(1));
    expect(evaluate(fx, 400).opacity, 1);
    expect(evaluate(fx, 9999).opacity, 1); // 结束态不回弹
  });

  test('delay：未到延迟时间不生效', () {
    final fx = FxSpec.fromJson({
      'on': 'enter',
      'target': 'screen',
      'type': 'fade',
      'duration': 200,
      'delay': 300,
    });
    expect(evaluate(fx, 100).opacity, 1); // 空帧=不透明
    expect(evaluate(fx, 100).active, isFalse);
    expect(evaluate(fx, 400).opacity, greaterThan(0));
  });

  test('slide：四个方向位移正确', () {
    final left = _fx('slide', extra: {'from': 'left', 'distance': 20});
    expect(evaluate(left, 0).offsetX, -20);
    expect(evaluate(left, 400).offsetX, 0);
    final right = _fx('slide', extra: {'from': 'right', 'distance': 20});
    expect(evaluate(right, 0).offsetX, 20);
    final top = _fx('slide', extra: {'from': 'top', 'distance': 20});
    expect(evaluate(top, 0).offsetY, -20);
  });

  test('pop：缩放从 from 到 1', () {
    final fx = _fx('pop', extra: {'from': 0.5});
    expect(evaluate(fx, 0).scale, 0.5);
    expect(evaluate(fx, 400).scale, 1);
  });

  test('shake：振荡衰减，幅度随时间收敛', () {
    final fx = _fx('shake', duration: 400, extra: {'intensity': 8, 'cycles': 3});
    final a = evaluate(fx, 30).offsetX.abs();
    final b = evaluate(fx, 300).offsetX.abs();
    expect(a, greaterThan(0));
    expect(b, lessThan(a)); // 早期幅度大于后期
  });

  test('panZoom：缩放从 from 到 to', () {
    final fx = _fx('panZoom', extra: {'from': 1.0, 'to': 1.1});
    expect(evaluate(fx, 0).scale, 1.0);
    expect(evaluate(fx, 400).scale, 1.1);
  });

  test('typewriter：按 cps 逐字显现', () {
    final fx = _fx('typewriter', duration: 5000, extra: {'cps': 10});
    expect(evaluate(fx, 0).textReveal, 0);
    expect(evaluate(fx, 500).textReveal, 5);
    expect(evaluate(fx, 1000).textReveal, 10);
  });

  test('flash：先亮后暗', () {
    final fx = _fx('flash', duration: 400);
    expect(evaluate(fx, 0).opacity, 0);
    expect(evaluate(fx, 160).opacity, 1); // 40% 处峰值
    expect(evaluate(fx, 400).opacity, 0);
  });

  test('unknown 动作：空帧，不崩', () {
    final fx = _fx('teleport');
    expect(fx.isRenderable, isFalse);
    final f = evaluate(fx, 200);
    expect(f.active, isFalse);
    expect(f.opacity, 1);
  });

  test('evaluateAll：多个特效叠加', () {
    final fade = _fx('fade', duration: 400);
    final pop = _fx('pop', extra: {'from': 0.5});
    final f = evaluateAll([fade, pop], 200);
    expect(f.opacity, greaterThan(0));
    expect(f.scale, greaterThan(0.5));
    expect(f.scale, lessThan(1));
  });

  test('动效减弱：只保留 fade 与 typewriter', () {
    expect(shouldRender(_fx('fade'), true), isTrue);
    expect(shouldRender(_fx('typewriter'), true), isTrue);
    expect(shouldRender(_fx('shake'), true), isFalse);
    expect(shouldRender(_fx('slide'), true), isFalse);
    expect(shouldRender(_fx('shake'), false), isTrue);
  });

  test('四种缓动曲线单调', () {
    for (final ease in FxEase.values) {
      final fx = FxSpec.fromJson({
        'on': 'enter',
        'target': 'screen',
        'type': 'fade',
        'duration': 400,
        'ease': ease.name,
      });
      final a = evaluate(fx, 100).opacity;
      final b = evaluate(fx, 200).opacity;
      final c = evaluate(fx, 300).opacity;
      expect(a, lessThanOrEqualTo(b), reason: ease.name);
      expect(b, lessThanOrEqualTo(c), reason: ease.name);
    }
  });
}
