import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';

import '../../controllers/diary_table_editing.dart';
import '../../controllers/diary_table_structure.dart';
import '../../controllers/diary_table_selection.dart';

/// 表格里的键盘规则，排在上游的快捷键之前：
///
/// - 回车：沿用上游，在同一格里另起一段（上游“回车跳到下一格”的表格命令
///   不装入，见 [kUpstreamTableCommandKeys]）；选区跨出表格时先按本应用
///   的规则删掉选区（[deleteDiaryTableSelection]）再另起一段；
/// - 退格：格子第一段开头什么都不做（不并进上一格、不并出表格），其余段
///   开头并进同格的上一段；非折叠选区触及表格时按本应用的规则删除；
/// - Delete：格子最后一段末尾什么都不做，其余段末尾把同格的下一段并进来；
/// - Tab / Shift + Tab：到下一格 / 上一格的第一段开头（阅读顺序）；最后
///   一格按 Tab 在表格末尾追加一行并进入新行第一格，第一格按 Shift + Tab
///   不动；
/// - ← / →：第一段开头按 ← 到上一格末尾（第一格到表格前一块的末尾），最后
///   一段末尾按 → 到下一格开头（最后一格到表格后一块的开头）；格内段落之间
///   与段内移动沿用上游；
/// - ↑ / ↓：第一段的首行按 ↑ 到上一行同列格子的最后一段（首行到表格前一块），
///   最后一段的末行按 ↓ 到下一行同列格子的第一段（末行到表格后一块），偏移
///   尽量保持；段内其他行沿用上游；
/// - Markdown 快捷输入（`# `、`- `、`1. `、`[] `、`> `、`---`……）在格子里按
///   原文插入：格子只能放段落；
/// - 软键盘（输入法）走 diary_table_keyboard_interceptor.dart：退格与覆盖
///   选区的输入按同样的规则。
///
/// 这些命令只在光标落在格子里时接手，其余情况交还上游（返回 ignored）。

/// 上游 `standardCommandShortcutEvents` 里表格命令的 key：按“一格一段”
/// 设计（回车跳格、↑ ↓ 直接换格），与多段格子冲突，装编辑器时过滤掉。
const Set<String> kUpstreamTableCommandKeys = <String>{
  "Don't add new line in table cell",
  'Move to left cell if its at start of current cell',
  'Move to right cell if its at the end of current cell',
  'Move to up cell at same offset',
  'Move to down cell at same offset',
  'Navigate around the cells at same offset',
  'Navigate around the cells at same offset in reverse',
  'Stop at the beginning of the cell',
};

List<af.CommandShortcutEvent> diaryTableCommandShortcuts() => [
  af.CommandShortcutEvent(
    key: 'diary_table_backspace',
    getDescription: () => 'backspace in table',
    command: 'backspace, shift+backspace',
    handler: (state) => _backspace(state),
  ),
  af.CommandShortcutEvent(
    key: 'diary_table_delete',
    getDescription: () => 'delete in table',
    command: 'delete, shift+delete',
    handler: (state) => _delete(state),
  ),
  af.CommandShortcutEvent(
    key: 'diary_table_tab',
    getDescription: () => 'next table cell',
    command: 'tab',
    handler: (state) => _tab(state, forward: true),
  ),
  af.CommandShortcutEvent(
    key: 'diary_table_shift_tab',
    getDescription: () => 'previous table cell',
    command: 'shift+tab',
    handler: (state) => _tab(state, forward: false),
  ),
  af.CommandShortcutEvent(
    key: 'diary_table_arrow_left',
    getDescription: () => 'previous table cell end',
    command: 'arrow left',
    handler: (state) => _horizontal(state, forward: false),
  ),
  af.CommandShortcutEvent(
    key: 'diary_table_arrow_right',
    getDescription: () => 'next table cell start',
    command: 'arrow right',
    handler: (state) => _horizontal(state, forward: true),
  ),
  af.CommandShortcutEvent(
    key: 'diary_table_arrow_up',
    getDescription: () => 'table cell above',
    command: 'arrow up',
    handler: (state) => _vertical(state, up: true),
  ),
  af.CommandShortcutEvent(
    key: 'diary_table_arrow_down',
    getDescription: () => 'table cell below',
    command: 'arrow down',
    handler: (state) => _vertical(state, up: false),
  ),
];

