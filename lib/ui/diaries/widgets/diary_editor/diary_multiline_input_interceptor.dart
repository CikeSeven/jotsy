import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/services.dart';

import '../../controllers/diary_editor_clipboard.dart';
import '../../controllers/diary_editor_controller.dart';

/// 输入法一次上屏的多行文字与粘贴同样落成块：Markdown 照样转换，普通文字
/// 每行一段。
///
/// 为什么需要：手机上很多人直接在输入法的剪贴板面板里点一条粘贴。这段文字
/// 作为一次输入（折叠光标为 `TextEditingDeltaInsertion`，选中文字时为
/// `TextEditingDeltaReplacement`）交给上游，而上游对多于一个字符的输入不跑
/// 任何字符快捷规则，整段连同换行原样插进当前这一段：Markdown 不转换，几十段
/// 文字也全挤在同一个块里（换行只是块内的软换行），没法逐段改成待办、列表。
///
/// 只接手同时满足这些条件的输入，交给 [DiaryEditorClipboard.pasteInputText]
/// （与菜单粘贴同一转换与插入路径，一步撤销）：
/// - 含换行且不止一个字符：单独的回车（以及上游当作回车的“空格 + 回车”）
///   仍走回车规则；打字、语音转写的一次上屏不带换行；
/// - 不在组字中：组字区间非空时是输入法还没确认的文字；
/// - 由 `pasteInputText` 判断要不要切段：像 Markdown 的按 Markdown 转换；
///   普通文字只在换行出现在末尾之前时每行一段（只有末尾一个换行时多半是
///   输入法把确认的字和回车一起上屏）；光标在代码块里一律原样留在块内。
///
/// 其余输入一律返回 false 交给上游（或排在前面的表格、嵌入块拦截器），行为
/// 不变。
class DiaryMultilineInputInterceptor
    extends af.AppFlowyKeyboardServiceInterceptor {
  DiaryMultilineInputInterceptor(this.controller);

  final DiaryEditorController controller;

  @override
  Future<bool> interceptInsert(
    TextEditingDeltaInsertion insertion,
    af.EditorState editorState,
    List<af.CharacterShortcutEvent> characterShortcutEvents,
  ) => _paste(editorState, insertion.textInserted, insertion.composing);

  @override
  Future<bool> interceptReplace(
    TextEditingDeltaReplacement replacement,
    af.EditorState editorState,
    List<af.CharacterShortcutEvent> characterShortcutEvents,
  ) => _paste(editorState, replacement.replacementText, replacement.composing);

  Future<bool> _paste(
    af.EditorState editorState,
    String text,
    TextRange composing,
  ) async {
    if (editorState != controller.state ||
        text.length < 2 ||
        !text.contains('\n') ||
        (composing.isValid && !composing.isCollapsed) ||
        editorState.selection == null) {
      return false;
    }
    return DiaryEditorClipboard.pasteInputText(controller, text);
  }
}
