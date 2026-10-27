import 'package:flutter/material.dart';

import '../../app_surface/widgets/app_card_surface.dart';

/// 设置页统一分组卡片组件。
///
/// 职责：
/// - 将设置项收纳为现代 Grouped Inset Island 卡片；
/// - 消除全屏割裂式粗暴 Divider，内部项之间使用优雅微缩进分割线；
/// - 支持可选的分组标题与底部附注。
class SettingsCardGroup extends StatelessWidget {
  const SettingsCardGroup({
    super.key,
    this.title,
    this.footer,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final String? title;
  final String? footer;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 8),
              child: Text(
                title!,
                style: textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
          // 经典 / 玻璃两种材质都经 AppCardSurface：经典分支与原来的
          // Container + Material 写法逐像素一致。
          AppCardSurface(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1) const SettingsCardGroupDivider(),
                ],
              ],
            ),
          ),
          if (footer != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 6),
              child: Text(
                footer!,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 分组卡片内两项之间的微缩进分割线。
///
/// [SettingsCardGroup] 在相邻子项之间自动插入；子项内部自带的从属行（如
/// 功能管理里日历下方的纪念日）也用它，与分组里的分割线一致，起点改为从属
/// 行的缩进（[indent]），让分割线与它下面的内容对齐。
class SettingsCardGroupDivider extends StatelessWidget {
  const SettingsCardGroupDivider({super.key, this.indent = 16});

  /// 起点缩进；右侧固定 16。
  final double indent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = colorScheme.brightness == Brightness.light;
    return Padding(
      padding: EdgeInsetsDirectional.only(start: indent, end: 16),
      child: Divider(
        height: 1,
        thickness: 0.6,
        color: colorScheme.outlineVariant.withValues(
          alpha: isLight ? 0.35 : 0.18,
        ),
      ),
    );
  }
}
