import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../l10n/app_localizations.dart';
import '../../database/app_database.dart';
import '../app_features.dart';
import '../app_platform.dart';
import '../settings_service.dart';
import 'todo_notification_gateway.dart';
import 'todo_notification_gateway_plugin.dart';
import 'todo_reminder_format.dart';
import 'todo_reminder_planner.dart';

/// 通知上“完成 / 稍后提醒”的处理。
///
/// 两条路径：
/// 1. 应用在运行（主 isolate 活着）：Android 上经原生 `TodoNotificationsChannel`
///    直接交给主 isolate，iOS 上经 [IsolateNameServer] 找到主 isolate 登记的端口
///    （[TodoNotificationActionPort]）——由主 isolate 用它自己的数据库连接写库，
///    Drift 的查询流照常刷新、两个连接不会同时写库；
/// 2. 应用没在运行（或主 isolate 不应答）：后台 isolate 自己打开数据库写入，
///    “稍后提醒”再直接排一条一次性通知，“完成”取消同一次剩下的提醒并在遇到
///    重复待办时立刻把下一次的提醒补排进系统队列。
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

/// Android 后台动作引擎入口（`TodoNotificationActionReceiver` 在主引擎不在时拉起）。
///
/// 通过 `com.jotsy.diary/notifications` 拉取队列里的按钮事件，确保写库与闹钟重排
/// 完成后才通知原生 `finishBackgroundActions` 释放 `PendingResult`。
@pragma('vm:entry-point')
Future<void> todoNotificationBackgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  var draining = false;
  var rerunRequested = false;

  Future<void> drain() async {
    if (draining) {
      rerunRequested = true;
      return;
    }
    draining = true;
    try {
      for (var pass = 0; pass < 10; pass++) {
        rerunRequested = false;
        final items = await todoNotificationsChannel
            .invokeListMethod<Map<dynamic, dynamic>>('takePendingActions');
        for (final item in items ?? const <Map<dynamic, dynamic>>[]) {
          final actionId = item['actionId'] as String?;
          final payload = item['payload'] as String?;
          await _handleBackgroundAction(actionId: actionId, payload: payload);
        }
        if (rerunRequested) continue;
        final done =
            await todoNotificationsChannel.invokeMethod<bool>(
              'finishBackgroundActions',
            ) ??
            true;
        if (done) break;
      }
    } catch (error) {
      debugPrint('todo reminders: background main failed: $error');
      try {
        await todoNotificationsChannel.invokeMethod<bool>(
          'finishBackgroundActions',
        );
      } catch (_) {}
    } finally {
      draining = false;
    }
  }

  todoNotificationsChannel.setMethodCallHandler((MethodCall call) async {
    if (call.method == 'drainPendingActions') {
      unawaited(drain());
      return true;
    }
    return null;
  });

  await drain();
}

/// iOS / 插件回调的后台 isolate 入口。必须是顶层函数并标 `vm:entry-point`，否则
/// release 构建会被摇树摇掉。
@pragma('vm:entry-point')
Future<void> todoNotificationBackgroundHandler(
  NotificationResponse response,
) async {
  await _handleBackgroundAction(
    actionId: response.actionId,
    payload: response.payload,
  );
}

Future<void> _handleBackgroundAction({
  required String? actionId,
  required String? payload,
}) async {
  final event = TodoNotificationEvent.fromResponse(
    actionId: actionId,
    payload: payload,
  );
  if (event == null || event.action == TodoNotificationAction.open) return;
  if (await _forwardToMainIsolate(actionId: actionId, payload: payload)) {
    return;
  }

  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final database = AppDatabase();
  try {
    final wrote = await applyTodoNotificationAction(database, event);
    if (!wrote) return;
    final extras = decodeTodoNotificationExtras(payload);
    final l10n = lookupAppLocalizations(
      _notificationLocale(extras?.languageCode),
    );
    final gateway = PluginTodoNotificationGateway.forBackground(
      todoNotificationTextsOf(l10n),
    );
    if (event.action == TodoNotificationAction.snooze) {
      await _scheduleSnooze(database, gateway, l10n, event, extras);
    } else if (event.action == TodoNotificationAction.complete) {
      await cancelTodoOccurrenceNotifications(
        gateway,
        todoId: event.todoId,
        occurrence: event.occurrence,
      );
      await _rescheduleRepeatingTodo(database, gateway, event.todoId, extras);
    }
  } catch (error) {
    debugPrint('todo reminders: background action failed: $error');
  } finally {
    await database.close();
  }
}

