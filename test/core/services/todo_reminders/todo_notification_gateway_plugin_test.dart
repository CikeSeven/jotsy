import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/todo_reminders/todo_notification_gateway.dart';
import 'package:node_diary/core/services/todo_reminders/todo_notification_gateway_plugin.dart';
import 'package:node_diary/core/services/todo_reminders/todo_reminder_planner.dart';

const _pluginChannel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);
const _nativeChannel = MethodChannel('com.jotsy.diary/notifications');
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
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _pluginChannel,
      null,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _nativeChannel,
      null,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  test('an exact alarm rejected by Android is scheduled inexactly', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final exactArgs = <bool>[];
    final payloads = <String>[];
    var canExact = true;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_nativeChannel, (
      call,
    ) async {
      switch (call.method) {
        case 'canScheduleExactAlarms':
          return canExact;
        case 'scheduleReminder':
          final args = call.arguments as Map;
          final exact = args['exact'] as bool;
          exactArgs.add(exact);
          payloads.add(args['payload'] as String);
          if (exactArgs.length == 1) {
            canExact = false;
            throw PlatformException(code: 'exact_alarms_not_permitted');
          }
          return null;
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

    expect(exactArgs, [true, false]);
    expect(payloads, [request.payload, request.payloadForAlarmMode(false)]);
  });

  test(
    'Android initialization migrates legacy plugin reminders and handles live actions',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      final cancelledLegacy = <int>[];
      final nativeCalls = <String>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(_pluginChannel, (
        call,
      ) async {
        switch (call.method) {
          case 'initialize':
            return true;
          case 'pendingNotificationRequests':
            return <Map<String, Object?>>[
              <String, Object?>{
                'id': 11,
                'title': 'Legacy todo',
                'body': 'Today',
                'payload': 'todo:{"t":"t1","o":"2026-11-26"}',
              },
              <String, Object?>{
                'id': 12,
                'title': 'Other',
                'body': 'Keep me',
                'payload': 'other:payload',
              },
            ];
          case 'cancel':
            cancelledLegacy.add((call.arguments as Map)['id'] as int);
            return null;
        }
        return null;
      });
      binding.defaultBinaryMessenger.setMockMethodCallHandler(_nativeChannel, (
        call,
      ) async {
        nativeCalls.add(call.method);
        if (call.method == 'initialize') return true;
        if (call.method == 'getPendingReminders') {
          return <Map<String, Object?>>[
            <String, Object?>{
              'id': 21,
              'payload': 'todo:{"t":"t2","o":"2026-11-27"}',
            },
          ];
        }
        if (call.method == 'notificationsEnabled') return true;
        if (call.method == 'canScheduleExactAlarms') return true;
        return null;
      });

      final events = <TodoNotificationEvent>[];
      final gateway = PluginTodoNotificationGateway();
      await gateway.initialize(texts: _texts, onEvent: events.add);

      expect(nativeCalls, contains('initialize'));
      expect(cancelledLegacy, [11]);
      expect(await gateway.pending(), <int, String>{
        21: 'todo:{"t":"t2","o":"2026-11-27"}',
      });
      expect(await gateway.notificationsEnabled(), isTrue);
      expect(await gateway.exactAlarmsAllowed(), isTrue);

      final actionEnvelope = const StandardMethodCodec().encodeMethodCall(
        const MethodCall('onNotificationAction', <String, Object?>{
          'actionId': 'todo.snooze.15',
          'payload': 'todo:{"t":"t2","o":"2026-11-27"}',
        }),
      );
      ByteData? reply;
      await binding.defaultBinaryMessenger.handlePlatformMessage(
        _nativeChannel.name,
        actionEnvelope,
        (data) => reply = data,
      );
      expect(const StandardMethodCodec().decodeEnvelope(reply!), isTrue);
      expect(events, hasLength(1));
      expect(events.single.action, TodoNotificationAction.snooze);
      expect(events.single.todoId, 't2');
      expect(events.single.snoozeMinutes, 15);
    },
  );

  test(
    'Android battery and auto-start helpers handle channel replies safely',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final calls = <String>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(_nativeChannel, (
        call,
      ) async {
        calls.add(call.method);
        return switch (call.method) {
          'isIgnoringBatteryOptimizations' => false,
          'requestIgnoreBatteryOptimizations' => true,
          'requestExactAlarmsPermission' => true,
          'openAutoStartSettings' => true,
          _ => null,
        };
      });

      expect(await isIgnoringTodoBatteryOptimizations(), isFalse);
      expect(await requestIgnoreTodoBatteryOptimizations(), isTrue);
      expect(await requestTodoExactAlarmPermission(), isTrue);
      expect(await openTodoAutoStartSettings(), isTrue);
      expect(calls, <String>[
        'isIgnoringBatteryOptimizations',
        'requestIgnoreBatteryOptimizations',
        'requestExactAlarmsPermission',
        'openAutoStartSettings',
      ]);

      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _nativeChannel,
        null,
      );
      expect(await isIgnoringTodoBatteryOptimizations(), isTrue);
      expect(await openTodoAutoStartSettings(), isFalse);
    },
  );

  test('iOS initializes without asking for notification permission', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_pluginChannel, (
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
