import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/diary_embed_editing.dart';

/// 嵌入块（图片、视频、分隔线、卡片等）旁边的退格与 Delete，规则见
/// diary_embed_editing.dart。

/// 硬键盘退格（手机上输入法在段首也按退格键发出）：在 DiaryEditor 的
/// 快捷键列表里紧排在上游 `backspaceCommand` 之前，即上游“段首转正文”与
/// 表格规则之后。
final af.CommandShortcutEvent diaryEmbedBackspaceCommand =
    af.CommandShortcutEvent(
      key: 'diary_embed_backspace',
      getDescription: () => 'backspace next to an embed',
      command: 'backspace, shift+backspace',
      handler: (state) => deleteDiaryEmbedBeforeCaret(state)
          ? KeyEventResult.handled
          : KeyEventResult.ignored,
    );

/// 桌面的 Delete：紧排在上游 `deleteCommand` 之前。
final af.CommandShortcutEvent diaryEmbedDeleteCommand = af.CommandShortcutEvent(
  key: 'diary_embed_delete',
  getDescription: () => 'delete next to an embed',
  command: 'delete, shift+delete',
  handler: (state) => deleteDiaryEmbedAfterCaret(state)
      ? KeyEventResult.handled
      : KeyEventResult.ignored,
);

/// 软键盘的删除：上游把输入法的删除直接交给它自己的“段首转正文 + 退格”，
/// 不经快捷键列表，只能从这里接手（同 DiaryTableKeyboardInterceptor，登记
/// 在它之后）。段内的字符删除（含组字中）与非折叠选区照旧交给上游；标题、
/// 列表等可转为正文的块也先交给上游转换，下一次退格才轮到这里。
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
    return deleteDiaryEmbedBeforeCaret(editorState);
  }
}
