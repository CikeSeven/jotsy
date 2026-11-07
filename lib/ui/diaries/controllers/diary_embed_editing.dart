import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/foundation.dart';

import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../models/diary_thumbnail_rows.dart';
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
/// 规则：先选中、再删除（硬键盘经 diary_embed_keys.dart 的快捷键，排在
/// 上游“段首转正文”之后、上游退格 / Delete 之前；软键盘经同一文件的输入法
/// 拦截器）：
/// - 退格，插入点在文字块开头、显示上紧挨着的上一块是嵌入块：
///   - 嵌入块已选中 → 删掉它，本行接到它原来的位置，插入点不动；
///   - 本行是空段落（没有字、没有子块）且后面紧跟着文字块 → 删掉这个空行，
///     插入点到下一行开头（仍在嵌入块正下方），并选中嵌入块；
///   - 其余（本行有字，或空行后面没有能放插入点的文字块）→ 只选中嵌入块，
///     本行不动；
/// - Delete（桌面），插入点在文字块末尾、紧接着的下一块是嵌入块：已选中 →
///   删掉它；否则选中它。插入点都不动；
/// - 删除是一个事务、一步撤销；选中不改正文、不进撤销栈。标题、列表等在
///   段首退格仍先转为正文（上游 `convertToParagraphCommand`），之后才轮到
///   这里；表格格子另有规则（diary_table_shortcuts.dart），格子不是嵌入块。
///
/// “选中”不把插入点挪到嵌入块上（[DiaryArmedEmbed]）：嵌入块没有文字，
/// 上游不会为它更新输入法的编辑值，拦截器处理完按键后又把输入法退回按键前
/// 的值——插入点停在块上时打字（尤其拼音组字）会与输入法对不上。插入点
/// 留在原来那行，输入法始终连着真实的文字；嵌入块只是画成选中的样子。
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
///
/// 块旁的空白：[placeDiaryCaretAfterEmbed] 在点按落在嵌入块的空白处（图片
/// 右侧、上下留白、分隔线）时把插入点放到它下面一行，同样由
/// DiaryEditorKeyboardReopen 在点按后调用。

/// 退格 / Delete 选中的嵌入块：插入点留在旁边那行，再按一次才删掉它。
///
/// 按编辑状态各一份（[of]，用 Expando 挂在 [af.EditorState] 上，快捷键与
/// 输入法拦截器只拿得到它）。只在内存里，从不写进正文。选中期间监听选区
/// 与事务：选区变成别处（点按、方向键、打字后插入点后移、失焦清空）或正文
/// 有任何改动（打字、撤销、粘贴……）即取消，避免隔了别的操作再按退格时
/// 删掉一个早先选中的块。嵌入块据 [node] 画出选中的样子（见
/// diary_editor_blocks.dart）。
class DiaryArmedEmbed {
  DiaryArmedEmbed._(this._state);

  static final Expando<DiaryArmedEmbed> _all = Expando('diaryArmedEmbed');

  /// [state] 的选中状态；首次调用时创建。
  static DiaryArmedEmbed of(af.EditorState state) =>
      _all[state] ??= DiaryArmedEmbed._(state);

  final af.EditorState _state;

  /// 当前选中的嵌入块；没有时为 null。
  final ValueNotifier<af.Node?> node = ValueNotifier(null);

  af.Selection? _selection;
  StreamSubscription<af.EditorTransactionValue>? _edits;

  /// 选中 [embed]，以当前选区为准：之后选区变了或正文改了即取消。
  void arm(af.Node embed) {
    disarm();
    if (_state.isDisposed) return;
    _selection = _state.selection;
    _state.selectionNotifier.addListener(_onSelection);
    // 事务流是同步广播：改动应用的同时就取消，先于任何后续按键。
    _edits = _state.transactionStream.listen((event) {
      if (event.$1 == af.TransactionTime.after &&
          event.$2.operations.isNotEmpty) {
        disarm();
      }
    });
    node.value = embed;
  }

  /// 取消选中；没有选中时什么都不做。
  void disarm() {
    if (node.value == null && _edits == null) return;
    if (!_state.isDisposed) {
      _state.selectionNotifier.removeListener(_onSelection);
    }
    unawaited(_edits?.cancel());
    _edits = null;
    _selection = null;
    node.value = null;
  }

  /// [embed] 是否仍是选中的那块（选中后没有别的操作）。
  bool holds(af.Node embed) => identical(node.value, embed);

  void _onSelection() {
    // 选区通知在值相同时也会触发（上游重设同一选区），只看值有没有变。
    if (_state.selection != _selection) disarm();
  }
}

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

/// 删掉 [embed]，插入点放到 [caret]。一步撤销；选中随正文改动取消。
void _deleteEmbed(af.EditorState state, af.Node embed, af.Position caret) {
  final transaction = state.transaction
    ..deleteNode(embed)
    ..afterSelection = af.Selection.collapsed(caret);
  unawaited(state.apply(transaction, skipHistoryDebounce: true));
}

