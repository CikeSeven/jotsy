import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../home/widgets/home_hint_visibility_scope.dart';
import '../../controllers/diary_block_batch_structure.dart';
import '../../controllers/diary_block_group_move.dart';
import '../../controllers/diary_block_selection.dart';
import '../../controllers/diary_editor_clipboard.dart';
import '../../controllers/diary_editor_controller.dart';

/// 段落选择模式的操作，段落操作栏与选择模式的按键共用：作用于选中的块，
/// 执行后更新选择、给出提示。
///
/// - 移动、创建副本：留在模式里，选择跟着块（创建副本后换到副本上）；
/// - 复制：写进剪贴板（保留格式与嵌套），提示“已复制 N 段”，留在模式里；
/// - 删除、剪切：退出模式（[DiaryBlockSelectionExit.release]，不落光标），
///   提示条带「撤销」（`persist: false`，到时自动收起）。
abstract final class DiaryBlockActions {
  static DiaryBlockSelection _selection(DiaryEditorController controller) =>
      controller.blockSelection;

  /// 选中的块朝 [up] 方向能不能再移一格。
  static bool canStep(DiaryEditorController controller, {required bool up}) =>
      canStepDiaryBlockGroup(controller, _selection(controller).roots, up: up);

  static void step(DiaryEditorController controller, {required bool up}) {
    if (stepDiaryBlockGroup(controller, _selection(controller).roots, up: up)) {
      unawaited(HapticFeedback.selectionClick());
    }
  }

  static void moveToEdge(
    DiaryEditorController controller, {
    required bool top,
  }) {
    if (moveDiaryBlockGroupToEdge(
      controller,
      _selection(controller).roots,
      top: top,
    )) {
      unawaited(HapticFeedback.selectionClick());
    }
  }

  static void duplicate(DiaryEditorController controller) {
    final copies = duplicateDiaryBlocks(
      controller,
      _selection(controller).roots,
    );
    if (copies.isNotEmpty) _selection(controller).replace(copies);
  }

  static Future<void> copy(
    BuildContext context,
    DiaryEditorController controller,
  ) async {
    final roots = _selection(controller).roots;
    if (roots.isEmpty) return;
    final message = context.l10n.diaryBlockCopied(roots.length);
    await DiaryEditorClipboard.copyBlocks(roots);
    if (!context.mounted) return;
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(content: Text(message)),
      ),
    );
  }

  static Future<void> cut(
    BuildContext context,
    DiaryEditorController controller,
  ) async {
    final roots = _selection(controller).roots;
    if (roots.isEmpty || controller.readOnly) return;
    final message = context.l10n.diaryBlockCutDone(roots.length);
    await DiaryEditorClipboard.copyBlocks(roots);
    if (!context.mounted || controller.isDisposed) return;
    _deleteWithUndo(context, controller, message);
  }

  static void delete(BuildContext context, DiaryEditorController controller) {
    final roots = _selection(controller).roots;
    if (roots.isEmpty || controller.readOnly) return;
    _deleteWithUndo(
      context,
      controller,
      context.l10n.diaryBlockDeleted(roots.length),
    );
  }

  static void _deleteWithUndo(
    BuildContext context,
    DiaryEditorController controller,
    String message,
  ) {
    final undo = context.l10n.commonUndo;
    final selection = _selection(controller);
    if (deleteDiaryBlocks(controller, selection.roots) == 0) return;
    selection.exit(DiaryBlockSelectionExit.release);
    unawaited(HapticFeedback.mediumImpact());
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(
          content: Text(message),
          persist: false,
          action: SnackBarAction(
            label: undo,
            onPressed: () {
              if (!controller.isDisposed) controller.undo();
            },
          ),
        ),
      ),
    );
  }
}
