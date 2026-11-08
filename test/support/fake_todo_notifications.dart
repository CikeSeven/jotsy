import 'package:node_diary/core/services/todo_reminders/todo_notification_gateway.dart';

/// 不碰插件的通知网关：记下排了什么、取消了什么，测试可以模拟点开与按钮。
class FakeTodoNotificationGateway implements TodoNotificationGateway {
  final Map<int, TodoNotificationRequest> scheduled =
      <int, TodoNotificationRequest>{};
  final List<int> cancelled = <int>[];
  int scheduleCalls = 0;
  bool enabled = true;
  bool exact = true;
  int permissionRequests = 0;
  bool grantOnRequest = true;
  TodoNotificationEvent? launchEvent;
  void Function(TodoNotificationEvent event)? _onEvent;
  bool initialized = false;

  /// 模拟用户点开通知或按了按钮（应用在运行时）。
  void emit(TodoNotificationEvent event) => _onEvent?.call(event);

  @override
  Future<void> initialize({
    required TodoNotificationTexts texts,
    required void Function(TodoNotificationEvent event) onEvent,
  }) async {
    initialized = true;
    _onEvent = onEvent;
  }

  @override
  Future<TodoNotificationEvent?> takeLaunchEvent() async {
    final event = launchEvent;
    launchEvent = null;
    return event;
  }

  @override
  Future<bool> notificationsEnabled() async => enabled;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    if (grantOnRequest) enabled = true;
    return enabled;
  }

  @override
  Future<bool> exactAlarmsAllowed() async => exact;

  @override
  Future<Map<int, String>> pending() async => <int, String>{
    for (final entry in scheduled.entries) entry.key: entry.value.payload,
  };

  @override
  Future<void> schedule(TodoNotificationRequest request) async {
    scheduleCalls++;
    scheduled[request.id] = request;
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
  }
}
