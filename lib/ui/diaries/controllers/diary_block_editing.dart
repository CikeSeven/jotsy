import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/services.dart';

import '../../../core/database/code_block_codec.dart';
import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import 'diary_editor_controller.dart';
import 'diary_toggle_editing.dart';

/// 代码块的语言、转换、复制与退出都通过原生事务操作节点，保持子树与撤销。
List<af.Node> selectedDiaryCodeBlocks(DiaryEditorController controller) =>
    controller.selectedNodes.where((node) => node.type == 'code').toList();

bool diarySelectionInCodeBlock(DiaryEditorController controller) =>
    selectedDiaryCodeBlocks(controller).isNotEmpty;

void setDiaryCodeBlockLanguage(DiaryEditorController controller, Object value) {
  final transaction = controller.state.transaction;
  for (final node in selectedDiaryCodeBlocks(controller)) {
    transaction.updateNode(node, {
      'language': codeBlockExplicitLanguage(value),
    });
  }
  transaction.afterSelection = controller.selection;
  controller.apply(transaction);
}

void convertDiaryCodeBlockToText(DiaryEditorController controller) {
  final transaction = controller.state.transaction;
  for (final node in selectedDiaryCodeBlocks(controller)) {
    transaction.updateNodeType(node, 'paragraph', {
      'delta': node.delta!.toJson(),
    });
  }
  transaction.afterSelection = controller.selection;
  controller.apply(transaction);
}

void exitDiaryCodeBlock(DiaryEditorController controller) {
  final blocks = selectedDiaryCodeBlocks(controller);
  if (blocks.isEmpty) return;
  final block = blocks.last;
  final next = block.next;
  if (next?.type == 'paragraph' && next!.delta?.isEmpty == true) {
    controller.select(af.Selection.collapsed(af.Position(path: next.path)));
    return;
  }
  final transaction = controller.state.transaction
    ..insertNode(block.path.next, af.paragraphNode())
    ..afterSelection = af.Selection.collapsed(
      af.Position(path: block.path.next),
    );
  controller.apply(transaction);
}

Future<void> copyDiaryCodeBlock(af.Node block) =>
    Clipboard.setData(ClipboardData(text: block.delta?.toPlainText() ?? ''));

void toggleDiaryCodeBlockOn(DiaryEditorController controller) {
  final nodes = controller.selectedNodes
      .where((node) => node.delta != null)
      .toList();
  final siblings =
      nodes.length > 1 &&
      nodes.every(
        (node) => node.parent == nodes.first.parent && node.children.isEmpty,
      );
  if (!siblings) {
    controller.setBlockType('code');
    return;
  }
  // 把选中的连续行合为一个真正的多行代码块；子树存在时保留各块，不能为
  // 合并外观而摊平或丢掉子块。插入和删除同在一次事务，撤销原样恢复各行。
  final delta = af.Delta();
  for (var i = 0; i < nodes.length; i++) {
    if (i > 0) delta.insert('\n');
    delta.addAll(nodes[i].delta!);
  }
  final transaction = controller.state.transaction
    ..insertNode(
      nodes.first.path,
      af.Node(type: 'code', attributes: {'delta': delta.toJson()}),
    )
    ..deleteNodes(nodes)
    ..afterSelection = af.Selection.single(
      path: nodes.first.path,
      startOffset: 0,
      endOffset: delta.length,
    );
  controller.apply(transaction);
}

/// 软键盘与硬键盘走同一条字符快捷链；代码回车先于默认“新建段落”。
List<af.CharacterShortcutEvent> diaryBlockCharacterShortcuts() => [
  af.CharacterShortcutEvent(
    key: 'diary_code_newline',
    character: '\n',
    handler: _codeNewline,
  ),
  af.CharacterShortcutEvent(
    key: 'diary_code_fence_enter',
    character: '\n',
    handler: _codeFence,
  ),
  af.CharacterShortcutEvent(
    key: 'diary_code_fence_space',
    character: ' ',
    handler: _codeFence,
  ),
  af.CharacterShortcutEvent(
    key: 'diary_code_literal',
    character: '',
    regExp: RegExp(r'[\s\S]'),
    handler: (_) async => false,
    handlerWithCharacter: (state, character) async {
      final selection = state.selection;
      if (character == '\n' ||
          selection == null ||
          !selection.isCollapsed ||
          state.document.nodeAtPath(selection.end.path)?.type != 'code') {
        return false;
      }
      // 代码里的 Markdown 标记都是原文，不能把 **、#、反引号等改成格式。
      await state.insertTextAtPosition(character);
      return true;
    },
  ),
  // 空提示块里回车：转为正文段落，不再新起一个空段落（见
  // [_emptyCalloutEnter]）。非空提示块的回车沿用上游：光标后的文字另起
  // 一个正文段落，所以在末尾回车就是在提示块后面接着写正文。
  af.CharacterShortcutEvent(
    key: 'diary_callout_empty_enter',
    character: '\n',
    handler: _emptyCalloutEnter,
  ),
  // 折叠块标题里回车：空标题转正文，展开时接第一个子块，收起时接同级
  // 折叠块（见 [diaryToggleEnterEvent]）。
  diaryToggleEnterEvent,
  // 行首 `> ` 转为引用。上游只认 `" `，`/` 菜单却教的是 `>`；排在代码原文
  // 之后，代码块里的 `> ` 已按原文插入，走不到这里。
  af.CharacterShortcutEvent(
    key: 'diary_greater_to_quote',
    character: ' ',
    handler: _greaterToQuote,
  ),
  ...af.standardCharacterShortcutEvents,
];

