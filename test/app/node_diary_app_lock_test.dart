import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/node_diary_app.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/app_lock/widgets/app_lock_surface.dart';
import 'package:node_diary/ui/app_lock/widgets/passcode_dots.dart';
import 'package:node_diary/ui/app_lock/widgets/passcode_keypad.dart';
import 'package:node_diary/ui/app_lock/widgets/pattern_pad.dart';
import 'package:node_diary/ui/home/pages/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/app_lock/app_lock_test_support.dart';

/// 冷启动时应用锁按验证方式分流：应用密码在遮罩里输入（数字键盘或图案），
/// 系统验证弹系统框。测试环境的系统语言为英文，断言用英文文案。
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

Future<void> _tapKeys(WidgetTester tester, String digits) async {
  for (final digit in digits.split('')) {
    await tester.tap(
      find.descendant(
        of: find.byType(PasscodeKeypad),
        matching: find.text(digit),
      ),
    );
    await tester.pump();
  }
  await _settle(tester);
}

void main() {
  testWidgets('a PIN unlocks the app from the lock screen keypad', (
    tester,
  ) async {
    final auth = FakeBiometricAuth(hasBiometrics: false);
    await _pumpApp(
      tester,
      auth: auth,
      prefs: await presetPin('2580', appLock: true),
    );
    await _pumpUntil(tester, find.byType(AppLockSurface));
    await _settle(tester);
    expect(find.text('App Locked'), findsOneWidget);
    expect(
      find.text('Verify with your app passcode to continue'),
      findsOneWidget,
    );
    expect(tester.widget<PasscodeDots>(find.byType(PasscodeDots)).length, 4);
    // 不弹系统键盘：锁屏上没有输入框。
    expect(find.byType(TextField), findsNothing);
    expect(auth.reasons, isEmpty);

    await _tapKeys(tester, '1111');
    expect(find.text('Wrong passcode, try again'), findsOneWidget);
    expect(find.byType(AppLockSurface), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await _settle(tester);

    await _tapKeys(tester, '2580');
    expect(find.byType(AppLockSurface), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('a pattern lock screen shows the pattern pad', (tester) async {
    final auth = FakeBiometricAuth(hasBiometrics: false);
    await _pumpApp(
      tester,
      auth: auth,
      prefs: await presetPattern(<int>[0, 3, 6, 7], appLock: true),
    );
    await _pumpUntil(tester, find.byType(PatternPad));
    await _settle(tester);
    expect(find.byType(PasscodeKeypad), findsNothing);
    await drawPattern(tester, <int>[0, 3, 6, 7]);
    await _settle(tester);
    expect(find.byType(AppLockSurface), findsNothing);
    await _unmount(tester);
  });

  testWidgets('a fingerprint unlocks at once when enabled', (tester) async {
    final auth = FakeBiometricAuth(biometricResults: <bool>[true]);
    await _pumpApp(
      tester,
      auth: auth,
      prefs: await presetPin('258036', biometric: true, appLock: true),
    );
    await _pumpUntil(tester, find.byType(HomePage));
    await _settle(tester);
    expect(auth.biometricReasons, <String>[
      'Verify with your app passcode to continue',
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

  testWidgets('Linux keeps app lock with an app passcode', (tester) async {
    final auth = FakeBiometricAuth(supported: false, hasBiometrics: false);
    await _pumpApp(
      tester,
      auth: auth,
      prefs: await presetPin('2580', appLock: true),
    );
    await _pumpUntil(tester, find.byType(AppLockSurface));
    await _settle(tester);
    final settings = await tester.runAsync(SettingsService.create);
    expect(settings!.isAppLockEnabled, isTrue);
    await _unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
