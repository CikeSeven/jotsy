import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import '../../../widgets/soft_keyboard_selection_keys.dart';
import '../../controllers/diary_editor_controller.dart';
import 'diary_block_handle_layer.dart';
import 'diary_editor_selection_gestures.dart';
import 'diary_editor_selection_toolbar.dart';
import 'diary_editor_viewport.dart';
import 'diary_read_only_shortcuts.dart';

/// 原生正文外围的交互层：手机选区菜单、软键盘扩选兼容、编辑态段落把手与
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
    this.pinPath,
    this.contentLeft = 0,
    this.childIndent = 28,
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

  /// 让顶层块停在列表视口的给定比例处，见 [DiaryBlockHandleLayer.pinPath]。
  final void Function(af.Path path, double alignment)? pinPath;

  /// 编辑器左内边距，段落把手画在这块边距里。
  final double contentLeft;

  /// 子块相对父块的缩进（行首标记列宽），子块的把手画在这段缩进里。
  final double childIndent;
  @override
  Widget build(BuildContext context) {
    // 只读正文按内容高度嵌入整页滚动时，末行的选区把手会画在文字下方。
    // clipBehavior.none 只允许绘制溢出，不能让编辑器边界外参与命中测试；
    // 把完整触控区计入服务视口，短正文和最后一段的把手才能接到拖动。
    final handleSpace =
        textSelection &&
            (Theme.of(context).platform == TargetPlatform.android ||
                Theme.of(context).platform == TargetPlatform.iOS)
        ? kMinInteractiveDimension
        : 0.0;
    final native = shrinkWrap && controller.readOnly && handleSpace > 0
        ? DiaryEditorSelectionGestures(controller: controller, child: editor)
        : editor;
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
            ? SizedBox(height: inlineHeight + handleSpace, child: native)
            : native,
      ),
    );
    if (controller.readOnly) {
      return DiaryReadOnlyShortcuts(
        controller: controller,
        enabled: textSelection,
        focusNode: focusNode,
        child: content,
      );
    }
    final handles = DiaryBlockHandleLayer(
      controller: controller,
      focusNode: focusNode,
      contentLeft: contentLeft,
      childIndent: childIndent,
      coveredHeight: shrinkWrap ? 0 : coveredHeight,
      pinPath: pinPath,
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
