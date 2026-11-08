import 'dart:async';

import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_platform.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/todo_reminders/todo_notification_actions.dart';
import '../../../core/services/todo_reminders/todo_notification_gateway.dart';
import '../../../core/services/todo_reminders/todo_notification_gateway_desktop.dart';
import '../../../core/services/todo_reminders/todo_notification_gateway_plugin.dart';
import '../../../core/services/todo_reminders/todo_reminder_planner.dart';
import '../../settings/providers/app_features_provider.dart';
import '../models/todo_settings.dart';
import '../providers/todo_providers.dart';
import '../widgets/todo_labels.dart';

/// 系统通知的实现：手机交给系统定时，桌面在进程里计时；不支持的平台为 null。
/// 测试换成假实现。
final todoNotificationGatewayProvider = Provider<TodoNotificationGateway?>((
  Ref ref,
) {
  if (!AppPlatform.supportsReminders) return null;
  return AppPlatform.supportsBackgroundReminders
      ? PluginTodoNotificationGateway()
      : DesktopTodoNotificationGateway();
});

/// 点通知要打开的待办（业务 id）；首页消费后置回 null。
final todoNotificationOpenRequestProvider =
    NotifierProvider<TodoNotificationOpenRequest, String?>(
      TodoNotificationOpenRequest.new,
    );

class TodoNotificationOpenRequest extends Notifier<String?> {
  @override
  String? build() => null;

  void request(String todoId) => state = todoId;

  void consume() => state = null;
}

/// 待办提醒的调度器（由 `NodeDiaryApp` 常驻监听，整个应用生命周期只有一份）。
///
/// 输入：功能开关、待办偏好、界面语言与未完成的待办（drift `.watch()`：本机
/// 编辑、局域网同步与导入备份都会推过来）。每次输入变化防抖 [_replanDelay]
/// 后重新排：按 [planTodoReminders] 算出接下来要弹的提醒，与系统里已排好的
/// 待办通知对账——只取消多出来的、只补上缺的或内容变了的。回到前台、桌面上
/// 每隔 [_desktopReplanInterval] 也重排一次（时间过去了、电脑睡眠过、时区
/// 变了）。功能关闭时取消全部待办通知。
///
/// 通知的点开与按钮：主 isolate 直接处理；Android 上应用在后台时插件在后台
/// isolate 回调，经 [TodoNotificationActionPort] 转回这里（见
/// `todo_notification_actions.dart`）。点开交给首页打开详情
/// （[todoNotificationOpenRequestProvider]）。
final todoReminderSchedulerProvider = Provider<TodoReminderScheduler?>((
  Ref ref,
) {
  final gateway = ref.watch(todoNotificationGatewayProvider);
  if (gateway == null) return null;
  final scheduler = TodoReminderScheduler(
    gateway: gateway,
    database: ref.read(appDatabaseProvider),
    onOpen: (String todoId) =>
        ref.read(todoNotificationOpenRequestProvider.notifier).request(todoId),
  );
  ref.onDispose(scheduler.dispose);
  ref.listen<bool>(
    appFeaturesProvider.select((features) => features.todos),
    (_, bool enabled) => scheduler.enabled = enabled,
    fireImmediately: true,
  );
  ref.listen<TodoSettings>(
    todoSettingsProvider,
    (_, TodoSettings settings) => scheduler.settings = settings,
    fireImmediately: true,
  );
  ref.listen<AsyncValue<List<TodoRow>>>(openTodosProvider, (
    _,
    AsyncValue<List<TodoRow>> next,
  ) {
    final rows = next.value;
    if (rows != null) scheduler.todos = rows;
  }, fireImmediately: true);
  final settingsService = ref.watch(settingsServiceProvider).asData?.value;
  if (settingsService != null) {
    final locale = settingsService.localeNotifier;
    void onLocale() => scheduler.locale = locale.value;
    locale.addListener(onLocale);
    ref.onDispose(() => locale.removeListener(onLocale));
    onLocale();
  }
  return scheduler;
});

/// 输入防抖（非动画计时）：一次编辑常连着改好几列，不必每列都对账一次。
const Duration _replanDelay = Duration(milliseconds: 500);

