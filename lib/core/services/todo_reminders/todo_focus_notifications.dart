import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../app_platform.dart';
import 'todo_notification_gateway.dart';

/// 专注计时的通知渠道（Android 8+）：倒计时安静、不响；结束提醒要响。id 一经
/// 发布不能改（用户对渠道的设置跟着 id 走）。
const String kTodoFocusChannelId = 'todo_focus';
const String kTodoFocusEndChannelId = 'todo_focus_end';

/// Android 的倒计时通知：常驻、不响、系统按 chronometer 倒着走秒，走完时
/// 自己收起（`timeoutAfter`），不会接着显示负数。
NotificationDetails todoFocusCountdownDetails(
  TodoFocusNotice notice,
  DateTime now,
) {
  final left = notice.endsAt.difference(now).inMilliseconds;
  return NotificationDetails(
    android: AndroidNotificationDetails(
      kTodoFocusChannelId,
      notice.channelName,
      channelDescription: notice.channelDescription,
      icon: 'ic_stat_todo',
      importance: Importance.low,
      priority: Priority.low,
      category: AndroidNotificationCategory.stopwatch,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      silent: true,
      showWhen: true,
      when: notice.endsAt.millisecondsSinceEpoch,
      usesChronometer: true,
      chronometerCountDown: true,
      timeoutAfter: left > 0 ? left : null,
    ),
  );
}

/// 走完时的一次提醒（各平台；Android 走结束渠道，按闹钟的优先级）。
NotificationDetails todoFocusEndDetails(TodoFocusNotice notice) =>
    NotificationDetails(
      android: AndroidNotificationDetails(
        kTodoFocusEndChannelId,
        notice.channelName,
        channelDescription: notice.channelDescription,
        icon: 'ic_stat_todo',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
      ),
      iOS: const DarwinNotificationDetails(),
      macOS: const DarwinNotificationDetails(),
      linux: const LinuxNotificationDetails(),
      windows: const WindowsNotificationDetails(),
    );

/// 手机（Android / iOS）上的专注通知：倒计时用插件的 `show`，结束提醒交给
/// 系统定时（Android 用 `alarmClock` 模式即 `setAlarmClock`，与待办提醒同样
/// 不受 Doze 推迟；不许准时闹钟时退回不精确）。只有几十分钟、应用多半刚在
/// 前台，不经待办提醒的原生管理器（那是为开机、升级后补排设计的）。
mixin TodoFocusPluginNotifications {
  FlutterLocalNotificationsPlugin get plugin;

  Future<void> showFocus(TodoFocusNotice notice) async {
    final now = DateTime.now();
    if (!notice.endsAt.isAfter(now)) return;
    if (AppPlatform.isAndroid) {
      await plugin.show(
        id: kTodoFocusCountdownId,
        title: notice.title,
        body: null,
        notificationDetails: todoFocusCountdownDetails(notice, now),
        payload: kTodoFocusPayloadPrefix,
      );
    }
    final at = tz.TZDateTime.from(notice.endsAt, tz.UTC);
    Future<void> scheduleWith(AndroidScheduleMode mode) => plugin.zonedSchedule(
      id: kTodoFocusEndId,
      title: notice.endTitle,
      body: notice.endBody,
      scheduledDate: at,
      notificationDetails: todoFocusEndDetails(notice),
      androidScheduleMode: mode,
      payload: kTodoFocusPayloadPrefix,
    );
    try {
      await scheduleWith(AndroidScheduleMode.alarmClock);
    } on PlatformException catch (error) {
      debugPrint('todo focus: exact end alarm refused: $error');
      await scheduleWith(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  Future<void> cancelFocus() async {
    await plugin.cancel(id: kTodoFocusCountdownId);
    await plugin.cancel(id: kTodoFocusEndId);
  }
}
