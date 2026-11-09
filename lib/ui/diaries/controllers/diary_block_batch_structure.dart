import 'package:appflowy_editor/appflowy_editor.dart' as af;

import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import 'diary_block_reorder.dart';
import 'diary_editor_controller.dart';
import 'diary_table_editing.dart';

/// 段落选择模式里改变块结构的批量操作：删除、创建副本、拆分成段落、合并
/// 成一段。
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

/// 能拆分的文字块：选中块（连同子块）里文字中带换行的块；代码块（换行即
/// 代码的行）与表格格子里的段落不拆。
List<af.Node> _splittable(Iterable<af.Node> roots) {
  final nodes = <af.Node>[];
  void visit(af.Node node) {
    final delta = node.delta;
    if (delta != null &&
        node.type != kDiaryBlockCode &&
        !diaryNodeInTableCell(node) &&
        delta.toPlainText().contains('\n')) {
      nodes.add(node);
    }
    node.children.forEach(visit);
  }

  diaryBlockRoots(roots).forEach(visit);
  return nodes;
}

/// 选中的块里有没有能拆分的（文字里带换行、不是代码块）。
bool canSplitDiaryBlockLines(Iterable<af.Node> roots) =>
    _splittable(roots).isNotEmpty;

/// 拆分成段落：把文字里带换行的块按行拆成几块（旧日记里粘贴时挤在一块的
/// 多段文字），一步撤销；返回拆分后应该选中的块（拆出的块一并选上）。
///
/// - 每行成为一块，类型与块属性（标题级别、待办勾选、提示块图标、对齐等）
///   与原块相同，行内格式按原样切开；只有空白的行丢掉——段与段之间本来就
///   有段间距；
/// - 原块留作最后一行，子块（缩进在它下面的块）仍挂在它下面：拆出的前几行
///   插在它前面，阅读顺序不变；
/// - 代码块与表格格子里的段落不拆。
List<af.Node> splitDiaryBlockLines(
  DiaryEditorController controller,
  List<af.Node> roots,
) {
  final targets = _splittable(roots);
  if (controller.readOnly || targets.isEmpty) return roots;
  final transaction = controller.state.transaction;
  final added = <af.Node>[];
  // 自后往前：后面块的插入不影响前面块的路径。
  for (final node in targets.reversed) {
    final delta = node.delta!;
    final text = delta.toPlainText();
    final lines = <(int, int)>[];
    var start = 0;
    for (var i = 0; i <= text.length; i++) {
      if (i == text.length || text[i] == '\n') {
        if (text.substring(start, i).trim().isNotEmpty) lines.add((start, i));
        start = i + 1;
      }
    }
    if (lines.isEmpty) continue;
    final (lastStart, lastEnd) = lines.last;
    final pieces = [
      for (final (from, to) in lines.take(lines.length - 1))
        node.copyWith(
          attributes: {
            ...node.attributes,
            kDiaryBlockDeltaKey: delta.slice(from, to).toJson(),
          },
          children: const [],
        ),
    ];
    // 原块只留最后一行：先删尾部，再删开头（两次都按原文字的位置）。
    if (lastEnd < text.length) {
      transaction.deleteText(node, lastEnd, text.length - lastEnd);
    }
    if (lastStart > 0) transaction.deleteText(node, 0, lastStart);
    if (pieces.isNotEmpty) {
      transaction.insertNodes(node.path, pieces, deepCopy: false);
      added.addAll(pieces);
    }
  }
  controller.apply(transaction, updateSelection: false);
  return diaryBlockRoots([...roots, ...added]);
}

/// 选中的块里能合并的文字块（最上层的选中块里带文字的，表格与嵌入块不算）。
List<af.Node> _mergeable(Iterable<af.Node> roots) => [
  for (final node in diaryBlockRoots(roots))
    if (node.delta != null) node,
];

/// 选中的块里有没有两块以上能合并的文字块。
bool canMergeDiaryBlocks(Iterable<af.Node> roots) =>
    _mergeable(roots).length >= 2;

/// 合并成一段：把选中的文字块按先后接进第一块（块与块之间换行，行内格式
/// 保留），其余删除，一步撤销；返回合并后的那一块。
///
/// 被合并的块的子块不丢：第一块能挂子块（段落、列表、待办、折叠块）时依次
/// 接到它的子块末尾，否则依次排在它后面。图片、表格等不是文字块的选中块
/// 原地不动。是 [splitDiaryBlockLines] 的反操作。
List<af.Node> mergeDiaryBlocks(
  DiaryEditorController controller,
  List<af.Node> roots,
) {
  final nodes = _mergeable(roots);
  if (controller.readOnly || nodes.length < 2) return roots;
  final first = nodes.first;
  final rest = nodes.sublist(1);
  final transaction = controller.state.transaction
    ..insertTextDelta(
      first,
      first.delta!.length,
      af.Delta.fromJson([
        for (final node in rest) ...[
          {'insert': '\n'},
          ...node.delta!.toJson(),
        ],
      ]),
    );
  final orphans = [
    for (final node in rest)
      for (final child in node.children) child.deepCopy(),
  ];
  if (orphans.isNotEmpty) {
    // 先插子块、再删其余的块：删除的路径由事务按插入换算；反过来时插在
    // “第一块之后”的位置会被同位的删除多减一格。
    final path = kDiaryContainerBlockTypes.contains(first.type)
        ? [...first.path, first.children.length]
        : first.path.next;
    transaction.insertNodes(path, orphans, deepCopy: false);
  }
  for (final node in rest.reversed) {
    transaction.deleteNode(node);
  }
  controller.apply(transaction, updateSelection: false);
  return [first];
}
