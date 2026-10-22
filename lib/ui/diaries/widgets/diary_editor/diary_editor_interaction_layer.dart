import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import '../../../widgets/soft_keyboard_selection_keys.dart';
import '../../controllers/diary_editor_controller.dart';
import 'diary_editor_selection_toolbar.dart';
import 'diary_editor_viewport.dart';

/// 原生正文外围的交互层：平台选区菜单、软键盘扩选兼容与编辑态光标避让。
/// 与块注册/主题解析分开，键盘约束变化时只更新这一层。
class DiaryEditorInteractionLayer extends StatelessWidget {
  const DiaryEditorInteractionLayer({
    super.key,
    required this.controller,
    required this.editor,
    required this.shrinkWrap,
    required this.textSelection,
    required this.inlineHeight,
    required this.coveredHeight,
    required this.revealPath,
    this.focusNode,
  });
  final DiaryEditorController controller;
  final af.AppFlowyEditor editor;
  final bool shrinkWrap;
  final bool textSelection;
  final double inlineHeight;
  final double coveredHeight;
  final FocusNode? focusNode;
  final void Function(af.Path) revealPath;
  @override
  Widget build(BuildContext context) {
    final content = SoftKeyboardSelectionKeys(
      onExtendSelection: (key) {
        final focusContext = primaryFocus?.context;
        final focusedEditor = focusContext
            ?.findAncestorWidgetOfExactType<af.AppFlowyEditor>();
        if (focusedEditor?.editorState != controller.state ||
            controller.state.selection == null) {
          return false;
        }
        final command = key == LogicalKeyboardKey.arrowLeft
            ? af.moveCursorLeftSelectCommand
            : key == LogicalKeyboardKey.arrowRight
            ? af.moveCursorRightSelectCommand
            : key == LogicalKeyboardKey.arrowUp
            ? af.moveCursorUpSelectCommand
            : key == LogicalKeyboardKey.arrowDown
            ? af.moveCursorDownSelectCommand
            : key == LogicalKeyboardKey.home
            ? af.moveCursorBeginSelectCommand
            : key == LogicalKeyboardKey.end
            ? af.moveCursorEndSelectCommand
            : null;
        return command?.handler(controller.state) == KeyEventResult.handled;
      },
      child: DiaryEditorSelectionToolbar(
        controller: controller,
        enabled: textSelection,
        child: shrinkWrap
            ? SizedBox(height: inlineHeight, child: editor)
            : editor,
      ),
    );
    return !shrinkWrap && !controller.readOnly
        ? DiaryEditorViewport(
            controller: controller,
            focusNode: focusNode,
            coveredHeight: coveredHeight,
            revealPath: revealPath,
            child: content,
          )
        : content;
  }
}
