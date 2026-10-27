import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/widgets.dart';

import 'app_platform.dart';

/// 在桌面的可取消退出请求中等待本会话保存；不退出路由，也不负责写库。
///
/// Windows / Linux 的关闭按钮由 Flutter 引擎转成 didRequestAppExit；所有
/// 已注册的会话都保存成功后才放行。重复关闭共用一次保存，失败或异常时保留
/// 窗口，供原页面提示错误并重试。释放会话时注销，不拦截之后的退出。
class DesktopExitGuard with WidgetsBindingObserver {
  DesktopExitGuard({required this.onExit}) {
    if (_registered) WidgetsBinding.instance.addObserver(this);
  }

  final Future<bool> Function() onExit;
  final bool _registered = AppPlatform.isDesktop;
  Future<AppExitResponse>? _pending;
  bool _disposed = false;

  @override
  Future<AppExitResponse> didRequestAppExit() {
    if (_disposed) return Future.value(AppExitResponse.exit);
    return _pending ??= _saveBeforeExit().whenComplete(() => _pending = null);
  }

  Future<AppExitResponse> _saveBeforeExit() async {
    try {
      return await onExit() ? AppExitResponse.exit : AppExitResponse.cancel;
    } catch (error, stackTrace) {
      // 单个会话抛错也不能被框架当成默认允许退出，否则会直接丢失待存内容。
      debugPrint('Desktop exit save failed: $error\n$stackTrace');
      return AppExitResponse.cancel;
    }
  }

  void dispose() {
    _disposed = true;
    if (_registered) WidgetsBinding.instance.removeObserver(this);
  }
}
