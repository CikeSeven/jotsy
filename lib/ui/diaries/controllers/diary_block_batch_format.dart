import 'package:appflowy_editor/appflowy_editor.dart' as af;

import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../models/diary_text_style_options.dart';
import 'diary_block_convert.dart';
import 'diary_block_reorder.dart';
import 'diary_editor_controller.dart';
import 'diary_table_editing.dart';
import 'diary_text_style_editing.dart';

/// 段落选择模式里的批量排版：换块类型、行内格式（加粗、斜体、下划线、
/// 删除线）、对齐、清除格式。
///
/// - 作用范围：选中的块连同子块里的文字块；表格格子里的段落不换类型（见
///   [addDiaryBlockTypeChange]），代码块不加行内格式、不改对齐（代码是原文，
///   同工具栏）；
/// - 每个操作一个事务、一步撤销，正文选区不动（模式里正文没有选区）；取值
///   都已相同时不写，不留空的撤销步骤；
/// - 换类型可能把块换成副本、把子块提到后面（换成标题、引用、代码块时），
///   返回改写后应该选中的块：按先序位置找回（替换不改变阅读顺序），选中块
///   原来的子块（现在提到了后面）一并选上。
///
/// 输入：编辑控制器与选中的块；输出：文档事务；没有其他副作用。

/// 选中块（各自连同子块）里的文字块，按文档先后。
List<af.Node> diaryBlockTextNodes(Iterable<af.Node> roots) {
  final nodes = <af.Node>[];
  void visit(af.Node node) {
    if (node.delta != null) nodes.add(node);
    node.children.forEach(visit);
  }

  diaryBlockRoots(roots).forEach(visit);
  return nodes;
}

/// 能改行内格式与对齐的文字块：代码块除外。
List<af.Node> _styleTargets(Iterable<af.Node> roots) => [
  for (final node in diaryBlockTextNodes(roots))
    if (node.type != kDiaryBlockCode) node,
];

/// 类型面板的一格：块类型与标题级别（其他类型为 null）。
typedef DiaryBlockTypeChoice = ({String type, int? level});

/// 选中的文字块（格子里的段落除外）共同的类型；不同或没有文字块时为 null。
DiaryBlockTypeChoice? diaryBlocksType(Iterable<af.Node> roots) {
  final choices = {
    for (final node in diaryBlockTextNodes(roots))
      if (!diaryNodeInTableCell(node))
        (
          type: node.type,
          level: node.type == kDiaryBlockHeading ? _headingLevel(node) : null,
        ),
  };
  return choices.length == 1 ? choices.single : null;
}

/// 选中的块里有没有能换类型的文字块（格子里的段落不算）。
bool diaryBlocksConvertible(Iterable<af.Node> roots) =>
    diaryBlockTextNodes(roots).any((node) => !diaryNodeInTableCell(node));

/// 把选中块里的文字块换成 [choice]，一步撤销；返回改写后的块。
///
/// 文字与对齐保留；已是提示块的保留图标与底色，已是待办的保留勾选；换成
/// 提示块、折叠块时代码块不转（同工具栏）；已是这种类型（标题还要同级）的
/// 块不动。
List<af.Node> setDiaryBlocksType(
  DiaryEditorController controller,
  List<af.Node> roots,
  DiaryBlockTypeChoice choice,
) {
  if (controller.readOnly || roots.isEmpty) return roots;
  final type = choice.type;
  final skipsCode = type == kDiaryBlockCallout || type == kDiaryBlockToggleList;
  final nodes = [
    for (final node in diaryBlockTextNodes(roots))
      if (!diaryNodeInTableCell(node) &&
          !(skipsCode && node.type == kDiaryBlockCode) &&
          !(node.type == type &&
              (type != kDiaryBlockHeading ||
                  _headingLevel(node) == choice.level)))
        node,
  ];
  if (nodes.isEmpty) return roots;
  final spans = _preorderSpans(controller.document, roots);
  final transaction = controller.state.transaction;
  addDiaryBlockTypeChange(
    transaction,
    root: controller.document.root,
    nodes: nodes,
    type: type,
    attributesFor: (node) => {
      kDiaryBlockDeltaKey: node.delta!.toJson(),
      if (node.attributes[kDiaryBlockAlignKey] case final align?)
        kDiaryBlockAlignKey: align,
      if (type == kDiaryBlockHeading) kDiaryBlockLevelKey: choice.level ?? 1,
      if (type == kDiaryBlockTodoList)
        kDiaryBlockCheckedKey: node.attributes[kDiaryBlockCheckedKey] == true,
      if (type == kDiaryBlockCallout && node.type == kDiaryBlockCallout) ...{
        for (final key in [kDiaryCalloutIconKey, kDiaryCalloutToneKey])
          if (node.attributes[key] case final value?) key: value,
      },
    },
    selection: null,
  );
  controller.apply(transaction, updateSelection: false);
  return _nodesInSpans(controller.document, spans);
}

