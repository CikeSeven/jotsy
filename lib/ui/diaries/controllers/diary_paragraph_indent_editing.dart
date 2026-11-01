import 'package:appflowy_editor/appflowy_editor.dart' as af;

import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import 'diary_editor_controller.dart';
import 'diary_table_editing.dart';

/// 工具栏「缩进 / 取消缩进」作用在正文段落上时的首行缩进。
///
/// 为什么不用上游的嵌套缩进：上游 `indentCommand` 把段落挂成上一块的子块，
/// 子块整块向内缩进一个标记列宽，多行段落的每一行都跟着右移——用户按
/// 「缩进」想要的是中文排版的首行缩进（只有第一行空出两个字）。所以：
/// - 选区触及的文字块全是正文段落（且不在表格格子里）时，「缩进」只给这些
///   段落写 `data.firstLineIndent = true`（[kDiaryParagraphIndentKey]），由
///   `DiaryParagraphBlock` 把首行缩进两个字，折行后的各行仍顶格；
/// - 「取消缩进」先清掉这个标记；段落没有标记但已是子块（旧版嵌套缩进过的，
///   或拖动进去的）时，交还上游 `outdentCommand` 提回上一层；
/// - 选区里有列表、待办、折叠块等其他块时不走这里，仍是真实的父子嵌套
///   （列表层级是结构，不是排版）。
///
/// 每次写入一个事务、一步撤销；没有要改的段落时不写。

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

/// [node] 是否带首行缩进标记。
bool diaryParagraphHasFirstLineIndent(af.Node node) =>
    node.attributes[kDiaryParagraphIndentKey] == true;

/// 「缩进」是否可按：还有段落没缩进首行。
bool canIndentDiaryFirstLine(List<af.Node> targets) =>
    targets.any((node) => !diaryParagraphHasFirstLineIndent(node));

/// 「取消缩进」是否可按：有段落缩进了首行，或（都没有时）能提回上一层。
bool canOutdentDiaryFirstLine(
  DiaryEditorController controller,
  List<af.Node> targets,
) =>
    targets.any(diaryParagraphHasFirstLineIndent) ||
    af.isOutdentable(controller.state);

/// 给 [targets] 里还没缩进的段落写上首行缩进。
void indentDiaryFirstLine(
  DiaryEditorController controller,
  List<af.Node> targets,
) {
  if (controller.readOnly) return;
  final nodes = [
    for (final node in targets)
      if (!diaryParagraphHasFirstLineIndent(node)) node,
  ];
  if (nodes.isEmpty) return;
  final transaction = controller.state.transaction;
  for (final node in nodes) {
    transaction.updateNode(node, {kDiaryParagraphIndentKey: true});
  }
  transaction.afterSelection = controller.selection;
  controller.apply(transaction);
}

/// 清掉 [targets] 的首行缩进（稀疏：删键）；都没有标记时按上游提回上一层。
void outdentDiaryFirstLine(
  DiaryEditorController controller,
  List<af.Node> targets,
) {
  if (controller.readOnly) return;
  final nodes = targets.where(diaryParagraphHasFirstLineIndent).toList();
  if (nodes.isEmpty) {
    af.outdentCommand.handler(controller.state);
    return;
  }
  final transaction = controller.state.transaction;
  for (final node in nodes) {
    transaction.updateNode(node, {kDiaryParagraphIndentKey: null});
  }
  transaction.afterSelection = controller.selection;
  controller.apply(transaction);
}
