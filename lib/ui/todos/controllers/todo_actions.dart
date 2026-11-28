import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../widgets/app_modal/app_dialog.dart';
import '../viewmodels/todo_series_rows.dart';
import '../widgets/todo_labels.dart';
import 'todo_completion_undo.dart';

/// 撤销提示的停留时间（非动画计时）。
const Duration _undoDuration = Duration(seconds: 5);

/// 待办的勾选、删除与清除流程（列表、详情页、日历卡片共用）。
///
/// 写库都交给 [AppDatabase]；提示一律用调用方的 context 经
/// [HomeHintVisibilityScope.showTrackedSnackBar] 弹出——它会把撤销窗口登记到
/// 局域网同步的注册表，提示在时同步先等着，撤销不会和同步写入打架。撤销用的
/// 是调用前取好的 [AppDatabase]：提示关闭时页面可能已卸载。

/// 勾选 / 取消勾选一条待办。完成时给出可撤销的提示：重复待办写明下一次的
/// 日子；给了 [undo]（待办页的列表）时经它与接连完成的几条合并成一条提示。
/// 取消完成重复待办的已完成副本时：若回滚到了原待办，经 [onSwitchedTodoId]
/// 让详情面板原地切回原待办并给出可撤销提示；若为更早的历史记录恢复为单次
/// 待办，明确提示不影响原重复计划。普通待办取消完成不提示（再点一下就回
/// 去了）。[onWritten] 在写库之后、弹提示之前调用（待办页据此结束“收起中”，
/// 详情头部据此释放勾选动画锁，不必等提示关闭）。
Future<void> toggleTodoDone(
  BuildContext context,
  AppDatabase database,
  TodoRow row, {
  VoidCallback? onWritten,
  TodoCompletionUndo? undo,
  ValueChanged<String>? onSwitchedTodoId,
}) async {
  if (row.completedAt != null) {
    final uncompletion = await database.uncompleteTodo(row.todoId);
    onWritten?.call();
    if (uncompletion == null) return;
    if (uncompletion.rolledBack) {
      onSwitchedTodoId?.call(uncompletion.resultingTodoId);
    }
    if (!context.mounted) return;
    if (TodoSeriesRows.seriesOf(uncompletion.before) == null) return;
    final l10n = context.l10n;
    final message = uncompletion.rolledBack
        ? l10n.todoUncompletedRolledBackNotice
        : l10n.todoUncompletedStandaloneNotice;
    final undone = await showTodoUndoHint(context, message);
    if (!undone) return;
    await database.undoTodoUncompletion(uncompletion);
    if (uncompletion.rolledBack) {
      onSwitchedTodoId?.call(uncompletion.before.todoId);
    }
    return;
  }
  final completion = await database.completeTodo(row.todoId);
  onWritten?.call();
  if (completion == null || !context.mounted) return;
  if (undo != null) {
    await undo.add(context, database, completion);
    return;
  }
  final l10n = context.l10n;
  final next = completion.nextDue;
  final message = next == null
      ? l10n.todoCompletedNotice
      : l10n.todoCompletedNextNotice(
          TodoLabels.relativeDay(l10n, next, _today()),
        );
  final undone = await showTodoUndoHint(context, message);
  if (undone) await database.undoTodoCompletion(completion);
}

/// 删除一条待办，给出可撤销的提示。
Future<void> deleteTodoWithUndo(
  BuildContext context,
  AppDatabase database,
  String todoId,
) async {
  final row = await database.deleteTodo(todoId);
  if (row == null || !context.mounted) return;
  final undone = await showTodoUndoHint(
    context,
    context.l10n.todoDeletedNotice,
  );
  if (undone) await database.restoreTodos(<TodoRow>[row]);
}

/// 清除已完成（[listId] 为 null 且 [allLists] 为 false 时是收集箱的）：先经
/// 确认框，删掉后给出可撤销的提示。
Future<void> clearCompletedTodos(
  BuildContext context,
  AppDatabase database, {
  required int count,
  String? listId,
  bool allLists = false,
}) async {
  if (count <= 0) return;
  final confirmed = await showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final l10n = dialogContext.l10n;
      final theme = Theme.of(dialogContext);
      final scheme = theme.colorScheme;
      return AlertDialog(
        title: Text(l10n.todoClearCompletedTitle),
        content: Text(l10n.todoClearCompletedBody(count)),
        actions: <Widget>[
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: scheme.onSurfaceVariant,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: scheme.error,
              textStyle: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.todoClearCompleted),
          ),
        ],
      );
    },
  );
  if (confirmed != true || !context.mounted) return;
  final rows = await database.deleteCompletedTodos(
    listId: listId,
    allLists: allLists,
  );
  if (rows.isEmpty || !context.mounted) return;
  final undone = await showTodoUndoHint(
    context,
    context.l10n.todoClearedCount(rows.length),
  );
  if (undone) await database.restoreTodos(rows);
}

/// 弹出带“撤销”的提示（经 [HomeHintVisibilityScope.showTrackedSnackBar]，
/// `persist: false`），返回用户是否点了撤销。待办的单条与批量操作共用。
Future<bool> showTodoUndoHint(BuildContext context, String message) async {
  var undo = false;
  final reason = await HomeHintVisibilityScope.showTrackedSnackBar(
    context: context,
    snackBar: SnackBar(
      content: Text(message),
      duration: _undoDuration,
      persist: false,
      action: SnackBarAction(
        label: context.l10n.commonUndo,
        onPressed: () => undo = true,
      ),
    ),
  );
  return undo || reason == SnackBarClosedReason.action;
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
