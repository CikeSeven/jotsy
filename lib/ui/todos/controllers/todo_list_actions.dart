import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../widgets/app_modal/app_dialog.dart';
import '../widgets/todo_list_edit_sheet.dart';

/// 撤销提示的停留时间（非动画计时）。
const Duration _undoDuration = Duration(seconds: 5);

/// 清单的新建、编辑与删除流程（待办页、选清单面板、清单管理页共用）。

/// 新建清单：弹出编辑面板，保存后写库，返回新清单的业务 id；取消为 null。
Future<String?> createTodoListFlow(BuildContext context, WidgetRef ref) async {
  final database = ref.read(appDatabaseProvider);
  final edit = await showTodoListEditSheet(context);
  if (edit == null) return null;
  return database.createTodoList(
    name: edit.name,
    colorKey: edit.colorKey,
    iconKey: edit.iconKey,
  );
}

/// 编辑清单的名称、颜色与图标。
Future<void> editTodoListFlow(
  BuildContext context,
  WidgetRef ref,
  TodoListRow list,
) async {
  final database = ref.read(appDatabaseProvider);
  final edit = await showTodoListEditSheet(context, editing: list);
  if (edit == null) return;
  await database.updateTodoList(
    list.listId,
    name: edit.name,
    colorKey: edit.colorKey,
    iconKey: edit.iconKey,
  );
}

/// 删除清单：确认框写明会连同其中的待办（含已完成）一起删，删后给出可撤销
/// 的提示。删掉返回 true。
Future<bool> deleteTodoListFlow(
  BuildContext context,
  WidgetRef ref,
  TodoListRow list,
) async {
  final database = ref.read(appDatabaseProvider);
  final count = await database.countTodosInList(list.listId);
  if (!context.mounted) return false;
  final confirmed = await showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final l10n = dialogContext.l10n;
      final theme = Theme.of(dialogContext);
      final scheme = theme.colorScheme;
      return AlertDialog(
        title: Text(l10n.todoListDeleteTitle(list.name)),
        content: Text(l10n.todoListDeleteBody(count)),
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
            child: Text(l10n.todoListDelete),
          ),
        ],
      );
    },
  );
  if (confirmed != true || !context.mounted) return false;
  final deletion = await database.deleteTodoList(list.listId);
  if (deletion == null || !context.mounted) return deletion != null;
  var undo = false;
  final reason = await HomeHintVisibilityScope.showTrackedSnackBar(
    context: context,
    snackBar: SnackBar(
      content: Text(context.l10n.todoListDeletedNotice),
      duration: _undoDuration,
      persist: false,
      action: SnackBarAction(
        label: context.l10n.commonUndo,
        onPressed: () => undo = true,
      ),
    ),
  );
  if (undo || reason == SnackBarClosedReason.action) {
    await database.restoreTodoList(deletion);
  }
  return true;
}
