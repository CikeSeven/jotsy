import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import '../../../widgets/soft_keyboard_selection_keys.dart';
import '../../controllers/diary_editor_controller.dart';
import 'diary_block_handle_layer.dart';
import 'diary_editor_selection_toolbar.dart';
import 'diary_editor_viewport.dart';

/// 原生正文外围的交互层：平台选区菜单、软键盘扩选兼容、编辑态段落把手与
/// 光标避让。
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
    this.contentLeft = 0,
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

  /// 编辑器左内边距，段落把手画在这块边距里。
  final double contentLeft;
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
    if (controller.readOnly) return content;
    final handles = DiaryBlockHandleLayer(
      controller: controller,
      focusNode: focusNode,
      contentLeft: contentLeft,
      child: content,
    );
    return shrinkWrap
        ? handles
        : DiaryEditorViewport(
            controller: controller,
            focusNode: focusNode,
            coveredHeight: coveredHeight,
            revealPath: revealPath,
            child: handles,
          );
  }
}
