import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/services/app_platform.dart';
import '../../controllers/diary_editor_controller.dart';
import '../../controllers/diary_embed_editing.dart';
import 'diary_editor_trailing_region.dart';

/// 点按正文之后，让插入点与键盘出现在该出现的地方。两种情形：
///
/// 1. 点正文最后一块下方的空白处，而最后显示的块不能打字（图片、视频、
///    音频、附件、分隔线、日记链接卡片、表格）：在末尾补一个空段落、插入点
///    放进去，键盘随之弹出（[appendDiaryTrailingLine]）。嵌入块没有文字
///    位置，上游点到它下方时只把光标“盖”在它上面、不连接输入法；图片、
///    音频与附件外面还有 DiaryPlaybackInteractionGuard（点按期间不让正文
///    拿焦点，点图片看大图、播放录音时不弹键盘）。文末是这类块时就没有
///    地方能放出插入点：键盘不出来，既删不掉它也接不着往下写。不改那层
///    防护（点块本身仍不弹键盘），只给块下方的空白一个可写的去处；不点就
///    不改正文。手机与桌面都生效（桌面同样没有插入点可写）。
///
/// 2. 收起软键盘后，点回正文时重新弹出键盘。上游 AppFlowy 只在“编辑值
///    变了”时让输入法 show：编辑值是插入点所在段落的文字加偏移，
///    `NonDeltaTextInputService.attach` 发现它和上次相同就直接返回。用户用
///    系统返回手势或输入法自带的按钮收起键盘时，正文的焦点与输入连接都
///    还在，于是点回原来的插入点、或点到另一处编辑值相同的位置（最常见的
///    是从一个空行点到另一个空行：都是空文字、偏移 0）时键盘不再弹出。
///    普通输入框点按时总会 show，这里补上同样的行为：点按前后编辑值相同
///    就断开重连。编辑值变了的点按上游已按新值 show 过，不动它。键盘正
///    显示时也不动它：重新连接会让输入法重置当前面板（符号页回到字母页
///    等）。只在手机上生效；桌面没有软键盘，上游桌面选区服务每次点按本就
///    先断开再连接。
///
/// 只观察指针（[Listener] 不参与手势竞技场，上游的点按、长按选字、拖动把手
/// 与外层滚动都不受影响）：一次点按（未越过触摸容差、未到长按时长、期间
/// 没有第二根手指）抬起后，等这一轮指针分发结束——上游在竞技场清场时才处理
/// 点按——再按上面的顺序检查。只读正文没有插入点，整个跳过。
class DiaryEditorKeyboardReopen extends StatefulWidget {
  const DiaryEditorKeyboardReopen({
    super.key,
    required this.controller,
    required this.child,
  });

  final DiaryEditorController controller;
  final Widget child;

  @override
  State<DiaryEditorKeyboardReopen> createState() =>
      _DiaryEditorKeyboardReopenState();
}

class _DiaryEditorKeyboardReopenState extends State<DiaryEditorKeyboardReopen> {
  int? _pointer;
  Offset _downPosition = Offset.zero;
  af.Selection? _downSelection;

  /// 按下时插入点的编辑值（见 [_editValueOf]），与点按后的比较。
  (String, int)? _downValue;

  /// 按住到长按时长即不再算点按；用计时器而非事件时间戳，测试的假时钟
  /// 与真机一致。抬起、取消、第二根手指按下与销毁时都取消。
  Timer? _tapDeadline;

  bool get _active =>
      !widget.controller.isDisposed && !widget.controller.readOnly;

  void _onDown(PointerDownEvent event) {
    if (_pointer != null) {
      // 双指（缩放、两指滚动）不是点按，整次手势都不算。
      _reset();
      return;
    }
    // 桌面右键是打开菜单，不是点按（触摸与手写笔按下时同为主键）。
    if (!_active || event.buttons & kPrimaryButton == 0) return;
    _pointer = event.pointer;
    _downPosition = event.position;
    _downSelection = widget.controller.state.selection;
    _downValue = _editValueOf(_downSelection);
    _tapDeadline = Timer(kLongPressTimeout, _reset);
  }

