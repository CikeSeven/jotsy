import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_10y.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../l10n/app_localizations_gen.dart';
import '../../database/app_database.dart';
import 'todo_notification_gateway.dart';
import 'todo_notification_gateway_plugin.dart';
import 'todo_reminder_planner.dart';

/// 通知上“完成 / 稍后提醒”的处理。
///
/// 两条路径：
/// 1. 应用在运行（主 isolate 活着）：插件在主 isolate 回调
///    `onDidReceiveNotificationResponse`，或者（Android 上应用退到后台时）在
///    后台 isolate 回调 [todoNotificationBackgroundHandler]，后者经
///    [IsolateNameServer] 找到主 isolate 登记的端口、把动作转交给它
///    （[TodoNotificationActionPort]）——由主 isolate 用它自己的数据库连接
///    写库，Drift 的查询流照常刷新、两个连接不会同时写库；
/// 2. 应用没在运行（或主 isolate 不应答）：后台 isolate 自己打开数据库写入，
///    “稍后提醒”再直接排一条一次性通知，“完成”顺手取消同一次剩下的提醒。
///    下次打开应用时调度器按库里的数据重新对账。
///
/// 写库的口径只有 [applyTodoNotificationAction]：完成只在通知那一次仍是当前
/// 截止日时生效（另一台设备已经完成并推到下一次时不再重复完成）。

/// 主 isolate 登记接收端口用的名字。
const String kTodoNotificationPortName = 'jotsy.todo_notification_actions';

/// 后台 isolate 等主 isolate 应答的时长（非动画计时）：端口可能是上次进程
/// 留下的死端口，等不到就自己处理。
const Duration _forwardTimeout = Duration(seconds: 3);

/// 按通知动作写库；待办不存在或已完成时什么都不做。返回是否写了库。
Future<bool> applyTodoNotificationAction(
  AppDatabase database,
  TodoNotificationEvent event, {
  DateTime? now,
}) async {
  final row = await database.getTodo(event.todoId);
  if (row == null || row.completedAt != null) return false;
  switch (event.action) {
    case TodoNotificationAction.open:
      return false;
    case TodoNotificationAction.complete:
      final due = row.dueDate;
      if (due != null && due != event.occurrence) return false;
      return await database.completeTodo(event.todoId) != null;
    case TodoNotificationAction.snooze:
      final at = (now ?? DateTime.now()).add(
        Duration(minutes: event.snoozeMinutes),
      );
      await database.snoozeTodo(event.todoId, at);
      return true;
  }
}

/// 主 isolate 一侧：登记接收端口，收到后台 isolate 转来的动作就交给
/// [onAction] 处理并应答。
class TodoNotificationActionPort {
  TodoNotificationActionPort(this.onAction);

  final Future<void> Function(TodoNotificationEvent event) onAction;
  ReceivePort? _port;

  void open() {
    if (_port != null) return;
    final port = ReceivePort();
    // 上次进程异常退出可能留下同名登记：先移除再登记。
    IsolateNameServer.removePortNameMapping(kTodoNotificationPortName);
    IsolateNameServer.registerPortWithName(
      port.sendPort,
      kTodoNotificationPortName,
    );
    port.listen((Object? message) async {
      // [应答端口, 按钮 id, payload]，见 _forwardToMainIsolate。
      if (message is! List || message.length != 3) return;
      final reply = message[0];
      final event = TodoNotificationEvent.fromResponse(
        actionId: message[1] as String?,
        payload: message[2] as String?,
      );
      if (event != null) {
        try {
          await onAction(event);
        } catch (error) {
          debugPrint('todo reminders: action failed: $error');
        }
      }
      if (reply is SendPort) reply.send(true);
    });
    _port = port;
  }

  void close() {
    IsolateNameServer.removePortNameMapping(kTodoNotificationPortName);
    _port?.close();
    _port = null;
  }
}

