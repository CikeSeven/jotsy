import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/services.dart';

import '../../controllers/diary_editor_clipboard.dart';
import '../../controllers/diary_editor_controller.dart';

/// 输入法一次上屏的多行 Markdown 与粘贴同样转换。
///
/// 为什么需要：手机上光标停在文字中间时没有“粘贴”菜单（见
/// `DiaryEditorSelectionToolbar`），很多人直接在输入法的剪贴板面板里点一条
/// 粘贴。这段文字作为一次输入（折叠光标为 `TextEditingDeltaInsertion`，选中
/// 文字时为 `TextEditingDeltaReplacement`）交给上游，而上游对多于一个字符的
/// 输入不跑任何字符快捷规则，整段连同换行原样插进当前这一段：Markdown 不
/// 转换，多行也挤在同一段里。
///
/// 只接手同时满足这些条件的输入，交给 [DiaryEditorClipboard.pasteMarkdown]
/// （与菜单粘贴同一转换与插入路径，一步撤销）：
/// - 含换行且不止一个字符：单独的回车（以及上游当作回车的“空格 + 回车”）
///   仍走回车规则；打字、语音转写的一次上屏不带换行；
/// - 不在组字中：组字区间非空时是输入法还没确认的文字；
/// - 看起来是 Markdown、光标不在代码块或表格格子里（由 `pasteMarkdown`
///   判断）。代码块里的多行输入要原样留在块内。
///
/// 其余输入一律返回 false 交给上游（或排在前面的表格拦截器），行为不变。
class DiaryMarkdownInputInterceptor
    extends af.AppFlowyKeyboardServiceInterceptor {
  DiaryMarkdownInputInterceptor(this.controller);

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
    return DiaryEditorClipboard.pasteMarkdown(controller, text);
  }
}
