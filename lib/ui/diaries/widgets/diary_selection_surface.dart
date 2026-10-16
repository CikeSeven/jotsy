import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';
import '../viewmodels/diary_card_surface_spec.dart';

/// 日记卡片的统一选中表面。
///
/// 输入为页面层已经确定的选中状态和解析好的表面参数 [spec]（底色、渐变、
/// 描边、阴影，均已按主题、置顶与卡片样式算好）；输出只包含视觉与语义
/// 反馈，不持有或修改业务选择状态。短促缩放仅发生在状态切换过程中，避免
/// 改变卡片的最终尺寸或瀑布流布局。
class DiarySelectionSurface extends StatelessWidget {
  const DiarySelectionSurface({
    super.key,
    required this.diaryId,
    required this.selected,
    required this.compact,
    required this.spec,
    required this.child,
  });

  static const Duration transitionDuration = ExpressiveMotion.medium;

  final String diaryId;
  final bool selected;
  final bool compact;
  final DiaryCardSurfaceSpec spec;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = colorScheme.brightness == Brightness.light;
    final highlightAlpha = isLight ? 0.14 : 0.22;
    final borderRadius = BorderRadius.circular(spec.radius);

    return Semantics(
      container: true,
      selected: selected,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: selected ? 1 : 0),
        duration: ExpressiveMotion.duration(context, transitionDuration),
        curve: ExpressiveMotion.effects,
        builder: (BuildContext context, double progress, Widget? child) {
          Color highlight(Color base) => Color.alphaBlend(
            colorScheme.primary.withValues(alpha: highlightAlpha * progress),
            base,
          );
          // 渐变表面上 BoxDecoration.color 不生效，选中高亮逐个混入色标。
          final gradientColors = spec.gradientColors;
          final gradient = gradientColors == null
              ? null
              : LinearGradient(
                  begin: spec.gradientBegin,
                  end: spec.gradientEnd,
                  colors: <Color>[for (final c in gradientColors) highlight(c)],
                );
          final effectiveBorderColor = Color.lerp(
            spec.borderColor,
            colorScheme.primary.withValues(alpha: 0.82),
            progress,
          )!;
          final effectiveBorderWidth = spec.borderWidth + 1.2 * progress;
          // 圆角表面使用完整描边，避免单侧边框与圆角裁切不一致；静止态宽度为
          // 0 时不画（宽 0 的 BorderSide 会被绘制成一像素细线）。
          final accentBorder = effectiveBorderWidth > 0
              ? Border.all(
                  color: effectiveBorderColor,
                  width: effectiveBorderWidth,
                )
              : null;
          final pulseDepth = compact ? 0.016 : 0.008;
          final scale = 1 - math.sin(math.pi * progress) * pulseDepth;

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
                color: gradient == null ? highlight(spec.color) : null,
                gradient: gradient,
                borderRadius: borderRadius,
                boxShadow: <BoxShadow>[...spec.shadows, ...selectionShadows],
              ),
              foregroundDecoration: BoxDecoration(
                border: accentBorder,
                borderRadius: borderRadius,
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