/// 后台 isolate 的入口（插件在应用退到后台或没在运行时调用）。必须是顶层
/// 函数并标 `vm:entry-point`，否则 release 构建会被摇树摇掉。
@pragma('vm:entry-point')
Future<void> todoNotificationBackgroundHandler(
  NotificationResponse response,
) async {
  final event = TodoNotificationEvent.fromResponse(
    actionId: response.actionId,
    payload: response.payload,
  );
  if (event == null || event.action == TodoNotificationAction.open) return;
  if (await _forwardToMainIsolate(response)) return;

  // 后台引擎里调用别的插件（path_provider、通知本身）之前要先注册。
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final database = AppDatabase();
  try {
    final wrote = await applyTodoNotificationAction(database, event);
    if (!wrote) return;
    final plugin = FlutterLocalNotificationsPlugin();
    if (event.action == TodoNotificationAction.snooze) {
      await _scheduleSnooze(plugin, database, event, response.payload);
    } else if (event.action == TodoNotificationAction.complete) {
      await _cancelOccurrence(plugin, event);
    }
  } catch (error) {
    debugPrint('todo reminders: background action failed: $error');
  } finally {
    await database.close();
  }
}

/// 转交给主 isolate；它在 [_forwardTimeout] 内应答才算交出去了。
Future<bool> _forwardToMainIsolate(NotificationResponse response) async {
  final port = IsolateNameServer.lookupPortByName(kTodoNotificationPortName);
  if (port == null) return false;
  final reply = ReceivePort();
  try {
    port.send(<Object?>[reply.sendPort, response.actionId, response.payload]);
    return await reply.first.timeout(_forwardTimeout, onTimeout: () => false) ==
        true;
  } finally {
    reply.close();
  }
}

/// 后台排“稍后提醒”：主 isolate 不在，没人按库里的 `snoozed_until` 重排。
/// 一次性的、几分钟后的通知，按绝对时刻（UTC）排即可，不必读本机时区。
Future<void> _scheduleSnooze(
  FlutterLocalNotificationsPlugin plugin,
  AppDatabase database,
  TodoNotificationEvent event,
  String? payload,
) async {
  final row = await database.getTodo(event.todoId);
  final until = row?.snoozedUntil;
  if (row == null || until == null) return;
  tz_data.initializeTimeZones();
  final extras = decodeTodoNotificationExtras(payload);
  final l10n = lookupAppLocalizations(
    Locale(
      extras?.languageCode ?? PlatformDispatcher.instance.locale.languageCode,
    ),
  );
  final occurrence = parseAnniversaryDate(event.occurrence) ?? until;
  final reminder = PlannedReminder(
    id: todoReminderNotificationId(row.todoId, until),
    todoId: row.todoId,
    title: row.title,
    occurrence: occurrence,
    dueMinute: row.dueMinute,
    fireAt: until,
    snooze: true,
  );
  final request = TodoNotificationRequest(
    reminder: reminder,
    body: l10n.todoNotificationSnoozedBody,
    languageCode: l10n.localeName,
    snoozeMinutes: event.snoozeMinutes,
    hideOnLockScreen: extras?.hide ?? false,
  );
  await plugin.zonedSchedule(
    id: request.id,
    title: reminder.title,
    body: request.body,
    scheduledDate: tz.TZDateTime.from(until.toUtc(), tz.UTC),
    notificationDetails: todoNotificationDetails(
      texts: todoNotificationTextsOf(l10n),
      snoozeMinutes: event.snoozeMinutes,
      hideOnLockScreen: request.hideOnLockScreen,
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    payload: request.payload,
  );
}

/// 后台完成后取消同一次剩下的提醒（如“提前 1 天”已响、“准时”还没响）。
/// 重复待办下一次及以后的提醒保留：它们本来就排好了。
Future<void> _cancelOccurrence(
  FlutterLocalNotificationsPlugin plugin,
  TodoNotificationEvent event,
) async {
  final pending = await plugin.pendingNotificationRequests();
  for (final request in pending) {
    final decoded = decodeTodoReminderPayload(request.payload);
    if (decoded != null &&
        decoded.todoId == event.todoId &&
        decoded.occurrence == event.occurrence) {
      await plugin.cancel(id: request.id);
    }
  }
}

/// 按界面语言取通知文案。
TodoNotificationTexts todoNotificationTextsOf(AppLocalizations l10n) =>
    TodoNotificationTexts(
      channelName: l10n.todoNotificationChannel,
      channelDescription: l10n.todoNotificationChannelDescription,
      complete: l10n.todoNotificationComplete,
      snooze: l10n.todoNotificationSnooze,
      open: l10n.todoNotificationOpen,
    );
