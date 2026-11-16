import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/database/mind_map/mind_map_schema.dart';
import '../../../core/services/app_platform.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../controllers/mind_map_editing_controller.dart';
import '../controllers/mind_map_viewport_controller.dart';
import '../layout/mind_map_scene.dart';

/// 节点文字的输入框：叠在节点上，跟着视口缩放，字号、颜色与对齐和节点一致，
/// 画布在这期间不画这个节点的文字。
///
/// 输入即写（经 [MindMapEditingController.setText]，同一节点连续输入合并为
/// 一步撤销）；节点随字变宽时布局直接到位（不播转场），输入框按新矩形跟上。
/// 桌面：Enter 结束编辑，Shift + Enter 换行，Tab 结束并加子主题，Esc 结束。
/// 手机：键盘上的“完成”结束编辑；换行与加主题在键盘上方的附件条里。
class MindMapNodeEditor extends StatefulWidget {
  const MindMapNodeEditor({
    super.key,
    required this.controller,
    required this.viewport,
    required this.node,
  });

  final MindMapEditingController controller;
  final MindMapViewportController viewport;
  final MindMapSceneNode node;

  @override
  State<MindMapNodeEditor> createState() => _MindMapNodeEditorState();
}

class _MindMapNodeEditorState extends State<MindMapNodeEditor> {
  late final TextEditingController _text = TextEditingController(
    text: widget.node.node.text,
  );
  late final FocusNode _focus = FocusNode(onKeyEvent: _onKey);

  @override
  void initState() {
    super.initState();
    // 桌面上选中全部文字（直接打字即替换），手机上光标放在末尾。
    _text.selection = AppPlatform.isDesktop
        ? TextSelection(baseOffset: 0, extentOffset: _text.text.length)
        : TextSelection.collapsed(offset: _text.text.length);
    _text.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _text.removeListener(_onTextChanged);
    _focus.removeListener(_onFocusChanged);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final id = widget.node.id;
    if (widget.controller.document.index[id]?.text == _text.text) return;
    widget.controller.setText(id, _text.text);
  }

  void _onFocusChanged() {
    // 焦点被别处拿走（点了工具坞、对话框）时结束编辑。
    if (!_focus.hasFocus && widget.controller.editingId == widget.node.id) {
      widget.controller.stopEditing();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final keys = HardwareKeyboard.instance;
    final key = event.logicalKey;
    if (_text.value.composing.isValid) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.escape) {
      widget.controller.stopEditing();
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
        !keys.isShiftPressed) {
      widget.controller.stopEditing();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab && !keys.isShiftPressed) {
      widget.controller.addChild(parentId: widget.node.id);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final visual = widget.node.visual;
    return ListenableBuilder(
      listenable: widget.viewport,
      builder: (BuildContext context, Widget? _) {
        final scale = widget.viewport.scale;
        final rect = widget.viewport.toScreenRect(widget.node.rect);
        // 比节点宽出一截：新打的字先在输入框里排开，节点下一帧再变宽，
        // 不会先折行再跳回来。
        final extra = 48 * scale;
        final centered = visual.textAlign == TextAlign.center;
        final style = visual.textStyle.copyWith(
          fontSize: (visual.textStyle.fontSize ?? 14) * scale,
          decoration: TextDecoration.none,
        );
        final padding = visual.padding * scale;
        return Positioned(
          left: centered ? rect.left - extra / 2 : rect.left,
          top: rect.top,
          width: rect.width + extra,
          child: Material(
            type: MaterialType.transparency,
            child: TextField(
              controller: _text,
              focusNode: _focus,
              style: style,
              textAlign: visual.textAlign,
              cursorColor: style.color,
              maxLines: null,
              maxLength: kMindMapMaxTextLength,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              keyboardType: TextInputType.multiline,
              textInputAction: AppPlatform.isDesktop
                  ? TextInputAction.newline
                  : TextInputAction.done,
              onSubmitted: (_) => widget.controller.stopEditing(),
              contextMenuBuilder: appTextContextMenuBuilder,
              // 主题里输入框的描边与底色一律去掉：画的是节点本身。
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                counterText: '',
                filled: false,
                // 输入框比节点宽 extra（居中时两侧各一半），内容区因此比
                // 节点里的文字宽出这一截余量，不会卡着边折行。
                contentPadding: padding,
              ),
            ),
          ),
        );
      },
    );
  }
}
