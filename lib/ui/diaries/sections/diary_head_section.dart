import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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

/// 笔记页顶部头部区块。
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
              icon: const Icon(CupertinoIcons.xmark),
            ),
            IconButton(
              tooltip: '归档',
              onPressed: onArchiveSelected,
              icon: const Icon(CupertinoIcons.archivebox),
            ),
            IconButton(
              tooltip: '删除',
              onPressed: onDeleteSelected,
              icon: Icon(
                CupertinoIcons.delete,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ] else ...[
            IconButton(
              tooltip: '已归档笔记',
              onPressed: onOpenArchived,
              icon: const Icon(CupertinoIcons.archivebox),
            ),
            PopupMenuButton<DiaryMenuAction>(
              tooltip: '更多',
              onSelected: onMenuSelected,
              icon: const Icon(Icons.more_vert),
              itemBuilder: (BuildContext context) {
                return <PopupMenuEntry<DiaryMenuAction>>[
                  PopupMenuItem<DiaryMenuAction>(
                    value: DiaryMenuAction.sortUpdatedDesc,
                    child: _MenuRow(
                      label: '排序：最近更新',
                      selected: sortMode == DiarySortMode.updatedDesc,
                    ),
                  ),
                  PopupMenuItem<DiaryMenuAction>(
                    value: DiaryMenuAction.sortUpdatedAsc,
                    child: _MenuRow(
                      label: '排序：最早更新',
                      selected: sortMode == DiarySortMode.updatedAsc,
                    ),
                  ),
                  PopupMenuItem<DiaryMenuAction>(
                    value: DiaryMenuAction.sortTitleAsc,
                    child: _MenuRow(
                      label: '排序：标题 A-Z',
                      selected: sortMode == DiarySortMode.titleAsc,
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<DiaryMenuAction>(
                    value: DiaryMenuAction.layoutList,
                    child: _MenuRow(
                      label: '布局：列表',
                      selected: layoutMode == DiaryLayoutMode.list,
                    ),
                  ),
                  PopupMenuItem<DiaryMenuAction>(
                    value: DiaryMenuAction.layoutWaterfall,
                    child: _MenuRow(
                      label: '布局：瀑布流',
                      selected: layoutMode == DiaryLayoutMode.waterfall,
                    ),
                  ),
                ];
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        if (selected) const Icon(Icons.check, size: 18),
      ],
    );
  }
}
