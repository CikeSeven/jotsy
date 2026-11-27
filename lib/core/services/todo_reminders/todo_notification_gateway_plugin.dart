import 'dart:async';
import 'dart:ui' show PluginUtilities;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../database/app_database.dart' show formatAnniversaryDate;
import '../app_platform.dart';
import 'todo_focus_notifications.dart';
import 'todo_notification_actions.dart';
import 'todo_notification_gateway.dart';
import 'todo_reminder_planner.dart';

/// 待办提醒的通知渠道（Android 8+）。id 一经发布不能改：用户在系统里对渠道
/// 做的设置（静音、关闭）跟着 id 走。
const String kTodoNotificationChannelId = 'todo_reminders';

/// 待办提醒与权限的原生通道（Android：`TodoNotificationsChannel.kt`，iOS：`AppDelegate.swift`）。
const MethodChannel todoNotificationsChannel = MethodChannel(
  'com.jotsy.diary/notifications',
);

/// 打开系统里本应用的通知设置（权限被拒后从设置页跳过去）；平台不支持或
/// 打不开时返回 false。
Future<bool> openTodoNotificationSettings() =>
    _invokeSettingsMethod('openNotificationSettings', defaultValue: false);

/// 打开系统里本应用的“闹钟和提醒”权限页（Android 12+）。
Future<bool> requestTodoExactAlarmPermission() =>
    _invokeSettingsMethod('requestExactAlarmsPermission', defaultValue: false);

/// 系统是否已对本应用关闭电池优化（忽略后台限制）；非 Android 平台恒为 true。
Future<bool> isIgnoringTodoBatteryOptimizations() async {
  if (!AppPlatform.isAndroid) return true;
  return _invokeSettingsMethod(
    'isIgnoringBatteryOptimizations',
    defaultValue: true,
  );
}

/// 引导用户关闭对本应用的电池优化（Android 6+）；支持时弹出系统弹窗或跳转设置页。
Future<bool> requestIgnoreTodoBatteryOptimizations() async {
  if (!AppPlatform.isAndroid) return true;
  return _invokeSettingsMethod(
    'requestIgnoreBatteryOptimizations',
    defaultValue: false,
  );
}

/// 尽量直达厂商“自启动 / 后台运行管理”设置页，不支持时回落到系统应用详情页。
Future<bool> openTodoAutoStartSettings() =>
    _invokeSettingsMethod('openAutoStartSettings', defaultValue: false);

Future<bool> _invokeSettingsMethod(
  String method, {
  required bool defaultValue,
}) async {
  try {
    return await todoNotificationsChannel.invokeMethod<bool>(method) ??
        defaultValue;
  } on MissingPluginException {
    return defaultValue;
  } on PlatformException {
    return defaultValue;
  }
}

/// 一条待办通知在各平台上的外观：渠道、优先级、锁屏可见性与两个按钮。
/// iOS / 桌面排提醒与后台排“稍后提醒”共用，保证外观一致。每日摘要不对应
/// 某条待办，不带按钮（[actions] 为 false）。
NotificationDetails todoNotificationDetails({
  required TodoNotificationTexts texts,
  required int snoozeMinutes,
  required bool hideOnLockScreen,
  bool actions = true,
}) {
  final darwin = actions
      ? const DarwinNotificationDetails(
          categoryIdentifier: kTodoDarwinCategoryId,
        )
      : const DarwinNotificationDetails();
  return NotificationDetails(
    android: AndroidNotificationDetails(
      kTodoNotificationChannelId,
      texts.channelName,
      channelDescription: texts.channelDescription,
      icon: 'ic_stat_todo',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      visibility: hideOnLockScreen
          ? NotificationVisibility.private
          : NotificationVisibility.public,
      actions: <AndroidNotificationAction>[
        if (actions) ...<AndroidNotificationAction>[
          AndroidNotificationAction(kTodoCompleteActionId, texts.complete),
          AndroidNotificationAction(
            todoNotificationActionId(snoozeMinutes),
            texts.snooze,
          ),
        ],
      ],
    ),
    iOS: darwin,
    macOS: darwin,
    linux: LinuxNotificationDetails(
      actions: <LinuxNotificationAction>[
        if (actions) ...<LinuxNotificationAction>[
          LinuxNotificationAction(
            key: kTodoCompleteActionId,
            label: texts.complete,
          ),
          LinuxNotificationAction(
            key: todoNotificationActionId(snoozeMinutes),
            label: texts.snooze,
          ),
        ],
      ],
    ),
    windows: WindowsNotificationDetails(
      actions: <WindowsAction>[
        if (actions) ...<WindowsAction>[
          WindowsAction(
            content: texts.complete,
            arguments: kTodoCompleteActionId,
          ),
          WindowsAction(
            content: texts.snooze,
            arguments: todoNotificationActionId(snoozeMinutes),
          ),
        ],
      ],
    ),
  );
}

