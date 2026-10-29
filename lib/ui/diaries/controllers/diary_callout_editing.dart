import 'package:appflowy_editor/appflowy_editor.dart' as af;

import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../models/diary_callout_tone.dart';
import 'diary_block_convert.dart';
import 'diary_editor_controller.dart';

/// 工具栏「提示块」工具与提示块面板读写正文。
///
/// - 作用范围：选区触及的文字块，代码块除外（代码块的转换与退出另有代码块
///   面板）；
/// - 选区“在提示块里”= 这些文字块都是提示块（折叠光标看光标所在的块）。
///   工具据此决定转为提示块还是打开面板，按钮的选中态与面板何时收起同一
///   口径；
/// - 图标与底色稀疏写入：选默认图标（[kDiaryCalloutDefaultIcon]）或默认底色
///   时删掉这个键，缺省即默认；
/// - 每次写入是一个事务、一步撤销；取值与当前相同时不写，不留空的撤销步骤。

/// 面板里的图标选项，第一个为默认图标。
const List<String> kDiaryCalloutIconChoices = <String>[
  kDiaryCalloutDefaultIcon,
  '📌',
  '⭐',
  '✅',
  '⚠️',
  '❗',
  '❓',
  '📝',
];

/// 选区触及、能转为提示块或已是提示块的文字块（代码块除外），按文档顺序。
List<af.Node> _calloutTargets(DiaryEditorController controller) => [
  for (final node in controller.selectedNodes)
    if (node.delta != null && node.type != kDiaryBlockCode) node,
];

/// 选区里的提示块，按文档顺序。
List<af.Node> selectedDiaryCallouts(DiaryEditorController controller) => [
  for (final node in controller.selectedNodes)
    if (node.type == kDiaryBlockCallout) node,
];

/// 选区里的文字块（代码块除外）是否都是提示块。
bool diarySelectionInCallout(DiaryEditorController controller) {
  final targets = _calloutTargets(controller);
  return targets.isNotEmpty &&
      targets.every((node) => node.type == kDiaryBlockCallout);
}

/// 把选区里还不是提示块的文字块（代码块除外）转为提示块，保留文字与对齐；
/// 已是提示块的不动（图标与底色保留）。图标、底色不写（缺省即默认）。带缩进
/// 子块的块经 [addDiaryBlockTypeChange] 把子块提到提示块后面。
void convertDiaryBlocksToCallout(DiaryEditorController controller) {
  if (controller.readOnly) return;
  final nodes = [
    for (final node in _calloutTargets(controller))
      if (node.type != kDiaryBlockCallout) node,
  ];
  if (nodes.isEmpty) return;
  final transaction = controller.state.transaction;
  transaction.afterSelection = addDiaryBlockTypeChange(
    transaction,
    root: controller.document.root,
    nodes: nodes,
    type: kDiaryBlockCallout,
    attributesFor: (node) => {
      kDiaryBlockDeltaKey: node.delta!.toJson(),
      if (node.attributes[kDiaryBlockAlignKey] case final align?)
        kDiaryBlockAlignKey: align,
    },
    selection: controller.selection,
  );
  controller.apply(transaction);
}

/// 把选区里的提示块转回正文段落，保留文字与对齐，丢掉图标与底色。
void convertDiaryCalloutsToText(DiaryEditorController controller) {
  if (controller.readOnly) return;
  final nodes = selectedDiaryCallouts(controller);
  if (nodes.isEmpty) return;
  final transaction = controller.state.transaction;
  for (final node in nodes) {
    transaction.updateNodeType(node, kDiaryBlockParagraph, {
      kDiaryBlockDeltaKey: node.delta!.toJson(),
      if (node.attributes[kDiaryBlockAlignKey] case final align?)
        kDiaryBlockAlignKey: align,
    });
  }
  transaction.afterSelection = controller.selection;
  controller.apply(transaction);
}

/// 选区里提示块的图标；各块不同（或没有提示块）时为 null。
String? selectedDiaryCalloutIcon(DiaryEditorController controller) {
  final icons = {
    for (final node in selectedDiaryCallouts(controller))
      diaryCalloutIconOf(node),
  };
  return icons.length == 1 ? icons.single : null;
}

/// 选区里提示块的底色档位；各块不同（或没有提示块）时为 null。
DiaryCalloutTone? selectedDiaryCalloutTone(DiaryEditorController controller) {
  final tones = {
    for (final node in selectedDiaryCallouts(controller))
      DiaryCalloutTone.fromId(node.attributes[kDiaryCalloutToneKey]),
  };
  return tones.length == 1 ? tones.single : null;
}

/// 把选区里每个提示块的图标设为 [icon]；默认图标删掉这个键。
void setDiaryCalloutIcon(DiaryEditorController controller, String icon) {
  final value = icon == kDiaryCalloutDefaultIcon ? null : icon;
  _writeCallouts(controller, kDiaryCalloutIconKey, value);
}

/// 把选区里每个提示块的底色设为 [tone]；默认底色删掉这个键。
void setDiaryCalloutTone(
  DiaryEditorController controller,
  DiaryCalloutTone tone,
) {
  final value = tone == DiaryCalloutTone.neutral ? null : tone.id;
  _writeCallouts(controller, kDiaryCalloutToneKey, value);
}

/// 写入值为 null 时删除键（上游合并属性时去掉值为 null 的键）。已是这个
/// 原值的块不写；认不出的旧值照样改写。
void _writeCallouts(
  DiaryEditorController controller,
  String key,
  String? value,
) {
  if (controller.readOnly) return;
  final nodes = [
    for (final node in selectedDiaryCallouts(controller))
      if (node.attributes[key] != value) node,
  ];
  if (nodes.isEmpty) return;
  final transaction = controller.state.transaction;
  for (final node in nodes) {
    transaction.updateNode(node, {key: value});
  }
  transaction.afterSelection = controller.selection;
  controller.apply(transaction);
}

/// 块数据里的图标（编辑器渲染与面板共用）；缺省、空串或不是字符串时为
/// 默认图标。
String diaryCalloutIconOf(af.Node node) {
  final raw = node.attributes[kDiaryCalloutIconKey];
  return raw is String && raw.trim().isNotEmpty
      ? raw
      : kDiaryCalloutDefaultIcon;
}
