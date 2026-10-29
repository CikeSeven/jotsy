import 'package:flutter/material.dart';

import '../../app_surface/widgets/app_page_backdrop.dart';

/// 同步页的分组标题：14 / w700 `onSurfaceVariant`，右侧可带 13 灰字或
/// “正在寻找…”（DESIGN.md §5.27 页面结构）。
///
/// 标题直接画在页面背景上：有背景图时经 `onBackgroundTextStyle` 保证可读。
class LanSyncSectionHeader extends StatelessWidget {
  const LanSyncSectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  /// 右侧 13 灰字的样式（调用方给 [trailing] 用，已含背景可读处理）。
  static TextStyle? trailingStyle(BuildContext context, {Color? color}) {
    final theme = Theme.of(context);
    return AppPageBackdrop.onBackgroundTextStyle(
      context,
      theme.textTheme.bodySmall?.copyWith(
        fontSize: 13,
        color: color ?? theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trailing = this.trailing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppPageBackdrop.onBackgroundTextStyle(
                  context,
                  theme.textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
