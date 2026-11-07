import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;

import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import 'diary_toggle_state.dart';

/// 嵌入块（图片、视频、音频、附件、分隔线、日记链接卡片，即
/// [kDiaryEmbedBlockTypes]）旁边的插入点、退格、Delete 与回车。
///
/// 插入点可以停在嵌入块上：选区折叠在块里，偏移 0 是块的左侧、1 是右侧
/// （竖线画在画面边上，见 DiaryEmbedSelectable），与图文混排里插入点停在
/// 图片旁边一样。点块旁的空白、退格 / Delete 越过文字行都会停到这里；输入法
/// 照常连着（DiaryEmbedCaretInput），键盘照常弹出。没有字的块上不能写字：
/// 一开始打字（含拼音组字）就在插入点那一侧补一个段落、插入点挪进去，字由
/// 上游照常写进这一行（[openDiaryLineAtEmbedCaret]）——在此之前正文里不多出
/// 任何空行。
///
/// 为什么要接手：上游把块上的插入点画成盖住整块、不连接输入法，点在块旁边
/// 键盘不出来；上游的退格在段首找“前面最近的带文字的块”合并
/// （`previousNodeWhere(delta != null)`），会越过中间的嵌入块——下一行的字
/// 并进嵌入块上面那段，嵌入块看上去跑到了后面。Delete 同理。
///
/// 规则（硬键盘经 diary_embed_keys.dart 的快捷键，排在上游“段首转正文”与
/// 表格规则之后、上游退格 / Delete / 回车之前；软键盘经同一文件的输入法
/// 拦截器）：
/// - 退格，插入点在文字块开头、显示上紧挨着的上一块是嵌入块：本行是空段落
///   （没有字、没有子块）→ 删掉这一行，插入点到嵌入块右侧；否则插入点只是
///   挪到嵌入块右侧，本行不动（块里没有字可以并进去）；
/// - 退格，插入点在嵌入块右侧 → 删掉这一块，插入点退到前一个位置（上一块
///   的末尾：文字末尾或嵌入块右侧；前面没有时到后一块开头；全文删空时补一个
///   空段落）；在嵌入块左侧 → 同段首退格：上一块是空段落就删掉它，否则插入
///   点挪到上一块末尾；
/// - Delete（桌面）左右对称：文字块末尾、下一块是嵌入块 → 空段落删掉、插入
///   点到嵌入块左侧，否则只挪过去；嵌入块左侧 → 删掉这一块；右侧 → 下一块
///   是空段落就删掉它，否则挪到下一块开头；
/// - 回车，插入点在嵌入块右侧 → 后面补一个空段落、插入点进去；左侧 → 前面
///   补一个空段落、插入点留在块左侧（同文字行首回车）；
/// - 表格同理（表格外的那一行）：表格下一行开头退格，空段落删掉、插入点进
///   最后一格最后一段的末尾，否则只挪进去；表格上一行末尾 Delete 对称，
///   进第一格开头——与表格里的 ← → 一致（diary_table_shortcuts.dart）。
///   原先这里交给上游，上游什么都不做，插入点卡在表格下面的空行里；
/// - 每次删除、补行都是一个事务、一步撤销（补行连同随后打的字合成一步）。
///   标题、列表等在段首退格仍先转为正文（上游 `convertToParagraphCommand`），
///   之后才轮到这里；格子里的按键另有规则（diary_table_shortcuts.dart）。
///
/// “紧挨着”按显示顺序：上一块是上一兄弟里最后显示的块（不进收起的折叠块
/// 与表格），没有上一兄弟时是父块；下一块是第一个子块（同样不进收起的
/// 折叠块），没有子块时是自己或最近祖先的下一兄弟。
///
/// 文末是表格时：[appendDiaryTrailingLine] 补一个空段落，供点按正文下方
/// 空白处时把插入点放进去（见 DiaryEditorKeyboardReopen）。嵌入块不需要：
/// 点在它下方，插入点停到它右侧。

bool _isEmbed(af.Node? node) =>
    node != null && kDiaryEmbedBlockTypes.contains(node.type);

/// 越不过去、只能进到里面的块：表格（插入点进最后一格末尾 / 第一格开头，
/// 同表格里的 ← →，见 diary_table_shortcuts.dart）。
bool _isTable(af.Node? node) => node != null && node.type == kDiaryBlockTable;

/// 空段落：没有字、没有子块。
bool _blankLine(af.Node node) =>
    node.type == kDiaryBlockParagraph &&
    (node.delta?.isEmpty ?? false) &&
    node.children.isEmpty;

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

