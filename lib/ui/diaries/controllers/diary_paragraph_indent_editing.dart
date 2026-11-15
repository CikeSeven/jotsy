import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart' as af;

import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../core/services/diary_typography.dart';
import 'diary_editor_controller.dart';
import 'diary_table_editing.dart';

/// 工具栏「缩进 / 取消缩进」作用在正文段落上时的首行缩进。
///
/// 为什么不用上游的嵌套缩进：上游 `indentCommand` 把段落挂成上一块的子块，
/// 子块整块向内缩进一个标记列宽，多行段落的每一行都跟着右移——用户按
/// 「缩进」想要的是中文排版的首行缩进（只有第一行空出两个字）。所以选区
/// 触及的文字块全是正文段落（且不在表格格子里）时，只改这些段落的首行缩进
/// 标记 `data.firstLineIndent`（[kDiaryParagraphIndentKey]），由
/// `DiaryParagraphBlock` 只缩进首行，折行后的各行仍顶格。
///
/// 标记是三态，因为排版设置另有一个对所有段落生效的全局首行缩进
/// （`DiaryTypography.firstLineIndent`，见 [DiaryEditorController.globalFirstLineIndent]）：
/// - `true`：缩进（两个字与全局取较大者）；
/// - `false`：这一段不缩进，盖过全局缩进（#253：全局缩进两字时，「取消缩进」
///   只取消这一段）；
/// - 没有这个键：跟随全局。
///
/// 两个按钮都按“按下后这一段看起来会不会变”判断，不会出现标记加了又删、
/// 画面不动的情况：
/// - 「缩进」把没缩进到位的段落缩进：全局已缩进到两字及以上时删键（跟随
///   全局就是缩进到位，且以后改全局缩进时跟着变），否则写 `true`；
/// - 「取消缩进」把缩进着的段落取消：全局不缩进时删键（稀疏，与改版前
///   一致），否则写 `false`；没有缩进着的段落但已是子块（旧版嵌套缩进过的，
///   或拖动进去的）时，交还上游 `outdentCommand` 提回上一层；
/// - 选区里有列表、待办、折叠块等其他块时不走这里，仍是真实的父子嵌套
///   （列表层级是结构，不是排版）。
///
/// 只按标记与全局缩进判断，不看对齐：居中、右对齐的段落画出来不缩进，但
/// 标记照常改写，换回左对齐时即生效。每次写入一个事务、一步撤销；没有要改
/// 的段落时不写。

/// 「缩进」按钮作用于首行缩进的段落：选区里的文字块全是正文段落、且都不在
/// 表格格子里时为这些段落，否则为 null（交给嵌套缩进）。
List<af.Node>? diaryFirstLineIndentTargets(DiaryEditorController controller) {
  final nodes = [
    for (final node in controller.selectedNodes)
      if (node.delta != null) node,
  ];
  if (nodes.isEmpty) return null;
  for (final node in nodes) {
    if (node.type != kDiaryBlockParagraph || diaryNodeInTableCell(node)) {
      return null;
    }
  }
  return nodes;
}

/// [node] 首行缩进的字数（不看对齐与表格格子）：标记为 `true` 时两字与全局
/// 取较大者，`false` 时为 0，没有标记时为全局缩进 [global]。
double _indentChars(af.Node node, double global) => diaryParagraphIndentFor(
  node.attributes[kDiaryParagraphIndentKey],
  regular: global,
  marked: _indentedChars(global),
);

/// 缩进到位的字数：与带 `true` 标记的段落一样宽。
double _indentedChars(double global) =>
    math.max(global, DiaryTypography.paragraphFirstLineIndent);

/// 「缩进」要改的段落：还没缩进到位的。
List<af.Node> _indentNodes(List<af.Node> targets, double global) => [
  for (final node in targets)
    if (_indentChars(node, global) < _indentedChars(global)) node,
];

/// 「取消缩进」要改的段落：首行缩进着的。
List<af.Node> _outdentNodes(List<af.Node> targets, double global) => [
  for (final node in targets)
    if (_indentChars(node, global) > 0) node,
];

/// 「缩进」是否可按：还有段落没缩进到位。
bool canIndentDiaryFirstLine(
  DiaryEditorController controller,
  List<af.Node> targets,
) => _indentNodes(targets, controller.globalFirstLineIndent).isNotEmpty;

/// 「取消缩进」是否可按：有段落缩进着首行，或（都没有时）能提回上一层。
bool canOutdentDiaryFirstLine(
  DiaryEditorController controller,
  List<af.Node> targets,
) =>
    _outdentNodes(targets, controller.globalFirstLineIndent).isNotEmpty ||
    af.isOutdentable(controller.state);

/// 把 [targets] 里没缩进到位的段落缩进首行。
void indentDiaryFirstLine(
  DiaryEditorController controller,
  List<af.Node> targets,
) {
  if (controller.readOnly) return;
  final global = controller.globalFirstLineIndent;
  final nodes = _indentNodes(targets, global);
  if (nodes.isEmpty) return;
  // 全局已缩进到两字及以上时跟随全局与写 true 一样宽，删键更稀疏。
  final value = global >= DiaryTypography.paragraphFirstLineIndent
      ? null
      : true;
  _write(controller, nodes, value);
}

/// 取消 [targets] 里缩进着的段落的首行缩进；都没缩进时按上游提回上一层。
void outdentDiaryFirstLine(
  DiaryEditorController controller,
  List<af.Node> targets,
) {
  if (controller.readOnly) return;
  final global = controller.globalFirstLineIndent;
  final nodes = _outdentNodes(targets, global);
  if (nodes.isEmpty) {
    af.outdentCommand.handler(controller.state);
    return;
  }
  // 全局缩进时删键会回到全局缩进、画面不变，只能写“这一段不缩进”。
  _write(controller, nodes, global > 0 ? false : null);
}

/// 一个事务写入 [nodes] 的首行缩进标记（null 删键），选区不动。
void _write(
  DiaryEditorController controller,
  List<af.Node> nodes,
  bool? value,
) {
  final transaction = controller.state.transaction;
  for (final node in nodes) {
    transaction.updateNode(node, {kDiaryParagraphIndentKey: value});
  }
  transaction.afterSelection = controller.selection;
  controller.apply(transaction);
}
