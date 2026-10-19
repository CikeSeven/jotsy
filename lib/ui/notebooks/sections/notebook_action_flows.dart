import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../settings/widgets/style_editor/style_editor_common.dart';
import '../controllers/notebook_lock_flow.dart';
import '../providers/notebook_providers.dart';
import '../viewmodels/notebook_view.dart';
import 'notebook_action_sheets.dart';
import 'notebook_dialogs.dart';

/// 删除时宿主页面的配合：管理页先让这一行收起（[beforeDelete] 等收起动画
/// 结束），删除失败时 [onDeleteFailed] 让它展开回来，撤销写回后
/// [onRestored] 让这一行重新展开。书架面板不需要这些。
class NotebookDeleteHooks {
  const NotebookDeleteHooks({
    this.beforeDelete,
    this.onDeleteFailed,
    this.onRestored,
  });

  final Future<void> Function()? beforeDelete;
  final VoidCallback? onDeleteFailed;
  final VoidCallback? onRestored;
}

/// 会打开编辑页或让日记本内容露出来的操作：对上锁的日记本要先验证身份。
///
/// - 编辑：编辑页能把隐私改回“正常”；
/// - 合并（这本是来源）：日记并入别的本子后不再受锁保护；
/// - 删除：“只删除日记本”让日记回到全部日记，“连同日记删除”的日记进回收站
///   也能看到；
/// - 转为普通日记本：同样会打开设置。
///
/// 置顶、合上 / 重新打开、排序不涉及内容，不需要验证。
const Set<NotebookAction> notebookRevealingActions = <NotebookAction>{
  NotebookAction.edit,
  NotebookAction.merge,
  NotebookAction.convert,
  NotebookAction.delete,
};

/// 执行对 [notebook] 的一个操作：书架长按菜单、管理页“更多”面板与首页头部
/// 卡片共用。
///
/// [notebookRevealingActions] 里的操作对上锁的日记本先经
/// [authorizeNotebookEntry]，取消、失败或设备不支持时什么也不做；
/// [authorized] 为 true 表示调用方已在这本的解锁范围里（首页头部卡片），
/// 不再重复验证。
///
/// 读写经 [NotebooksController]；确认框、提示条与撤销在这里组装。删除带 4 秒
/// 撤销（`showStyleEditorUndoSnackBar`，经 Home 的跟踪接口、`persist: false`）；
/// 合并不可撤销，先确认。数据库写入失败时只提示，不改动界面状态。
Future<void> runNotebookAction(
  BuildContext context,
  WidgetRef ref, {
  required NotebookView notebook,
  required NotebookAction action,
  NotebookDeleteHooks hooks = const NotebookDeleteHooks(),
  bool authorized = false,
}) async {
  if (!authorized && notebookRevealingActions.contains(action)) {
    final allowed = await authorizeNotebookEntry(context, ref, notebook);
    if (!allowed || !context.mounted) {
      return;
    }
  }
  final controller = ref.read(notebooksControllerProvider);
  final l10n = context.l10n;
  Future<void> guarded(Future<void> Function() write) async {
    try {
      await write();
    } catch (error) {
      debugPrint('Notebook action $action failed: $error');
      if (context.mounted) {
        showStyleEditorMessage(context, l10n.notebookActionFailed);
      }
    }
  }

  switch (action) {
    case NotebookAction.edit:
      // 上面已验证过，这里不再重复。
      await openNotebookEditor(context, ref, notebook, authorized: true);
    case NotebookAction.pin:
    case NotebookAction.unpin:
      await guarded(
        () => controller.setPinned(notebook.id, action == NotebookAction.pin),
      );
    case NotebookAction.close:
    case NotebookAction.reopen:
      await guarded(
        () => controller.setClosed(notebook.id, action == NotebookAction.close),
      );
    case NotebookAction.merge:
      await _merge(context, ref, notebook);
    case NotebookAction.convert:
      // 规则编辑器接入前不可用（面板里该项为禁用态）。
      break;
    case NotebookAction.delete:
      await _delete(context, ref, notebook, hooks);
  }
}

Future<void> _delete(
  BuildContext context,
  WidgetRef ref,
  NotebookView notebook,
  NotebookDeleteHooks hooks,
) async {
  final l10n = context.l10n;
  final controller = ref.read(notebooksControllerProvider);
  final counts = ref.read(notebookEntryCountsProvider).value;
  final trashDiaries = await showNotebookDeleteDialog(
    context,
    notebook: notebook,
    count: counts?[notebook.id] ?? 0,
  );
  if (trashDiaries == null || !context.mounted) return;
  await hooks.beforeDelete?.call();
  final NotebookDeletion deletion;
  try {
    deletion = await controller.delete(notebook.id, trashDiaries: trashDiaries);
  } catch (error) {
    debugPrint('Deleting notebook failed: $error');
    hooks.onDeleteFailed?.call();
    if (context.mounted) {
      showStyleEditorMessage(context, l10n.notebookActionFailed);
    }
    return;
  }
  if (!context.mounted) return;
  unawaited(
    showStyleEditorUndoSnackBar(
      context,
      message: l10n.notebookDeleted(notebook.name),
      onUndo: () => unawaited(
        controller.restore(deletion).then((_) {
          hooks.onRestored?.call();
        }),
      ),
    ),
  );
}

Future<void> _merge(
  BuildContext context,
  WidgetRef ref,
  NotebookView source,
) async {
  final l10n = context.l10n;
  final controller = ref.read(notebooksControllerProvider);
  final all = ref.read(notebooksProvider).value ?? const <NotebookView>[];
  final counts =
      ref.read(notebookEntryCountsProvider).value ?? const <String, int>{};
  final target = await showNotebookMergeTargetSheet(
    context,
    candidates: <NotebookView>[
      for (final notebook in all)
        if (notebook.isManual && notebook.id != source.id) notebook,
    ],
    counts: counts,
  );
  if (target == null || !context.mounted) return;
  final confirmed = await showNotebookMergeConfirmDialog(
    context,
    source: source,
    target: target,
    count: counts[source.id] ?? 0,
  );
  if (!confirmed || !context.mounted) return;
  try {
    await controller.merge(sourceId: source.id, targetId: target.id);
  } catch (error) {
    debugPrint('Merging notebook failed: $error');
    if (context.mounted) {
      showStyleEditorMessage(context, l10n.notebookActionFailed);
    }
    return;
  }
  if (context.mounted) {
    showStyleEditorMessage(context, l10n.notebookMerged(target.name));
  }
}
