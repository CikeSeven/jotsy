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
/// 2. 收起软键盘后，点回原来的插入点时重新弹出键盘。上游 AppFlowy 只在
///    “编辑值变了”时让输入法 show：点按后它照常把选区再设一遍，但
///    `NonDeltaTextInputService.attach` 发现文字与选区都和上次相同就直接
///    返回。用户用系统返回手势或输入法自带的按钮收起键盘时，正文的焦点与
///    输入连接都还在，点回光标所在的位置得到同一个折叠选区，于是键盘不再
///    弹出，只有点到别处（选区变了）才行。普通输入框点按时总会 show，这里
///    补上同样的行为。键盘正显示时不动它：重新连接会让输入法重置当前面板
///    （符号页回到字母页等）。只在手机上生效；桌面没有软键盘，上游桌面
///    选区服务每次点按本就先断开再连接。
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
    _tapDeadline = Timer(kLongPressTimeout, _reset);
  }

  void _onMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    if ((event.position - _downPosition).distance > kTouchSlop) _reset();
  }

  void _onUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    final before = _downSelection;
    final position = event.position;
    _reset();
    scheduleMicrotask(() => _afterTap(before, position));
  }

  void _afterTap(af.Selection? before, Offset position) {
    if (!mounted || !_active) return;
    if (_appendLineBelow(position)) return;
    if (before == null || !before.isCollapsed || !AppPlatform.isMobile) return;
    _reopenIfUnchanged(before);
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
  }

  /// 情形 2。
  void _reopenIfUnchanged(af.Selection before) {
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
