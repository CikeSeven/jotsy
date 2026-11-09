import 'package:appflowy_editor/appflowy_editor.dart' as af;

import 'diary_block_reorder.dart';
import 'diary_editor_controller.dart';
import 'diary_table_editing.dart';

/// 按组移动段落的入口：正文里 Alt + Shift + ↑ / ↓（光标所在块，或文字选区
/// 碰到的几块），以及段落选择模式的上移 / 下移 / 移到开头 / 末尾。缝与
/// 事务见 `diary_block_reorder.dart`。
///
/// 输入：编辑控制器与要移动的块；输出：一步可撤销的移动；没有其他副作用。

/// 正文选区碰到的块，规整为最上层的块（子块随父块）：表格里的格子与格内
/// 段落换成整个表格。选区止于某一块开头（偏移 0）时不算碰到那一块——
/// 拖选整行常常停在下一行开头。没有选区时为空。
List<af.Node> diaryBlocksTouchedBySelection(DiaryEditorController controller) {
  final selection = controller.state.selection?.normalized;
  if (selection == null) return const [];
  final nodes = controller.state.getNodesInSelection(selection);
  return diaryBlockRoots([
    for (final node in nodes)
      if (selection.isCollapsed ||
          !node.path.equals(selection.end.path) ||
          selection.end.offset > 0 ||
          node.delta == null)
        diaryTableOf(node) ?? node,
  ]);
}

/// Alt + Shift + ↑ / ↓：光标所在块（文字选区跨块时为碰到的几块）整组上移
/// 或下移一格，选区跟着走。没有选区时返回 false（按键交还）；有选区但朝
/// 那个方向放不下时什么也不做、仍算处理过——不交给上游当作扩选。
///
/// 选区止于下一块开头（那一块不算碰到、不跟着走）时，终点先收到最后一块
/// 的末尾：否则块移过那一块后选区首尾颠倒、框住别的文字。
bool moveDiaryBlocksAtSelection(
  DiaryEditorController controller, {
  required bool up,
}) {
  if (controller.readOnly) return false;
  final selection = controller.state.selection?.normalized;
  final nodes = diaryBlocksTouchedBySelection(controller);
  if (selection == null || nodes.isEmpty) return false;
  final destination = DiaryBlockGaps(
    controller.document.root,
    nodes,
  ).step(up: up);
  if (destination != null) {
    moveDiaryEditorBlocks(
      controller,
      nodes,
      destination,
      selection: DiaryBlockMoveSelection.follow,
      follow: _withinBlocks(selection, nodes),
    );
  }
  return true;
}

/// [selection] 的终点不在 [roots] 里时收到最后一块（它的子树里先序最后
/// 一块）的末尾。
af.Selection _withinBlocks(af.Selection selection, List<af.Node> roots) {
  final endPath = selection.end.path;
  final inside = roots.any((root) {
    final path = root.path;
    return endPath.length >= path.length &&
        endPath.sublist(0, path.length).equals(path);
  });
  if (inside) return selection;
  var last = roots.last;
  while (last.children.isNotEmpty) {
    last = last.children.last;
  }
  return af.Selection(
    start: selection.start,
    end: af.Position(path: last.path, offset: last.delta?.length ?? 0),
  );
}

/// 段落选择模式：[nodes] 朝 [up] 方向能不能再移一格（按钮是否可用）。
bool canStepDiaryBlockGroup(
  DiaryEditorController controller,
  List<af.Node> nodes, {
  required bool up,
}) =>
    nodes.isNotEmpty &&
    DiaryBlockGaps(controller.document.root, nodes).step(up: up) != null;

/// 段落选择模式的上移 / 下移：整组移一格，不连续的几块聚到一起；正文
/// 选区保持为空。
bool stepDiaryBlockGroup(
  DiaryEditorController controller,
  List<af.Node> nodes, {
  required bool up,
}) {
  if (controller.readOnly || nodes.isEmpty) return false;
  final destination = DiaryBlockGaps(
    controller.document.root,
    nodes,
  ).step(up: up);
  return destination != null &&
      moveDiaryEditorBlocks(
        controller,
        nodes,
        destination,
        selection: DiaryBlockMoveSelection.none,
      );
}

/// 段落选择模式的移到开头 / 末尾：整组成为文首 / 文末的顶层块。
bool moveDiaryBlockGroupToEdge(
  DiaryEditorController controller,
  List<af.Node> nodes, {
  required bool top,
}) {
  if (controller.readOnly || nodes.isEmpty) return false;
  final destination = DiaryBlockGaps(
    controller.document.root,
    nodes,
  ).edge(top: top);
  return destination != null &&
      moveDiaryEditorBlocks(
        controller,
        nodes,
        destination,
        selection: DiaryBlockMoveSelection.none,
      );
}