/// 文字块（引用、代码块除外）行首只有 `>` 时按空格：去掉 `>` 转为引用，
/// 对齐随块保留。与上游的列表、标题快捷输入同一个助手：只认折叠光标、光标
/// 前正好是这个符号，整次转换一个事务。引用不画子块，带缩进子块的块把子块
/// 提到引用后面（与 `# ` 一致，见 `addDiaryBlockTypeChange`）。
Future<bool> _greaterToQuote(af.EditorState state) => af.formatMarkdownSymbol(
  state,
  (node) =>
      node.delta != null &&
      node.type != kDiaryBlockQuote &&
      node.type != kDiaryBlockCode,
  (_, text, _) => text == '>',
  (_, node, delta) => [
    af.quoteNode(
      attributes: {
        kDiaryBlockDeltaKey: delta.compose(af.Delta()..delete(1)).toJson(),
        if (node.attributes[kDiaryBlockAlignKey] case final align?)
          kDiaryBlockAlignKey: align,
      },
    ),
    ...node.children,
  ],
);

/// 光标停在空提示块里回车：原地转为正文段落（保留对齐），与列表、待办
/// 在空项上回车即退出同一手感。桌面 Shift + 回车照旧交给上游（在行内
/// 换行）。整次一个事务、一步撤销。
Future<bool> _emptyCalloutEnter(af.EditorState state) async {
  if (HardwareKeyboard.instance.isShiftPressed) return false;
  final selection = state.selection;
  if (selection == null || !selection.isCollapsed) return false;
  final node = state.document.nodeAtPath(selection.end.path);
  if (node?.type != kDiaryBlockCallout || node!.delta?.isEmpty != true) {
    return false;
  }
  final transaction = state.transaction
    ..updateNodeType(node, kDiaryBlockParagraph, {
      kDiaryBlockDeltaKey: <Object?>[],
      if (node.attributes[kDiaryBlockAlignKey] case final align?)
        kDiaryBlockAlignKey: align,
    })
    ..afterSelection = af.Selection.collapsed(af.Position(path: node.path));
  await state.apply(transaction, skipHistoryDebounce: true);
  return true;
}

Future<bool> _codeFence(af.EditorState state) async {
  final selection = state.selection;
  if (selection == null || !selection.isCollapsed) return false;
  final node = state.document.nodeAtPath(selection.end.path);
  if (node?.type != 'paragraph' || node!.children.isNotEmpty) return false;
  final text = node.delta?.toPlainText() ?? '';
  if (selection.end.offset != text.length) return false;
  final match = RegExp(r'^```([\w+-]*)$').firstMatch(text);
  if (match == null) return false;
  final language = codeBlockExplicitLanguage(
    normalizeCodeLanguageTag(match.group(1)),
  );
  final transaction = state.transaction
    ..updateNodeType(node, 'code', {
      'delta': <Object?>[],
      if (language != null) 'language': language,
    })
    ..afterSelection = af.Selection.collapsed(af.Position(path: node.path));
  await state.apply(transaction, skipHistoryDebounce: true);
  return true;
}

Future<bool> _codeNewline(af.EditorState state) async {
  final selection = state.selection;
  if (selection == null || !selection.isCollapsed) return false;
  final node = state.document.nodeAtPath(selection.end.path);
  if (node?.type != 'code' || node!.delta == null) return false;
  final text = node.delta!.toPlainText();
  final offset = selection.end.offset.clamp(0, text.length);
  final lineStart = offset == 0 ? 0 : text.lastIndexOf('\n', offset - 1) + 1;
  final current = text.substring(lineStart);
  final previousStart = lineStart <= 1
      ? 0
      : text.lastIndexOf('\n', lineStart - 2) + 1;
  final previous = lineStart == 0
      ? null
      : text.substring(previousStart, lineStart - 1);
  final transaction = state.transaction;
  if (offset == text.length &&
      current.trim().isEmpty &&
      previous != null &&
      previous.trim().isEmpty) {
    final kept = text.trimRight();
    if (kept.isEmpty) {
      transaction
        ..updateNodeType(node, 'paragraph', {'delta': <Object?>[]})
        ..afterSelection = af.Selection.collapsed(af.Position(path: node.path));
    } else {
      transaction
        ..deleteText(node, kept.length, text.length - kept.length)
        ..insertNode(node.path.next, af.paragraphNode())
        ..afterSelection = af.Selection.collapsed(
          af.Position(path: node.path.next),
        );
    }
  } else {
    final lineEnd = text.indexOf('\n', offset);
    final line = text.substring(lineStart, lineEnd < 0 ? text.length : lineEnd);
    final leading = RegExp(r'^[ \t]*').stringMatch(line) ?? '';
    final indent = leading.substring(
      0,
      (offset - lineStart).clamp(0, leading.length),
    );
    transaction.insertText(node, offset, '\n$indent');
  }
  await state.apply(transaction, skipHistoryDebounce: true);
  return true;
}
