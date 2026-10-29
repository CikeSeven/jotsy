import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/services.dart';

import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import 'diary_block_convert.dart';
import 'diary_editor_controller.dart';
import 'diary_toggle_state.dart';

/// 折叠块（`toggle_list`）的编辑：展开 / 收起、工具栏转换与回车规则。
///
/// - 每个动作是一个事务、一步撤销；只读会话一律不写；
/// - 收起状态稀疏写入：收起写 `collapsed: true`，展开删掉这个键（缺省即
///   展开）；
/// - 退格（标题开头转正文段落）与缩进进出折叠块不在这里：折叠块登记进上游
///   的可转换、可缩进类型表即生效（见 `ensureDiaryEditorGlobals`）。

/// 展开或收起 [node]。收起时选区若有一端在它的子块（将被收起的内容）里，
/// 光标改落到标题末尾，不留在看不见的地方；其余情况选区原样保留。
void setDiaryToggleCollapsed(
  DiaryEditorController controller,
  af.Node node, {
  required bool collapsed,
}) {
  if (controller.readOnly || node.type != kDiaryBlockToggleList) return;
  if (isDiaryToggleCollapsed(node) == collapsed) return;
  final path = node.path;
  final selection = controller.selection;
  bool inside(af.Position position) =>
      position.path.length > path.length &&
      position.path.sublist(0, path.length).equals(path);
  final after =
      collapsed &&
          selection != null &&
          (inside(selection.start) || inside(selection.end))
      ? af.Selection.collapsed(
          af.Position(path: path, offset: node.delta?.length ?? 0),
        )
      : selection;
  final transaction = controller.state.transaction
    ..updateNode(node, {kDiaryToggleCollapsedKey: collapsed ? true : null})
    ..afterSelection = after;
  controller.apply(transaction);
}

/// 选区触及、能转为折叠块或已是折叠块的文字块（代码块除外），按文档顺序。
List<af.Node> _toggleTargets(DiaryEditorController controller) => [
  for (final node in controller.selectedNodes)
    if (node.delta != null && node.type != kDiaryBlockCode) node,
];

/// 选区里的文字块（代码块除外）是否都是折叠块（工具栏按钮的选中态与
/// 转换方向同一口径）。
bool diarySelectionInToggle(DiaryEditorController controller) {
  final targets = _toggleTargets(controller);
  return targets.isNotEmpty &&
      targets.every((node) => node.type == kDiaryBlockToggleList);
}

/// 工具栏「折叠块」：选区里的文字块（代码块除外）不全是折叠块时，把其余
/// 的转为折叠块；全是时转回正文段落。文字与对齐保留，收起状态不带过去
/// （新折叠块展开，转回的段落照常显示子块）。折叠块与段落都能挂子块，
/// 子块原地保留。
void toggleDiaryToggleBlocks(DiaryEditorController controller) {
  if (controller.readOnly) return;
  final targets = _toggleTargets(controller);
  if (targets.isEmpty) return;
  final toText = targets.every((node) => node.type == kDiaryBlockToggleList);
  final nodes = toText
      ? targets
      : [
          for (final node in targets)
            if (node.type != kDiaryBlockToggleList) node,
        ];
  final transaction = controller.state.transaction;
  transaction.afterSelection = addDiaryBlockTypeChange(
    transaction,
    root: controller.document.root,
    nodes: nodes,
    type: toText ? kDiaryBlockParagraph : kDiaryBlockToggleList,
    attributesFor: (node) => {
      kDiaryBlockDeltaKey: node.delta!.toJson(),
      if (node.attributes[kDiaryBlockAlignKey] case final align?)
        kDiaryBlockAlignKey: align,
    },
    selection: controller.selection,
  );
  controller.apply(transaction);
}

