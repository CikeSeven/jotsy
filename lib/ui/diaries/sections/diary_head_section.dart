import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_effects.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';

enum DiarySortMode { updatedDesc, updatedAsc, titleAsc }

enum DiaryLayoutMode { list, waterfall }

enum DiaryMenuAction {
  sortUpdatedDesc,
  sortUpdatedAsc,
  sortTitleAsc,
  layoutList,
  layoutWaterfall,
}

/// 日记页顶部头部区块。
///
/// 布局职责：
/// - 左侧展示页面标题或多选计数；
/// - 右侧展示操作按钮（取消选择、归档、删除、归档列表入口）。
class DiaryHeadSection extends StatelessWidget {
  const DiaryHeadSection({
    super.key,
    required this.isSelectionMode,
    required this.selectedCount,
    required this.onCancelSelection,
    required this.onArchiveSelected,
    required this.onDeleteSelected,
    required this.onOpenArchived,
    required this.sortMode,
    required this.layoutMode,
    required this.onMenuSelected,
    required this.searchFieldKey,
    required this.searchPreviewText,
    required this.searchEnabled,
  });

  final bool isSelectionMode;
  final int selectedCount;
  final VoidCallback onCancelSelection;
  final VoidCallback onArchiveSelected;
  final VoidCallback onDeleteSelected;
  final VoidCallback onOpenArchived;
  final DiarySortMode sortMode;
  final DiaryLayoutMode layoutMode;
  final ValueChanged<DiaryMenuAction> onMenuSelected;
  final GlobalKey searchFieldKey;
  final String searchPreviewText;
  final bool searchEnabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.m,
        AppSpacing.l,
        0,
      ),
      child: Row(
        children: [
          if (isSelectionMode) ...[
            Expanded(
              child: Text(
                'Jotsy',
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: '取消',
              onPressed: onCancelSelection,
              icon: const FaIcon(FontAwesomeIcons.xmark, size: 18),
            ),
            IconButton(
              tooltip: '归档',
              onPressed: onArchiveSelected,
              icon: const FaIcon(FontAwesomeIcons.boxArchive, size: 18),
            ),
            IconButton(
              tooltip: '删除',
              onPressed: onDeleteSelected,
              icon: FaIcon(
                FontAwesomeIcons.trashCan,
                size: 18,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ] else ...[
            Text(
              'Jotsy',
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: AppSpacing.xl),
            Expanded(
              child: _SearchPreview(
                searchFieldKey: searchFieldKey,
                searchPreviewText: searchPreviewText,
                searchEnabled: searchEnabled,
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            IconButton(
              tooltip: '已归档笔记',
              onPressed: onOpenArchived,
              icon: const FaIcon(FontAwesomeIcons.boxArchive, size: 18),
            ),
            IconButton(
              tooltip: '更多',
              onPressed: () => _showSettingsSheet(context),
              icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              AppSpacing.s,
              AppSpacing.l,
              AppSpacing.l,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FaIcon(
                      FontAwesomeIcons.arrowDownWideShort,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Text(
                      '排序方式',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                _ActionTile(
                  label: '最近更新',
                  selected: sortMode == DiarySortMode.updatedDesc,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onMenuSelected(DiaryMenuAction.sortUpdatedDesc);
                  },
                ),
                _ActionTile(
                  label: '最早更新',
                  selected: sortMode == DiarySortMode.updatedAsc,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onMenuSelected(DiaryMenuAction.sortUpdatedAsc);
                  },
                ),
                _ActionTile(
                  label: '标题 A-Z',
                  selected: sortMode == DiarySortMode.titleAsc,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onMenuSelected(DiaryMenuAction.sortTitleAsc);
                  },
                ),
                const SizedBox(height: AppSpacing.s),
                Row(
                  children: [
                    FaIcon(
                      FontAwesomeIcons.tableCellsLarge,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Text(
                      '显示布局',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                _ActionTile(
                  label: '列表',
                  selected: layoutMode == DiaryLayoutMode.list,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onMenuSelected(DiaryMenuAction.layoutList);
                  },
                ),
                _ActionTile(
                  label: '瀑布流',
                  selected: layoutMode == DiaryLayoutMode.waterfall,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onMenuSelected(DiaryMenuAction.layoutWaterfall);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SearchPreview extends StatelessWidget {
  const _SearchPreview({
    required this.searchFieldKey,
    required this.searchPreviewText,
    required this.searchEnabled,
  });

  final GlobalKey searchFieldKey;
  final String searchPreviewText;
  final bool searchEnabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hintStyle = Theme.of(context).textTheme.bodyMedium;
    final textStyle = Theme.of(context).textTheme.bodyMedium;
    final displayedText = searchPreviewText.trim();
    final hasText = displayedText.isNotEmpty;

    return Container(
      key: searchFieldKey,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.nav),
        boxShadow: AppEffects.softShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color:
                      searchEnabled
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppRadii.nav),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.nav),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 17,
                  sigmaY: 17,
                  tileMode: TileMode.mirror,
                ),
                child: Container(
                  color:
                      searchEnabled
                          ? colorScheme.primary.withAlpha(20)
                          : colorScheme.surfaceContainerHigh,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      FaIcon(
                        FontAwesomeIcons.magnifyingGlass,
                        size: 14,
                        color:
                            searchEnabled
                                ? colorScheme.onSurfaceVariant
                                : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          hasText ? displayedText : '搜索标题或内容',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              hasText
                                  ? textStyle?.copyWith(color: colorScheme.onSurface)
                                  : hintStyle?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: AppSpacing.l),
      onTap: onTap,
      title: Text(label),
      trailing: selected ? const FaIcon(FontAwesomeIcons.check, size: 16) : null,
    );
  }
}
