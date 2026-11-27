import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_platform.dart';
import '../../../core/services/todo_reminders/todo_digest_planner.dart';
import '../../../core/services/todo_reminders/todo_notification_actions.dart';
import '../../../core/services/todo_reminders/todo_notification_gateway.dart';
import '../../../core/services/todo_reminders/todo_reminder_format.dart';
import '../../../core/services/todo_reminders/todo_reminder_planner.dart';
import '../models/todo_settings.dart';

// 应用运行时补排进入 30 天窗口的提醒。手机退到后台后仍由系统负责投递。
const _replanInterval = Duration(minutes: 15);
const _retryIntervals = <Duration>[
  Duration(seconds: 2),
  Duration(seconds: 10),
  Duration(minutes: 1),
];

/// 对账数据库规划和系统队列。输入和生命周期变化会触发串行排程。
/// 通知按钮写入数据库，点按详情通过 [onOpen] 交由应用处理。
class TodoReminderScheduler {
  TodoReminderScheduler({
    required this.gateway,
    required this.database,
    required this.onOpen,
    this.now = DateTime.now,
  });

  final TodoNotificationGateway gateway;
  final AppDatabase database;
  final void Function(String todoId) onOpen;

  /// 只供测试注入的时钟。
  final DateTime Function() now;

  bool? _enabled;
  TodoSettings _settings = TodoSettings.defaults;
  List<TodoRow>? _todos;
  Locale _locale = const Locale('en');
  bool _initialized = false;
  Set<int>? _restoringAndroidAlarms = AppPlatform.isAndroid ? <int>{} : null;
  bool _disposed = false;
  bool _permissionAsked = false;
  Timer? _replan;
  Timer? _retry;
  int _retryStep = 0;
  Timer? _periodic;
  AppLifecycleListener? _lifecycle;
  late final TodoNotificationActionPort _port = TodoNotificationActionPort(
    _handleAction,
  );