List<af.CharacterShortcutEvent> diaryTableCharacterShortcuts() => [
  // 选区跨出表格（或跨格）时回车：先按本应用的规则删，再另起一段。
  af.CharacterShortcutEvent(
    key: 'diary_table_newline',
    character: '\n',
    handler: (state) async {
      final selection = state.selection;
      if (selection == null ||
          selection.isCollapsed ||
          !diarySelectionTouchesTable(state, selection)) {
        return false;
      }
      if (!await deleteDiaryTableSelection(state, selection)) return false;
      if (state.isDisposed) return true;
      await state.insertNewLine();
      return true;
    },
  ),
  // 格子里的 Markdown 标记按原文插入。
  af.CharacterShortcutEvent(
    key: 'diary_table_literal_space',
    character: ' ',
    handler: (state) => _literalInCell(state, ' ', _kSpaceTriggers),
  ),
  for (final symbol in ['-', '*', '_'])
    af.CharacterShortcutEvent(
      key: 'diary_table_literal_$symbol',
      character: symbol,
      handler: (state) => _literalInCell(state, symbol, [
        RegExp('^${RegExp.escape(symbol)}{2}\$'),
      ]),
    ),
];

/// 空格前的整行命中这些写法时上游会把段落换成标题、列表、待办、引用或
/// 代码块。
final List<RegExp> _kSpaceTriggers = [
  RegExp(r'^#{1,6}$'),
  RegExp(r'^[-*+]$'),
  RegExp(r'^\d+\.$'),
  RegExp(r'^-?\[[ xX]?\]$'),
  RegExp(r'^[>"]$'),
  RegExp(r'^```[\w+-]*$'),
];

Future<bool> _literalInCell(
  af.EditorState state,
  String character,
  List<RegExp> triggers,
) async {
  final selection = state.selection;
  if (selection == null || !selection.isCollapsed) return false;
  final node = state.document.nodeAtPath(selection.end.path);
  if (node == null || node.delta == null || !diaryNodeInTableCell(node)) {
    return false;
  }
  final before = node.delta!.toPlainText().substring(
    0,
    selection.end.offset.clamp(0, node.delta!.length),
  );
  if (!triggers.any((trigger) => trigger.hasMatch(before))) return false;
  await state.insertTextAtPosition(character);
  return true;
}

/// 光标所在的格内段落（折叠选区）；不在格子里为 null。
({af.Node node, DiaryTableCaret caret})? diaryTableCaretParagraph(
  af.EditorState state,
) {
  final selection = state.selection;
  if (selection == null || !selection.isCollapsed) return null;
  final node = state.document.nodeAtPath(selection.end.path);
  if (node == null || node.delta == null || !diaryNodeInTableCell(node)) {
    return null;
  }
  final caret = diaryTableCaretOf(node);
  return caret == null ? null : (node: node, caret: caret);
}

KeyEventResult _deleteSelectionIfTouchesTable(af.EditorState state) {
  final selection = state.selection;
  if (selection == null || selection.isCollapsed) return KeyEventResult.ignored;
  if (!diarySelectionTouchesTable(state, selection)) {
    return KeyEventResult.ignored;
  }
  unawaited(deleteDiaryTableSelection(state, selection));
  return KeyEventResult.handled;
}

KeyEventResult _backspace(af.EditorState state) {
  final selection = state.selection;
  if (selection == null) return KeyEventResult.ignored;
  if (!selection.isCollapsed) return _deleteSelectionIfTouchesTable(state);
  if (selection.end.offset != 0) return KeyEventResult.ignored;
  final found = diaryTableCaretParagraph(state);
  if (found == null) return KeyEventResult.ignored;
  mergeDiaryCellParagraphBackward(state, found.node);
  return KeyEventResult.handled;
}

/// 退格：格子第一段开头不动；其余段并进同格的上一段。软键盘与硬键盘共用。
void mergeDiaryCellParagraphBackward(af.EditorState state, af.Node node) {
  final previous = node.previous;
  if (previous == null || previous.delta == null) return;
  final transaction = state.transaction
    ..mergeText(previous, node)
    ..deleteNode(node)
    ..afterSelection = af.Selection.collapsed(
      af.Position(path: previous.path, offset: previous.delta!.length),
    );
  unawaited(state.apply(transaction, skipHistoryDebounce: true));
}

KeyEventResult _delete(af.EditorState state) {
  final selection = state.selection;
  if (selection == null) return KeyEventResult.ignored;
  if (!selection.isCollapsed) return _deleteSelectionIfTouchesTable(state);
  final found = diaryTableCaretParagraph(state);
  if (found == null || selection.end.offset != found.node.delta!.length) {
    return KeyEventResult.ignored;
  }
  final next = found.node.next;
  if (next != null && next.delta != null) {
    final transaction = state.transaction
      ..mergeText(found.node, next)
      ..deleteNode(next)
      ..afterSelection = selection;
    unawaited(state.apply(transaction, skipHistoryDebounce: true));
  }
  return KeyEventResult.handled;
}

/// 格子按阅读顺序的前后一格；越界为 null。
af.Node? _neighbourCell(DiaryTableCaret caret, {required bool forward}) {
  final index = caret.row * caret.cols + caret.col + (forward ? 1 : -1);
  if (index < 0 || index >= caret.rows * caret.cols) return null;
  return caret.table.children.elementAtOrNull(index);
}

