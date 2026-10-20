import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart' show ScrollHoldController, ScrollPosition;
import 'package:flutter_quill/flutter_quill.dart' show Block;

// 代码块标题栏上的手势：复制按钮的点按，以及（编辑器自带滚动视图时）把从
// 标题栏开始的竖向拖动转交给编辑器的滚动位置。
//
// 输入：落在标题栏上的 PointerDownEvent（由 RenderDiaryCodeBlockChrome 在
// handleEvent 里转来）、按下时所在的代码块（落在复制按钮上时）。
// 输出：点按成立时回调 [onCopy]；拖动直接驱动滚动位置。
// 副作用：持有两个手势识别器与滚动的 hold / drag，用完须 [dispose]。
//
// 为什么要转交拖动：标题栏上的指针不进入 QuillEditor（不然 Quill 会挪光标），
// 可滚动编辑器的滚动视图却在 QuillEditor 里面，同样收不到这次拖动。转交的
// 方式与 Scrollable 一致：按下先 hold 住正在进行的惯性滚动，拖动开始后交给
// ScrollPosition.drag，松手由滚动物理接手惯性，手感与在正文上拖动相同。
// 编辑器不可滚动时页面滚动视图本就在命中路径上，[scrollPosition] 返回 null，
// 不加拖动识别器，免得与页面的拖动重复。

/// 标题栏手势；由 RenderDiaryCodeBlockChrome 持有。
class DiaryCodeBlockHeaderGestures {
  DiaryCodeBlockHeaderGestures({
    required this.debugOwner,
    required this.onCopy,
    required this.scrollPosition,
  });

  final Object debugOwner;

  /// 点按复制按钮成立时调用，参数为按下时所在的代码块。
  final ValueChanged<Block> onCopy;

  /// 需要转交拖动的滚动位置；null 表示不转交。
  final ScrollPosition? Function() scrollPosition;

  TapGestureRecognizer? _tap;
  VerticalDragGestureRecognizer? _drag;
  Block? _pressedBlock;
  ScrollHoldController? _hold;
  Drag? _scrollDrag;

  /// 标题栏上按下：[copyBlock] 非 null 表示落在该块的复制按钮上。
  void addPointer(PointerDownEvent event, {Block? copyBlock}) {
    if (copyBlock != null) {
      _pressedBlock = copyBlock;
      (_tap ??= TapGestureRecognizer(
        debugOwner: debugOwner,
      )..onTap = _onTap).addPointer(event);
    }
    if (scrollPosition() != null) {
      (_drag ??= VerticalDragGestureRecognizer(debugOwner: debugOwner)
            ..onDown = _onDragDown
            ..onStart = _onDragStart
            ..onUpdate = _onDragUpdate
            ..onEnd = _onDragEnd
            ..onCancel = _onDragCancel)
          .addPointer(event);
    }
  }

  void _onTap() {
    final block = _pressedBlock;
    _pressedBlock = null;
    if (block != null) {
      onCopy(block);
    }
  }

  void _onDragDown(DragDownDetails details) {
    _hold = scrollPosition()?.hold(() => _hold = null);
  }

  void _onDragStart(DragStartDetails details) {
    _scrollDrag = scrollPosition()?.drag(details, () => _scrollDrag = null);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _scrollDrag?.update(details);
  }

  void _onDragEnd(DragEndDetails details) {
    _scrollDrag?.end(details);
  }

  void _onDragCancel() {
    cancelScroll();
  }

  /// 放开正在转交的 hold / 拖动（渲染层卸下时）。
  void cancelScroll() {
    _hold?.cancel();
    _scrollDrag?.cancel();
  }

  void dispose() {
    cancelScroll();
    _tap?.dispose();
    _drag?.dispose();
  }
}
