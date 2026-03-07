import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';

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
  });

  final bool isSelectionMode;
  final int selectedCount;
  final VoidCallback onCancelSelection;
  final VoidCallback onArchiveSelected;
  final VoidCallback onDeleteSelected;
  final VoidCallback onOpenArchived;

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
          ] else
            IconButton(
              tooltip: '已归档笔记',
              onPressed: onOpenArchived,
              icon: const Icon(CupertinoIcons.archivebox),
            ),
        ],
      ),
    );
  }
}
