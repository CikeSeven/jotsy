import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/services/app_platform.dart';
import '../../controllers/diary_editor_controller.dart';

/// 收起软键盘后，点回原来的插入点时重新弹出键盘。
///
/// 上游 AppFlowy 只在“编辑值变了”时让输入法 show：点按后它照常把选区再设
/// 一遍，但 `NonDeltaTextInputService.attach` 发现文字与选区都和上次相同就
/// 直接返回。用户用系统返回手势或输入法自带的按钮收起键盘时，正文的焦点与
/// 输入连接都还在，点回光标所在的位置得到同一个折叠选区，于是键盘不再弹出，
/// 只有点到别处（选区变了）才行。普通输入框点按时总会 show，这里补上同样的
/// 行为。
///
/// 只观察指针（[Listener] 不参与手势竞技场，上游的点按、长按选字、拖动把手
/// 与外层滚动都不受影响）：一次点按（未越过触摸容差、未到长按时长、期间
/// 没有第二根手指）抬起后，等这一轮指针分发结束——上游在竞技场清场时才处理
/// 点按——再看：正文仍持有焦点、选区还是按下时那个折叠插入点、落在文字块里、
/// 键盘是收起的，就断开并重新连接输入法，新连接会 setEditingState + show。
///
/// 键盘正显示时不动它：重新连接会让输入法重置当前面板（符号页回到字母页
/// 等）。只在手机上生效；桌面没有软键盘，上游桌面选区服务每次点按本就先
/// 断开再连接。只读正文没有插入点，同样跳过。
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

  /// 按住到长按时长即不再算点按；用计时器而非事件时间戳，测试的假时钟
  /// 与真机一致。抬起、取消、第二根手指按下与销毁时都取消。
  Timer? _tapDeadline;

  bool get _active =>
      AppPlatform.isMobile &&
      !widget.controller.isDisposed &&
      !widget.controller.readOnly;

  void _onDown(PointerDownEvent event) {
    if (_pointer != null) {
      // 双指（缩放、两指滚动）不是点按，整次手势都不算。
      _reset();
      return;
    }
    if (!_active) return;
    _pointer = event.pointer;
    _downPosition = event.position;
    _downSelection = widget.controller.state.selection;
    _tapDeadline = Timer(kLongPressTimeout, _reset);
  }

  void _onMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    if ((event.position - _downPosition).distance > kTouchSlop) _reset();
  }

  void _onUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    final before = _downSelection;
    _reset();
    if (before == null || !before.isCollapsed) return;
    scheduleMicrotask(() => _reopenIfUnchanged(before));
  }

  void _onCancel(PointerCancelEvent event) {
    if (event.pointer == _pointer) _reset();
  }

  void _reset() {
    _tapDeadline?.cancel();
    _tapDeadline = null;
    _pointer = null;
    _downSelection = null;
  }

  void _reopenIfUnchanged(af.Selection before) {
    if (!mounted || !_active) return;
    final state = widget.controller.state;
    final selection = state.selection;
    // 选区变了时上游已按新编辑值 show 过。
    if (selection == null || selection != before) return;
    // 图片、分隔线等非文字块上游本就不连接输入法。
    if (state.document.nodeAtPath(selection.end.path)?.delta == null) return;
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
