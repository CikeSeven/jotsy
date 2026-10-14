import 'package:flutter/widgets.dart';

import '../../app/theme/expressive_motion.dart';

/// 二态颜色过渡：[active] 翻转时给出 0→1 / 1→0 的补间进度，调用方据此插值
/// 背景、前景、描边等颜色。
///
/// Material 与 ButtonStyle 自带的隐式动画只补间形状、阴影，颜色会硬切：播放中
/// 的卡片染色、按钮在待机/会话态之间换色、标签行选中，都是一帧跳变。需要“状态
/// 变色”的表面统一用它把颜色也补间起来。首帧不播放（起点即终点），时长默认
/// fast，减少动画时直接落位。不随进度变化的子树经 [child] 传入，不会逐帧重建。
class ExpressiveStateBlend extends StatelessWidget {
  const ExpressiveStateBlend({
    super.key,
    required this.active,
    required this.builder,
    this.child,
    this.duration = ExpressiveMotion.fast,
  });

  final bool active;
  final Duration duration;
  final Widget? child;

  /// `t` 为 0（非激活）到 1（激活）之间的补间进度。
  final Widget Function(BuildContext context, double t, Widget? child) builder;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: active ? 1 : 0),
      duration: ExpressiveMotion.duration(context, duration),
      curve: ExpressiveMotion.effects,
      builder: builder,
      child: child,
    );
  }
}
