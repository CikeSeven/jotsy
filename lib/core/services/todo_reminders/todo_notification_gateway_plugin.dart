import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_10y.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'todo_notification_actions.dart';
import 'todo_notification_gateway.dart';
import 'todo_reminder_planner.dart';

/// 待办提醒的通知渠道（Android 8+）。id 一经发布不能改：用户在系统里对渠道
/// 做的设置（静音、关闭）跟着 id 走。
const String kTodoNotificationChannelId = 'todo_reminders';

/// 原生通道：本机时区名、打开系统通知设置（`MainActivity` / `AppDelegate`）。
const MethodChannel todoNotificationsChannel = MethodChannel(
  'com.jotsy.diary/notifications',
);

/// 打开系统里本应用的通知设置（权限被拒后从设置页跳过去）；平台不支持或
/// 打不开时返回 false。
Future<bool> openTodoNotificationSettings() async {
  try {
    return await todoNotificationsChannel.invokeMethod<bool>(
          'openNotificationSettings',
        ) ??
        false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}

/// 按本机时区初始化 timezone 库：定时通知用带时区的时刻排，夏令时切换后
/// “早上 9 点”仍是墙上时钟的 9 点。时区名读不到或不认识时退回 UTC（按绝对
/// 时刻排，只在跨过夏令时切换的那几条上差一小时）。
Future<void> initializeTodoTimeZone() async {
  tz_data.initializeTimeZones();
  try {
    final name = await todoNotificationsChannel.invokeMethod<String>(
      'timeZone',
    );
    if (name != null && name.isNotEmpty) {
      tz.setLocalLocation(tz.getLocation(name));
      return;
    }
  } on MissingPluginException {
    // 落到下面的 UTC。
  } on PlatformException {
    // 同上。
  } on tz.LocationNotFoundException {
    // 同上。
  }
  tz.setLocalLocation(tz.UTC);
}

/// 一条待办通知在各平台上的外观：渠道、优先级、锁屏可见性与两个按钮。
/// 主 isolate 排提醒与后台 isolate 排“稍后提醒”共用，保证两边一模一样。
NotificationDetails todoNotificationDetails({
  required TodoNotificationTexts texts,
  required int snoozeMinutes,
  required bool hideOnLockScreen,
}) {
  final actions = <AndroidNotificationAction>[
    AndroidNotificationAction(kTodoCompleteActionId, texts.complete),
    AndroidNotificationAction(
      todoNotificationActionId(snoozeMinutes),
      texts.snooze,
    ),
  ];
  return NotificationDetails(
    android: AndroidNotificationDetails(
      kTodoNotificationChannelId,
      texts.channelName,
      channelDescription: texts.channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      visibility: hideOnLockScreen
          ? NotificationVisibility.private
          : NotificationVisibility.public,
      actions: actions,
    ),
    iOS: const DarwinNotificationDetails(
      categoryIdentifier: kTodoDarwinCategoryId,
    ),
    macOS: const DarwinNotificationDetails(
      categoryIdentifier: kTodoDarwinCategoryId,
    ),
    linux: LinuxNotificationDetails(
      actions: <LinuxNotificationAction>[
        LinuxNotificationAction(
          key: kTodoCompleteActionId,
          label: texts.complete,
        ),
        LinuxNotificationAction(
          key: todoNotificationActionId(snoozeMinutes),
          label: texts.snooze,
        ),
      ],
    ),
    windows: WindowsNotificationDetails(
      actions: <WindowsAction>[
        WindowsAction(
          content: texts.complete,
          arguments: kTodoCompleteActionId,
        ),
        WindowsAction(
          content: texts.snooze,
          arguments: todoNotificationActionId(snoozeMinutes),
        ),
      ],
    ),
  );
}

/// iOS / macOS 的通知分类（按钮在分类里预先登记）。“稍后提醒”的时长按默认
/// 10 分钟登记；分类在初始化时定下，之后改设置的时长只影响 Android 与桌面。
const String kTodoDarwinCategoryId = 'todo_reminder';

/// 手机：交给系统定时（Android 的 AlarmManager、iOS 的本地通知），应用没在
/// 运行也会按时弹出；开机后由插件的 receiver 重新排定。
class PluginTodoNotificationGateway implements TodoNotificationGateway {
  PluginTodoNotificationGateway({FlutterLocalNotificationsPlugin? plugin})
    : plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin plugin;
  TodoNotificationTexts? _texts;
  bool _initialized = false;

  @protected
  TodoNotificationTexts get texts => _texts!;

  @override
  Future<void> initialize({
    required TodoNotificationTexts texts,
    required void Function(TodoNotificationEvent event) onEvent,
  }) async {
    _texts = texts;
    if (_initialized) return;
    await initializeTodoTimeZone();
    final darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: <DarwinNotificationCategory>[
        DarwinNotificationCategory(
          kTodoDarwinCategoryId,
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain(
              kTodoCompleteActionId,
              texts.complete,
            ),
            DarwinNotificationAction.plain(
              todoNotificationActionId(10),
              texts.snooze,
            ),
          ],
        ),
      ],
    );
    await plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('ic_stat_todo'),
        iOS: darwin,
        macOS: darwin,
        linux: LinuxInitializationSettings(defaultActionName: texts.open),
        windows: const WindowsInitializationSettings(
          appName: 'Jotsy',
          appUserModelId: 'com.jotsy.diary',
          // 固定的 GUID：Windows 用它把通知点按交回本应用，不能改。
          guid: 'a6f1d8f2-5c2e-4b1d-9c43-2e7d4f0c9b17',
        ),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final event = TodoNotificationEvent.fromResponse(
          actionId: response.actionId,
          payload: response.payload,
        );
        if (event != null) onEvent(event);
      },
      onDidReceiveBackgroundNotificationResponse:
          todoNotificationBackgroundHandler,
    );
    _initialized = true;
  }

  @override
  Future<TodoNotificationEvent?> takeLaunchEvent() async {
    try {
      final details = await plugin.getNotificationAppLaunchDetails();
      final response = details?.notificationResponse;
      if (details == null || !details.didNotificationLaunchApp) return null;
      return TodoNotificationEvent.fromResponse(
        actionId: response?.actionId,
        payload: response?.payload,
      );
    } catch (error) {
      debugPrint('todo reminders: launch details failed: $error');
      return null;
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> notificationsEnabled() async {
    try {
      if (Platform.isAndroid) {
        return await _android?.areNotificationsEnabled() ?? false;
      }
      if (Platform.isIOS) {
        final options = await _ios?.checkPermissions();
        return options?.isEnabled ?? false;
      }
      return true;
    } catch (error) {
      debugPrint('todo reminders: permission check failed: $error');
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      if (Platform.isAndroid) {
        return await _android?.requestNotificationsPermission() ?? false;
      }
      if (Platform.isIOS) {
        return await _ios?.requestPermissions(alert: true, sound: true) ??
            false;
      }
      return true;
    } catch (error) {
      debugPrint('todo reminders: permission request failed: $error');
      return false;
    }
  }

  @override
  Future<bool> exactAlarmsAllowed() async {
    try {
      if (Platform.isAndroid) {
        return await _android?.canScheduleExactNotifications() ?? false;
      }
      return true;
    } catch (error) {
      return false;
    }
  }

  @override
  Future<Map<int, String>> pending() async {
    try {
      final requests = await plugin.pendingNotificationRequests();
      return <int, String>{
        for (final request in requests)
          if (request.payload case final payload?)
            if (payload.startsWith(kTodoReminderPayloadPrefix))
              request.id: payload,
      };
    } catch (error) {
      debugPrint('todo reminders: listing pending failed: $error');
      return const <int, String>{};
    }
  }

  @override
  Future<void> schedule(TodoNotificationRequest request) async {
    try {
      final exact = await exactAlarmsAllowed();
      await plugin.zonedSchedule(
        id: request.id,
        title: request.reminder.title,
        body: request.body,
        scheduledDate: tz.TZDateTime.from(request.reminder.fireAt, tz.local),
        notificationDetails: todoNotificationDetails(
          texts: texts,
          snoozeMinutes: request.snoozeMinutes,
          hideOnLockScreen: request.hideOnLockScreen,
        ),
        // 准时闹钟被系统收回时退回不精确的：提醒可能晚几分钟，但不会不响。
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: request.payload,
      );
    } catch (error) {
      debugPrint('todo reminders: scheduling ${request.id} failed: $error');
    }
  }

  @override
  Future<void> cancel(int id) async {
    try {
      await plugin.cancel(id: id);
    } catch (error) {
      debugPrint('todo reminders: cancelling $id failed: $error');
    }
  }
}
