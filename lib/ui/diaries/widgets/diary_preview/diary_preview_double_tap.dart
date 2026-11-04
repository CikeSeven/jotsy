import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../controllers/diary_editor_controller.dart';
import '../diary_editor/diary_text_hit_test.dart';

/// 预览页正文的“双击进入编辑”：双击文字时交出双击处的文字位置
/// （[onDoubleTap]），由页面打开编辑页并把光标放在那里。
///
/// 只观察指针、不加入手势竞争（[Listener]）：在正文上挂双击识别器会让链接、
/// 图片、待办这些单击都等满双击超时才生效，还会抢走上游只读正文自己的
/// 双击选词。两次点按都满足“不移动（[kTouchSlop]）、不长按
/// （[kLongPressTimeout]）”，第二次在第一次抬起后 [kDoubleTapTimeout] 内按下、
/// 离第一次不超过 [kDoubleTapSlop] 才算双击；中途有第二根手指、滚动或拖动都
/// 作废。
///
/// 位置在第二次抬起时同步算出（布局还是双击时的样子），交出则放到微任务：
/// 上游的双击选词在同一次指针分发里稍后才执行，等它选完再清掉，回到预览页
/// 时不会留着一个选中的词。第一次点按已经打开了别的页面（链接、看图）时
/// 不再进入编辑。落点不是文字（嵌入块、行首控件、空白处）时不处理，见
/// [diaryTextPositionAt]。
class DiaryPreviewDoubleTap extends StatefulWidget {
  const DiaryPreviewDoubleTap({
    super.key,
    required this.controller,
    required this.onDoubleTap,
    required this.child,
  });

  final DiaryEditorController controller;
  final ValueChanged<af.Position> onDoubleTap;
  final Widget child;

  @override
  State<DiaryPreviewDoubleTap> createState() => _DiaryPreviewDoubleTapState();
}

class _DiaryPreviewDoubleTapState extends State<DiaryPreviewDoubleTap> {
  /// 正按在正文上的手指数：多于一根（缩放等）时这一轮不算点按。
  int _pointers = 0;

  /// 当前这次按下：指针、位置与时间；移动超出 [kTouchSlop] 或多指时清空。
  int? _pointer;
  Offset? _downPosition;
  Duration? _downTime;

  /// 上一次完整的点按：抬起的位置与时间，等着凑成双击。
  Offset? _lastTapPosition;
  Duration? _lastTapUpTime;

  void _onDown(PointerDownEvent event) {
    _pointers++;
    if (_pointers > 1) {
      _cancelPending();
      _forgetLastTap();
      return;
    }
    _pointer = event.pointer;
    _downPosition = event.position;
    _downTime = event.timeStamp;
  }

  void _onMove(PointerMoveEvent event) {
    final down = _downPosition;
    if (event.pointer != _pointer || down == null) return;
    if ((event.position - down).distance > kTouchSlop) {
      _cancelPending();
      _forgetLastTap();
    }
  }

  void _onUp(PointerUpEvent event) {
    _pointers = _pointers > 0 ? _pointers - 1 : 0;
    final down = _downPosition;
    final downTime = _downTime;
    if (event.pointer != _pointer || down == null || downTime == null) {
      return;
    }
    _cancelPending();
    if (event.timeStamp - downTime > kLongPressTimeout) {
      _forgetLastTap();
      return;
    }
    final lastPosition = _lastTapPosition;
    final lastUpTime = _lastTapUpTime;
    if (lastPosition != null &&
        lastUpTime != null &&
        downTime - lastUpTime <= kDoubleTapTimeout &&
        (down - lastPosition).distance <= kDoubleTapSlop) {
      _forgetLastTap();
      _handleDoubleTap(event.position);
      return;
    }
    _lastTapPosition = event.position;
    _lastTapUpTime = event.timeStamp;
  }

  void _onCancel(PointerCancelEvent event) {
    _pointers = _pointers > 0 ? _pointers - 1 : 0;
    if (event.pointer == _pointer) {
      _cancelPending();
      _forgetLastTap();
    }
  }

  void _cancelPending() {
    _pointer = null;
    _downPosition = null;
    _downTime = null;
  }

  void _forgetLastTap() {
    _lastTapPosition = null;
    _lastTapUpTime = null;
  }

  void _handleDoubleTap(Offset global) {
    final controller = widget.controller;
    if (controller.isDisposed) return;
    final position = diaryTextPositionAt(controller.state, global);
    if (position == null) return;
    scheduleMicrotask(() {
      if (!mounted || controller.isDisposed) return;
      if (ModalRoute.of(context)?.isCurrent == false) return;
      controller.state.selection = null;
      widget.onDoubleTap(position);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: _onCancel,
      child: widget.child,
    );
  }
}
