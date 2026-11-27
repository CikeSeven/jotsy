import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../widgets/app_modal/app_dialog.dart';
import '../providers/todo_providers.dart';
import '../sections/todo_section_callbacks.dart';
import '../widgets/todo_quick_add_sheet.dart';
import '../widgets/todo_section_name_dialog.dart';
import 'todo_actions.dart';
import 'todo_reorder.dart';

/// 清单视图里分区的操作流程（页面经 [buildTodoSectionCallbacks] 接上）：
/// 新建 / 重命名（弹窗）、上移 / 下移、删除（确认框可选连同其中的待办，
/// 可撤销）、在分区里新建（快速新建面板预填这个清单与分区），以及拖动排序
/// 跨分区（交给 [TodoReorder]）。

/// [listId] 这个清单视图的分区操作；[sections] 为它此刻的分区。
TodoSectionCallbacks buildTodoSectionCallbacks({
  required BuildContext context,
  required WidgetRef ref,
  required String listId,
  required List<TodoSection> sections,
  required TodoReorder reorder,
  required TodoQuickAddPreset Function() preset,
}) {
  AppDatabase database() => ref.read(appDatabaseProvider);
  return TodoSectionCallbacks(
    sections: sections,
    onCreate: () => unawaited(() async {
      final name = await showTodoSectionNameDialog(context);
      if (name != null) await database().addTodoSection(listId, name);
    }()),
    onAddTodo: (TodoSection section) => unawaited(
      showTodoQuickAddSheet(
        context,
        preset: preset().withSection(listId, section.id),
      ),
    ),
    onRename: (TodoSection section) => unawaited(() async {
      final name = await showTodoSectionNameDialog(
        context,
        current: section.name,
      );
      if (name != null) {
        await database().renameTodoSection(listId, section.id, name);
      }
    }()),
    onMove: (TodoSection section, int delta) =>
        unawaited(database().moveTodoSection(listId, section.id, delta)),
    onDelete: (TodoSection section) =>
        unawaited(deleteTodoSectionFlow(context, ref, listId, section)),
    onReorder: (List<TodoRow> rows, int oldIndex, int newIndex, String? id) =>
        reorder.drop(
          database(),
          rows,
          oldIndex,
          newIndex,
          readOpen: () => ref.read(openTodosProvider).value,
          section: (id: id),
        ),
  );
}

/// 删除分区：确认框里可勾选“连同其中的 N 条待办一起删除”（默认不勾，
/// 待办移到未分区），删后给出可撤销的提示。
Future<void> deleteTodoSectionFlow(
  BuildContext context,
  WidgetRef ref,
  String listId,
  TodoSection section,
) async {
  final database = ref.read(appDatabaseProvider);
  final count = await database.countTodosInSection(listId, section.id);
  if (!context.mounted) return;
  final choice = await showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) =>
        _DeleteSectionDialog(name: section.name, count: count),
  );
  if (choice == null || !context.mounted) return;
  final deletion = await database.deleteTodoSection(
    listId,
    section.id,
    withTodos: choice,
  );
  if (deletion == null || !context.mounted) return;
  final undone = await showTodoUndoHint(
    context,
    context.l10n.todoSectionDeletedNotice(section.name),
  );
  if (undone) await database.restoreTodoSection(deletion);
}

/// 删除分区的确认框：返回是否连同待办一起删（true / false），取消为 null。
class _DeleteSectionDialog extends StatefulWidget {
  const _DeleteSectionDialog({required this.name, required this.count});

  final String name;
  final int count;

  @override
  State<_DeleteSectionDialog> createState() => _DeleteSectionDialogState();
}

class _DeleteSectionDialogState extends State<_DeleteSectionDialog> {
  bool _withTodos = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AlertDialog(
      title: Text(l10n.todoSectionDeleteTitle(widget.name)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.todoSectionDeleteBody),
          if (widget.count > 0)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _withTodos,
              onChanged: (bool? value) =>
                  setState(() => _withTodos = value ?? false),
              title: Text(l10n.todoSectionDeleteWithTodos(widget.count)),
            ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: scheme.error,
            textStyle: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          onPressed: () => Navigator.of(context).pop(_withTodos),
          child: Text(l10n.commonDelete),
        ),
      ],
    );
  }
}