/// iOS / macOS 的通知分类（按钮在分类里预先登记）。“稍后提醒”的时长按默认
/// 10 分钟登记；分类在初始化时定下，之后改设置的时长只影响 Android 与桌面。
const String kTodoDarwinCategoryId = 'todo_reminder';

/// 手机端通知网关：
/// - Android：经原生 `TodoReminderManager` 使用 `AlarmManager.setAlarmClock` +
///   自愈系统接收器 + WorkManager 巡检，划掉后台后仍能唤醒推送；点开与冷启动
///   仍由插件的 `SELECT_NOTIFICATION` 接住；
/// - iOS / 桌面：走 `flutter_local_notifications`。
class PluginTodoNotificationGateway
    with TodoFocusPluginNotifications
    implements TodoNotificationGateway {
  PluginTodoNotificationGateway({FlutterLocalNotificationsPlugin? plugin})
    : plugin = plugin ?? FlutterLocalNotificationsPlugin();

  // 后台动作的引擎已由原生/插件启动，不需要再次注册通知回调。
  PluginTodoNotificationGateway.forBackground(this._texts)
    : plugin = FlutterLocalNotificationsPlugin();

  @override
  final FlutterLocalNotificationsPlugin plugin;
  TodoNotificationTexts? _texts;
  void Function(TodoNotificationEvent event)? _onEvent;
  bool _initialized = false;

  @protected
  TodoNotificationTexts get texts => _texts!;

  @override
  Future<void> initialize({
    required TodoNotificationTexts texts,
    required void Function(TodoNotificationEvent event) onEvent,
  }) async {
    _texts = texts;
    _onEvent = onEvent;
    if (_initialized) return;

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
    final initialized = await plugin.initialize(
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
        if (event != null) _onEvent?.call(event);
      },
      onDidReceiveBackgroundNotificationResponse:
          todoNotificationBackgroundHandler,
    );
    // Darwin 在初始化不请求权限时也会返回 false，Android 的结果表示初始化状态。
    if (AppPlatform.isAndroid && initialized != true) {
      throw StateError('Could not initialize local notifications');
    }
    if (AppPlatform.isAndroid) {
      todoNotificationsChannel.setMethodCallHandler(_handleAndroidChannelCall);
      final callbackHandle = PluginUtilities.getCallbackHandle(
        todoNotificationBackgroundMain,
      )?.toRawHandle();
      await todoNotificationsChannel
          .invokeMethod<bool>('initialize', <String, Object?>{
            'channelName': texts.channelName,
            'channelDescription': texts.channelDescription,
            if (callbackHandle != null) 'actionCallbackHandle': callbackHandle,
          });
      await _cancelLegacyAndroidPluginReminders();
    }
    _initialized = true;
  }

  Future<Object?> _handleAndroidChannelCall(MethodCall call) async {
    if (call.method == 'onNotificationAction') {
      final args = call.arguments as Map<dynamic, dynamic>?;
      final event = TodoNotificationEvent.fromResponse(
        actionId: args?['actionId'] as String?,
        payload: args?['payload'] as String?,
      );
      final onEvent = _onEvent;
      if (event == null || onEvent == null) return false;
      onEvent(event);
      return true;
    }
    return null;
  }

  /// 清理旧版本留在 `flutter_local_notifications` 队列里的待办闹钟，防止升级后重复响铃。
  Future<void> _cancelLegacyAndroidPluginReminders() async {
    try {
      final legacy = await plugin.pendingNotificationRequests();
      for (final request in legacy) {
        if (request.payload?.startsWith(kTodoReminderPayloadPrefix) ?? false) {
          await plugin.cancel(id: request.id);
        }
      }
    } catch (error) {
      debugPrint('todo reminders: legacy cleanup skipped: $error');
    }
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
      if (AppPlatform.isAndroid) {
        return await todoNotificationsChannel.invokeMethod<bool>(
              'notificationsEnabled',
            ) ??
            false;
      }
      if (AppPlatform.isIOS) {
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
      if (AppPlatform.isAndroid) {
        await _android?.requestNotificationsPermission();
        return await notificationsEnabled();
      }
      if (AppPlatform.isIOS) {
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
      if (AppPlatform.isAndroid) {
        return await todoNotificationsChannel.invokeMethod<bool>(
              'canScheduleExactAlarms',
            ) ??
            false;
      }
      return true;
    } catch (error) {
      return false;
    }
  }

  @override
  Future<Map<int, String>> pending() async {
    if (AppPlatform.isAndroid) {
      final entries = await todoNotificationsChannel
          .invokeListMethod<Map<dynamic, dynamic>>('getPendingReminders');
      return <int, String>{
        for (final entry in entries ?? const <Map<dynamic, dynamic>>[])
          if (entry['id'] is int && entry['payload'] is String)
            if ((entry['payload'] as String).startsWith(
              kTodoReminderPayloadPrefix,
            ))
              entry['id'] as int: entry['payload'] as String,
      };
    }
    final requests = await plugin.pendingNotificationRequests();
    return <int, String>{
      for (final request in requests)
        if (request.payload case final payload?)
          if (payload.startsWith(kTodoReminderPayloadPrefix))
            request.id: payload,
    };
  }

  @override
  Future<void> schedule(TodoNotificationRequest request) async {
    if (AppPlatform.isAndroid) {
      await _scheduleAndroidNative(request);
      return;
    }

    final details = todoNotificationDetails(
      texts: texts,
      snoozeMinutes: request.snoozeMinutes,
      hideOnLockScreen: request.hideOnLockScreen,
      actions: !request.reminder.digest,
    );
    // 规划器已用本地日期计算出绝对时刻。传 UTC 可防止平台在夏令时回拨
    // 的重叠时段重新解释本地时刻。
    final fireAt = tz.TZDateTime.from(request.reminder.fireAt, tz.UTC);
    Future<void> scheduleWithMode(bool? exact) => plugin.zonedSchedule(
      id: request.id,
      title: request.reminder.title,
      body: request.body,
      scheduledDate: fireAt,
      notificationDetails: details,
      androidScheduleMode: exact == true
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: request.payloadForAlarmMode(exact),
    );

    final exact = request.androidExact;
    try {
      await scheduleWithMode(exact);
    } on PlatformException catch (error) {
      // 权限可能在检查后、AlarmManager 接到闹钟前被收回。
      if (exact != true ||
          (error.code != 'exact_alarms_not_permitted' &&
              await exactAlarmsAllowed())) {
        rethrow;
      }
      await scheduleWithMode(false);
    }
  }

  Future<void> _scheduleAndroidNative(TodoNotificationRequest request) async {
    final localFireAt = request.reminder.fireAt.toLocal();
    Future<void> invokeWithMode(bool exact) => todoNotificationsChannel
        .invokeMethod<void>('scheduleReminder', <String, Object?>{
          'id': request.id,
          'todoId': request.reminder.todoId,
          'occurrence': formatAnniversaryDate(request.reminder.occurrence),
          'title': request.reminder.title,
          'body': request.body,
          'payload': request.payloadForAlarmMode(exact),
          'fireAtMillis': localFireAt.millisecondsSinceEpoch,
          'localYear': localFireAt.year,
          'localMonth': localFireAt.month,
          'localDay': localFireAt.day,
          'localHour': localFireAt.hour,
          'localMinute': localFireAt.minute,
          'snoozeMinutes': request.snoozeMinutes,
          'hideOnLockScreen': request.hideOnLockScreen,
          'exact': exact,
          'channelName': texts.channelName,
          'channelDescription': texts.channelDescription,
          'completeLabel': texts.complete,
          'snoozeLabel': texts.snooze,
          // 每日摘要没有对应的待办，原生通知不加“完成 / 稍后提醒”按钮。
          'actions': !request.reminder.digest,
        });

    final exact = request.androidExact ?? true;
    try {
      await invokeWithMode(exact);
    } on PlatformException catch (error) {
      if (!exact ||
          (error.code != 'exact_alarms_not_permitted' &&
              await exactAlarmsAllowed())) {
        rethrow;
      }
      await invokeWithMode(false);
    }
  }

  @override
  Future<void> cancel(int id) {
    if (AppPlatform.isAndroid) {
      return todoNotificationsChannel.invokeMethod<void>(
        'cancelReminder',
        <String, Object?>{'id': id},
      );
    }
    return plugin.cancel(id: id);
  }
}
