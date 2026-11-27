import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_platform.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/todo_reminders/todo_notification_actions.dart';
import '../../../core/services/todo_reminders/todo_notification_gateway.dart';
import '../../../core/services/todo_reminders/todo_notification_gateway_desktop.dart';
import '../../../core/services/todo_reminders/todo_notification_gateway_plugin.dart';
import '../../settings/providers/app_features_provider.dart';
import '../controllers/todo_reminder_scheduler.dart';
import '../models/todo_settings.dart';
import '../models/todo_view.dart';
import 'todo_providers.dart';

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

/// 点通知要打开的待办（业务 id；每日摘要为空字符串）；首页消费后置回 null。
final todoNotificationOpenRequestProvider =
    NotifierProvider<TodoNotificationOpenRequest, String?>(
      TodoNotificationOpenRequest.new,
    );

/// Android / iOS 系统提醒权限与后台限制状态（不支持提醒的平台为 null）。
typedef TodoReminderSystemStatus = ({
  bool notifications,
  bool exact,
  bool ignoringBattery,
});

final todoReminderSystemStatusProvider =
    FutureProvider.autoDispose<TodoReminderSystemStatus?>((Ref ref) async {
      final gateway = ref.watch(todoNotificationGatewayProvider);
      if (gateway == null) return null;
      return (
        notifications: await gateway.notificationsEnabled(),
        exact: await gateway.exactAlarmsAllowed(),
        ignoringBattery: await isIgnoringTodoBatteryOptimizations(),
      );
    });

class TodoNotificationOpenRequest extends Notifier<String?> {
  @override
  String? build() => null;

  void request(String todoId) => state = todoId;

  void consume() => state = null;
}

/// 要待办页换到的视图（点每日摘要通知时为“今天”，由首页发出）；待办页
/// 消费后置回 null。待办页还没建好时请求留着，建好时接住。
final todoViewRequestProvider = NotifierProvider<TodoViewRequest, TodoView?>(
  TodoViewRequest.new,
);

class TodoViewRequest extends Notifier<TodoView?> {
  @override
  TodoView? build() => null;

  void request(TodoView view) => state = view;

  void consume() => state = null;
}

/// 待办提醒的调度器（由 `NodeDiaryApp` 常驻监听，整个应用生命周期只有一份）。
///
/// 输入为功能开关、待办偏好、界面语言与未完成待办。Drift 查询流涵盖本机编辑、
/// 局域网同步与备份恢复。输入变化、回到前台或定期巡检会按规划器
/// 与系统队列串行对账。功能关闭时取消全部待办通知。
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
  ref.listen<bool>(appFeaturesProvider.select((features) => features.todos), (
    _,
    bool enabled,
  ) {
    if (ref.read(settingsServiceProvider).asData != null) {
      scheduler.enabled = enabled;
    }
  }, fireImmediately: true);
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
  VoidCallback? removeLocaleListener;
  ref.onDispose(() => removeLocaleListener?.call());
  ref.listen<AsyncValue<SettingsService>>(settingsServiceProvider, (_, next) {
    final settings = next.asData?.value;
    if (settings == null) return;
    // 设置就绪前的默认开关是 false，不能因此撤掉上次运行已排好的提醒。
    scheduler.enabled = ref.read(appFeaturesProvider).todos;
    removeLocaleListener?.call();
    final locale = settings.localeNotifier;
    void onLocale() => scheduler.locale = locale.value;
    locale.addListener(onLocale);
    removeLocaleListener = () => locale.removeListener(onLocale);
    onLocale();
  }, fireImmediately: true);
  return scheduler;
});
