import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;

import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import 'diary_toggle_state.dart';

/// 文字块旁边的嵌入块（图片、视频、音频、附件、分隔线、日记链接卡片，即
/// [kDiaryEmbedBlockTypes]）怎么删，文末是这类块时怎么接着往下写。
///
/// 为什么要接手：上游的退格在段首找“前面最近的带文字的块”合并
/// （`previousNodeWhere(delta != null)`），会越过中间的嵌入块——下一行的字
/// 并进嵌入块上面那段，嵌入块看上去跑到了后面；下一行是最后一段时，它就
/// 成了全文最后一块，后面再没有能放插入点的地方。Delete 同理，把嵌入块
/// 后面的字拉到它前面。
///
/// 规则（硬键盘经 diary_embed_keys.dart 的快捷键，排在上游“段首转正文”
/// 之后、上游退格 / Delete 之前；软键盘经同一文件的输入法拦截器）：
/// - 退格：插入点在文字块开头、显示上紧挨着的上一块是嵌入块 → 删掉嵌入块，
///   本行接到它原来的位置，插入点不动。例外：本行是空段落（没有字、没有
///   子块）且后面紧跟着文字块时，先删掉这个空行、插入点到下一行开头——
///   视觉上仍在嵌入块正下方，再按一次才删嵌入块。与常见编辑器“先删空行、
///   再删图片”一致，清理空行时多按一下不会误删照片；空行是最后一块（或
///   后面是嵌入块、表格）时不删它，否则嵌入块后面又没有能写字的行了；
/// - Delete（桌面）：插入点在文字块末尾、紧接着的下一块是嵌入块 → 删掉
///   嵌入块，插入点不动；
/// - 每次一个事务、一步撤销。标题、列表等在段首退格仍先转为正文（上游
///   `convertToParagraphCommand`），之后才轮到这里；表格格子另有规则
///   （diary_table_shortcuts.dart），格子不是嵌入块，这里从不接手。
///
/// “紧挨着”按显示顺序：上一块是上一兄弟里最后显示的块（不进收起的折叠块
/// 与表格），没有上一兄弟时是父块；下一块是第一个子块（同样不进收起的
/// 折叠块），没有子块时是自己或最近祖先的下一兄弟。
///
/// 文末：[appendDiaryTrailingLine] 在正文最后显示的块不能打字（嵌入块或
/// 表格）时补一个空段落，供点按正文下方空白处时把插入点放进去（见
/// DiaryEditorKeyboardReopen）。插入媒体本就总在后面补空段落
/// （insertDiaryEditorNodes），但旧数据、拖动排序与导入的正文仍可能以
/// 嵌入块结尾。

bool _isEmbed(af.Node? node) =>
    node != null && kDiaryEmbedBlockTypes.contains(node.type);

/// 显示时能往里走的块：有子块、不是收起的折叠块、不是表格（表格整个是
/// 一块，格子里的段落不算“紧挨着”表格外的块）。
bool _showsChildren(af.Node node) =>
    node.children.isNotEmpty &&
    node.type != kDiaryBlockTable &&
    !isDiaryToggleCollapsed(node);

/// [node] 显示上的上一块；在文档开头时为 null。
af.Node? _shownBefore(af.Node node) {
  var previous = node.previous;
  if (previous == null) {
    final parent = node.parent;
    // 顶层块的父块是页面根节点，不是正文里的块。
    return parent?.parent == null ? null : parent;
  }
  while (_showsChildren(previous!)) {
    previous = previous.children.last;
  }
  return previous;
}

/// [node] 显示上的下一块；在文档末尾时为 null。
af.Node? _shownAfter(af.Node node) {
  if (_showsChildren(node)) return node.children.first;
  for (af.Node? current = node; current != null; current = current.parent) {
    if (current.parent == null) return null;
    final next = current.next;
    if (next != null) return next;
  }
  return null;
}

/// 硬键盘与软键盘共用的前提：可编辑、折叠插入点、行内选区、落在文字块里。
af.Node? _caretTextNode(af.EditorState state) {
  final selection = state.selection;
  if (!state.editable ||
      selection == null ||
      !selection.isCollapsed ||
      state.selectionType == af.SelectionType.block) {
    return null;
  }
  final node = state.getNodeAtPath(selection.end.path);
  return node?.delta == null ? null : node;
}

/// 插入点在文字块开头、上一块是嵌入块时按退格规则删除（见文件说明）；
/// 不适用时返回 false、什么都不做。
bool deleteDiaryEmbedBeforeCaret(af.EditorState state) {
  final node = _caretTextNode(state);
  if (node == null || state.selection!.end.offset != 0) return false;
  final embed = _shownBefore(node);
  if (!_isEmbed(embed)) return false;
  final transaction = state.transaction;
  final next = node.next;
  if (node.type == kDiaryBlockParagraph &&
      node.delta!.isEmpty &&
      node.children.isEmpty &&
      next?.delta != null) {
    // 先删空行：下一行接到这里，插入点到它开头。
    transaction
      ..deleteNode(node)
      ..afterSelection = af.Selection.collapsed(af.Position(path: node.path));
  } else {
    // 嵌入块从不挂子块：它要么是本行的上一兄弟（删掉后本行前移一位），
    // 要么在上一兄弟的子树里（本行的路径不变）。
    final sibling = embed!.parent == node.parent;
    transaction
      ..deleteNode(embed)
      ..afterSelection = af.Selection.collapsed(
        af.Position(path: sibling ? node.path.previous : node.path),
      );
  }
  unawaited(state.apply(transaction, skipHistoryDebounce: true));
  return true;
}

/// 插入点在文字块末尾、下一块是嵌入块时删掉它（见文件说明）；不适用时
/// 返回 false、什么都不做。
bool deleteDiaryEmbedAfterCaret(af.EditorState state) {
  final node = _caretTextNode(state);
  if (node == null) return false;
  final selection = state.selection!;
  if (selection.end.offset != node.delta!.length) return false;
  final embed = _shownAfter(node);
  if (!_isEmbed(embed)) return false;
  // 嵌入块在本行之后（子块或后面的块），删掉它不改变本行的路径。
  final transaction = state.transaction
    ..deleteNode(embed!)
    ..afterSelection = selection;
  unawaited(state.apply(transaction, skipHistoryDebounce: true));
  return true;
}

/// 正文最后显示的块不能打字（嵌入块或表格；收起的折叠块不往里看）时，在
/// 末尾补一个空段落、插入点放进去，返回新的插入点；不需要时返回 null、
/// 什么都不做。一步撤销。
///
/// 选区以点按（[af.SelectionUpdateReason.uiEvent]）的名义更新：上游键盘
/// 服务据此请求正文焦点并连接输入法，与点在文字上一样。
af.Selection? appendDiaryTrailingLine(af.EditorState state) {
  final root = state.document.root;
  if (!state.editable || root.children.isEmpty) return null;
  var last = root.children.last;
  while (_showsChildren(last)) {
    last = last.children.last;
  }
  // 不往表格里走，表格本身没有文字：也算不能打字（格子里写不到表格下面）。
  if (last.delta != null) return null;
  final path = root.children.last.path.next;
  final selection = af.Selection.collapsed(af.Position(path: path));
  final transaction = state.transaction
    ..insertNode(path, af.paragraphNode())
    ..afterSelection = selection
    ..reason = af.SelectionUpdateReason.uiEvent
    ..customSelectionType = af.SelectionType.inline;
  unawaited(state.apply(transaction, skipHistoryDebounce: true));
  return selection;
}
