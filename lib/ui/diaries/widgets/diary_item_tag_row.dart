import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';

/// 日记卡片内的标签展示行（仅展示，不可交互）。
///
/// 规则：
/// - 最多展示前 2 个标签；
/// - 超出部分使用 `+N` 汇总；
/// - 单行展示，标签文本超长时省略。
class DiaryItemTagRow extends StatelessWidget {
  const DiaryItemTagRow({
    super.key,
    required this.tags,
  });

  static const int _maxVisibleTags = 2;

  final List<Tag> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final visibleTags = tags.take(_maxVisibleTags).toList(growable: false);
    final hiddenCount = tags.length - visibleTags.length;
    final children = <Widget>[
      for (var index = 0; index < visibleTags.length; index += 1) ...[
        Flexible(
          fit: FlexFit.loose,
          child: _DiaryTagText(
            label: visibleTags[index].name,
            hashColor: Color(visibleTags[index].color),
            textColor: colorScheme.onSurfaceVariant,
          ),
        ),
        if (index < visibleTags.length - 1 || hiddenCount > 0)
          const SizedBox(width: 8),
      ],
      if (hiddenCount > 0)
        Text(
          '+$hiddenCount',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
    ];

    return SizedBox(
      height: 22,
      child: Row(children: children),
    );
  }
}

class _DiaryTagText extends StatelessWidget {
  const _DiaryTagText({
    required this.label,
    required this.hashColor,
    required this.textColor,
  });

  final String label;
  final Color hashColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '# ',
            style: Theme.of(context).textTheme.labelLarge ?.copyWith(
              color: hashColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ]
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