  void _onMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    if ((event.position - _downPosition).distance > kTouchSlop) _reset();
  }

  void _onUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    final before = _downSelection;
    final beforeValue = _downValue;
    final position = event.position;
    _reset();
    scheduleMicrotask(() => _afterTap(before, beforeValue, position));
  }

  void _afterTap(
    af.Selection? before,
    (String, int)? beforeValue,
    Offset position,
  ) {
    if (!mounted || !_active) return;
    if (_appendLineBelow(position)) return;
    if (before == null || !before.isCollapsed || !AppPlatform.isMobile) return;
    _reopenIfUnchanged(beforeValue);
  }

  /// 折叠插入点交给输入法的编辑值：所在段落的文字与偏移（与上游
  /// `_getCurrentTextEditingValue` 对折叠选区的取法相同）。不是折叠选区或
  /// 不在文字块里时为 null。
  (String, int)? _editValueOf(af.Selection? selection) {
    if (selection == null || !selection.isCollapsed) return null;
    final delta = widget.controller.state.document
        .nodeAtPath(selection.end.path)
        ?.delta;
    if (delta == null) return null;
    return (delta.toPlainText(), selection.end.offset);
  }

  /// 情形 1：点按落在最后一个顶层块下方、需要补行时补上并弹出键盘。
  bool _appendLineBelow(Offset position) {
    final state = widget.controller.state;
    final blocks = state.document.root.children;
    if (blocks.isEmpty) return false;
    // 最后一块没有排版（滚出了虚拟列表）时点不到它下方，也量不出位置。
    final box = blocks.last.renderBox;
    if (box == null || !box.attached || !box.hasSize) return false;
    final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    if (position.dy <= bottom) return false;
    // 页尾里不属于正文的内容（阅读式编辑页的留言区等）不算正文下方的空白。
    if (DiaryEditorTrailingRegion.isHit(context, position)) return false;
    final keyboardShown = View.of(context).viewInsets.bottom > 0;
    final selection = appendDiaryTrailingLine(state);
    if (selection == null) return false;
    // 新空行的编辑值（空文字、偏移 0）可能与输入法上次拿到的相同，上游
    // 连接时会直接返回、不弹键盘：键盘收着时同情形 2 断开重连。
    if (AppPlatform.isMobile && !keyboardShown) {
      state.service.keyboardService
        ?..closeKeyboard()
        ..enableKeyBoard(selection);
    }
    return true;
  }

  void _onCancel(PointerCancelEvent event) {
    if (event.pointer == _pointer) _reset();
  }

  void _reset() {
    _tapDeadline?.cancel();
    _tapDeadline = null;
    _pointer = null;
    _downSelection = null;
    _downValue = null;
  }

  /// 情形 2。
  void _reopenIfUnchanged((String, int)? beforeValue) {
    final state = widget.controller.state;
    final selection = state.selection;
    // 图片、分隔线等非文字块上游本就不连接输入法（编辑值为 null）；编辑值
    // 变了时上游已按新值 show 过。
    final value = _editValueOf(selection);
    if (selection == null || value == null || value != beforeValue) return;
    if (View.of(context).viewInsets.bottom > 0) return;
    final focusedEditor = primaryFocus?.context
        ?.findAncestorWidgetOfExactType<af.AppFlowyEditor>();
    if (focusedEditor?.editorState != state) return;
    final keyboard = state.service.keyboardService;
    if (keyboard == null) return;
    // 断开后同步重连：Flutter 的隐藏在微任务里检查到已有新连接，不会先
    // 收起再弹出。
    keyboard
      ..closeKeyboard()
      ..enableKeyBoard(selection);
  }

  @override
  void dispose() {
    _reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _onDown,
    onPointerMove: _onMove,
    onPointerUp: _onUp,
    onPointerCancel: _onCancel,
    child: widget.child,
  );
}
