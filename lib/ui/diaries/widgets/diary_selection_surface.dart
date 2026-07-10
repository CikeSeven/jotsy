import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 日记卡片的统一选中表面。
///
/// 输入为页面层已经确定的选中状态和卡片底色；输出只包含视觉与语义反馈，
/// 不持有或修改业务选择状态。短促缩放仅发生在状态切换过程中，避免改变卡片
/// 的最终尺寸或瀑布流布局。
class DiarySelectionSurface extends StatelessWidget {
  const DiarySelectionSurface({
    super.key,
    required this.diaryId,
    required this.selected,
    required this.compact,
    required this.backgroundColor,
    required this.borderRadius,
    required this.child,
  });

  static const Duration transitionDuration = Duration(milliseconds: 220);

  final String diaryId;
  final bool selected;
  final bool compact;
  final Color backgroundColor;
  final double borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final highlightAlpha =
        colorScheme.brightness == Brightness.dark ? 0.22 : 0.14;

    return Semantics(
      container: true,
      selected: selected,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: selected ? 1 : 0),
        duration: transitionDuration,
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, double progress, Widget? child) {
          final highlightColor = Color.alphaBlend(
            colorScheme.primary.withValues(alpha: highlightAlpha * progress),
            backgroundColor,
          );
          final accentColor = colorScheme.primary.withValues(
            alpha: 0.82 * progress,
          );
          final accentBorder =
              compact
                  ? Border.all(color: accentColor, width: 2)
                  : Border(left: BorderSide(color: accentColor, width: 4));
          final pulseDepth = compact ? 0.016 : 0.008;
          final scale = 1 - math.sin(math.pi * progress) * pulseDepth;

          return Transform.scale(
            key: ValueKey<String>('diary_selection_motion_$diaryId'),
            scale: scale,
            child: Container(
              key: ValueKey<String>('diary_selection_surface_$diaryId'),
              decoration: BoxDecoration(
                color: highlightColor,
                borderRadius: BorderRadius.circular(borderRadius),
                boxShadow:
                    compact && progress > 0
                        ? <BoxShadow>[
                          BoxShadow(
                            color: colorScheme.primary.withValues(
                              alpha: 0.16 * progress,
                            ),
                            blurRadius: 12 * progress,
                            spreadRadius: 0.5 * progress,
                            offset: Offset(0, 3 * progress),
                          ),
                        ]
                        : const <BoxShadow>[],
              ),
              foregroundDecoration: BoxDecoration(
                border: accentBorder,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: child,
            ),
          );
        },
        child: child,
      ),
    );
  }
}
