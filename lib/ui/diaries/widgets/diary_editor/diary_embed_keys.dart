import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/diary_embed_editing.dart';

/// 嵌入块（图片、视频、分隔线、卡片等）旁边的退格与 Delete：先选中、再按
/// 一次删除，规则见 diary_embed_editing.dart。

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

/// 软键盘的删除：上游把输入法的删除直接交给它自己的“段首转正文 + 退格”，
/// 不经快捷键列表，只能从这里接手（同 DiaryTableKeyboardInterceptor，登记
/// 在它之后）。手机上段首退格走的就是这里：上游在输入法的编辑值前垫了一个
/// 空格占位，段首退格删掉的是这个占位，不会发出退格键。段内的字符删除（含
/// 组字中）与非折叠选区照旧交给上游；标题、列表等可转为正文的块也先交给
/// 上游转换，下一次退格才轮到这里。
///
/// 拦截后上游会把输入法退回按键前的编辑值（它以为这次删除没生效）。只选中
/// 时插入点没动，退回的值正好对得上；删掉空行后插入点落到下一行（路径可能
/// 不变、文字却换了），所以每次都等那次退回之后再按当前选区重新同步一次
/// 输入法，免得下一次输入按旧行的文字计算。编辑值相同时上游不会再发给
/// 输入法。
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
    // 退回发生在本次拦截返回后的微任务里，计时器排在它之后。
    Timer.run(() {
      final current = editorState.selection;
      if (!editorState.isDisposed && current != null) {
        editorState.service.keyboardService?.enableKeyBoard(current);
      }
    });
    return true;
  }
}