/// 插入点在文字块开头、上一块是嵌入块时按退格规则选中或删除（见文件说明）；
/// 不适用时返回 false、什么都不做。
bool backspaceDiaryEmbed(af.EditorState state) {
  final node = _caretTextNode(state);
  if (node == null || state.selection!.end.offset != 0) return false;
  final embed = _shownBefore(node);
  if (!_isEmbed(embed)) return false;
  final armed = DiaryArmedEmbed.of(state);
  if (armed.holds(embed!)) {
    // 嵌入块从不挂子块：它要么是本行的上一兄弟（删掉后本行前移一位），
    // 要么在上一兄弟的子树里（本行的路径不变）。
    final sibling = embed.parent == node.parent;
    _deleteEmbed(
      state,
      embed,
      af.Position(path: sibling ? node.path.previous : node.path),
    );
    return true;
  }
  if (node.type == kDiaryBlockParagraph &&
      node.delta!.isEmpty &&
      node.children.isEmpty &&
      node.next?.delta != null) {
    // 删掉空行：下一行接到这里，插入点到它开头。事务同步应用完（事务流
    // 也已同步通知过），再选中嵌入块。
    final transaction = state.transaction
      ..deleteNode(node)
      ..afterSelection = af.Selection.collapsed(af.Position(path: node.path));
    unawaited(state.apply(transaction, skipHistoryDebounce: true));
  }
  armed.arm(embed);
  return true;
}

/// 插入点在文字块末尾、下一块是嵌入块时按 Delete 规则选中或删除（见文件
/// 说明）；不适用时返回 false、什么都不做。
bool deleteForwardDiaryEmbed(af.EditorState state) {
  final node = _caretTextNode(state);
  if (node == null) return false;
  final selection = state.selection!;
  if (selection.end.offset != node.delta!.length) return false;
  final embed = _shownAfter(node);
  if (!_isEmbed(embed)) return false;
  final armed = DiaryArmedEmbed.of(state);
  if (armed.holds(embed!)) {
    // 嵌入块在本行之后（子块或后面的块），删掉它不改变本行的路径。
    _deleteEmbed(state, embed, selection.end);
  } else {
    armed.arm(embed);
  }
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
  return _insertLineAt(state, root.children.last.path.next);
}

/// 点按落在嵌入块 [embed] 的空白处时，把插入点放到它下面一行，返回新的
/// 插入点；只读或 [embed] 不是嵌入块时返回 null、什么都不做。
///
/// 为什么：上游把点在嵌入块旁边的点按解释成把光标“盖”在块上
/// （`DiaryEmbedSelectable`），块里没有文字，输入法不连接——键盘不出来，
/// 打字也没有去处，插入点像是卡在了图片上。点块旁的空白，用户要的是在块
/// 后面接着写，与图文混排的编辑器里点在图片右侧一样。
///
/// - 紧接着的下一块是空的文字块（没有字、没有子块）→ 插入点放进去，不改
///   正文；
/// - 否则在块后面补一个空段落、插入点放进去（一步撤销）。下一块有字时也
///   补：插入点停在图片和下面那段字之间，接着写的字紧跟在图片后面，不会
///   写到下一段开头。反复点同一块旁边只会补出一行（第二次就是空行了）；
/// - 并排的小图按整排算（[diaryThumbnailRowOf]），补在这一排最后一张后面，
///   不会把一排拆开。
///
/// 选区以点按的名义更新（[af.SelectionUpdateReason.uiEvent]），上游据此请求
/// 焦点并连接输入法，与点在文字上一样。
af.Selection? placeDiaryCaretAfterEmbed(af.EditorState state, af.Node embed) {
  if (!state.editable || !_isEmbed(embed)) return null;
  var anchor = embed;
  final row = diaryThumbnailRowOf(embed);
  if (row != null) anchor = embed.parent!.children[row.end - 1];
  final next = anchor.next;
  if (next != null &&
      next.delta != null &&
      next.delta!.isEmpty &&
      next.children.isEmpty) {
    final selection = af.Selection.collapsed(af.Position(path: next.path));
    unawaited(
      state.updateSelectionWithReason(
        selection,
        reason: af.SelectionUpdateReason.uiEvent,
      ),
    );
    return selection;
  }
  return _insertLineAt(state, anchor.path.next);
}

/// 在 [path] 插入一个空段落，插入点放进去（点按的名义，一步撤销）。
af.Selection _insertLineAt(af.EditorState state, af.Path path) {
  final selection = af.Selection.collapsed(af.Position(path: path));
  final transaction = state.transaction
    ..insertNode(path, af.paragraphNode())
    ..afterSelection = selection
    ..reason = af.SelectionUpdateReason.uiEvent
    ..customSelectionType = af.SelectionType.inline;
  unawaited(state.apply(transaction, skipHistoryDebounce: true));
  return selection;
}
