import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../app_surface/widgets/app_card_surface.dart';
import '../models/todo_view.dart';
import 'todo_row_drag.dart';
import 'todo_tag_nav.dart';
import 'todo_view_switcher.dart';

/// 宽窗口（≥1024）左栏：2 列智能视图网格 + 清单（各带进度条）+ 新建清单 +
/// 待办标签（有标签时）。给了 [onDrop]（桌面）时，今天、收集箱、各清单与
/// 各标签接得住拖来的待办行。
class TodoSidebar extends StatelessWidget {
  const TodoSidebar({
    super.key,
    required this.view,
    required this.lists,
    required this.counts,
    required this.progress,
    required this.onSelected,
    required this.onCreateList,
    required this.onManageLists,
    required this.tags,
    required this.onManageTags,
    this.onDrop,
  });

  final TodoView view;
  final List<TodoListRow> lists;
  final Map<TodoSmartView, int> counts;
  final Map<String?, TodoListProgress> progress;
  final ValueChanged<TodoView> onSelected;

  /// 桌面上把待办拖到今天、收集箱或清单上。
  final TodoViewDrop? onDrop;
  final VoidCallback onCreateList;
  final VoidCallback onManageLists;
  final List<TodoTagUsage> tags;
  final VoidCallback onManageTags;

  @override
  Widget build(BuildContext context) {
    return AppCardSurface(
      shadow: false,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.m),
        children: <Widget>[
          TodoSmartViewGrid(
            view: view,
            counts: counts,
            columns: 2,
            onSelected: onSelected,
            onDrop: onDrop,
          ),
          TodoListsSectionHeader(onManage: onManageLists),
          for (final list in lists)
            TodoDropTarget(
              onDrop: todoDropFor(onDrop, TodoView.list(list.listId)),
              child: TodoListNavRow(
                list: list,
                progress: progress[list.listId],
                selected: view.listId == list.listId,
                onTap: () => onSelected(TodoView.list(list.listId)),
              ),
            ),
          TodoNewListRow(onTap: onCreateList),
          TodoTagNavSection(
            tags: tags,
            view: view,
            onSelected: onSelected,
            onManage: onManageTags,
            onDrop: onDrop,
          ),
        ],
      ),
    );
  }
}