/// 选中块里的文字块（代码块除外）是否都整段带着行内格式 [key]（加粗等）。
bool diaryBlocksHaveInline(Iterable<af.Node> roots, String key) {
  final nodes = [
    for (final node in _styleTargets(roots))
      if (node.delta!.isNotEmpty) node,
  ];
  return nodes.isNotEmpty &&
      nodes.every(
        (node) => node.delta!.every((op) => op.attributes?[key] == true),
      );
}

/// 选中块里的文字块（代码块除外）整段都带 [key] 时去掉，否则全部加上；
/// 一步撤销。
void toggleDiaryBlocksInline(
  DiaryEditorController controller,
  List<af.Node> roots,
  String key,
) {
  if (controller.readOnly) return;
  final value = diaryBlocksHaveInline(roots, key) ? null : true;
  final transaction = controller.state.transaction;
  var changed = false;
  for (final node in _styleTargets(roots)) {
    final length = node.delta!.length;
    if (length == 0) continue;
    transaction.formatText(node, 0, length, {key: value});
    changed = true;
  }
  if (changed) controller.apply(transaction, updateSelection: false);
}

/// 选中块里文字块（代码块除外）共同的对齐；不同时为 null。
DiaryTextAlign? diaryBlocksAlign(Iterable<af.Node> roots) =>
    diaryTextAlignOf(_styleTargets(roots));

/// 把选中块里的文字块（代码块除外）设为 [align]，一步撤销。
void setDiaryBlocksAlign(
  DiaryEditorController controller,
  List<af.Node> roots,
  DiaryTextAlign align,
) {
  if (controller.readOnly) return;
  final transaction = controller.state.transaction;
  if (addDiaryTextAlign(transaction, _styleTargets(roots), align)) {
    controller.apply(transaction, updateSelection: false);
  }
}

/// 清除选中块里文字块的格式（换回正文段落、去掉行内格式与块属性），一步
/// 撤销；返回改写后的块。格子里的段落只去掉行内格式（本来就是段落）。
List<af.Node> clearDiaryBlocksFormat(
  DiaryEditorController controller,
  List<af.Node> roots,
) {
  if (controller.readOnly || roots.isEmpty) return roots;
  final spans = _preorderSpans(controller.document, roots);
  final transaction = controller.state.transaction;
  if (!addDiaryClearFormat(transaction, diaryBlockTextNodes(roots))) {
    return roots;
  }
  controller.apply(transaction, updateSelection: false);
  // 换类型会换掉节点对象（位置不变）：按先序位置找回。
  return _nodesInSpans(controller.document, spans);
}

int _headingLevel(af.Node node) {
  final raw = node.attributes[kDiaryBlockLevelKey];
  return raw is num ? raw.toInt().clamp(1, 6) : 1;
}

/// 各块（连同子树）在先序里占的区间 [开始, 结束)。
List<(int, int)> _preorderSpans(af.Document document, List<af.Node> roots) {
  final order = walkDiaryEditorNodes(document).toList();
  return [
    for (final root in diaryBlockRoots(roots))
      if (order.indexOf(root) case final start when start >= 0)
        (start, start + _subtreeSize(root)),
  ];
}

int _subtreeSize(af.Node node) =>
    1 + node.children.fold(0, (sum, child) => sum + _subtreeSize(child));

/// 先序区间里的块，规整为最上层的块。
List<af.Node> _nodesInSpans(af.Document document, List<(int, int)> spans) {
  final order = walkDiaryEditorNodes(document).toList();
  return diaryBlockRoots([
    for (final (start, end) in spans)
      for (var i = start; i < end && i < order.length; i++) order[i],
  ]);
}
