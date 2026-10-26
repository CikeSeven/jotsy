import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart' as af;

import '../../../../app/theme/expressive_motion.dart';
import '../../controllers/diary_editor_controller.dart';

/// 面板增高后揭示原生块的光标。日常输入与键盘变化由 AppFlowy 自己处理；
/// 这里只补充它无法感知的悬浮工具栏遮挡，与正文 footer 的留白同源。
void revealDiaryEditorCaretAbove(
  DiaryEditorController controller, {
  required double coveredHeight,
  required Duration duration,
}) {
  final selection = controller.selection;
  if (selection == null || !selection.isCollapsed) return;
  final af.Node? node = controller.document.nodeAtPath(selection.end.path);
  final rect = node?.selectable?.getCursorRectInPosition(
    selection.end,
    shiftWithBaseOffset: true,
  );
  final box = node?.renderBox;
  if (rect == null || box == null || !box.attached) return;
  box.showOnScreen(
    rect: Rect.fromLTRB(
      rect.left,
      rect.top,
      rect.right,
      rect.bottom + coveredHeight,
    ),
    duration: duration,
    curve: ExpressiveMotion.effects,
  );
}
