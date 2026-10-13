import 'dart:async';

import 'package:flutter/material.dart';

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

  static Future<SnackBarClosedReason> showTrackedSnackBar({
    required BuildContext context,
    required SnackBar snackBar,
    bool hideCurrent = true,
    Duration? forceCloseAfter,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return SnackBarClosedReason.remove;
    }

    final controller = maybeController(context);
    if (hideCurrent) {
      messenger.hideCurrentSnackBar();
    }

    controller?.onHintShown();
    final featureController = messenger.showSnackBar(snackBar);
    final forceCloseTimer = forceCloseAfter == null
        ? null
        : Timer(forceCloseAfter, featureController.close);
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

    final reason = await featureController.closed;
    closed = true;
    forceCloseTimer?.cancel();
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
