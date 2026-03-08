import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/ui/diaries/widgets/diary_card.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../widgets/diaries_empty_state.dart';
import '../widgets/swipe_action_background.dart';


/// 笔记页主列表区块。
///
/// 布局职责：
/// - 顶部列表标题行；
/// - 空状态展示；
/// - 普通卡片列表；
/// - 非多选模式下支持左滑归档。
class DiariesListSection extends StatelessWidget {
  static const Duration _searchRowAnimationDuration = Duration(
    milliseconds: 280,
  );

  const DiariesListSection({
    super.key,
    required this.themeBrightness,
    required this.tags,
    required this.searchFieldKey,
    required this.searchPreviewText,
    required this.animateSearchRow,
    required this.searchEnabled,
    required this.diaries,
    required this.selectedDiaryIds,
    required this.isSelectionMode,
    required this.listBottomOffset,
    required this.onCreate,
    required this.onOpenEditor,
    required this.onToggleSelection,
    required this.onArchiveBySwipe,
  });
  final Brightness themeBrightness;
  final List<Tag> tags;
  final GlobalKey searchFieldKey;
  final String searchPreviewText;
  final bool animateSearchRow;
  final bool searchEnabled;
  final List<DiaryWithTags> diaries;
  final Set<String> selectedDiaryIds;
  final bool isSelectionMode;
  final double listBottomOffset;
  final VoidCallback onCreate;
  final ValueChanged<String?> onOpenEditor;
  final void Function(String noteId, bool forceSelect) onToggleSelection;
  final Future<void> Function(DiaryWithTags note) onArchiveBySwipe;

  @override
  Widget build(BuildContext context) {
    final baseItemCount = diaries.isEmpty ? 2 : diaries.length + 1;
    final itemCount = baseItemCount + 1;
    return Expanded(
      child: ListView.separated(
        key: PageStorageKey<String>('notes_list_${themeBrightness.name}'),
        padding: EdgeInsets.only(bottom: listBottomOffset),
        itemCount: itemCount,
        separatorBuilder: (context, index) {
          return const SizedBox(height: AppSpacing.s);
        },
        itemBuilder: (context, index) {
          // 区块一：搜索框（列表顶部，随列表滚动）。
          if (index == 0) {
            final hintStyle = Theme.of(context).textTheme.bodyMedium;
            final textStyle = Theme.of(context).textTheme.bodyLarge;
            final colorScheme = Theme.of(context).colorScheme;
            final displayedText = searchPreviewText.trim();
            final hasText = displayedText.isNotEmpty;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
              child: ClipRect(
                child: GestureDetector(
                  onTap: null,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color:
                          searchEnabled
                              ? colorScheme.surfaceContainerHighest
                              : colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color:
                            searchEnabled
                                ? Theme.of(
                                  context,
                                ).dividerColor.withValues(alpha: 0.22)
                                : Theme.of(
                                  context,
                                ).dividerColor.withValues(alpha: 0.1),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.search,
                          size: 18,
                          color:
                              searchEnabled
                                  ? colorScheme.onSurfaceVariant
                                  : colorScheme.onSurfaceVariant.withValues(
                                    alpha: 0.45,
                                  ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            hasText ? displayedText : '搜索标题或内容',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                hasText
                                    ? textStyle?.copyWith(
                                      color: colorScheme.onSurface,
                                    )
                                    : hintStyle?.copyWith(
                                      color: colorScheme.onSurfaceVariant
                                          .withValues(
                                            alpha: 0.9,
                                          ),
                                      ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          final effectiveIndex = index - 1;

          // 区块二：列表标题行（位于搜索框下方，随列表滚动）。
          if (effectiveIndex == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '日记',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    DateFormat('MMM d').format(DateTime.now()),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          // 区块三：空状态。
          if (diaries.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
              child: DiariesEmptyState(onCreate: onCreate),
            );
          }

          // 区块四：普通笔记卡片。
          final diary = diaries[effectiveIndex - 1];
          final selected = selectedDiaryIds.contains(diary.diary.diaryId);

          Widget card = Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
            child: DiaryCard(
              diary: diary,
              selected: selected,
              onTap: () {
                if (isSelectionMode) {
                  onToggleSelection(diary.diary.diaryId, false);
                  return;
                }
                onOpenEditor(diary.diary.diaryId);
              },
              onLongPress: () => onToggleSelection(diary.diary.diaryId, true),
            ),
          );

          // 多选模式下关闭滑动手势，避免与批量操作语义冲突。
          if (isSelectionMode) {
            return card;
          }

          return Dismissible(
            key: ValueKey<String>('active-${diary.diary.diaryId}'),
            direction: DismissDirection.endToStart,
            background: SwipeActionBackground(
              label: '归档',
              icon: CupertinoIcons.archivebox_fill,
              color: Theme.of(context).colorScheme.primary,
            ),
            onDismissed: (_) async {
              await onArchiveBySwipe(diary);
            },
            child: card,
          );
        },
      ),
    );
  }
}