/// 桌面的定期重排（非动画计时）：进程内计时器在电脑睡眠时会晚到。
const Duration _desktopReplanInterval = Duration(minutes: 15);

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

  bool _enabled = false;
  TodoSettings _settings = TodoSettings.defaults;
  List<TodoRow>? _todos;
  Locale _locale = const Locale('en');
  bool _started = false;
  bool _disposed = false;
  bool _permissionAsked = false;
  Timer? _replan;
  Timer? _periodic;
  AppLifecycleListener? _lifecycle;
  late final TodoNotificationActionPort _port = TodoNotificationActionPort(
    _handleAction,
  );

  /// 当前一次对账；重排时等它结束再开始，免得两次对账交错。
  Future<void> _reconciling = Future<void>.value();

  set enabled(bool value) {
    if (_enabled == value && _started) return;
    _enabled = value;
    if (value) unawaited(_start());
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

  /// 第一次开启时初始化插件、接收端口与冷启动的点开。
  Future<void> _start() async {
    if (_started) return;
    _started = true;
    try {
      await gateway.initialize(
        texts: todoNotificationTextsOf(_l10n),
        onEvent: (TodoNotificationEvent event) =>
            unawaited(_handleAction(event)),
      );
      _port.open();
      final launch = await gateway.takeLaunchEvent();
      if (launch != null && !_disposed) unawaited(_handleAction(launch));
    } catch (error) {
      debugPrint('todo reminders: start failed: $error');
    }
    if (_disposed) return;
    _lifecycle = AppLifecycleListener(onResume: _scheduleReplan);
    if (AppPlatform.isDesktop) {
      _periodic = Timer.periodic(
        _desktopReplanInterval,
        (_) => _scheduleReplan(),
      );
    }
    _scheduleReplan();
  }

  void _scheduleReplan() {
    if (_disposed || !_started) return;
    _replan?.cancel();
    _replan = Timer(_replanDelay, () {
      _reconciling = _reconciling.then((_) => _reconcile());
    });
  }

  /// 立即重排（测试与调试用）；返回对账结束的 Future。
  @visibleForTesting
  Future<void> replanNow() {
    _replan?.cancel();
    return _reconciling = _reconciling.then((_) => _reconcile());
  }

  Future<void> _reconcile() async {
    if (_disposed) return;
    try {
      final pending = await gateway.pending();
      final todos = _todos;
      if (!_enabled || todos == null) {
        if (!_enabled) {
          for (final id in pending.keys) {
            await gateway.cancel(id);
          }
        }
        return;
      }
      final l10n = _l10n;
      // 正文里的星期、月日与时刻按界面语言格式化；调度器不在界面里，不能
      // 指望 MaterialApp 的本地化委托已经加载过这门语言的日期数据。
      await initializeDateFormatting(l10n.localeName);
      final today = DateUtils.dateOnly(now());
      final requests = <int, TodoNotificationRequest>{
        for (final reminder in planTodoReminders(
          todos: todos,
          now: now(),
          limit: AppPlatform.isIOS ? 60 : 200,
        ))
          reminder.id: TodoNotificationRequest(
            reminder: reminder,
            body: _body(l10n, reminder, today),
            languageCode: l10n.localeName,
            snoozeMinutes: _settings.snoozeMinutes,
            hideOnLockScreen: _settings.hideContentOnLockScreen,
          ),
      };
      for (final entry in pending.entries) {
        final wanted = requests[entry.key];
        if (wanted == null || wanted.payload != entry.value) {
          await gateway.cancel(entry.key);
        }
      }
      for (final request in requests.values) {
        if (pending[request.id] != request.payload) {
          await gateway.schedule(request);
        }
      }
    } catch (error) {
      debugPrint('todo reminders: reconcile failed: $error');
    }
  }

  /// 通知正文：这一次的截止日（与时刻），如“今天 15:00”“明天”；稍后提醒
  /// 且没有截止日时写“稍后提醒”。
  String _body(
    AppLocalizations l10n,
    PlannedReminder reminder,
    DateTime today,
  ) {
    final todo = _todos?.where((row) => row.todoId == reminder.todoId);
    final hasDue =
        todo != null && todo.isNotEmpty && todo.first.dueDate != null;
    if (!hasDue) return l10n.todoNotificationSnoozedBody;
    final date = TodoLabels.relativeDay(l10n, reminder.occurrence, today);
    final minute = reminder.dueMinute;
    if (minute == null) return date;
    final time = DateFormat.jm(
      l10n.localeName,
    ).format(DateTime(2000, 1, 1, minute ~/ 60, minute % 60));
    return l10n.todoDueWithTime(date, time);
  }

  Future<void> _handleAction(TodoNotificationEvent event) async {
    if (_disposed) return;
    if (event.action == TodoNotificationAction.open) {
      onOpen(event.todoId);
      return;
    }
    await applyTodoNotificationAction(database, event, now: now());
  }

  /// 第一次给待办加提醒时请求发通知的权限（每次运行只问一次）；返回系统
  /// 是否允许。
  Future<bool> ensurePermission() async {
    if (await gateway.notificationsEnabled()) return true;
    if (_permissionAsked) return false;
    _permissionAsked = true;
    return gateway.requestPermission();
  }

  void dispose() {
    _disposed = true;
    _replan?.cancel();
    _periodic?.cancel();
    _lifecycle?.dispose();
    _port.close();
  }
}
