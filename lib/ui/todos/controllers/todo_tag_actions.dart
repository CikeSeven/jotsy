import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../widgets/app_modal/app_dialog.dart';
import '../providers/todo_providers.dart';
import '../widgets/todo_tag_rename_dialog.dart';
import 'todo_actions.dart';

/// 待办标签的管理流程（标签管理页用）：改名 / 合并与删除。
///
/// 两者都在一个事务里改完所有带这个标签的待办（`renameTodoTag` /
/// `deleteTodoTag`，只动 `metadata.tags`），再弹一条可撤销的提示；撤销按
/// 改之前的行写回标签（`restoreTodoFields(..., TodoBatchField.tags)`）。与日记
/// 标签无关。

/// 改名：改成已有的标签名（不分大小写）即合并，提示写“已合并到…”。
Future<void> renameTodoTagFlow(
  BuildContext context,
  WidgetRef ref,
  String name,
) async {
  final next = await showTodoTagRenameDialog(context, current: name);
  if (next == null || !context.mounted) return;
  final existing = ref.read(todoTagsProvider).value ?? const <TodoTagUsage>[];
  // 改成另一个已有标签（不只是换大小写）才算合并。
  final merging =
      !TodoTags.same(next, name) &&
      existing.any((TodoTagUsage u) => TodoTags.same(u.name, next));
  final database = ref.read(appDatabaseProvider);
  final before = await database.renameTodoTag(name, next);
  if (before.isEmpty || !context.mounted) return;
  final l10n = context.l10n;
  final undone = await showTodoUndoHint(
    context,
    merging ? l10n.todoTagMergedNotice(next) : l10n.todoTagRenamedNotice(next),
  );
  if (undone) await database.restoreTodoFields(before, TodoBatchField.tags);
}

/// 删除：确认框写明会从几条待办上去掉（待办本身保留）。
Future<void> deleteTodoTagFlow(
  BuildContext context,
  WidgetRef ref,
  TodoTagUsage usage,
) async {
  final confirmed = await showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final l10n = dialogContext.l10n;
      final theme = Theme.of(dialogContext);
      final scheme = theme.colorScheme;
      return AlertDialog(
        title: Text(l10n.todoTagDeleteTitle(usage.name)),
        content: Text(l10n.todoTagDeleteMessage(usage.totalCount)),
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
            child: Text(l10n.commonDelete),
          ),
        ],
      );
    },
  );
  if (confirmed != true || !context.mounted) return;
  final database = ref.read(appDatabaseProvider);
  final before = await database.deleteTodoTag(usage.name);
  if (before.isEmpty || !context.mounted) return;
  final undone = await showTodoUndoHint(
    context,
    context.l10n.todoTagDeletedNotice(usage.name),
  );
  if (undone) await database.restoreTodoFields(before, TodoBatchField.tags);
}
