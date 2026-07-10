import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';

/// 日记卡片内的标签展示区，仅负责展示，不处理标签交互。
///
/// 规则：
/// - 展示数量由调用方配置，默认展示前 2 个，传入 0 时隐藏整个区域；
/// - 超出部分使用 `+N` 汇总；
/// - 每个标签保持单行省略，标签集合则根据卡片可用宽度自动换行。
class DiaryItemTagRow extends StatelessWidget {
  const DiaryItemTagRow({
    super.key,
    required this.tags,
    this.maxVisibleTags = 2,
  });

  final List<Tag> tags;
  final int maxVisibleTags;

  @override
  Widget build(BuildContext context) {
    final effectiveLimit =
        maxVisibleTags < 0
            ? 0
            : maxVisibleTags > tags.length
            ? tags.length
            : maxVisibleTags;
    if (tags.isEmpty || effectiveLimit == 0) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final visibleTags = tags.take(effectiveLimit).toList(growable: false);
    final hiddenCount = tags.length - effectiveLimit;

    // 较高展示上限会让标签超过一行，瀑布流窄卡片尤其明显；按可用宽度换行
    // 可避免横向 RenderFlex 溢出，同时保留每个标签自身的单行省略行为。
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: <Widget>[
        for (final tag in visibleTags)
          _DiaryTagText(
            label: tag.name,
            hashColor: Color(tag.color),
            textColor: colorScheme.onSurfaceVariant,
          ),
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
      ],
    );
  }
}

/// 单个标签文案片段：彩色 `#` + 标签名。
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
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
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
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
