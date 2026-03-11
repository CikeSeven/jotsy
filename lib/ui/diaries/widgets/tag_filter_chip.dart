import 'package:flutter/material.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';

/// 顶部标签筛选项通用组件。
///
/// 支持两类视觉形态：
/// - 普通标签（可选颜色点）；
/// - 特殊入口（通过 `leading` 自定义左侧图标）。
class TagFilterChip extends StatelessWidget {
  const TagFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.selectedForegroundColor,
    required this.unselectedColor,
    required this.unselectedForegroundColor,
    required this.onTap,
    this.colorDot,
    this.leading,
    this.radius = AppRadii.nav,
    this.colorDotSize = 8,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.m,
      vertical: AppSpacing.s,
    ),
    this.animateBorder = false,
    this.showSelectedShadow = true,
  });

  /// 文案标签。
  final String label;
  /// 当前是否选中。
  final bool selected;
  final Color selectedColor;
  final Color selectedForegroundColor;
  final Color unselectedColor;
  final Color unselectedForegroundColor;
  /// 点击回调。
  final VoidCallback onTap;
  final Color? colorDot;
  final Widget? leading;
  final double radius;
  final double colorDotSize;
  final EdgeInsetsGeometry padding;
  /// 动态边框过渡（用于和主色卡片一致的“选中态切换感”）。
  final bool animateBorder;
  /// 选中态阴影开关。
  final bool showSelectedShadow;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = selected ? selectedColor : unselectedColor;
    final foregroundColor =
        selected ? selectedForegroundColor : unselectedForegroundColor;
    final borderColor =
        selected
            ? selectedForegroundColor.withValues(alpha: 0.45)
            : colorScheme.outlineVariant.withValues(alpha: 0.55);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOutCubic,
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(radius),
            border:
                animateBorder
                    ? Border.all(
                      color: borderColor,
                      width: selected ? 2.0 : 1.2,
                    )
                    : null,
            boxShadow:
                selected && showSelectedShadow
                    ? <BoxShadow>[
                      BoxShadow(
                        color: backgroundColor.withAlpha(140),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                    : null,
          ),
          child: DefaultTextStyle(
            style: Theme.of(context).textTheme.labelMedium!.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (leading != null) ...[
                  IconTheme(
                    data: IconThemeData(color: foregroundColor, size: 12),
                    child: leading!,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                if (colorDot != null) ...[
                  Container(
                    width: colorDotSize,
                    height: colorDotSize,
                    decoration: BoxDecoration(
                      color: colorDot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                ],
                Text(label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