  Future<void> _reconciling = Future<void>.value();
  Future<void>? _queuedReconcile;

  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    _lifecycle ??= AppLifecycleListener(onResume: _scheduleReplan);
    _periodic?.cancel();
    _periodic = value
        ? Timer.periodic(_replanInterval, (_) => _scheduleReplan())
        : null;
    _scheduleReplan();
  }

  set settings(TodoSettings value) {
    if (_settings == value) return;
    _settings = value;
    _scheduleReplan();
  }

  set todos(List<TodoRow> value) {
    _todos = value;
    _scheduleReplan();
  }

  set locale(Locale value) {
    if (_locale == value) return;
    _locale = value;
    _scheduleReplan();
  }

  AppLocalizations get _l10n {
    final locale = AppLocalizations.delegate.isSupported(_locale)
        ? _locale
        : const Locale('en');
    return lookupAppLocalizations(locale);
  }

  Future<void> _initialize() async {
    await gateway.initialize(
      texts: todoNotificationTextsOf(_l10n),
      onEvent: (event) => unawaited(_handleAction(event)),
    );
    if (_disposed) return;
    _initialized = true;
    _port.open();
    final launch = await gateway.takeLaunchEvent();
    if (launch != null) unawaited(_handleAction(launch));
  }

  void _scheduleReplan() {
    if (_disposed || _enabled == null) return;
    // 合并同一轮事件里的流更新。多等一个防抖间隔会错过刚保存的整分钟提醒。
    _replan ??= Timer(Duration.zero, () => unawaited(replanNow()));
  }

  @visibleForTesting
  Future<void> replanNow() {
    _replan?.cancel();
    _replan = null;
    // 排程操作需要串行；进行中的一轮至多积一轮后续对账。
    return _queuedReconcile ??= _reconciling = _reconciling.then((_) {
      _queuedReconcile = null;
      return _reconcile();
    });
  }

  Future<void> _reconcile() async {
    _retry?.cancel();
    _retry = null;
    if (_disposed || _enabled == null) return;

    try {
      final success = await _reconcilePending(enabled: _enabled!);
      if (success) {
        _retryStep = 0;
        return;
      }
    } catch (error) {
      debugPrint('todo reminders: reconcile failed: $error');
    }
    if (_disposed) return;
    _retry = Timer(_retryIntervals[_retryStep], _scheduleReplan);
    if (_retryStep < _retryIntervals.length - 1) _retryStep++;
  }

  Future<bool> _reconcilePending({required bool enabled}) async {
    if (enabled && !_initialized) await _initialize();
    final todos = _todos;
    if (_disposed || _enabled != enabled || (enabled && todos == null)) {
      return true;
    }

    final pending = <int, String>{...await gateway.pending()};
    final clock = now();
    final limit = AppPlatform.isIOS ? 60 : 200;
    final requests = enabled
        ? await _planRequests(todos!, clock, limit, pending.keys.toSet())
        : const <int, TodoNotificationRequest>{};

    // Android 插件的 pending 来自持久化缓存，系统强停后缓存仍在。每次冷启动
    // 向 AlarmManager 确认未来的闹钟，同 id 覆盖，保留正在等系统投递的提醒。
    final restoredAlarms = enabled ? _restoringAndroidAlarms : null;
    var success = true;
    for (final entry in pending.entries.toList()) {
      if (_disposed || _enabled != enabled) return true;
      final request = requests[entry.key];
      if (request != null) {
        final payload = request.reminder.payload;
        final sameOccurrence =
            entry.value == payload || entry.value.startsWith('$payload|');
        final visibilityAllowed =
            !request.hideOnLockScreen ||
            decodeTodoNotificationExtras(entry.value)?.hide == true;
        if (sameOccurrence && visibilityAllowed) {
          continue;
        }
      }
      try {
        await gateway.cancel(entry.key);
        pending.remove(entry.key);
      } catch (error) {
        success = false;
        debugPrint('todo reminders: cancelling ${entry.key} failed: $error');
      }
    }
    for (final request in requests.values) {
      if (_disposed || _enabled != enabled) return true;
      if (!request.reminder.fireAt.isAfter(now())) continue;
      final existing = pending[request.id];
      if (existing == request.payload &&
          (restoredAlarms == null || restoredAlarms.contains(request.id))) {
        continue;
      }
      if (existing == null && pending.length >= limit) continue;
      try {
        // 替换现有 id 由系统完成，避免先取消后排程失败时丢掉原提醒。
        await gateway.schedule(request);
        pending[request.id] = request.payload;
        restoredAlarms?.add(request.id);
      } catch (error) {
        success = false;
        debugPrint('todo reminders: scheduling ${request.id} failed: $error');
      }
    }
    if (success && enabled) _restoringAndroidAlarms = null;
    return success;
  }

  Future<Map<int, TodoNotificationRequest>> _planRequests(
    List<TodoRow> todos,
    DateTime clock,
    int limit,
    Set<int> pendingIds,
  ) async {
    final l10n = _l10n;
    final settings = _settings;
    await initializeDateFormatting(l10n.localeName);
    final exact = AppPlatform.isAndroid
        ? await gateway.exactAlarmsAllowed()
        : null;
    final kept = AppPlatform.supportsBackgroundReminders
        ? pendingIds
        : const <int>{};
    final digestMinute = settings.digestMinute;
    // 摘要最多一周 7 条，先从上限里留出来，提醒排在剩下的名额里。
    final digests = digestMinute == null
        ? const <PlannedTodoDigest>[]
        : planTodoDigests(
            todos: todos,
            now: clock,
            minute: digestMinute,
            pendingIds: kept,
          );
    TodoNotificationRequest request(PlannedReminder reminder, String body) =>
        TodoNotificationRequest(
          reminder: reminder,
          body: body,
          languageCode: l10n.localeName,
          snoozeMinutes: settings.snoozeMinutes,
          hideOnLockScreen: settings.hideContentOnLockScreen,
          androidExact: exact,
        );
    final requests = <int, TodoNotificationRequest>{
      for (final reminder in planTodoReminders(
        todos: todos,
        now: clock,
        limit: limit - digests.length,
        pendingIds: kept,
      ))
        reminder.id: request(
          reminder,
          formatTodoReminderNotificationBody(l10n, reminder),
        ),
    };
    for (final digest in digests) {
      final text = formatTodoDigestNotification(l10n, digest);
      requests[digest.id] = request(digest.toReminder(text.title), text.body);
    }
    return requests;
  }

  Future<void> _handleAction(TodoNotificationEvent event) async {
    if (_disposed) return;
    if (event.action == TodoNotificationAction.open) {
      // 每日摘要的 todoId 为空：首页据此切到待办 Tab 的“今天”。
      onOpen(event.todoId);
      return;
    }
    if (event.todoId.isEmpty) return;
    await applyTodoNotificationAction(database, event, now: now());
  }

  /// 第一次给待办加提醒时请求发通知的权限（每次运行只问一次）；返回系统
  /// 是否允许。
  Future<bool> ensurePermission() async {
    if (await gateway.notificationsEnabled()) return true;
    if (_permissionAsked) return false;
    _permissionAsked = true;
    final allowed = await gateway.requestPermission();
    if (allowed) _scheduleReplan();
    return allowed;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _replan?.cancel();
    _retry?.cancel();
    _periodic?.cancel();
    _lifecycle?.dispose();
    if (_initialized) _port.close();
  }
}
