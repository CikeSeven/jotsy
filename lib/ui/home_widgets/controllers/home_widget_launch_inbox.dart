// 接住点桌面小组件带来的链接（由 `NodeDiaryApp` 常驻监听）：冷启动时的
// 那一个与应用已在运行时的后续点按，解析后交给
// [homeWidgetLaunchRequestProvider]，由首页打开对应页面
// （`HomeWidgetLaunchRouter`）。应用锁的遮罩盖在导航之上，打开的页面同样
// 先要解锁，与点待办通知一致。

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/home_widgets/home_widget_launch.dart';
import '../providers/home_widget_providers.dart';

final homeWidgetLaunchInboxProvider = Provider<void>((Ref ref) {
  final gateway = ref.watch(homeWidgetGatewayProvider);
  if (gateway == null) return;
  void deliver(Uri? uri) {
    final launch = HomeWidgetLaunch.parse(uri);
    if (launch != null) {
      ref.read(homeWidgetLaunchRequestProvider.notifier).request(launch);
    }
  }

  final subscription = gateway.launches.listen(
    deliver,
    onError: (Object error) =>
        debugPrint('home widgets: launch stream failed: $error'),
  );
  ref.onDispose(subscription.cancel);
  unawaited(
    gateway.initialLaunch().then(
      deliver,
      onError: (Object error) {
        debugPrint('home widgets: initial launch failed: $error');
      },
    ),
  );
});