af.Selection _caret(af.Path path, [int offset = 0]) =>
    af.Selection.collapsed(af.Position(path: path, offset: offset));

/// 插入点停在 [node] 末尾时的位置：文字块为文字末尾，嵌入块为右侧，表格
/// 为最后一格最后一段的末尾；都不是（或表格是空的）时为 null。
af.Selection? _endOf(af.Node node) {
  final delta = node.delta;
  if (delta != null) return _caret(node.path, delta.length);
  if (_isEmbed(node)) return _caret(node.path, 1);
  if (!_isTable(node) || node.children.isEmpty) return null;
  final cell = node.children.last;
  if (cell.children.isEmpty) return null;
  final last = cell.children.last;
  return last.delta == null ? null : _caret(last.path, last.delta!.length);
}

/// 插入点停在 [node] 开头时的位置路径：文字块与嵌入块为它自己（偏移 0），
/// 表格为第一格第一段；都不是（或表格是空的）时为 null。
af.Path? _startPathOf(af.Node node) {
  if (node.delta != null || _isEmbed(node)) return node.path;
  if (!_isTable(node) || node.children.isEmpty) return null;
  final cell = node.children.first;
  if (cell.children.isEmpty || cell.children.first.delta == null) return null;
  return cell.children.first.path;
}

