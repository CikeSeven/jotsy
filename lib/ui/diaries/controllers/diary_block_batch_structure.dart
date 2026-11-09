import 'package:appflowy_editor/appflowy_editor.dart' as af;

import 'diary_block_reorder.dart';
import 'diary_editor_controller.dart';

/// 段落选择模式里改变块结构的批量操作：删除、创建副本。
///
/// 每个操作作用于给定的块（各自连同子树，先经 [diaryBlockRoots] 规整），
/// 一个事务、一步撤销；正文选区不动（模式里正文没有选区）。返回操作后
/// 应该选中的块，交给 `DiaryBlockSelection.replace`。
///
/// 输入：编辑控制器与块；输出：文档事务；没有其他副作用。

/// 删除 [nodes]，一步撤销；全文删空时补一个空段落（正文至少留一行可写）。
/// 返回删掉的块数。
int deleteDiaryBlocks(
  DiaryEditorController controller,
  Iterable<af.Node> nodes,
) {
  final roots = diaryBlockRoots(nodes);
  if (controller.readOnly || roots.isEmpty) return 0;
  final emptied = controller.document.root.children.every(roots.contains);
  final transaction = controller.state.transaction;
  // 自下而上删除：后面的块先删，前面块的路径不受影响。
  for (final node in roots.reversed) {
    transaction.add(af.DeleteOperation(node.path, [node]), transform: false);
  }
  if (emptied) {
    transaction.add(
      af.InsertOperation([0], [af.paragraphNode()]),
      transform: false,
    );
  }
  controller.apply(transaction, updateSelection: false);
  return roots.length;
}

/// 在最后一块之后按先后插入 [nodes] 的副本（各自连同子树，与最后一块
/// 同级），一步撤销；返回副本，选择随之换到副本上，接着就能移动它们。
List<af.Node> duplicateDiaryBlocks(
  DiaryEditorController controller,
  Iterable<af.Node> nodes,
) {
  final roots = diaryBlockRoots(nodes);
  if (controller.readOnly || roots.isEmpty) return const [];
  final copies = [for (final node in roots) node.deepCopy()];
  final transaction = controller.state.transaction
    ..insertNodes(roots.last.path.next, copies, deepCopy: false);
  controller.apply(transaction, updateSelection: false);
  return copies;
}
