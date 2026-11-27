/// 特效播放器：把 FxSpec 列表 + 时间 → 对子 widget 施加变换。
///
/// 求值用纯 Dart 的 [evaluateAll]（单一真源），本 widget 只做动画驱动与绘制。
/// 动效减弱时由 [shouldRender] 过滤——尊重用户/系统设置。
library;

import 'package:flutter/material.dart';
import 'package:larg_editor/component/engine.dart';

class FxPlayer extends StatefulWidget {
  final List<FxSpec> specs;
  final bool reduceMotion;
  final Widget child;

  const FxPlayer({
    super.key,
    required this.specs,
    required this.child,
    this.reduceMotion = false,
  });

  @override
  State<FxPlayer> createState() => _FxPlayerState();
}

class _FxPlayerState extends State<FxPlayer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  List<FxSpec> _active = const [];
  int _maxDuration = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
    _configure();
  }

  @override
  void didUpdateWidget(covariant FxPlayer old) {
    super.didUpdateWidget(old);
    if (old.specs != widget.specs) _configure();
  }

  void _configure() {
    _active = widget.specs
        .where((s) => shouldRender(s, widget.reduceMotion))
        .toList();
    _maxDuration = _active.fold<int>(
      0,
      (m, s) => m > s.delayMs + s.durationMs ? m : s.delayMs + s.durationMs,
    );
    if (_maxDuration > 0) {
      _ctrl.duration = Duration(milliseconds: _maxDuration);
      _ctrl.forward(from: 0);
    } else {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final elapsed = (_ctrl.value * _maxDuration).round();
        final frame = evaluateAll(_active, elapsed);
        return Opacity(
          opacity: frame.opacity,
          child: Transform.translate(
            offset: Offset(frame.offsetX, frame.offsetY),
            child: Transform.scale(scale: frame.scale, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}
