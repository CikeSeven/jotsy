import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../viewmodels/notebook_book_layout.dart';

/// 首页按书序看一本日记本（全部章节）时，每章第一篇卡片上方的分隔行：
/// 章节名（`labelLarge` w700 `primary`）+ 篇数，高 32dp。未分章排在最后。
class NotebookChapterDivider extends StatelessWidget {
  const NotebookChapterDivider({
    super.key,
    required this.title,
    required this.count,
  });

  static const double height = 32;

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      header: true,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: AppSpacing.xs),
          child: Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Text(
                context.l10n.notebookEntryCount(count),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 给 `DiariesListSection.sectionHeaderBuilder` 用：[diaries] 是首页正显示的
/// 列表（已按书序排好），[entryChapters] 是本子里每篇日记的章节
/// （`notebookEntryChaptersProvider`）。某篇与上一篇章节不同（或是第一篇）时
/// 在它上方放一条分隔行，篇数为这一章的总篇数（与章节胶囊一致）。
Widget? Function(BuildContext context, int index) notebookBookSectionHeaders({
  required List<DiaryWithTags> diaries,
  required List<NotebookChapter> chapters,
  required Map<String, String?> entryChapters,
}) {
  final counts = NotebookChapterCounts.from(chapters, entryChapters);
  String? chapterAt(int index) => validNotebookChapterId(
    chapters,
    entryChapters[diaries[index].diary.diaryId],
  );
  return (BuildContext context, int index) {
    final chapterId = chapterAt(index);
    if (index > 0 && chapterAt(index - 1) == chapterId) {
      return null;
    }
    if (chapterId == null) {
      return NotebookChapterDivider(
        key: const ValueKey<String>('notebook_chapter_divider_unassigned'),
        title: context.l10n.notebookChapterUnassigned,
        count: counts.unassigned,
      );
    }
    final chapter = chapters.firstWhere((c) => c.id == chapterId);
    return NotebookChapterDivider(
      key: ValueKey<String>('notebook_chapter_divider_$chapterId'),
      title: chapter.title,
      count: counts.of(chapterId),
    );
  };
}
