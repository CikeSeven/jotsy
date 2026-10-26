import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';

/// 宽窗口首页切换 Tab 时的入场：新 Tab 从 0.98 放大到 1 并淡入。
///
/// 输入：[generation]（每次切页加一，变化时重播入场）、页面底色 [color] 与
/// 内容 [child]；无副作用。时长 `ExpressiveMotion.medium`、曲线 `effects`，
/// 经 `ExpressiveMotion.duration` 解析，减少动画时直接到位。
///
/// 为什么淡入靠“盖一层底色再淡出”而不是给内容套透明度：各 Tab 的顶栏可能
/// 是玻璃（`BackdropFilter`），放进 `Opacity` / `FadeTransition` 会让模糊
/// 采不到页面（AGENTS.md §6 的玻璃规则）。上面盖一层与首页 Scaffold 同色的
/// [ColoredBox] 由不透明淡到透明，看起来与内容淡入相同；透明度为 0 时这层
/// 不绘制，缩放回到 1 时 Transform 也不再建图层，静止时与不包这层完全一样。
/// 盖层不拦截点按，切页途中仍可操作新页面。
///
/// 首次挂载（含窗口从窄变宽时）不播放：只有 [generation] 变化才入场。
class HomeTabEntrance extends StatefulWidget {
  const HomeTabEntrance({
    super.key,
    required this.generation,
    required this.color,
    required this.child,
  });

  /// 入场的起始缩放。
  static const double scaleFrom = 0.98;

  final int generation;
  final Color color;
  final Widget child;

  @override
  State<HomeTabEntrance> createState() => _HomeTabEntranceState();
}

class _HomeTabEntranceState extends State<HomeTabEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ExpressiveMotion.medium,
    value: 1,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: ExpressiveMotion.effects,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: HomeTabEntrance.scaleFrom,
    end: 1,
  ).animate(_curve);
  late final Animation<double> _cover = Tween<double>(
    begin: 1,
    end: 0,
  ).animate(_curve);

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
      _controller.value = 1;
      return;
    }
    _controller
      ..duration = duration
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        ScaleTransition(scale: _scale, child: widget.child),
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
