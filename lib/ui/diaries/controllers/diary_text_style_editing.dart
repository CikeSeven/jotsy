import 'package:appflowy_editor/appflowy_editor.dart' as af;

import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../models/diary_text_colors.dart';
import '../models/diary_text_style_options.dart';
import 'diary_block_convert.dart';
import 'diary_editor_controller.dart';

/// 工具栏「标题」「对齐」「字号」三块面板读写正文：读出选区当前的取值（面板
/// 据此选中一格），以及把一个取值写进选区。
///
/// - 作用范围：选区触及的文字块，代码块除外（代码块里的 Markdown 与排版都是
///   原文，有自己的字体与字号）；一个文字块都没有时（光标在代码块里）面板
///   按钮全部停用，见 [diaryTextStyleEditable]；
/// - 每次写入是一个事务、一步撤销；取值与当前相同时不写，不留空的撤销步骤；
/// - 读取时选区跨了取值不同的块（或文字片段）返回 null，面板不选中任何一格。

/// 选区触及、能改标题 / 对齐 / 字号的文字块（代码块除外），按文档顺序。
List<af.Node> diaryTextStyleTargets(DiaryEditorController controller) => [
  for (final node in controller.selectedNodes)
    if (node.delta != null && node.type != kDiaryBlockCode) node,
];

/// 面板按钮是否可用：选区里至少有一个非代码的文字块，且正文可编辑。
bool diaryTextStyleEditable(DiaryEditorController controller) =>
    !controller.readOnly && diaryTextStyleTargets(controller).isNotEmpty;

// ---- 标题 ----

/// 选区里文字块的标题级别：都是正文段落为 0，都是同一级标题为 1–6；混着
/// 不同级别、或有列表、引用这类其他块时为 null。
int? selectedDiaryHeadingLevel(DiaryEditorController controller) {
  final levels = <int?>{
    for (final node in diaryTextStyleTargets(controller))
      switch (node.type) {
        kDiaryBlockParagraph => 0,
        kDiaryBlockHeading => _headingLevel(node),
        _ => null,
      },
  };
  return levels.length == 1 ? levels.single : null;
}

int _headingLevel(af.Node node) {
  final raw = node.attributes[kDiaryBlockLevelKey];
  return raw is num ? raw.toInt().clamp(1, 6) : 1;
}

/// 把选区里的文字块换成 [level] 级标题（0 为正文段落）。换成标题时带缩进
/// 子块的块经 [addDiaryBlockTypeChange] 把子块提到后面；对齐随块保留。
void setDiaryHeadingLevel(DiaryEditorController controller, int level) {
  if (controller.readOnly) return;
  final nodes = diaryTextStyleTargets(controller);
  if (nodes.isEmpty || selectedDiaryHeadingLevel(controller) == level) return;
  final transaction = controller.state.transaction;
  transaction.afterSelection = addDiaryBlockTypeChange(
    transaction,
    root: controller.document.root,
    nodes: nodes,
    type: level == 0 ? kDiaryBlockParagraph : kDiaryBlockHeading,
    attributesFor: (node) => {
      kDiaryBlockDeltaKey: node.delta!.toJson(),
      if (node.attributes[kDiaryBlockAlignKey] case final align?)
        kDiaryBlockAlignKey: align,
      if (level > 0) kDiaryBlockLevelKey: level,
    },
    selection: controller.selection,
  );
  controller.apply(transaction);
}

// ---- 对齐 ----

/// 选区里文字块的对齐；各块不同时为 null。
DiaryTextAlign? selectedDiaryTextAlign(DiaryEditorController controller) {
  final aligns = {
    for (final node in diaryTextStyleTargets(controller))
      DiaryTextAlign.fromAttribute(node.attributes[kDiaryBlockAlignKey]),
  };
  return aligns.length == 1 ? aligns.single : null;
}

