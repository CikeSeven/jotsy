import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/todos/pages/todo_settings_page.dart';
import 'package:node_diary/ui/todos/providers/todo_reminder_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';
import '../../support/fake_todo_notifications.dart';

const _nativeChannel = MethodChannel('com.jotsy.diary/notifications');

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _nativeChannel,
      null,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> unmount(WidgetTester tester, AppDatabase database) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    debugDefaultTargetPlatformOverride = null;
    await tester.runAsync(database.close);
  }

  Future<AppDatabase> pumpSettings(
    WidgetTester tester, {
    required FakeTodoNotificationGateway gateway,
    Brightness brightness = Brightness.light,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final settings = await tester.runAsync(SettingsService.create);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((_) async => settings!),
          todoNotificationGatewayProvider.overrideWithValue(gateway),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          theme: expressiveTestTheme(brightness),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const TodoSettingsPage(),
        ),
      ),
    );
    await settle(tester);
    return database;
  }

  testWidgets(
    'Android settings expose exact alarm, battery optimization, and reliability actions',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final calls = <String>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(_nativeChannel, (
        call,
      ) async {
        calls.add(call.method);
        return switch (call.method) {
          'isIgnoringBatteryOptimizations' => false,
          'requestExactAlarmsPermission' => true,
          'requestIgnoreBatteryOptimizations' => true,
          'openAutoStartSettings' => true,
          _ => null,
        };
      });

      final gateway = FakeTodoNotificationGateway()
        ..enabled = true
        ..exact = false;
      final database = await pumpSettings(tester, gateway: gateway);
      try {
        expect(find.text('通知权限'), findsOneWidget);
        expect(find.text('系统限制了准时闹钟，提醒可能晚几分钟'), findsOneWidget);
        expect(find.text('电池优化'), findsOneWidget);
        expect(find.text('受限制，点按开启'), findsOneWidget);

        await tester.tap(find.text('通知权限'));
        await tester.pumpAndSettle();
        expect(calls, contains('requestExactAlarmsPermission'));

        await tester.ensureVisible(find.text('电池优化'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('电池优化'));
        await tester.pumpAndSettle();
        expect(calls, contains('requestIgnoreBatteryOptimizations'));

        await Scrollable.ensureVisible(
          tester.element(find.text('提醒不准时？')),
          alignment: 0.5,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('提醒不准时？'));
        await tester.pumpAndSettle();

        expect(find.text('闹钟和提醒权限'), findsOneWidget);
        expect(find.text('自启动与后台管理'), findsOneWidget);

        await tester.tap(find.text('自启动与后台管理'));
        await tester.pumpAndSettle();
        expect(calls, contains('openAutoStartSettings'));
      } finally {
        await unmount(tester, database);
      }
    },
  );

  testWidgets(
    'Todo settings and reliability sheet render cleanly in dark theme',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(_nativeChannel, (
        call,
      ) async {
        if (call.method == 'isIgnoringBatteryOptimizations') return true;
        return true;
      });

      final gateway = FakeTodoNotificationGateway()
        ..enabled = true
        ..exact = true;
      final database = await pumpSettings(
        tester,
        gateway: gateway,
        brightness: Brightness.dark,
      );
      try {
        expect(find.text('无限制'), findsOneWidget);
        await Scrollable.ensureVisible(
          tester.element(find.text('提醒不准时？')),
          alignment: 0.5,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('提醒不准时？'));
        await tester.pumpAndSettle();
        expect(find.text('已开启'), findsNWidgets(3));
      } finally {
        await unmount(tester, database);
      }
    },
  );
}
