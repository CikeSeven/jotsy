import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
          Expanded(
            child: Text(
              'Jotsy',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (isSelectionMode) ...[
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
