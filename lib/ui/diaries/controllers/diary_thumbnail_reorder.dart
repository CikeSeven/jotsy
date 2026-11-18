import 'package:appflowy_editor/appflowy_editor.dart' as af;

import '../models/diary_thumbnail_rows.dart';
import 'diary_block_reorder.dart';
import 'diary_editor_controller.dart';

/// 并排小图的排序写入：长按拖动松手与读屏的“前移 / 后移”都经这里。
///
/// [run] 是开始拖动时的那一串小图（文档先后）。写入前核对它仍是正文顶层
/// 连续的几块小图、顺序没变——拖动途中同步、撤销改过正文时放弃，不挪错
/// 块。第 [from] 张挪到第 [to] 张（都按挪动前的顺序数），一次可撤销的
/// 移动（经 [moveDiaryEditorBlocks]）。选区跟着块走：光标停在某张小图旁时
/// 仍在它旁边；以 remote 原因更新，光标在别处时不把页面拉过去。
bool moveDiaryThumbnail(
  DiaryEditorController controller,
  List<af.Node> run, {
  required int from,
  required int to,
}) {
  if (controller.readOnly ||
      controller.isDisposed ||
      from == to ||
      from < 0 ||
      to < 0 ||
      from >= run.length ||
      to >= run.length) {
    return false;
  }
  final parent = run.first.parent;
  if (parent == null || parent.parent != null) return false;
  final start = run.first.path.last;
  final siblings = parent.children;
  if (start + run.length > siblings.length) return false;
  for (var i = 0; i < run.length; i++) {
    final node = siblings[start + i];
    if (!identical(node, run[i]) || !isDiaryThumbnailMedia(node)) return false;
  }
  // 目标路径按挪动前的树解释：往后挪时插到第 to 张之后。
  return moveDiaryEditorBlocks(
    controller,
    [run[from]],
    [start + (to > from ? to + 1 : to)],
    quiet: true,
    selection: DiaryBlockMoveSelection.follow,
  );
}