/// 转交给主 isolate；它在 [_forwardTimeout] 内应答才算交出去了。
Future<bool> _forwardToMainIsolate({
  required String? actionId,
  required String? payload,
}) async {
  final port = IsolateNameServer.lookupPortByName(kTodoNotificationPortName);
  if (port == null) return false;
  final reply = ReceivePort();
  try {
    port.send(<Object?>[reply.sendPort, actionId, payload]);
    return await reply.first.timeout(_forwardTimeout, onTimeout: () => false) ==
        true;
  } finally {
    reply.close();
  }
}

/// 后台排“稍后提醒”：主 isolate 不在，没人按库里的 `snoozed_until` 重排。
Future<void> _scheduleSnooze(
  AppDatabase database,
  PluginTodoNotificationGateway gateway,
  AppLocalizations l10n,
  TodoNotificationEvent event,
  ({String? languageCode, bool hide})? extras,
) async {
  final row = await database.getTodo(event.todoId);
  if (row == null) return;
  final reminder = planTodoReminders(
    todos: [row],
    now: DateTime.now(),
  ).where((reminder) => reminder.snooze).firstOrNull;
  if (reminder == null) return;

  final request = TodoNotificationRequest(
    reminder: reminder,
    body: l10n.todoNotificationSnoozedBody,
    languageCode: l10n.localeName,
    snoozeMinutes: event.snoozeMinutes,
    hideOnLockScreen: extras?.hide ?? false,
    androidExact: AppPlatform.isAndroid
        ? await gateway.exactAlarmsAllowed()
        : null,
  );
  await gateway.schedule(request);
}

/// 后台完成重复待办后立刻为其下一次排好提醒，避免用户不打开应用时漏掉后续周期。
Future<void> _rescheduleRepeatingTodo(
  AppDatabase database,
  PluginTodoNotificationGateway gateway,
  String todoId,
  ({String? languageCode, bool hide})? extras,
) async {
  final row = await database.getTodo(todoId);
  if (row == null || row.completedAt != null) return;
  final settingsService = await SettingsService.create();
  if (!AppFeatures.decode(settingsService.appFeaturesRawNotifier.value).todos) {
    return;
  }
  final todoSettings = decodeTodoReminderPrefs(
    settingsService.todoSettingsRawNotifier.value,
  );
  final l10n = lookupAppLocalizations(
    _notificationLocale(
      settingsService.appLocaleCode.isNotEmpty
          ? settingsService.appLocaleCode
          : extras?.languageCode,
    ),
  );
  await initializeDateFormatting(l10n.localeName);
  final pending = await gateway.pending();
  final exact = AppPlatform.isAndroid
      ? await gateway.exactAlarmsAllowed()
      : null;
  final now = DateTime.now();
  final limit = AppPlatform.isIOS ? 60 : 200;
  final planned = planTodoReminders(
    todos: [row],
    now: now,
    limit: limit,
    pendingIds: pending.keys.toSet(),
  );
  for (final reminder in planned) {
    if (!reminder.fireAt.isAfter(now)) continue;
    final body = formatTodoReminderNotificationBody(l10n, reminder);
    final request = TodoNotificationRequest(
      reminder: reminder,
      body: body,
      languageCode: l10n.localeName,
      snoozeMinutes: todoSettings.snoozeMinutes,
      hideOnLockScreen: todoSettings.hideContentOnLockScreen,
      androidExact: exact,
    );
    if (pending[request.id] == request.payload) continue;
    await gateway.schedule(request);
  }
}

Locale _notificationLocale(String? languageCode) {
  final locale = Locale(
    languageCode ?? PlatformDispatcher.instance.locale.languageCode,
  );
  return AppLocalizations.delegate.isSupported(locale)
      ? locale
      : const Locale('en');
}

/// 后台完成后取消同一次剩下的提醒（如“提前 1 天”已响、“准时”还没响）。
/// 重复待办下一次及以后的提醒保留：它们本来就排好了。通知按钮与桌面小组件
/// 的勾选（应用没在运行时）共用。
Future<void> cancelTodoOccurrenceNotifications(
  TodoNotificationGateway gateway, {
  required String todoId,
  required String? occurrence,
}) async {
  final pending = await gateway.pending();
  for (final entry in pending.entries) {
    final decoded = decodeTodoReminderPayload(entry.value);
    if (decoded != null &&
        decoded.todoId == todoId &&
        decoded.occurrence == occurrence) {
      await gateway.cancel(entry.key);
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