/// 把选区里的文字块设为 [align]；左对齐移除 `align` 键（稀疏）。认不出的旧值
/// 按左对齐读出，选左对齐时一并清掉。
void setDiaryTextAlign(DiaryEditorController controller, DiaryTextAlign align) {
  if (controller.readOnly) return;
  final value = align.attributeValue;
  final nodes = [
    for (final node in diaryTextStyleTargets(controller))
      if (node.attributes[kDiaryBlockAlignKey] != value) node,
  ];
  if (nodes.isEmpty) return;
  final transaction = controller.state.transaction;
  for (final node in nodes) {
    transaction.updateNode(node, {kDiaryBlockAlignKey: value});
  }
  transaction.afterSelection = controller.selection;
  controller.apply(transaction);
}

// ---- 字号 ----

/// 选区的字号档位：折叠光标取“接下来输入”的字号（含刚在光标上选过的），
/// 选中范围时取代码块之外各段文字的字号，不一致或认不出时为 null。
DiaryFontSize? selectedDiaryFontSize(DiaryEditorController controller) {
  final selection = controller.selection;
  if (selection == null) return null;
  if (selection.isCollapsed) {
    return DiaryFontSize.fromAttribute(
      controller.selectionAttributes[kDiaryInlineSize],
    );
  }
  final values = <Object?>{};
  _forEachSelectedRange(controller, selection.normalized, (node, from, to) {
    for (final op in node.delta!.slice(from, to)) {
      values.add(op.attributes?[kDiaryInlineSize]);
    }
  });
  return values.length == 1 ? DiaryFontSize.fromAttribute(values.single) : null;
}

/// 把选中范围（代码块之外）的文字设为 [size]，一步撤销；折叠光标时设为
/// “接下来输入”的字号（上游的 toggled style，接着打的字带上它，见
/// `ensureDiaryEditorGlobals`）。
void setDiaryFontSize(DiaryEditorController controller, DiaryFontSize size) {
  final selection = controller.selection;
  if (selection == null || controller.readOnly) return;
  if (diaryTextStyleTargets(controller).isEmpty) return;
  if (selectedDiaryFontSize(controller) == size) return;
  if (selection.isCollapsed) {
    controller.format(kDiaryInlineSize, size.attributeValue);
    return;
  }
  final transaction = controller.state.transaction;
  var changed = false;
  _forEachSelectedRange(controller, selection.normalized, (node, from, to) {
    changed = true;
    transaction.formatText(node, from, to - from, {
      kDiaryInlineSize: size.attributeValue,
    });
  });
  if (!changed) return;
  transaction.afterSelection = selection;
  controller.apply(transaction);
}

/// 选中范围在每个非代码文字块里覆盖的 `[from, to)`（空段跳过）。
void _forEachSelectedRange(
  DiaryEditorController controller,
  af.Selection normalized,
  void Function(af.Node node, int from, int to) visit,
) {
  for (final node in diaryTextStyleTargets(controller)) {
    final length = node.delta!.length;
    final from = node.path.equals(normalized.start.path)
        ? normalized.start.offset.clamp(0, length)
        : 0;
    final to = node.path.equals(normalized.end.path)
        ? normalized.end.offset.clamp(0, length)
        : length;
    if (to > from) visit(node, from, to);
  }
}

// ---- 高亮快捷键 ----

/// Ctrl / ⌘ + Shift + H 写入的高亮色：色板里黄色背景预设（与导入的高亮同值），
/// 按应用的颜色写法编码为大写 `#AARRGGBB`。
final String kDiaryDefaultHighlight = encodeDiaryColor(
  DiaryColorPreset.yellow.colorFor(DiaryColorTarget.background),
);

/// 选中的文字整段都是默认高亮色时去掉背景色，否则涂上默认高亮色（一步
/// 撤销）。取代上游的同名快捷键：上游写 `0x60FFCE00` 这种写法，与颜色面板、
/// 导出认的 `#AARRGGBB` 不一致。折叠光标时不处理（与上游相同）。
bool toggleDiaryDefaultHighlight(DiaryEditorController controller) {
  final selection = controller.selection;
  if (controller.readOnly || selection == null || selection.isCollapsed) {
    return false;
  }
  final current = DiaryColorValue.of(
    controller.selectionAttributes,
    DiaryColorTarget.background,
  );
  controller.format(
    DiaryColorTarget.background.attributeKey,
    current.raw == kDiaryDefaultHighlight ? null : kDiaryDefaultHighlight,
  );
  return true;
}
