import 'package:flutter/material.dart';
import 'package:node_diary/app/theme/app_radii.dart';

/// 发布/编辑面板里一行入口的统一表面：输入框填充色 + 输入框圆角 + 最小
/// 高度（DESIGN.md §2.1“输入框填充底色”、§4.2 `AppRadii.input`）。
///
/// 封面、标签、此时此地、发表时间、时间胶囊各行共用，外观只在这里调整。
/// 面板本身是卡片表面，行用比它深一级的填充色区分，默认不描边；
/// [color] / [borderColor] 供状态补间（如胶囊已设置时）覆盖默认色。
class PublishPanelTile extends StatelessWidget {
  const PublishPanelTile({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.color,
    this.borderColor,
  });

  static const double radius = AppRadii.input;
  static const double minHeight = 42;

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  /// 与主题里输入框的 fillColor 一致。
  static Color surfaceColor(ColorScheme colorScheme) =>
      colorScheme.brightness == Brightness.light
      ? colorScheme.surfaceContainerLow.withValues(alpha: 0.6)
      : colorScheme.surfaceContainerHighest;

  /// 默认无描边（透明），状态补间从这里过渡到强调色描边。
  static Color outlineColor(ColorScheme colorScheme) =>
      colorScheme.outlineVariant.withValues(alpha: 0);

  /// 行首标题（“封面”“标签”等）的字重与字号。
  static TextStyle? titleStyle(BuildContext context) => Theme.of(
    context,
  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: minHeight),
      child: Padding(padding: padding, child: child),
    );
    return Material(
      color: color ?? surfaceColor(colorScheme),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(
          color: borderColor ?? outlineColor(colorScheme),
          width: 0.8,
        ),
      ),
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(radius),
              child: content,
            ),
    );
  }
}
