import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/relative_time_formatter.dart';
import '../widgets/diaries_empty_state.dart';
import '../widgets/swipe_action_background.dart';
import 'diary_head_section.dart';

/// 日记页主列表区块。
class DiariesListSection extends StatelessWidget {
  const DiariesListSection({
    super.key,
    required this.themeBrightness,
    required this.tags,
    required this.diaries,
    required this.layoutMode,
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
  final List<DiaryWithTags> diaries;
  final DiaryLayoutMode layoutMode;
  final Set<String> selectedDiaryIds;
  final bool isSelectionMode;
  final double listBottomOffset;
  final VoidCallback onCreate;
  final void Function(String diaryId, Rect? sourceGlobalRect) onOpenEditor;
  final void Function(String noteId, bool forceSelect) onToggleSelection;
  final Future<void> Function(DiaryWithTags note) onArchiveBySwipe;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLightMode = themeBrightness == Brightness.light;
    final backgroundColor = isLightMode ? Colors.white : colorScheme.surface;

    if (layoutMode == DiaryLayoutMode.waterfall) {
      return _buildWaterfallView(context, backgroundColor);
    }
    return _buildListView(context, backgroundColor);
  }

  Widget _buildListView(BuildContext context, Color backgroundColor) {
    final itemCount = diaries.isEmpty ? 1 : diaries.length;
    return Expanded(
      child: Container(
        color: backgroundColor,
        child: ListView.separated(
          key: PageStorageKey<String>('notes_list_${themeBrightness.name}'),
          padding: EdgeInsets.only(bottom: listBottomOffset),
          itemCount: itemCount,
          separatorBuilder: (BuildContext context, int index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
              child: Divider(
                height: 1,
                thickness: 1,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.22),
              ),
            );
          },
          itemBuilder: (BuildContext context, int index) {
            if (diaries.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.m,
                  vertical: AppSpacing.m,
                ),
                child: DiariesEmptyState(onCreate: onCreate),
              );
            }
            return _buildDiaryItem(
              context,
              diary: diaries[index],
              compact: false,
              backgroundColor: backgroundColor,
            );
          },
        ),
      ),
    );
  }

  Widget _buildWaterfallView(BuildContext context, Color backgroundColor) {
    return Expanded(
      child: Container(
        color: backgroundColor,
        child: CustomScrollView(
          key: PageStorageKey<String>('notes_waterfall_${themeBrightness.name}'),
          slivers: <Widget>[
            if (diaries.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.m,
                    vertical: AppSpacing.m,
                  ),
                  child: DiariesEmptyState(onCreate: onCreate),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.m,
                  AppSpacing.m,
                  AppSpacing.m,
                  listBottomOffset,
                ),
                sliver: SliverMasonryGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.s,
                  crossAxisSpacing: AppSpacing.s,
                  childCount: diaries.length,
                  itemBuilder: (BuildContext context, int index) {
                    return _buildDiaryItem(
                      context,
                      diary: diaries[index],
                      compact: true,
                      backgroundColor: backgroundColor,
                    );
                  },
                ),
              ),
            if (diaries.isEmpty) SliverToBoxAdapter(child: SizedBox(height: listBottomOffset)),
          ],
        ),
      ),
    );
  }

  Widget _buildDiaryItem(
    BuildContext context, {
    required DiaryWithTags diary,
    required bool compact,
    required Color backgroundColor,
  }) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final selected = selectedDiaryIds.contains(diary.diary.diaryId);
    final title = diary.diary.title.trim().isEmpty ? '无标题' : diary.diary.title;
    final preview = diary.diary.contentText.replaceAll('\n', ' ').trim();

    Widget item = Builder(
      builder: (BuildContext itemContext) {
        Rect? sourceRect;

        Rect? resolveRect() {
          final renderObject = itemContext.findRenderObject();
          if (renderObject is! RenderBox ||
              !renderObject.hasSize ||
              !renderObject.attached) {
            return null;
          }
          final topLeft = renderObject.localToGlobal(Offset.zero);
          return topLeft & renderObject.size;
        }

        final content = compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
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
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      preview,
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    RelativeTimeFormatter.formatUpdatedAt(
                      updatedAt: diary.diary.updatedAt,
                      now: DateTime.now(),
                      l10n: l10n,
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        if (preview.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            preview,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          RelativeTimeFormatter.formatUpdatedAt(
                            updatedAt: diary.diary.updatedAt,
                            now: DateTime.now(),
                            l10n: l10n,
                          ),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 8),
                    Icon(
                      CupertinoIcons.check_mark_circled_solid,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                  ],
                ],
              );

        return Material(
          color: backgroundColor,
          child: InkWell(
            borderRadius: compact ? BorderRadius.circular(14) : null,
            onTapDown: (_) => sourceRect = resolveRect(),
            onTap: () {
              if (isSelectionMode) {
                onToggleSelection(diary.diary.diaryId, false);
                return;
              }
              onOpenEditor(diary.diary.diaryId, sourceRect ?? resolveRect());
            },
            onLongPress: () => onToggleSelection(diary.diary.diaryId, true),
            child: Container(
              decoration: compact
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? colorScheme.primary.withValues(alpha: 0.55)
                            : Theme.of(context).dividerColor.withValues(alpha: 0.22),
                      ),
                    )
                  : null,
              padding: EdgeInsets.fromLTRB(
                compact ? 12 : 16,
                compact ? 10 : 12,
                compact ? 12 : 16,
                compact ? 10 : 12,
              ),
              child: content,
            ),
          ),
        );
      },
    );

    if (isSelectionMode) {
      return item;
    }

    return Dismissible(
      key: ValueKey<String>(
        '${compact ? 'waterfall' : 'list'}-${diary.diary.diaryId}',
      ),
      direction: DismissDirection.endToStart,
      background: SwipeActionBackground(
        label: '归档',
        icon: CupertinoIcons.archivebox_fill,
        color: Theme.of(context).colorScheme.primary,
      ),
      confirmDismiss: (_) async {
        await onArchiveBySwipe(diary);
        return false;
      },
      child: item,
    );
  }
}
