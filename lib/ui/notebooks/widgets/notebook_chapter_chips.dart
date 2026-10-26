import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../widgets/expressive_state_blend.dart';
import '../providers/notebook_providers.dart';
import '../viewmodels/notebook_book_layout.dart';
import '../viewmodels/notebook_view.dart';
import 'notebook_header_card.dart';
import '../../widgets/desktop_horizontal_scroll.dart';

/// 首页日记本头部卡片里的章节胶囊行：全部 · 各章（按章节顺序）· 未分章。
///
/// 只在有章节的普通日记本里出现（由调用方判断）。每个胶囊带篇数，口径与
/// 首页列表一致（不算归档与回收站）；“未分章”只在有未分章的日记、或正选着
/// 它时出现。点按经 [onSelect] 交给日记页切换章节筛选（列表走筛选过渡），
/// 不改排序。放不下时横向滚动（首页这里没有左右翻页手势）。
class NotebookChapterChips extends ConsumerWidget {
  const NotebookChapterChips({
    super.key,
    required this.notebook,
    required this.selectedChapterId,
    required this.unassignedOnly,
    required this.onSelect,
  });

  final NotebookView notebook;
  final String? selectedChapterId;
  final bool unassignedOnly;

  /// 选中某章（[chapterId]）、未分章（[unassigned] 为 true）或全部（都为空）。
  final void Function({String? chapterId, bool unassigned}) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final chapters = notebook.payload.chapters;
    final entryChapters = ref
        .watch(notebookEntryChaptersProvider(notebook.id))
        .value;
    final counts = entryChapters == null
        ? null
        : NotebookChapterCounts.from(chapters, entryChapters);
    final isAll = selectedChapterId == null && !unassignedOnly;
    String label(String title, int? count) =>
        count == null ? title : l10n.notebookChapterChip(title, count);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.m),
      child: DesktopHorizontalScroll(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          // 放在卡片的铺满插槽里：左右内容边距与卡片内文字一致，滚出的胶囊在
          // 卡片边缘消失。最后一个胶囊自带的 end 间距并入右边距。
          padding: const EdgeInsetsDirectional.only(
            start: NotebookHeaderCard.contentPadding,
            end: NotebookHeaderCard.contentPadding - AppSpacing.s,
          ),
          child: Row(
            children: <Widget>[
              _ChapterChip(
                key: const ValueKey<String>('notebook_chapter_chip_all'),
                label: label(l10n.notebookChapterAll, counts?.total),
                selected: isAll,
                onTap: () => onSelect(),
              ),
              for (final chapter in chapters)
                _ChapterChip(
                  key: ValueKey<String>('notebook_chapter_chip_${chapter.id}'),
                  label: label(chapter.title, counts?.of(chapter.id)),
                  selected: selectedChapterId == chapter.id,
                  onTap: () => onSelect(chapterId: chapter.id),
                ),
              if ((counts?.unassigned ?? 0) > 0 || unassignedOnly)
                _ChapterChip(
                  key: const ValueKey<String>(
                    'notebook_chapter_chip_unassigned',
                  ),
                  label: label(
                    l10n.notebookChapterUnassigned,
                    counts?.unassigned,
                  ),
                  selected: unassignedOnly,
                  onTap: () => onSelect(unassigned: true),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 单个章节胶囊：选中为 `secondaryContainer`，未选为 `surfaceContainerHigh`，
/// 颜色经 [ExpressiveStateBlend] 补间。
class _ChapterChip extends StatelessWidget {
  const _ChapterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: AppSpacing.s),
      child: Semantics(
        button: true,
        selected: selected,
        child: ExpressiveStateBlend(
          active: selected,
          builder: (BuildContext context, double t, Widget? _) {
            final background = Color.lerp(
              scheme.surfaceContainerHigh,
              scheme.secondaryContainer,
              t,
            )!;
            final foreground = Color.lerp(
              scheme.onSurfaceVariant,
              scheme.onSecondaryContainer,
              t,
            )!;
            return Material(
              color: background,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 32),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.m,
                      vertical: 6,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: foreground,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
