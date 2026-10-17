import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:node_diary/ui/diaries/widgets/diary_toolbar_panel_reserve.dart';

/// 编辑页正文的光标跟随：打字、用键盘移动或扩展选区、软键盘弹起之后，把
/// 光标保持在底部浮层（悬浮工具栏、「更多」面板、元数据面板）上方。
///
/// 为什么不用 Quill 自带的：正文以 `scrollable: false` 嵌在页面的滚动容器里
/// （标题与正文一起滚动），Quill 的光标揭示只滚动交给它的 scrollController，
/// 而那个控制器不挂在任何视口上，于是在底部打字时新内容落到键盘与工具栏
/// 下面。这里改在页面视口里揭示（[revealDiaryCaretAbove]），并把浮层高度算进去。
///
/// - 触发：正文选区变化且正文有焦点；软键盘高度变化并停稳后。只改格式、勾选
///   待办这类选区不动的变化不滚动，免得把用户正在看的位置拽回光标处。
/// - 揭示哪一端：折叠的光标揭示光标；选区只有一端在动（键盘“选择”模式、拖动
///   手柄）时揭示在动的那端；两端同时变（全选、双击选词）不滚动。
/// - 时机：同一帧内的多次变化合并为一次，放到帧末执行，此时新的一行已布局、
///   滚动范围已更新。
/// - 副作用：只滚动外层视口，不改选区与文档；正文失焦（录音面板、元数据面板
///   展开）或控制器已销毁时什么也不做。
class DiaryCaretFollowController {
  DiaryCaretFollowController({
    required this.editorKey,
    required this.focusNode,
    required this.coveredHeight,
    required this.revealDuration,
  });

  final GlobalKey<quill.EditorState> editorKey;
  final FocusNode focusNode;

  /// 视口底部当前被浮层盖住的高度，与正文滚动容器的底部占位同源。
  final double Function() coveredHeight;

  /// 揭示滚动的时长（经 ExpressiveMotion 解析，减少动画时为 0）。
  final Duration Function() revealDuration;

  /// 软键盘高度逐帧变化、还可能回弹，停稳后再揭示一次（与 Quill 自身对键盘
  /// 高度的去抖一致）。这是去抖计时，不是动画时长。
  static const Duration _keyboardSettleDelay = Duration(milliseconds: 100);

  quill.QuillController? _controller;
  TextSelection? _lastSelection;
  TextPosition? _pendingTarget;
  bool _revealScheduled = false;
  Timer? _keyboardSettleTimer;
  double? _lastKeyboardInset;
  bool _disposed = false;

  /// 绑定（或换绑）正文控制器：编辑模式回填详情、新建模式恢复草稿时页面会
  /// 换一个新实例。旧实例此时可能已销毁，QuillController 允许销毁后移除监听。
  void attach(quill.QuillController controller) {
    if (identical(_controller, controller)) {
      return;
    }
    _controller?.removeListener(_handleContentChanged);
    _controller = controller..addListener(_handleContentChanged);
    _lastSelection = controller.selection;
  }

  void _handleContentChanged() {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final selection = controller.selection;
    final previous = _lastSelection;
    _lastSelection = selection;
    if (selection == previous || !selection.isValid || !focusNode.hasFocus) {
      return;
    }
    final target = _revealTarget(previous, selection);
    if (target != null) {
      _scheduleReveal(target);
    }
  }

  static TextPosition? _revealTarget(
    TextSelection? previous,
    TextSelection selection,
  ) {
    if (selection.isCollapsed) {
      return selection.extent;
    }
    final baseMoved = previous?.baseOffset != selection.baseOffset;
    final extentMoved = previous?.extentOffset != selection.extentOffset;
    if (extentMoved && !baseMoved) {
      return selection.extent;
    }
    if (baseMoved && !extentMoved) {
      return selection.base;
    }
    return null;
  }

  /// 页面 didChangeMetrics 时传入当前软键盘高度。弹起或改变高度后停稳再揭示
  /// 光标；收起键盘不滚动。
  void handleKeyboardInset(double inset) {
    if (inset == _lastKeyboardInset) {
      return;
    }
    _lastKeyboardInset = inset;
    _keyboardSettleTimer?.cancel();
    if (inset <= 0) {
      return;
    }
    _keyboardSettleTimer = Timer(_keyboardSettleDelay, () {
      final selection = _controller?.selection;
      if (_disposed ||
          selection == null ||
          !selection.isValid ||
          !focusNode.hasFocus) {
        return;
      }
      _scheduleReveal(selection.extent);
    });
  }

  void _scheduleReveal(TextPosition target) {
    _pendingTarget = target;
    if (_revealScheduled) {
      return;
    }
    _revealScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => _revealPending())
      // 键盘停稳的计时器触发时可能没有待绘制的帧，主动排一帧让回调执行。
      ..ensureVisualUpdate();
  }

  void _revealPending() {
    _revealScheduled = false;
    final target = _pendingTarget;
    _pendingTarget = null;
    if (_disposed || target == null || !focusNode.hasFocus) {
      return;
    }
    revealDiaryCaretAbove(
      editorKey,
      position: target,
      coveredHeight: coveredHeight(),
      duration: revealDuration(),
    );
  }

  void dispose() {
    _disposed = true;
    _keyboardSettleTimer?.cancel();
    _controller?.removeListener(_handleContentChanged);
    _controller = null;
  }
}
