import 'package:flutter/material.dart';

/// 日记本二级页（目录、统计）顶栏的两行标题：页面名 + 日记本名（小字）。
class NotebookPageTitle extends StatelessWidget {
  const NotebookPageTitle({super.key, required this.title, this.subtitle});

  final String title;

  /// 日记本名；还没读到时为 null，只显示页面名。
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = this.subtitle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (subtitle != null)
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
