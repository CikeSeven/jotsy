import 'dart:async';

import 'package:flutter/material.dart';

/// Home 范围内提示可见状态控制器。
///
/// 使用引用计数避免提示切换时出现错误归零。
class HomeHintVisibilityController {
  HomeHintVisibilityController();

  final ValueNotifier<bool> isHintVisibleNotifier = ValueNotifier<bool>(false);
  int _visibleCount = 0;

  void onHintShown() {
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
      isHintVisibleNotifier.value = false;
    }
  }

  void dispose() {
    isHintVisibleNotifier.dispose();
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
    final element =
        context.getElementForInheritedWidgetOfExactType<HomeHintVisibilityScope>();
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
    final forceCloseTimer =
        forceCloseAfter == null
            ? null
            : Timer(forceCloseAfter, featureController.close);

    final reason = await featureController.closed;
    forceCloseTimer?.cancel();
    controller?.onHintClosed();
    return reason;
  }

  @override
  bool updateShouldNotify(HomeHintVisibilityScope oldWidget) {
    return oldWidget.controller != controller;
  }
}
