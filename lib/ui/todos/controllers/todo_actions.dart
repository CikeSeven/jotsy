import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../widgets/app_modal/app_dialog.dart';
import '../widgets/todo_labels.dart';

/// 撤销提示的停留时间（非动画计时）。
const Duration _undoDuration = Duration(seconds: 5);

/// 待办的勾选、删除与清除流程（列表、详情页、日历卡片共用）。
///
/// 写库都交给 [AppDatabase]；提示一律用调用方的 context 经
/// [HomeHintVisibilityScope.showTrackedSnackBar] 弹出——它会把撤销窗口登记到
/// 局域网同步的注册表，提示在时同步先等着，撤销不会和同步写入打架。撤销用的
/// 是调用前取好的 [AppDatabase]：提示关闭时页面可能已卸载。

/// 勾选 / 取消勾选一条待办。完成时给出可撤销的提示：重复待办写明下一次的
/// 日子。取消完成不提示（再点一下就回去了）。
Future<void> toggleTodoDone(
  BuildContext context,
  AppDatabase database,
  TodoRow row,
) async {
  if (row.completedAt != null) {
    await database.uncompleteTodo(row.todoId);
    return;
  }
  final completion = await database.completeTodo(row.todoId);
  if (completion == null || !context.mounted) return;
  final l10n = context.l10n;
  final next = completion.nextDue;
  final message = next == null
      ? l10n.todoCompletedNotice
      : l10n.todoCompletedNextNotice(
          TodoLabels.relativeDay(l10n, next, _today()),
        );
  final undone = await _showUndo(context, message);
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
  final undone = await _showUndo(context, context.l10n.todoDeletedNotice);
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
  final undone = await _showUndo(
    context,
    context.l10n.todoClearedCount(rows.length),
  );
  if (undone) await database.restoreTodos(rows);
}

/// 弹出带“撤销”的提示，返回用户是否点了撤销。
Future<bool> _showUndo(BuildContext context, String message) async {
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
