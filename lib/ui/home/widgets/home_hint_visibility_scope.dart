import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/editing_session_registry.dart';

/// Home 范围内提示可见状态控制器。
///
/// 使用引用计数避免提示切换时出现错误归零。
class HomeHintVisibilityController {
  HomeHintVisibilityController();

  static const Duration _hideDebounceDuration = Duration(milliseconds: 260);

  final ValueNotifier<bool> isHintVisibleNotifier = ValueNotifier<bool>(false);

  /// 当前提示（SnackBar）实际占用的高度（含外边距），未测得时为 0。
  /// FAB 据此决定上移距离：固定 60dp 只够单行提示，双行或大字号会被遮挡。
  final ValueNotifier<double> hintExtentNotifier = ValueNotifier<double>(0);

  /// 上报测得的提示高度；提示已全部关闭时忽略迟到的测量结果。
  void reportHintExtent(double extent) {
    if (_visibleCount > 0 && extent > 0) {
      hintExtentNotifier.value = extent;
    }
  }

  Timer? _hideDebounceTimer;
  int _visibleCount = 0;

  void onHintShown() {
    _hideDebounceTimer?.cancel();
    _hideDebounceTimer = null;
    _visibleCount += 1;
    if (!isHintVisibleNotifier.value) {
      isHintVisibleNotifier.value = true;
    }
  }

  void onHintClosed() {
    if (_visibleCount > 0) {
      _visibleCount -= 1;
    }
    if (_visibleCount == 0 && isHintVisibleNotifier.value) {
      _hideDebounceTimer?.cancel();
      _hideDebounceTimer = Timer(_hideDebounceDuration, () {
        if (_visibleCount == 0 && isHintVisibleNotifier.value) {
          isHintVisibleNotifier.value = false;
          hintExtentNotifier.value = 0;
        }
      });
    }
  }

  void dispose() {
    _hideDebounceTimer?.cancel();
    isHintVisibleNotifier.dispose();
    hintExtentNotifier.dispose();
  }
}

/// 为 Home 子树提供统一的提示可见状态追踪能力。
class HomeHintVisibilityScope extends InheritedWidget {
  const HomeHintVisibilityScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final HomeHintVisibilityController controller;

  static HomeHintVisibilityController? maybeController(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<HomeHintVisibilityScope>();
    final widget = element?.widget;
    if (widget is! HomeHintVisibilityScope) {
      return null;
    }
    return widget.controller;
  }

  /// 展示提示并等到它关闭，返回关闭原因（撤销型提示据此判断是否撤销）。
  ///
  /// 提示必须会到时自动关闭：调用方 await 关闭结果来结束撤销窗口（之后才真正
  /// 回收媒体等），FAB 也要等它关闭才回落。Flutter 3.38 起带 action 的
  /// SnackBar 默认 `persist: true`（到时不关，直到点按钮），因此带按钮的提示
  /// 必须显式传 `persist: false`（下方断言与源码测试兜底）。此前靠调用方另传
  /// 强制关闭时长、在这里起计时器关闭，漏传的提示（日历删除撤销、纪念日创建）
  /// 就一直停在屏幕上；改由 SnackBar 自带的计时，它从入场动画结束才开始计。
  ///
  /// 带按钮（撤销）的提示显示期间登记一个撤销窗口
  /// （[EditingSessionRegistry.beginUndoWindow]）：撤销按删除前的整行恢复，
  /// 局域网同步要等它关闭再写库，否则撤销会盖掉同步写入。窗口随 `closed`
  /// 结束——到时、点按钮、被下一条提示替换或移除都会完成这个 future。
  static Future<SnackBarClosedReason> showTrackedSnackBar({
    required BuildContext context,
    required SnackBar snackBar,
    bool hideCurrent = true,
  }) async {
    assert(
      !snackBar.persist,
      'Tracked SnackBars must auto-dismiss: pass persist: false to a SnackBar '
      'with an action (it persists by default since Flutter 3.38).',
    );
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return SnackBarClosedReason.remove;
    }

    final controller = maybeController(context);
    if (hideCurrent) {
      messenger.hideCurrentSnackBar();
    }

    controller?.onHintShown();
    final undoWindow = snackBar.action == null
        ? null
        : EditingSessionRegistry.instance.beginUndoWindow();
    final featureController = messenger.showSnackBar(snackBar);
    var closed = false;
    if (controller != null) {
      unawaited(
        _reportSnackBarExtent(
          messengerContext: messenger.context,
          content: snackBar.content,
          controller: controller,
          isClosed: () => closed,
        ),
      );
    }

    final SnackBarClosedReason reason;
    try {
      reason = await featureController.closed;
    } finally {
      undoWindow?.end();
    }
    closed = true;
    controller?.onHintClosed();
    return reason;
  }

  /// 逐帧查找本次 SnackBar，待入场动画稳定后上报其高度。
  ///
  /// Scaffold 会用 `withAnimation` 生成新的 SnackBar 实例，但 content 引用不变，
  /// 因此按 content 匹配。若前一条提示仍在退场，新提示会晚几帧才进入树，
  /// 故最多重试 [_maxMeasureFrames] 帧；提示已关闭或页面销毁时停止。
  static const int _maxMeasureFrames = 40;

  static Future<void> _reportSnackBarExtent({
    required BuildContext messengerContext,
    required Widget content,
    required HomeHintVisibilityController controller,
    required bool Function() isClosed,
  }) async {
    double? previous;
    for (var frame = 0; frame < _maxMeasureFrames; frame++) {
      await WidgetsBinding.instance.endOfFrame;
      if (isClosed() || !messengerContext.mounted) {
        return;
      }
      // 入场动画期间高度从 0 逐帧增长，连续两帧一致且非 0 才视为最终高度。
      final extent = _measureSnackBar(messengerContext, content);
      if (extent != null && extent > 0 && extent == previous) {
        controller.reportHintExtent(extent);
        return;
      }
      previous = extent;
    }
    if (previous != null && previous > 0) {
      controller.reportHintExtent(previous);
    }
  }

  static double? _measureSnackBar(BuildContext root, Widget content) {
    double? extent;
    void visit(Element element) {
      if (extent != null) {
        return;
      }
      final widget = element.widget;
      if (widget is SnackBar && identical(widget.content, content)) {
        final box = element.renderObject;
        if (box is RenderBox && box.hasSize) {
          extent = box.size.height;
        }
        return;
      }
      element.visitChildren(visit);
    }

    root.visitChildElements(visit);
    return extent;
  }

  @override
  bool updateShouldNotify(HomeHintVisibilityScope oldWidget) {
    return oldWidget.controller != controller;
  }
}
