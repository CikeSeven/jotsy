import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../widgets/todo_labels.dart';
import '../widgets/todo_list_picker_sheet.dart';
import 'todo_actions.dart';

/// 多选与“全部改到今天”的批量操作流程：写库（`_AppDatabaseTodoBatchOps`，
/// 各在一个事务里）后给出可撤销的提示（[showTodoUndoHint]）。
///
/// 撤销用调用前取好的 [AppDatabase]：提示关闭时页面可能已卸载。改日期 /
/// 清单 / 优先级的批量写入返回改动前的行（值没变的行不写、不在其中），
/// 撤销经 `restoreTodoFields` 把同一列写回；完成按倒序逐条
/// `undoTodoCompletion`；删除经 `restoreTodos` 原样写回。

/// 批量完成。
Future<void> completeTodosWithUndo(
  BuildContext context,
  AppDatabase database,
  Iterable<String> ids,
) async {
  final completions = await database.completeTodos(ids);
  if (completions.isEmpty || !context.mounted) return;
  final undone = await showTodoUndoHint(
    context,
    context.l10n.todoBatchCompleted(completions.length),
  );
  if (!undone) return;
  for (final completion in completions.reversed) {
    await database.undoTodoCompletion(completion);
  }
}

/// 批量改截止日到 [date]（null 即移除日期）。[minute] 为 null 时每条保留
/// 自己原来的时刻（按时刻分组各写一次，全天的仍是全天），不会因为批量改
/// 日期把有时刻的待办改成全天、连带去掉它们的“准时 / 提前”提醒；给出
/// [minute] 时一律改成这个时刻。整批一条可撤销提示。
Future<void> setTodosDueWithUndo(
  BuildContext context,
  AppDatabase database,
  List<TodoRow> rows, {
  required DateTime? date,
  int? minute,
}) async {
  final before = <TodoRow>[];
  if (date == null || minute != null) {
    before.addAll(
      await database.setTodosDue(
        rows.map((row) => row.todoId),
        date: date,
        minute: minute,
      ),
    );
  } else {
    final byMinute = <int?, List<String>>{};
    for (final row in rows) {
      byMinute.putIfAbsent(row.dueMinute, () => <String>[]).add(row.todoId);
    }
    for (final entry in byMinute.entries) {
      before.addAll(
        await database.setTodosDue(entry.value, date: date, minute: entry.key),
      );
    }
  }
  if (before.isEmpty || !context.mounted) return;
  final l10n = context.l10n;
  final now = DateTime.now();
  final message = date == null
      ? l10n.todoBatchDueRemoved(before.length)
      : l10n.todoBatchDueSet(
          before.length,
          TodoLabels.due(
            context,
            date,
            minute,
            DateTime(now.year, now.month, now.day),
          ),
        );
  final undone = await showTodoUndoHint(context, message);
  if (undone) await database.restoreTodoFields(before, TodoBatchField.due);
}

/// 批量移到清单（[listId] 为 null 即收集箱），[listName] 写进提示。
Future<void> moveTodosToListWithUndo(
  BuildContext context,
  AppDatabase database,
  Iterable<String> ids, {
  required String? listId,
  required String listName,
}) async {
  final before = await database.setTodosListId(ids, listId);
  if (before.isEmpty || !context.mounted) return;
  final undone = await showTodoUndoHint(
    context,
    context.l10n.todoBatchMoved(before.length, listName),
  );
  if (undone) await database.restoreTodoFields(before, TodoBatchField.list);
}

/// 批量设优先级。
Future<void> setTodosPriorityWithUndo(
  BuildContext context,
  AppDatabase database,
  Iterable<String> ids,
  TodoPriority priority,
) async {
  final before = await database.setTodosPriority(ids, priority);
  if (before.isEmpty || !context.mounted) return;
  final l10n = context.l10n;
  final undone = await showTodoUndoHint(
    context,
    l10n.todoBatchPrioritySet(
      before.length,
      TodoLabels.priority(l10n, priority),
    ),
  );
  if (undone) {
    await database.restoreTodoFields(before, TodoBatchField.priority);
  }
}

/// 批量删除（硬删除，可撤销）。
Future<void> deleteTodosWithUndo(
  BuildContext context,
  AppDatabase database,
  Iterable<String> ids,
) async {
  final rows = await database.deleteTodos(ids);
  if (rows.isEmpty || !context.mounted) return;
  final undone = await showTodoUndoHint(
    context,
    context.l10n.todoBatchDeleted(rows.length),
  );
  if (undone) await database.restoreTodos(rows);
}

/// 把几条待办改到某一天（各自保留时刻）：右键“改到今天”、逾期组的“全部
/// 改到今天”共用。
Future<void> todoMoveRowsToDay(
  BuildContext context,
  WidgetRef ref,
  List<TodoRow> rows,
  DateTime day,
) => setTodosDueWithUndo(
  context,
  ref.read(appDatabaseProvider),
  rows,
  date: day,
);

/// 选一个清单，把几条待办移进去（右键“移到清单…”、多选的“清单”共用）。
Future<void> todoMoveRowsToList(
  BuildContext context,
  WidgetRef ref,
  List<TodoRow> rows,
) async {
  if (rows.isEmpty) return;
  final database = ref.read(appDatabaseProvider);
  final choice = await showTodoListPickerSheet(
    context,
    current: rows.length == 1 ? rows.single.listId : null,
  );
  if (choice == null || !context.mounted) return;
  final listId = choice.listId;
  String name = context.l10n.todoViewInbox;
  if (listId != null) {
    final list = await database.getTodoList(listId);
    if (list != null) name = list.name;
  }
  if (!context.mounted) return;
  await moveTodosToListWithUndo(
    context,
    database,
    rows.map((row) => row.todoId),
    listId: listId,
    listName: name,
  );
}
