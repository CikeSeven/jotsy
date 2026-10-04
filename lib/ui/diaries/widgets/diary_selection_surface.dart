import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../app/theme/expressive_surfaces.dart';

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
    this.isPinned = false,
    required this.child,
  });

  static const Duration transitionDuration = Duration(milliseconds: 220);

  final String diaryId;
  final bool selected;
  final bool compact;
  final Color backgroundColor;
  final double borderRadius;
  final bool isPinned;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = colorScheme.brightness == Brightness.light;
    final highlightAlpha = isLight ? 0.14 : 0.22;
    final defaultBorderColor = isPinned
        ? colorScheme.primary.withValues(alpha: isLight ? 0.35 : 0.45)
        : ExpressiveSurfaces.cardBorderColor(colorScheme);

    Widget effectiveChild = child;
    if (isPinned && !compact) {
      effectiveChild = Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          Positioned(
            left: 0,
            top: 14,
            bottom: 14,
            child: Container(
              width: 3.5,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(3),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Semantics(
      container: true,
      selected: selected,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: selected ? 1 : 0),
        duration: ExpressiveMotion.duration(context, transitionDuration),
        curve: ExpressiveMotion.effects,
        builder: (BuildContext context, double progress, Widget? child) {
          final highlightColor = Color.alphaBlend(
            colorScheme.primary.withValues(alpha: highlightAlpha * progress),
            backgroundColor,
          );
          final effectiveBorderColor = Color.lerp(
            defaultBorderColor,
            colorScheme.primary.withValues(alpha: 0.82),
            progress,
          )!;
          final effectiveBorderWidth = 0.8 + 1.2 * progress;
          // 圆角表面使用完整描边，避免单侧边框与圆角裁切不一致。
          final accentBorder = Border.all(
            color: effectiveBorderColor,
            width: effectiveBorderWidth,
          );
          final pulseDepth = compact ? 0.016 : 0.008;
          final scale = 1 - math.sin(math.pi * progress) * pulseDepth;

          final baseShadows = isLight
              ? <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isPinned ? 0.055 : 0.04,
                    ),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                  if (isPinned)
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 3.5),
                    ),
                ]
              : <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.32),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ];
          final selectionShadows = compact && progress > 0
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
              : const <BoxShadow>[];

          return Transform.scale(
            key: ValueKey<String>('diary_selection_motion_$diaryId'),
            scale: scale,
            child: Container(
              key: ValueKey<String>('diary_selection_surface_$diaryId'),
              decoration: BoxDecoration(
                color: highlightColor,
                borderRadius: BorderRadius.circular(borderRadius),
                boxShadow: <BoxShadow>[...baseShadows, ...selectionShadows],
              ),
              foregroundDecoration: BoxDecoration(
                border: accentBorder,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: child,
            ),
          );
        },
        child: effectiveChild,
      ),
    );
  }
}
