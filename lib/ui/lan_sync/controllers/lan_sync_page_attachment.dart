// 同步页与设备详情页共用的可见性跟踪：决定何时 `attachPage` / `detachPage`。
//
// 页面“可见”要同时满足两件事：应用在前台（生命周期不是 paused / hidden /
// detached），且所在路由没有被别的不透明页面盖住（TickerMode 开着——
// Overlay 会给被盖住的路由关掉 TickerMode）。任一变化都重新判断，变化时才
// 调用 attach / detach，保证成对、不重复；页面销毁时若仍处于 attach 状态则
// 补一次 detach。控制器按引用计数处理，同时打开的同步页与设备详情页各计
// 一次（详情页盖在同步页上时同步页 detach、详情页 attach，计数仍为 1）。

import 'package:flutter/widgets.dart';

import '../models/lan_sync_ui_controller.dart';

/// 见文件头注释。宿主须同时混入 [WidgetsBindingObserver]。
mixin LanSyncPageAttachment<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  /// 要通知的同步控制器。
  LanSyncUiController get lanSyncController;

  bool _foreground = true;
  bool _routeVisible = true;
  bool _attached = false;

  /// 页面现在是否看得见（前台且路由没被盖住）。
  bool get lanSyncPageVisible => _foreground && _routeVisible;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = _isForeground(WidgetsBinding.instance.lifecycleState);
  }

  /// 生命周期未知（测试、首帧前）时按在前台处理；inactive（桌面窗口失焦、
  /// 来电浮层）页面仍看得见，也算前台。
  static bool _isForeground(AppLifecycleState? state) {
    return switch (state) {
      null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
      _ => false,
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeVisible = TickerMode.valuesOf(context).enabled;
    _syncAttachment();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = _isForeground(state);
    if (foreground == _foreground) return;
    setState(() => _foreground = foreground);
    _syncAttachment();
  }

  void _syncAttachment() {
    final visible = lanSyncPageVisible;
    if (visible == _attached) return;
    _attached = visible;
    if (_attached) {
      lanSyncController.attachPage();
    } else {
      lanSyncController.detachPage();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_attached) lanSyncController.detachPage();
    super.dispose();
  }
}
