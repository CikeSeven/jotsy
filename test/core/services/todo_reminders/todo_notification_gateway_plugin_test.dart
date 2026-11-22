import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/todo_reminders/todo_notification_gateway.dart';
import 'package:node_diary/core/services/todo_reminders/todo_notification_gateway_plugin.dart';
import 'package:node_diary/core/services/todo_reminders/todo_reminder_planner.dart';

const _channel = MethodChannel('dexterous.com/flutter/local_notifications');
const _texts = TodoNotificationTexts(
  channelName: 'Reminders',
  channelDescription: 'To-do reminders',
  complete: 'Complete',
  snooze: 'Snooze',
  open: 'Open',
);

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('an exact alarm rejected by Android is scheduled inexactly', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final modes = <String>[];
    final payloads = <String>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
      call,
    ) async {
      expect(call.method, 'zonedSchedule');
      final args = call.arguments as Map;
      final specifics = args['platformSpecifics'] as Map;
      modes.add(specifics['scheduleMode'] as String);
      payloads.add(args['payload'] as String);
      if (modes.length == 1) {
        throw PlatformException(code: 'exact_alarms_not_permitted');
      }
      return null;
    });
    final fireAt = DateTime.now().add(const Duration(minutes: 10));
    final request = TodoNotificationRequest(
      reminder: PlannedReminder(
        id: 42,
        todoId: 'todo',
        title: 'Pay electricity bill',
        occurrence: fireAt,
        dueMinute: null,
        fireAt: fireAt,
        snooze: true,
      ),
      body: 'Snoozed reminder',
      languageCode: 'en',
      snoozeMinutes: 10,
      hideOnLockScreen: true,
      androidExact: true,
    );

    await PluginTodoNotificationGateway.forBackground(_texts).schedule(request);

    expect(modes, ['exactAllowWhileIdle', 'inexactAllowWhileIdle']);
    expect(payloads, [request.payload, request.payloadForAlarmMode(false)]);
  });

  test('iOS initializes without asking for notification permission', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
      call,
    ) async {
      expect(call.method, 'initialize');
      expect(call.arguments['requestAlertPermission'], isFalse);
      expect(call.arguments['requestSoundPermission'], isFalse);
      // Darwin returns false when no permission was requested.
      return false;
    });

    await PluginTodoNotificationGateway().initialize(
      texts: _texts,
      onEvent: (_) {},
    );
  });
}