/// 插入点停在其上的嵌入块：可编辑、折叠插入点、行内选区、落在嵌入块里；
/// 不是时为 null。
af.Node? diaryEmbedAtCaret(af.EditorState state) {
  final selection = state.selection;
  if (!state.editable ||
      selection == null ||
      !selection.isCollapsed ||
      state.selectionType == af.SelectionType.block) {
    return null;
  }
  final node = state.getNodeAtPath(selection.end.path);
  return _isEmbed(node) ? node : null;
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

void _apply(af.EditorState state, af.Transaction transaction) =>
    unawaited(state.apply(transaction, skipHistoryDebounce: true));

/// 只挪插入点，不改正文、不进撤销栈。
void _moveCaret(af.EditorState state, af.Selection selection) =>
    unawaited(state.updateSelectionWithReason(selection));

/// 删掉空行 [line]，插入点设为 [after]（按删除后的正文算）。
void _deleteLine(af.EditorState state, af.Node line, af.Selection after) {
  _apply(
    state,
    state.transaction
      ..deleteNode(line)
      ..afterSelection = after,
  );
}

/// 删掉嵌入块 [embed]，插入点退到旁边：[backward]（退格）先找前一块的末尾、
/// 再找后一块的开头；否则（Delete）反过来。两边都没有块（全文删空）时在
/// 原处补一个空段落。
void _deleteEmbed(
  af.EditorState state,
  af.Node embed, {
  required bool backward,
}) {
  final path = embed.path;
  final before = _shownBefore(embed);
  final after = _shownAfter(embed);
  af.Selection? previousEnd() => before == null ? null : _endOf(before);
  af.Selection? nextStart() {
    final start = after == null ? null : _startPathOf(after);
    return start == null ? null : _caret(af.transformPath(path, start, -1));
  }

  final caret = backward
      ? previousEnd() ?? nextStart()
      : nextStart() ?? previousEnd();
  final transaction = state.transaction..deleteNode(embed);
  if (caret == null) transaction.insertNode(path, af.paragraphNode());
  transaction.afterSelection = caret ?? _caret(path);
  _apply(state, transaction);
}

/// 退格：插入点在文字块开头而上一块是嵌入块，或插入点停在嵌入块上时按
/// 文件说明的规则处理，返回 true；不适用时返回 false、什么都不做（交给
/// 上游）。
bool backspaceDiaryEmbed(af.EditorState state) {
  final embed = diaryEmbedAtCaret(state);
  if (embed != null) {
    if (state.selection!.end.offset > 0) {
      _deleteEmbed(state, embed, backward: true);
      return true;
    }
    // 左侧：同段首退格。文首时什么都不做（也不交给上游：上游会把块当
    // 文字处理）。
    final before = _shownBefore(embed);
    if (before == null) return true;
    if (_blankLine(before)) {
      // 上一块是空段落时它就是上一兄弟（父块总有子块，不是空段落）：删掉
      // 它，块前移一位，插入点仍在块左侧。
      _deleteLine(
        state,
        before,
        _caret(af.transformPath(before.path, embed.path, -1)),
      );
    } else if (_endOf(before) case final end?) {
      _moveCaret(state, end);
    }
    return true;
  }
  final node = _caretTextNode(state);
  if (node == null || state.selection!.end.offset != 0) return false;
  final before = _shownBefore(node);
  if (before == null || !(_isEmbed(before) || _isTable(before))) return false;
  final end = _endOf(before);
  if (end == null) return false;
  // 上一块在本行之前（上一兄弟或它的子树里），删掉本行不改变它的路径。
  if (_blankLine(node)) {
    _deleteLine(state, node, end);
  } else {
    _moveCaret(state, end);
  }
  return true;
}

/// Delete：插入点在文字块末尾而下一块是嵌入块，或插入点停在嵌入块上时按
/// 文件说明的规则处理，返回 true；不适用时返回 false、什么都不做。
bool deleteForwardDiaryEmbed(af.EditorState state) {
  final embed = diaryEmbedAtCaret(state);
  if (embed != null) {
    if (state.selection!.end.offset == 0) {
      _deleteEmbed(state, embed, backward: false);
      return true;
    }
    final after = _shownAfter(embed);
    if (after == null) return true;
    if (_blankLine(after)) {
      // 下一块在块之后，删掉它不改变块的路径。
      _deleteLine(state, after, state.selection!);
    } else if (_startPathOf(after) case final start?) {
      _moveCaret(state, _caret(start));
    }
    return true;
  }
  final node = _caretTextNode(state);
  if (node == null) return false;
  if (state.selection!.end.offset != node.delta!.length) return false;
  final after = _shownAfter(node);
  if (after == null || !(_isEmbed(after) || _isTable(after))) return false;
  final start = _startPathOf(after);
  if (start == null) return false;
  if (_blankLine(node)) {
    _deleteLine(state, node, _caret(af.transformPath(node.path, start, -1)));
  } else {
    _moveCaret(state, _caret(start));
  }
  return true;
}

/// 回车，插入点停在嵌入块上：右侧 → 后面补一个空段落、插入点进去；左侧 →
/// 前面补一个空段落、插入点留在块左侧。不在嵌入块上时返回 false。
bool insertDiaryLineAtEmbed(af.EditorState state) {
  final embed = diaryEmbedAtCaret(state);
  if (embed == null) return false;
  final path = embed.path;
  final right = state.selection!.end.offset > 0;
  _apply(
    state,
    state.transaction
      ..insertNode(right ? path.next : path, af.paragraphNode())
      // 两种情形都落在 path.next：右侧是新段落的开头，左侧是被挤下去一位的
      // 块的左侧。
      ..afterSelection = _caret(path.next),
  );
  return true;
}

/// 插入点停在嵌入块上时开始打字：在插入点那一侧补一个空段落（右侧补在
/// 后面、左侧补在前面），插入点放进去，返回 true；不在嵌入块上时返回
/// false。
///
/// 由输入法拦截器在上游写字之前调用：补行的选区更新不让上游重连输入法
/// （[af.selectionExtraInfoDoNotAttachTextService]），随后上游把这次输入
/// （含组字中的拼音）照常写进新的一行——输入法那边本就是空行的编辑值，前后
/// 对得上，组字不受打扰。补行与随后打的字合成一步撤销。
bool openDiaryLineAtEmbedCaret(af.EditorState state) {
  final embed = diaryEmbedAtCaret(state);
  if (embed == null) return false;
  final path = state.selection!.end.offset > 0 ? embed.path.next : embed.path;
  final undo = state.undoManager.undoStack;
  // 不并进之前还在合并的打字：补行从这里单独起一步。
  if (undo.isNonEmpty) undo.last.seal();
  final transaction = state.transaction
    ..insertNode(path, af.paragraphNode())
    ..afterSelection = _caret(path)
    ..customSelectionType = af.SelectionType.inline
    ..selectionExtraInfo = {af.selectionExtraInfoDoNotAttachTextService: true};
  unawaited(state.apply(transaction));
  return true;
}

/// 正文最后显示的块是表格（收起的折叠块不往里看）时，在末尾补一个空段落、
/// 插入点放进去，返回新的插入点；不需要时返回 null、什么都不做。一步撤销。
/// 文末是嵌入块时不补：插入点停在它右侧即可。
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
  // 不往表格里走，表格本身没有文字（格子里写不到表格下面）。
  if (last.type != kDiaryBlockTable) return null;
  final path = root.children.last.path.next;
  final selection = _caret(path);
  _apply(
    state,
    state.transaction
      ..insertNode(path, af.paragraphNode())
      ..afterSelection = selection
      ..reason = af.SelectionUpdateReason.uiEvent
      ..customSelectionType = af.SelectionType.inline,
  );
  return selection;
}
