import 'package:flutter/widgets.dart';

import '../../app/theme/expressive_motion.dart';

/// 等所在路由的入场转场结束，再执行一次回调（典型用途：转场结束后才聚焦
/// 输入框弹出键盘，避免键盘动画与页面滑入叠在一起、逐帧重排）。
///
/// 输入：[schedule] 的 `state` 为宿主页面；`onEntered` 至多执行一次。
/// 副作用：在路由动画上挂状态监听，宿主销毁时必须调用 [dispose]。
///
/// 首帧之后才判断转场状态：存在 HeroController 时，新路由的第一帧以 offstage
/// 构建，期间 animation 被代理为已完成的动画，直接读取会误判“转场已完成”。
/// 减少动画、没有路由或转场已结束时，下一帧立即执行。
class RouteEntranceWaiter {
  Animation<double>? _animation;
  AnimationStatusListener? _listener;
  bool _disposed = false;

  void schedule(State state, VoidCallback onEntered) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !state.mounted) {
        return;
      }
      final context = state.context;
      final route = ModalRoute.of(context);
      final animation = route?.animation;
      if (route == null ||
          animation == null ||
          ExpressiveMotion.reduceMotion(context) ||
          (animation.isCompleted && !route.offstage)) {
        onEntered();
        return;
      }
      void listener(AnimationStatus status) {
        if (!status.isCompleted || route.offstage) {
          return;
        }
        _detach();
        if (!_disposed && state.mounted) {
          onEntered();
        }
      }

      _animation = animation;
      _listener = listener;
      animation.addStatusListener(listener);
    });
  }

  void _detach() {
    final listener = _listener;
    if (listener != null) {
      _animation?.removeStatusListener(listener);
    }
    _animation = null;
    _listener = null;
  }

  void dispose() {
    _disposed = true;
    _detach();
  }
}
