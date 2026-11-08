import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../controllers/todo_actions.dart';
import '../controllers/todo_list_actions.dart';
import '../controllers/todo_navigation.dart';
import '../models/todo_settings.dart';
import '../models/todo_view.dart';
import '../providers/todo_providers.dart';
import '../widgets/todo_labels.dart';
import '../widgets/todo_sheet.dart';

/// 视图 [view] 里已完成的条数（“清除已完成”用）：已完成视图为全部，清单与
/// 收集箱为其中已完成的，其余视图没有已完成的可清。
int countCompletedInView(TodoView view, List<TodoRow> completed) {
  if (view.smart == TodoSmartView.completed) return completed.length;
  if (!view.isSingleList) return 0;
  return completed.where((row) => row.listId == view.listId).length;
}

/// 待办页头的“更多”：项目多（排序、显示已完成、清除已完成、编辑 / 删除
/// 清单、管理清单），按规范用底部面板而不是弹出菜单。
class TodosPageMenu extends ConsumerWidget {
  const TodosPageMenu({
    super.key,
    required this.view,
    required this.settings,
    required this.completedInView,
    this.list,
  });

  final TodoView view;
  final TodoSettings settings;
  final int completedInView;

  /// 当前是清单视图时的清单。
  final TodoListRow? list;

  Future<void> _save(WidgetRef ref, TodoSettings next) async {
    final service = ref.read(settingsServiceProvider).asData?.value;
    if (service != null) await saveTodoSettings(service, next);
  }

  Future<void> _pickSort(BuildContext context, WidgetRef ref) async {
    final mode = await showTodoSheet<TodoSortMode>(
      context: context,
      builder: (BuildContext sheetContext) {
        final l10n = sheetContext.l10n;
        return TodoSheetBody(
          title: l10n.todoSortTitle,
          children: <Widget>[
            for (final mode in TodoSortMode.values)
              TodoSheetOption(
                icon: switch (mode) {
                  TodoSortMode.manual => FontAwesomeIcons.gripVertical,
                  TodoSortMode.due => FontAwesomeIcons.calendar,
                  TodoSortMode.priority => FontAwesomeIcons.flag,
                  TodoSortMode.created => FontAwesomeIcons.clock,
                },
                label: TodoLabels.sortMode(l10n, mode),
                selected: mode == settings.sort,
                onTap: () => Navigator.of(sheetContext).pop(mode),
              ),
          ],
        );
      },
    );
    if (mode != null) await _save(ref, settings.copyWith(sort: mode));
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final database = ref.read(appDatabaseProvider);
    final action = await showTodoSheet<_MenuAction>(
      context: context,
      builder: (BuildContext sheetContext) {
        final l10n = sheetContext.l10n;
        void pick(_MenuAction value) => Navigator.of(sheetContext).pop(value);
        return TodoSheetBody(
          title: l10n.todoMore,
          children: <Widget>[
            if (view.smart != TodoSmartView.completed)
              TodoSheetOption(
                icon: FontAwesomeIcons.arrowDownWideShort,
                label: l10n.todoSortLabel(
                  TodoLabels.sortMode(l10n, settings.sort),
                ),
                onTap: () => pick(_MenuAction.sort),
              ),
            if (view.isSingleList)
              TodoSheetOption(
                icon: settings.showCompleted
                    ? FontAwesomeIcons.eyeSlash
                    : FontAwesomeIcons.eye,
                label: settings.showCompleted
                    ? l10n.todoHideCompleted
                    : l10n.todoShowCompleted,
                onTap: () => pick(_MenuAction.toggleCompleted),
              ),
            if (completedInView > 0)
              TodoSheetOption(
                icon: FontAwesomeIcons.broom,
                label: l10n.todoClearCompleted,
                destructive: true,
                onTap: () => pick(_MenuAction.clearCompleted),
              ),
            if (list != null) ...<Widget>[
              TodoSheetOption(
                icon: FontAwesomeIcons.pen,
                label: l10n.todoListEdit,
                onTap: () => pick(_MenuAction.editList),
              ),
              TodoSheetOption(
                icon: FontAwesomeIcons.trashCan,
                label: l10n.todoListDelete,
                destructive: true,
                onTap: () => pick(_MenuAction.deleteList),
              ),
            ],
            TodoSheetOption(
              icon: FontAwesomeIcons.sliders,
              label: l10n.todoListManage,
              onTap: () => pick(_MenuAction.manageLists),
            ),
          ],
        );
      },
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _MenuAction.sort:
        await _pickSort(context, ref);
      case _MenuAction.toggleCompleted:
        await _save(
          ref,
          settings.copyWith(showCompleted: !settings.showCompleted),
        );
      case _MenuAction.clearCompleted:
        await clearCompletedTodos(
          context,
          database,
          count: completedInView,
          listId: view.listId,
          allLists: view.smart == TodoSmartView.completed,
        );
      case _MenuAction.editList:
        await editTodoListFlow(context, ref, list!);
      case _MenuAction.deleteList:
        await deleteTodoListFlow(context, ref, list!);
      case _MenuAction.manageLists:
        await openTodoListsManage(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: context.l10n.todoMore,
      onPressed: () => unawaited(_open(context, ref)),
      icon: const FaIcon(FontAwesomeIcons.ellipsis, size: 18),
    );
  }
}

enum _MenuAction {
  sort,
  toggleCompleted,
  clearCompleted,
  editList,
  deleteList,
  manageLists,
}
