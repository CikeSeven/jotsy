import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../app_platform.dart';
import 'todo_notification_actions.dart';
import 'todo_notification_gateway.dart';
import 'todo_reminder_planner.dart';

/// 待办提醒的通知渠道（Android 8+）。id 一经发布不能改：用户在系统里对渠道
/// 做的设置（静音、关闭）跟着 id 走。
const String kTodoNotificationChannelId = 'todo_reminders';

/// 打开系统通知设置的原生通道（`MainActivity` / `AppDelegate`）。
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

  // 后台动作的引擎已由插件启动，不需要再次注册通知回调。
  PluginTodoNotificationGateway.forBackground(this._texts)
    : plugin = FlutterLocalNotificationsPlugin();

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
        if (event != null) onEvent(event);
      },
      onDidReceiveBackgroundNotificationResponse:
          todoNotificationBackgroundHandler,
    );
    // Darwin 在初始化不请求权限时也会返回 false，Android 的结果表示初始化状态。
    if (AppPlatform.isAndroid && initialized != true) {
      throw StateError('Could not initialize local notifications');
    }
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
      if (AppPlatform.isAndroid) {
        final android = _android;
        if (android == null ||
            await android.areNotificationsEnabled() != true) {
          return false;
        }
        final channels = await android.getNotificationChannels();
        return !(channels?.any(
              (channel) =>
                  channel.id == kTodoNotificationChannelId &&
                  channel.importance == Importance.none,
            ) ??
            false);
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
        return await _android?.canScheduleExactNotifications() ?? false;
      }
      return true;
    } catch (error) {
      return false;
    }
  }

  @override
  Future<Map<int, String>> pending() async {
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
    final details = todoNotificationDetails(
      texts: texts,
      snoozeMinutes: request.snoozeMinutes,
      hideOnLockScreen: request.hideOnLockScreen,
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

  @override
  Future<void> cancel(int id) => plugin.cancel(id: id);
}
