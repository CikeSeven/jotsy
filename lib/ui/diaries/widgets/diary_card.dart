import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:node_diary/core/database/app_database.dart';

import '../../../l10n/app_localizations.dart';
import '../../../utils/relative_time_formatter.dart';

/// 笔记列表卡片组件。
///
/// 布局结构：
/// - 顶部：标题 + 选中态图标；
/// - 中部：正文预览（最多两行）；
/// - 底部：相对更新时间。
class DiaryCard extends StatelessWidget {
  const DiaryCard({
    super.key,
    required this.diary,
    required this.onTap,
    required this.onLongPress,
    required this.selected,
  });

  final DiaryWithTags diary;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final preview = diary.diary.contentText.replaceAll('\n', ' ');
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border:
            selected
                ? Border.all(color: colorScheme.primary.withValues(alpha: 0.55))
                : null,
      ),
      child: Card(
        margin: EdgeInsets.zero,
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题行（含选中态图标）。
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        diary.diary.title,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (selected)
                      Icon(
                        CupertinoIcons.check_mark_circled_solid,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                  ],
                ),
                // 正文摘要（无正文则不占位）。
                if (diary.diary.content.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  // 更新时间行。
                  const SizedBox(height: 8),
                ] else
                  const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      RelativeTimeFormatter.formatUpdatedAt(
                        updatedAt: diary.diary.updatedAt,
                        now: DateTime.now(),
                        l10n: l10n,
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
