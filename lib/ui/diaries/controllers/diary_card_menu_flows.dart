/// 列表卡片右键菜单里单篇日记的写入流程。
///
/// 职责边界：输入为日记业务 id，读写经 [appDatabaseProvider]，反馈一律经
/// [HomeHintVisibilityScope.showTrackedSnackBar]（带撤销的提示 `persist: false`）；
/// 不构建页面 UI。列表本身由数据库流驱动，写入后自动刷新，这里不做收起
/// 动画——日记页与归档页有自己的收起 / 出现动画，走各自的控制器，只复用
/// 这里的置顶写入与“编辑后删除了”的撤销。
///
/// 写入口径与多选栏、预览页一致：置顶、归档、删除都不改更新时间
/// （`touchUpdatedAt: false`），撤销后回到原来的位置。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../widgets/diary_preview/diary_preview_dialogs.dart';
import 'diary_preview_edit_flow.dart';

/// 撤销提示的时长，与日记页、归档页一致。
const Duration _undoDuration = Duration(seconds: 4);
const Duration _hintDuration = Duration(seconds: 2);

/// 置顶 / 取消置顶一篇；失败时提示“重试”并返回 false。
Future<bool> setDiaryPinned(
  BuildContext context,
  WidgetRef ref,
  String diaryId, {
  required bool pinned,
}) async {
  final db = ref.read(appDatabaseProvider);
  try {
    if (pinned) {
      await db.pinDiary(diaryId, touchUpdatedAt: false);
    } else {
      await db.unpinDiary(diaryId, touchUpdatedAt: false);
    }
    return true;
  } catch (error) {
    debugPrint('Pinning diary failed: $error');
    if (context.mounted) {
      await _showHint(context, context.l10n.commonRetry);
    }
    return false;
  }
}

/// 打开编辑页编辑一篇；在编辑页里删除了它时给出与预览页删除相同的撤销提示。
Future<void> editDiaryFromList(
  BuildContext context,
  WidgetRef ref,
  String diaryId,
) async {
  final deleted = await openDiaryEditorFromPreview(context, ref, diaryId);
  if (deleted && context.mounted) {
    await offerDeletedDiaryUndo(context, ref, diaryId);
  }
}

/// 已删除一篇（在别处确认过）：撤销提示，撤销时恢复。
Future<void> offerDeletedDiaryUndo(
  BuildContext context,
  WidgetRef ref,
  String diaryId,
) async {
  final l10n = context.l10n;
  final db = ref.read(appDatabaseProvider);
  final undo = await _showUndo(context, l10n.autoT0075);
  if (!undo || !context.mounted) return;
  try {
    await db.restoreDiary(diaryId, touchUpdatedAt: false);
    if (context.mounted) await _showHint(context, l10n.autoT0076);
  } catch (error) {
    debugPrint('Restoring diary failed: $error');
    if (context.mounted) await _showHint(context, l10n.autoT0077);
  }
}

/// 删除一篇：先确认（与预览页同一个对话框），删除后给撤销。
Future<void> deleteDiaryWithUndo(
  BuildContext context,
  WidgetRef ref,
  String diaryId,
) async {
  final confirmed = await confirmDiaryPreviewDelete(context);
  if (!confirmed || !context.mounted) return;
  try {
    await ref
        .read(appDatabaseProvider)
        .softDeleteDiary(diaryId, touchUpdatedAt: false);
  } catch (error) {
    debugPrint('Deleting diary failed: $error');
    if (context.mounted) await _showHint(context, context.l10n.autoT0073);
    return;
  }
  if (context.mounted) await offerDeletedDiaryUndo(context, ref, diaryId);
}

/// 归档（[archived] 为 true）或取消归档一篇，并给撤销。
Future<void> setDiaryArchivedWithUndo(
  BuildContext context,
  WidgetRef ref,
  String diaryId, {
  required bool archived,
}) async {
  final l10n = context.l10n;
  final db = ref.read(appDatabaseProvider);
  Future<void> write(bool value) => value
      ? db.archiveDiary(diaryId, touchUpdatedAt: false)
      : db.unarchiveDiary(diaryId, touchUpdatedAt: false);
  try {
    await write(archived);
  } catch (error) {
    debugPrint('Archiving diary failed: $error');
    if (context.mounted) {
      await _showHint(context, archived ? l10n.autoT0078 : l10n.autoT0071);
    }
    return;
  }
  if (!context.mounted) return;
  final undo = await _showUndo(
    context,
    archived ? l10n.autoT0079('1') : l10n.autoT0201('1'),
  );
  if (!undo || !context.mounted) return;
  try {
    await write(!archived);
    if (context.mounted) {
      await _showHint(context, archived ? l10n.autoT0080 : l10n.autoT0072);
    }
  } catch (error) {
    debugPrint('Undoing archive change failed: $error');
  }
}

Future<void> _showHint(BuildContext context, String message) =>
    HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(content: Text(message), duration: _hintDuration),
    );

/// 带撤销按钮的提示；返回用户是否点了撤销。`persist: false` 让它到时关闭。
Future<bool> _showUndo(BuildContext context, String message) async {
  var undoRequested = false;
  final reason = await HomeHintVisibilityScope.showTrackedSnackBar(
    context: context,
    snackBar: SnackBar(
      content: Text(message),
      duration: _undoDuration,
      persist: false,
      action: SnackBarAction(
        label: context.l10n.commonUndo,
        onPressed: () => undoRequested = true,
      ),
    ),
  );
  return undoRequested || reason == SnackBarClosedReason.action;
}
