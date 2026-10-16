import 'package:flutter/material.dart';

/// 发布/编辑面板里一行入口的统一表面：圆角卡片 + 细描边 + 最小高度。
///
/// 封面、标签、此时此地、发表时间、时间胶囊各行共用，外观只在这里调整。
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

  static const double radius = 14;
  static const double minHeight = 42;

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  static Color surfaceColor(ColorScheme colorScheme) =>
      colorScheme.surfaceContainerHighest;

  static Color outlineColor(ColorScheme colorScheme) =>
      colorScheme.outlineVariant.withValues(alpha: 0.45);

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
        side: BorderSide(color: borderColor ?? outlineColor(colorScheme)),
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
