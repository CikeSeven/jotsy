import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../models/todo_view.dart';
import '../providers/todo_providers.dart';
import '../viewmodels/todo_groups.dart';
import '../widgets/todo_sheet.dart';
import '../widgets/todo_view_switcher.dart';

/// 视图面板的结果：选了一个视图，或要新建 / 管理清单（由页面接着处理，
/// 面板先关掉，新建清单的编辑面板与管理页不叠在视图面板上）。
sealed class TodoViewSheetResult {
  const TodoViewSheetResult();
}

final class TodoViewPicked extends TodoViewSheetResult {
  const TodoViewPicked(this.view);

  final TodoView view;
}

final class TodoViewCreateList extends TodoViewSheetResult {
  const TodoViewCreateList();
}

final class TodoViewManageLists extends TodoViewSheetResult {
  const TodoViewManageLists();
}

/// 窄窗口点页头“今天 ▾”弹出的视图面板（经 [showTodoSheet]，按内容高度
/// 展开，清单多时在面板内滚动）：3 列智能视图方块 + “我的清单”（各带进度
/// 条）+ 新建清单。面板内容自己订阅数据，开着时数字照常更新。
Future<TodoViewSheetResult?> showTodoViewSheet(
  BuildContext context, {
  required TodoView current,
}) {
  return showTodoSheet<TodoViewSheetResult>(
    context: context,
    builder: (BuildContext sheetContext) => _TodoViewSheet(current: current),
  );
}

class _TodoViewSheet extends ConsumerWidget {
  const _TodoViewSheet({required this.current});

  final TodoView current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final open = ref.watch(openTodosProvider).value ?? const <TodoRow>[];
    final lists = ref.watch(todoListsProvider).value ?? const <TodoListRow>[];
    final progress =
        ref.watch(todoListProgressProvider).value ??
        const <String?, TodoListProgress>{};
    final now = DateTime.now();
    final counts = todoSmartViewCounts(
      open,
      DateTime(now.year, now.month, now.day),
    );
    void pop(TodoViewSheetResult result) => Navigator.of(context).pop(result);
    return TodoSheetBody(
      title: l10n.todoViewSheetTitle,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
          child: TodoSmartViewGrid(
            view: current,
            counts: counts,
            columns: 3,
            onSelected: (TodoView view) => pop(TodoViewPicked(view)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
          child: TodoListsSectionHeader(
            onManage: () => pop(const TodoViewManageLists()),
          ),
        ),
        for (final list in lists)
          TodoListNavRow(
            list: list,
            progress: progress[list.listId],
            selected: current.listId == list.listId,
            onTap: () => pop(TodoViewPicked(TodoView.list(list.listId))),
          ),
        TodoNewListRow(onTap: () => pop(const TodoViewCreateList())),
      ],
    );
  }
}
