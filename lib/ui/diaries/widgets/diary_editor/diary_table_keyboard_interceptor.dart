import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/services.dart';

import '../../controllers/diary_table_selection.dart';
import 'diary_table_shortcuts.dart';

/// 软键盘（输入法）在表格里的退格与覆盖选区的输入。上游把输入法的删除
/// 直接交给它自己的退格命令、不经快捷键列表，只能从这里接手：
/// - 删除：折叠光标在格内段落开头 → 同硬键盘退格；非折叠选区触及表格 →
///   按本应用的规则删除。段内的字符删除（含组字中）照旧交给上游；
/// - 插入 / 替换：选区跨段且触及表格时先按本应用的规则删掉选区，再在光标
///   处插入文字（上游会用它自己的 `deleteSelection`，从表格外选进来会把
///   整个表格删掉）。单段内的输入照旧交给上游。
class DiaryTableKeyboardInterceptor
    extends af.AppFlowyKeyboardServiceInterceptor {
  @override
  Future<bool> interceptDelete(
    TextEditingDeltaDeletion deletion,
    af.EditorState editorState,
  ) async {
    final selection = editorState.selection;
    if (selection == null) return false;
    if (selection.isSingle) {
      final node = editorState.getNodeAtPath(selection.start.path);
      if (node?.delta != null &&
          (deletion.composing.isValid || !deletion.deletedRange.isCollapsed)) {
        return false;
      }
    }
    if (!selection.isCollapsed) {
      if (!diarySelectionTouchesTable(editorState, selection)) return false;
      return deleteDiaryTableSelection(editorState, selection);
    }
    if (selection.end.offset != 0) return false;
    final found = diaryTableCaretParagraph(editorState);
    if (found == null) return false;
    mergeDiaryCellParagraphBackward(editorState, found.node);
    return true;
  }

  @override
  Future<bool> interceptInsert(
    TextEditingDeltaInsertion insertion,
    af.EditorState editorState,
    List<af.CharacterShortcutEvent> characterShortcutEvents,
  ) => _replaceSelection(editorState, insertion.textInserted);

  @override
  Future<bool> interceptReplace(
    TextEditingDeltaReplacement replacement,
    af.EditorState editorState,
    List<af.CharacterShortcutEvent> characterShortcutEvents,
  ) => _replaceSelection(editorState, replacement.replacementText);

  Future<bool> _replaceSelection(af.EditorState state, String text) async {
    final selection = state.selection;
    if (selection == null ||
        selection.isSingle ||
        !diarySelectionTouchesTable(state, selection)) {
      return false;
    }
    if (!await deleteDiaryTableSelection(state, selection)) return false;
    if (!state.isDisposed && text.isNotEmpty) {
      await state.insertTextAtCurrentSelection(text);
    }
    return true;
  }
}
