import 'package:flutter/material.dart';

import '../../app/theme/expressive_motion.dart';
import 'glass/glass_reveal.dart';

/// 条件插入组件的入场过渡：插入树时淡入并从 [offset]（按自身尺寸比例）
/// 滑回原位。
///
/// 适用于悬浮工具栏、底部面板、等待遮罩等“按状态插入/移除”的区块：
/// 移除仍是即时的（离场通常伴随键盘或页面状态切换，延迟移除反而会与新内容
/// 重叠），插入时不再硬切。时长经 [ExpressiveMotion.duration] 解析，减少动画
/// 时直接显示。结构恒定为 Opacity → FractionalTranslation，动画结束后
/// Opacity 为 1 不再产生合成层。
///
/// [glass] 为 true 时结构为 GlassReveal → FractionalTranslation，没有
/// Opacity：玻璃表面放进透明度层后背景模糊采不到页面（见 [GlassReveal]）。
class ExpressiveEntrance extends StatelessWidget {
  const ExpressiveEntrance({
    super.key,
    required this.child,
    this.offset = const Offset(0, 0.08),
    this.duration = ExpressiveMotion.medium,
    this.glass = false,
  });

  final Widget child;
  final Offset offset;
  final Duration duration;

  /// 子树主体是否为玻璃表面。由调用方按
  /// `AppGlass.of(context).isGlass(component)` 决定：为 true 时淡入交给子树里
  /// 的 `GlassSurface`（经 [GlassReveal]），不在玻璃之内的内容会硬切，所以只在
  /// 整块都在一块玻璃里时传 true；经典材质保持 false，照旧用 Opacity。
  final bool glass;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: ExpressiveMotion.duration(context, duration),
      curve: ExpressiveMotion.effects,
      child: child,
      builder: (BuildContext context, double progress, Widget? child) {
        final moved = FractionalTranslation(
          translation: offset * (1 - progress),
          child: child,
        );
        if (glass) {
          return GlassReveal(progress: progress, child: moved);
        }
        return Opacity(opacity: progress, child: moved);
      },
    );
  }
}
