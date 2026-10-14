import 'package:flutter/material.dart';

import '../../app/theme/expressive_motion.dart';

/// 图标（或小型指示器）切换：旧的缩小淡出，新的带弹性放大淡入。
///
/// 用于播放/暂停、开始/结束这类“同一控件、状态不同”的图标替换，让变化有
/// 过程而不是硬切。[switchKey] 变化即触发切换；减少动画时时长为 0，直接替换。
class ExpressiveIconSwap extends StatelessWidget {
  const ExpressiveIconSwap({
    super.key,
    required this.switchKey,
    required this.child,
  });

  final Object switchKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // 切换曲线本身必须不越界：弹簧曲线会输出 >1 的值，若让它同时驱动淡入淡出，
    // 再叠加任何断言 [0,1] 的曲线就会在 debug 下抛错。所以 AnimatedSwitcher 走
    // effects/exit，弹簧只在缩放这一路单独施加（缩放允许过冲）。
    return AnimatedSwitcher(
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
      switchInCurve: ExpressiveMotion.effects,
      switchOutCurve: ExpressiveMotion.exit,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: animation.drive(CurveTween(curve: ExpressiveMotion.spatial)),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey<Object>(switchKey), child: child),
    );
  }
}