/// 折叠块标题里回车（字符快捷事件，排在上游默认的“新建段落”之前）：
///
/// - 标题为空：原地转为正文段落（保留对齐），子块留在段落下面——与列表、
///   提示块在空项上回车即退出同一手感；
/// - 标题非空、展开：光标后的文字成为第一个子块（正文段落），光标落在
///   那里，接着写折叠的内容；
/// - 标题非空、收起：光标后的文字成为紧跟其后的同级折叠块（展开，对齐与
///   文字方向随原块），光标落在那里——不往看不见的内容里写。
///
/// 选区不折叠时先删掉选中的文字（同上游），再按上面的规则处理。桌面
/// Shift + 回车照旧交给上游（在标题里换行）。整次回车一步撤销。
///
/// 为什么不用上游默认：上游回车把块的全部子块挪到新段落下面，折叠的内容
/// 就从折叠块里掉了出来。
final af.CharacterShortcutEvent diaryToggleEnterEvent =
    af.CharacterShortcutEvent(
      key: 'diary_toggle_enter',
      character: '\n',
      handler: _toggleEnter,
    );

Future<bool> _toggleEnter(af.EditorState state) async {
  if (HardwareKeyboard.instance.isShiftPressed) return false;
  var selection = state.selection?.normalized;
  if (selection == null) return false;
  if (state.document.nodeAtPath(selection.start.path)?.type !=
      kDiaryBlockToggleList) {
    return false;
  }
  if (!selection.isCollapsed &&
      !selection.start.path.equals(selection.end.path)) {
    // 跨块的选区：先按上游删掉选中的内容（与之后的改写合成一步撤销：这一步
    // 不封口，后面的事务带 skipHistoryDebounce 并进同一步再封口）。
    await state.deleteSelection(selection);
    selection = state.selection?.normalized;
    if (selection == null || !selection.isCollapsed) return true;
  }
  final node = state.document.nodeAtPath(selection.start.path);
  final delta = node?.delta;
  if (node == null || node.type != kDiaryBlockToggleList || delta == null) {
    return true;
  }
  // 删掉同一块里选中的文字之后的标题，光标在选区开头。
  final offset = selection.start.offset.clamp(0, delta.length);
  final title = selection.isCollapsed
      ? delta
      : (af.Delta()
          ..addAll(delta.slice(0, offset))
          ..addAll(
            delta.slice(selection.end.offset.clamp(offset, delta.length)),
          ));
  final transaction = state.transaction;
  if (title.isEmpty) {
    // 换类型时整份改写 delta，不必另删选中的文字。
    transaction
      ..updateNodeType(node, kDiaryBlockParagraph, {
        kDiaryBlockDeltaKey: <Object?>[],
        if (node.attributes[kDiaryBlockAlignKey] case final align?)
          kDiaryBlockAlignKey: align,
      })
      ..afterSelection = af.Selection.collapsed(af.Position(path: node.path));
  } else {
    if (!selection.isCollapsed) {
      transaction.deleteText(node, offset, delta.length - title.length);
    }
    final tail = title.slice(offset);
    if (tail.isNotEmpty) transaction.deleteText(node, offset, tail.length);
    final direction = node.attributes[af.blockComponentTextDirection];
    final af.Path target;
    final af.Node inserted;
    if (isDiaryToggleCollapsed(node)) {
      target = node.path.next;
      inserted = af.Node(
        type: kDiaryBlockToggleList,
        attributes: {
          kDiaryBlockDeltaKey: tail.toJson(),
          if (node.attributes[kDiaryBlockAlignKey] case final align?)
            kDiaryBlockAlignKey: align,
          if (direction != null) af.blockComponentTextDirection: direction,
        },
      );
    } else {
      target = [...node.path, 0];
      inserted = af.paragraphNode(
        attributes: {
          kDiaryBlockDeltaKey: tail.toJson(),
          if (direction != null) af.blockComponentTextDirection: direction,
        },
      );
    }
    transaction
      ..insertNode(target, inserted)
      ..afterSelection = af.Selection.collapsed(af.Position(path: target));
  }
  await state.apply(transaction, skipHistoryDebounce: true);
  return true;
}
