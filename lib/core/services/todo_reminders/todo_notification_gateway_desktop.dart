import 'dart:async';

import 'package:flutter/foundation.dart';

import 'todo_notification_gateway.dart';
import 'todo_notification_gateway_plugin.dart';

/// 桌面（Linux / Windows / macOS）：应用运行期间用进程内计时器按时弹出系统
/// 通知（插件的 `show`），不交给系统定时。
///
/// 为什么：Linux 的插件不支持定时；Windows 未打包成 MSIX 时插件取不到已弹出
/// 的通知；进程内计时在三个平台上行为一致。代价是应用关着时不提醒（设置页
/// 写明）。电脑睡眠会让计时器晚到：调度器在回到前台与每隔一段时间重新对账，
/// 已经过点的不补弹（与手机上“开机后已过期的不补”一致）。
class DesktopTodoNotificationGateway extends PluginTodoNotificationGateway {
  DesktopTodoNotificationGateway({super.plugin, this.now = DateTime.now});

  /// 只供测试注入的时钟。
  final DateTime Function() now;

  final Map<int, ({Timer timer, String payload})> _timers =
      <int, ({Timer timer, String payload})>{};

  @override
  Future<TodoNotificationEvent?> takeLaunchEvent() async => null;

  @override
  Future<bool> notificationsEnabled() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> exactAlarmsAllowed() async => true;

  @override
  Future<Map<int, String>> pending() async => <int, String>{
    for (final entry in _timers.entries) entry.key: entry.value.payload,
  };

  @override
  Future<void> schedule(TodoNotificationRequest request) async {
    _timers.remove(request.id)?.timer.cancel();
    final delay = request.reminder.fireAt.difference(now());
    if (delay.isNegative) return;
    final timer = Timer(delay, () {
      _timers.remove(request.id);
      unawaited(_show(request));
    });
    _timers[request.id] = (timer: timer, payload: request.payload);
  }

  Future<void> _show(TodoNotificationRequest request) async {
    try {
      await plugin.show(
        id: request.id,
        title: request.reminder.title,
        body: request.body,
        notificationDetails: todoNotificationDetails(
          texts: texts,
          snoozeMinutes: request.snoozeMinutes,
          hideOnLockScreen: request.hideOnLockScreen,
        ),
        payload: request.payload,
      );
    } catch (error) {
      debugPrint('todo reminders: showing ${request.id} failed: $error');
    }
  }

  @override
  Future<void> cancel(int id) async {
    _timers.remove(id)?.timer.cancel();
  }
}
