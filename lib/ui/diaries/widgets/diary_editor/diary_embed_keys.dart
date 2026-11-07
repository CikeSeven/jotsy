import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/diary_embed_editing.dart';
import 'diary_embed_caret_input.dart';

/// 嵌入块（图片、视频、分隔线、卡片等）旁边与块上的退格、Delete、回车与
/// 打字，规则见 diary_embed_editing.dart。

/// 硬键盘退格（手机上输入法在段首也按退格键发出）：在 DiaryEditor 的
/// 快捷键列表里紧排在上游 `backspaceCommand` 之前，即上游“段首转正文”与
/// 表格规则之后。
final af.CommandShortcutEvent diaryEmbedBackspaceCommand =
    af.CommandShortcutEvent(
      key: 'diary_embed_backspace',
      getDescription: () => 'backspace next to an embed',
      command: 'backspace, shift+backspace',
      handler: (state) => backspaceDiaryEmbed(state)
          ? KeyEventResult.handled
          : KeyEventResult.ignored,
    );

/// 桌面的 Delete：紧排在上游 `deleteCommand` 之前。
final af.CommandShortcutEvent diaryEmbedDeleteCommand = af.CommandShortcutEvent(
  key: 'diary_embed_delete',
  getDescription: () => 'delete next to an embed',
  command: 'delete, shift+delete',
  handler: (state) => deleteForwardDiaryEmbed(state)
      ? KeyEventResult.handled
      : KeyEventResult.ignored,
);

/// 软键盘（与桌面的文字输入）经输入法发来的编辑：上游把它们直接交给自己的
/// 插入 / 删除 / 替换，不经快捷键列表，只能从这里接手（同
/// DiaryTableKeyboardInterceptor，登记在它之后、Markdown 拦截器之前）。
///
/// - 删除：手机上段首退格与块上的退格走的就是这里——上游在输入法的编辑值
///   前垫了一个空格占位，退格删掉的是这个占位，不会发出退格键。段内的字符
///   删除（含组字中）与非折叠选区照旧交给上游；标题、列表等可转为正文的块
///   也先交给上游转换，下一次退格才轮到这里。
/// - 插入 / 替换（打字、组字、粘贴的文字）：插入点停在嵌入块上时先在那一侧
///   补一行、插入点挪进去，再放行，由上游照常写进这一行
///   （`openDiaryLineAtEmbedCaret`）；换行则只补行（同回车规则）。
/// - 选区变化（输入法里拖动光标等）：插入点停在嵌入块上时不交给上游——上游
///   会按输入法的偏移把插入点挪到块的另一侧。
///
/// 拦截后上游会把输入法退回这次编辑之前的值（它以为这次没生效）；插入点
/// 换了地方（删掉空行、删掉块、挪到块上），所以每次都等那次退回之后再按
/// 当前选区重新同步一次输入法（DiaryEmbedCaretInput.sync），免得下一次输入
/// 按旧行的文字计算。编辑值相同时不会再发给输入法。
class DiaryEmbedKeyboardInterceptor
    extends af.AppFlowyKeyboardServiceInterceptor {
  @override
  Future<bool> interceptDelete(
    TextEditingDeltaDeletion deletion,
    af.EditorState editorState,
  ) async {
    final selection = editorState.selection;
    if (selection == null || !selection.isCollapsed) return false;
    if (deletion.composing.isValid || !deletion.deletedRange.isCollapsed) {
      return false;
    }
    final node = editorState.getNodeAtPath(selection.end.path);
    if (node == null || af.convertibleBlockTypes.contains(node.type)) {
      return false;
    }
    if (!backspaceDiaryEmbed(editorState)) return false;
    _resync(editorState);
    return true;
  }

  @override
  Future<bool> interceptInsert(
    TextEditingDeltaInsertion insertion,
    af.EditorState editorState,
    List<af.CharacterShortcutEvent> characterShortcutEvents,
  ) async {
    if (diaryEmbedAtCaret(editorState) == null) return false;
    if (insertion.textInserted == '\n') {
      insertDiaryLineAtEmbed(editorState);
      _resync(editorState);
      return true;
    }
    // 补好行后放行：上游把这次输入写进新的一行。
    openDiaryLineAtEmbedCaret(editorState);
    return false;
  }

  @override
  Future<bool> interceptReplace(
    TextEditingDeltaReplacement replacement,
    af.EditorState editorState,
    List<af.CharacterShortcutEvent> characterShortcutEvents,
  ) async {
    openDiaryLineAtEmbedCaret(editorState);
    return false;
  }

  @override
  Future<bool> interceptNonTextUpdate(
    TextEditingDeltaNonTextUpdate nonTextUpdate,
    af.EditorState editorState,
    List<af.CharacterShortcutEvent> characterShortcutEvents,
  ) async => diaryEmbedAtCaret(editorState) != null;

  @override
  Future<bool> interceptPerformAction(
    TextInputAction action,
    af.EditorState editorState,
  ) async {
    if (action != TextInputAction.newline ||
        !insertDiaryLineAtEmbed(editorState)) {
      return false;
    }
    _resync(editorState);
    return true;
  }

  /// 上游的退回发生在本次拦截返回后的微任务里，计时器排在它之后。
  static void _resync(af.EditorState editorState) {
    Timer.run(() => DiaryEmbedCaretInput.sync(editorState));
  }
}
