import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/node_diary_app.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/app_lock/widgets/app_lock_surface.dart';
import 'package:node_diary/ui/home/pages/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/app_lock/app_lock_test_support.dart';

/// 冷启动时应用锁按验证方式分流：应用密码在遮罩里输入，系统验证弹系统框。
/// 测试环境的系统语言为英文，断言用英文文案。
Future<void> _pumpApp(
  WidgetTester tester, {
  required FakeBiometricAuth auth,
  required Map<String, Object> prefs,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(database.close);
  final settings = await SettingsService.create();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        ...appLockOverrides(auth: auth, clock: TestClock(), settings: settings),
      ],
      child: const NodeDiaryApp(),
    ),
  );
}

/// 推进到 [finder] 出现（启动要等内存库与设置）。
Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var frame = 0; frame < 120; frame++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  fail('$finder never appeared');
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

void main() {
  testWidgets('an app password unlocks the app from the lock screen', (
    tester,
  ) async {
    final auth = FakeBiometricAuth(hasBiometrics: false);
    await _pumpApp(
      tester,
      auth: auth,
      prefs: await presetPassword('Secret12', appLock: true),
    );
    await _pumpUntil(tester, find.byType(AppLockSurface));
    await _settle(tester);
    expect(find.text('App Locked'), findsOneWidget);
    expect(find.text('Enter the app password to continue'), findsOneWidget);
    expect(auth.reasons, isEmpty);

    await tester.enterText(find.byType(TextField), 'wrong');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
    await _settle(tester);
    expect(find.text('Wrong password. Try again.'), findsOneWidget);
    expect(find.byType(AppLockSurface), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Secret12');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
    await _settle(tester);
    expect(find.byType(AppLockSurface), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('a fingerprint unlocks at once when enabled', (tester) async {
    final auth = FakeBiometricAuth(biometricResults: <bool>[true]);
    await _pumpApp(
      tester,
      auth: auth,
      prefs: await presetPassword('Secret12', biometric: true, appLock: true),
    );
    await _pumpUntil(tester, find.byType(HomePage));
    await _settle(tester);
    expect(auth.biometricReasons, <String>[
      'Enter the app password to continue',
    ]);
    expect(find.byType(AppLockSurface), findsNothing);
    expect(auth.reasons, isEmpty);
    await _unmount(tester);
  });

  testWidgets('system verification still uses the system prompt', (
    tester,
  ) async {
    final auth = FakeBiometricAuth(results: <bool>[true]);
    await _pumpApp(
      tester,
      auth: auth,
      prefs: <String, Object>{'app.settings.app_lock_enabled': true},
    );
    await _pumpUntil(tester, find.byType(HomePage));
    await _settle(tester);
    expect(auth.reasons, <String>['Please authenticate to unlock the app']);
    expect(find.byType(AppLockSurface), findsNothing);
    expect(find.text('App Locked'), findsNothing);
    await _unmount(tester);
  });

  testWidgets('Linux keeps app lock with an app password', (tester) async {
    final auth = FakeBiometricAuth(supported: false, hasBiometrics: false);
    await _pumpApp(
      tester,
      auth: auth,
      prefs: await presetPassword('Secret12', appLock: true),
    );
    await _pumpUntil(tester, find.byType(AppLockSurface));
    await _settle(tester);
    final settings = await tester.runAsync(SettingsService.create);
    expect(settings!.isAppLockEnabled, isTrue);
    await _unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