af.Selection? _cellStart(af.Node? cell) {
  final first = cell?.children.firstOrNull;
  return first == null
      ? null
      : af.Selection.collapsed(af.Position(path: first.path));
}

af.Selection? _cellEnd(af.Node? cell) {
  final last = cell?.children.lastOrNull;
  return last == null
      ? null
      : af.Selection.collapsed(
          af.Position(path: last.path, offset: last.delta?.length ?? 0),
        );
}

KeyEventResult _tab(af.EditorState state, {required bool forward}) {
  final selection = state.selection;
  if (selection == null) return KeyEventResult.ignored;
  final node = state.document.nodeAtPath(selection.end.path);
  final caret = diaryTableCaretOf(node);
  if (node == null || caret == null || !diaryNodeInTableCell(node)) {
    return KeyEventResult.ignored;
  }
  if (!selection.isCollapsed &&
      diaryTableCellOf(state.document.nodeAtPath(selection.start.path)) !=
          caret.cell) {
    return KeyEventResult.ignored;
  }
  final neighbour = _neighbourCell(caret, forward: forward);
  if (neighbour != null) {
    _select(state, _cellStart(neighbour));
  } else if (forward) {
    appendDiaryTableRow(state, caret);
  }
  return KeyEventResult.handled;
}

KeyEventResult _horizontal(af.EditorState state, {required bool forward}) {
  final found = diaryTableCaretParagraph(state);
  if (found == null) return KeyEventResult.ignored;
  final (node: node, caret: caret) = found;
  final offset = state.selection!.end.offset;
  if (forward) {
    if (offset != node.delta!.length || !caret.isLastParagraph) {
      return KeyEventResult.ignored;
    }
    final next = _neighbourCell(caret, forward: true);
    _select(state, next != null ? _cellStart(next) : _afterTable(caret.table));
  } else {
    if (offset != 0 || !caret.isFirstParagraph) return KeyEventResult.ignored;
    final previous = _neighbourCell(caret, forward: false);
    _select(
      state,
      previous != null ? _cellEnd(previous) : _beforeTable(caret.table),
    );
  }
  return KeyEventResult.handled;
}

KeyEventResult _vertical(af.EditorState state, {required bool up}) {
  final found = diaryTableCaretParagraph(state);
  if (found == null) return KeyEventResult.ignored;
  final (node: node, caret: caret) = found;
  if (up ? !caret.isFirstParagraph : !caret.isLastParagraph) {
    return KeyEventResult.ignored;
  }
  if (!_caretOnEdgeLine(state, node, top: up)) return KeyEventResult.ignored;
  final offset = state.selection!.end.offset;
  final targetRow = up ? caret.row - 1 : caret.row + 1;
  if (targetRow < 0 || targetRow >= caret.rows) {
    _select(state, up ? _beforeTable(caret.table) : _afterTable(caret.table));
    return KeyEventResult.handled;
  }
  final cell = caret.table.children.elementAtOrNull(
    targetRow * caret.cols + caret.col,
  );
  final target = up ? cell?.children.lastOrNull : cell?.children.firstOrNull;
  if (target != null) {
    _select(
      state,
      af.Selection.collapsed(
        af.Position(
          path: target.path,
          offset: offset.clamp(0, target.delta?.length ?? 0),
        ),
      ),
    );
  }
  return KeyEventResult.handled;
}

/// 光标是否在 [node] 的首行（[top]）或末行：按光标矩形与段落矩形（去掉
/// 块的上下间距）比较，一行以内算同一行。
bool _caretOnEdgeLine(af.EditorState state, af.Node node, {required bool top}) {
  final rects = state.selectionRects();
  final block = node.rect;
  if (rects.isEmpty || block == Rect.zero) return true;
  final caret = rects.first;
  final padding =
      state.service.rendererService
          .blockComponentBuilder(node.type)
          ?.configuration
          .padding(node) ??
      EdgeInsets.zero;
  return top
      ? caret.center.dy < block.top + padding.top + caret.height
      : caret.center.dy > block.bottom - padding.bottom - caret.height;
}

af.Selection? _beforeTable(af.Node table) {
  final previous = table.previous;
  if (previous == null) return null;
  final end = previous.selectable?.end();
  return af.Selection.collapsed(
    end ??
        af.Position(path: previous.path, offset: previous.delta?.length ?? 0),
  );
}

af.Selection? _afterTable(af.Node table) {
  final next = table.next;
  if (next == null) return null;
  final start = next.selectable?.start();
  return af.Selection.collapsed(start ?? af.Position(path: next.path));
}

void _select(af.EditorState state, af.Selection? selection) {
  if (selection == null) return;
  unawaited(state.updateSelectionWithReason(selection));
}
