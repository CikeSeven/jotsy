import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/database/mind_map/mind_map_rich_text.dart';
import '../../../core/database/mind_map/mind_map_schema.dart';
import '../../../core/services/app_platform.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../controllers/mind_map_editing_controller.dart';
import '../../widgets/rich_text/inline_rich_text_controller.dart';
import '../controllers/mind_map_viewport_controller.dart';
import '../layout/mind_map_scene.dart';
import '../viewmodels/mind_map_look.dart';

/// 节点文字的输入框：叠在节点上，跟着视口缩放，字号、颜色与对齐和节点一致，
/// 画布在这期间不画这个节点的文字。
///
/// 输入即写（经 [InlineRichTextController] → [MindMapEditingController.
/// setRichText]，局部样式跟着字走，同一节点连续输入合并为一步撤销）；
/// 节点随字变宽时布局直接到位（不播转场），输入框按新矩形跟上。输入框
/// 登记在 [MindMapEditingController.textSession]，格式条经它设局部样式。
/// 桌面：Enter 结束编辑，Shift + Enter 换行，Tab 结束并加子主题，Esc 结束，
/// Ctrl / ⌘ + B / I / U 粗体 / 斜体 / 下划线，Ctrl / ⌘ + Shift + S 删除线。
/// 手机：键盘上的“完成”结束编辑；格式、换行、加主题与删除在键盘上方的
/// 附件条里。
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
  late final InlineRichTextController _text = InlineRichTextController(
    runs: mindMapRunsOf(widget.node.node),
    onChanged: _onChanged,
  );
  late final FocusNode _focus = FocusNode(onKeyEvent: _onKey);

  @override
  void initState() {
    super.initState();
    // 桌面上选中全部文字（直接打字即替换），手机上光标放在末尾。
    _text.selection = AppPlatform.isDesktop
        ? TextSelection(baseOffset: 0, extentOffset: _text.text.length)
        : TextSelection.collapsed(offset: _text.text.length);
    widget.controller.textSession.attach(_text);
    // 从一个主题换到另一个（删除、加子主题 / 同级）时，旧输入框关掉输入法
    // 连接只是排一个“收起键盘”的微任务，新输入框在这一帧末接上连接后它就
    // 作废，键盘不收（测试经 testTextInput 的记录兜底）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
    _focus.addListener(_onFocusChanged);
    widget.controller.textSession.toolbarFocus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.textSession.detach(_text);
    widget.controller.textSession.toolbarFocus.removeListener(_onFocusChanged);
    _focus.removeListener(_onFocusChanged);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(
    String text,
    List<InlineTextRun> runs, {
    bool format = false,
  }) =>
      widget.controller.setRichText(widget.node.id, text, runs, format: format);

  void _onFocusChanged() {
    // 焦点被别处拿走（点了工具坞、对话框）时结束编辑；去了格式条（颜色代码
    // 输入框）不算，从那里回到别处时再结束。
    if (!_focus.hasFocus &&
        !widget.controller.textSession.keepsEditing &&
        widget.controller.editingId == widget.node.id) {
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
    if (inlineFormatShortcut(event) case final mark?) {
      _text.toggle(mark);
      return KeyEventResult.handled;
    }
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
    // 局部样式按导图配色画；整条样式的取值决定格式按钮的状态。
    final styles = MindMapLook.of(context, widget.controller.document).styles;
    _text
      ..runStyle = ((marks) => styles.runStyle(
        marks,
        base: visual.textStyle.decoration,
        ink: visual.textStyle.color,
        backdrop: visual.fill ?? styles.palette.surface,
      ))
      ..base = inlineBaseMarksOf(visual.textStyle);
    return ListenableBuilder(
      listenable: widget.viewport,
      builder: (BuildContext context, Widget? _) {
        final scale = widget.viewport.scale;
        // 输入框只盖住文字区（节点里还有待办框、贴纸等时文字不在正中）。
        final rect = widget.viewport.toScreenRect(
          widget.node.content.textRect.shift(widget.node.rect.topLeft),
        );
        // 比节点宽出一截：新打的字先在输入框里排开，节点下一帧再变宽，
        // 不会先折行再跳回来。
        final extra = 48 * scale;
        final centered = visual.textAlign == TextAlign.center;
        // 整条的下划线、删除线与高亮照画（与画布一致）；完成的待办不划掉，
        // 编辑时看得清。
        final style = visual.textStyleWithHighlight.copyWith(
          fontSize: (visual.textStyle.fontSize ?? 14) * scale,
        );
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
                // 输入框比文字区宽 extra（居中时两侧各一半），留出余量，
                // 新打的字不会卡着边折行。
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        );
      },
    );
  }
}
