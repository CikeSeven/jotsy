import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';

/// 宽窗口首页切换 Tab 时的入场：新 Tab 沿侧边栏的方向移入
/// （[slideFrom]）、从 [scaleFrom] 放大到 1，并淡入。
///
/// 输入：[generation]（每次切页加一，变化时重播入场）、[direction]（在
/// 侧边栏上往下切为 1、往上为 -1、不明为 0）、页面底色 [color] 与内容
/// [child]；无副作用。
///
/// 节奏：位移与缩放是空间量，走真弹簧（`ExpressiveMotion.springSpatial`，
/// 与侧边栏指示器同一类运动，连点时带着速度续上）；淡入是透明度，走
/// `ExpressiveMotion.medium` + `effects`。减少动画时一律直接到位。
///
/// 为什么淡入靠“盖一层底色再淡出”而不是给内容套透明度：各 Tab 的顶栏可能
/// 是玻璃（`BackdropFilter`），放进 `Opacity` / `FadeTransition` 会让模糊
/// 采不到页面（AGENTS.md §6 的玻璃规则）。上面盖一层与首页 Scaffold 同色的
/// [ColoredBox] 由不透明淡到透明，看起来与内容淡入相同；透明度为 0 时这层
/// 不绘制，位移与缩放回到原位时 Transform 也不再建图层，静止时与不包这层
/// 完全一样。盖层不拦截点按，切页途中仍可操作新页面。
///
/// 首次挂载（含窗口从窄变宽时）不播放：只有 [generation] 变化才入场。
class HomeTabEntrance extends StatefulWidget {
  const HomeTabEntrance({
    super.key,
    required this.generation,
    this.direction = 0,
    required this.color,
    required this.child,
  });

  /// 入场的起始缩放。
  static const double scaleFrom = 0.98;

  /// 入场的起始位移（逻辑像素），方向随 [direction]。
  static const double slideFrom = 24;

  final int generation;
  final int direction;
  final Color color;
  final Widget child;

  @override
  State<HomeTabEntrance> createState() => _HomeTabEntranceState();
}

class _HomeTabEntranceState extends State<HomeTabEntrance>
    with TickerProviderStateMixin {
  /// 弹簧停稳的阈值：进度以 0…1 计，千分之一不到 0.1 像素。
  static const Tolerance _settleTolerance = Tolerance(
    distance: 0.001,
    velocity: 0.01,
  );

  /// 空间进度（0 在起点、1 到位），无界：弹簧会轻轻越过 1 再落回。
  late final AnimationController _spatial = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: ExpressiveMotion.medium,
    value: 1,
  );
  late final CurvedAnimation _fadeCurve = CurvedAnimation(
    parent: _fade,
    curve: ExpressiveMotion.effects,
  );
  late final Animation<double> _cover = Tween<double>(
    begin: 1,
    end: 0,
  ).animate(_fadeCurve);

  @override
  void didUpdateWidget(HomeTabEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.generation == widget.generation) {
      return;
    }
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    if (duration == Duration.zero) {
      _spatial.value = 1;
      _fade.value = 1;
      return;
    }
    _fade
      ..duration = duration
      ..forward(from: 0);
    // 从起点重新出发：上一段还没到位时它的残余速度朝向旧方向，不沿用。
    _spatial.value = 0;
    ExpressiveMotion.springTo(
      context,
      _spatial,
      1,
      spring: ExpressiveMotion.springSpatial,
      tolerance: _settleTolerance,
    );
  }

  @override
  void dispose() {
    _fadeCurve.dispose();
    _fade.dispose();
    _spatial.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        AnimatedBuilder(
          animation: _spatial,
          builder: (BuildContext context, Widget? child) {
            final remaining = 1 - _spatial.value;
            final scale = 1 - (1 - HomeTabEntrance.scaleFrom) * remaining;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(scale, scale, 1)
                ..setTranslationRaw(
                  0,
                  widget.direction * HomeTabEntrance.slideFrom * remaining,
                  0,
                ),
              child: child,
            );
          },
          child: widget.child,
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: FadeTransition(
              opacity: _cover,
              child: ColoredBox(color: widget.color),
            ),
          ),
        ),
      ],
    );
  }
}
