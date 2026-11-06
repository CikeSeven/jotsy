import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_passcode/app_passcode_store.dart';
import 'package:node_diary/ui/app_lock/pages/app_lock_settings_page.dart';
import 'package:node_diary/ui/app_lock/pages/passcode_setup_page.dart';
import 'package:node_diary/ui/app_lock/pages/passcode_verify_page.dart';
import 'package:node_diary/ui/app_lock/widgets/passcode_dots.dart';
import 'package:node_diary/ui/app_lock/widgets/pattern_pad.dart';
import 'package:node_diary/ui/widgets/expressive_choice_tile.dart';

import 'app_lock_test_support.dart';

ExpressiveChoiceTile _choice(WidgetTester tester, String label) =>
    tester.widget<ExpressiveChoiceTile>(
      find.widgetWithText(ExpressiveChoiceTile, label),
    );

SwitchListTile _appLockSwitch(WidgetTester tester) =>
    tester.widget(find.widgetWithText(SwitchListTile, '应用锁'));

Future<void> _openSetup(WidgetTester tester) async {
  await tester.tap(find.text('应用密码'));
  await tester.pumpAndSettle();
  expect(find.byType(PasscodeSetupPage), findsOneWidget);
}

void main() {
  testWidgets('switching to an app passcode verifies first, then sets a PIN', (
    tester,
  ) async {
    final auth = FakeBiometricAuth(results: <bool>[true]);
    final (_, container) = await pumpAppLockApp(
      tester,
      home: const AppLockSettingsPage(),
      auth: auth,
      clock: TestClock(),
    );
    expect(_choice(tester, '系统验证').selected, isTrue);
    expect(find.text('修改应用密码'), findsNothing);

    await _openSetup(tester);
    expect(auth.reasons, <String>['验证身份以改用应用密码']);
    expect(find.text('设置数字密码'), findsOneWidget);
    expect(find.text('输入 6 位数字'), findsOneWidget);
    expect(find.textContaining('无法找回'), findsOneWidget);

    await tapDigits(tester, '258036');
    expect(find.text('再输入一次'), findsOneWidget);
    expect(container.read(appPasscodeConfigProvider).hasPasscode, isFalse);
    await tapDigits(tester, '258036');
    expect(find.byType(PasscodeSetupPage), findsNothing);
    expect(find.text('已设置应用密码'), findsOneWidget);

    final config = container.read(appPasscodeConfigProvider);
    expect(config.method, AppVerificationMethod.passcode);
    expect(config.kind, AppPasscodeKind.pin);
    expect(config.pinLength, 6);
    // 设备有指纹时首次设置默认开启快捷解锁。
    expect(config.biometric, isTrue);
    expect(_choice(tester, '应用密码').selected, isTrue);
    expect(find.text('修改应用密码'), findsOneWidget);
    expect(find.text('当前：6 位数字'), findsOneWidget);
    expect(find.text('指纹 / 面容快速解锁'), findsOneWidget);
  });

  testWidgets('a failed system check keeps system verification', (
    tester,
  ) async {
    final auth = FakeBiometricAuth(results: <bool>[false]);
    final (_, container) = await pumpAppLockApp(
      tester,
      home: const AppLockSettingsPage(),
      auth: auth,
      clock: TestClock(),
    );
    await tester.tap(find.text('应用密码'));
    await tester.pumpAndSettle();
    expect(find.byType(PasscodeSetupPage), findsNothing);
    expect(find.text('验证未通过，验证方式没有改变'), findsOneWidget);
    expect(container.read(appPasscodeConfigProvider).hasPasscode, isFalse);
  });

  testWidgets('a mismatch starts over and back returns to the first step', (
    tester,
  ) async {
    final auth = FakeBiometricAuth(results: <bool>[true]);
    final (_, container) = await pumpAppLockApp(
      tester,
      home: const AppLockSettingsPage(),
      auth: auth,
      clock: TestClock(),
    );
    await _openSetup(tester);
    await tapDigits(tester, '111111');
    await tapDigits(tester, '222222');
    expect(find.text('两次不一致，请重新设置'), findsOneWidget);
    expect(find.text('设置数字密码'), findsOneWidget);
    await waitRejectHold(tester);
    expect(container.read(appPasscodeConfigProvider).hasPasscode, isFalse);

    // 第二步按返回回到第一步，而不是离开页面。
    await tapDigits(tester, '333333');
    expect(find.text('再输入一次'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(PasscodeSetupPage), findsOneWidget);
    expect(find.text('设置数字密码'), findsOneWidget);
    expect(tester.widget<PasscodeDots>(find.byType(PasscodeDots)).filled, 0);
  });

  testWidgets('the setup page can switch to 4 digits or a pattern', (
    tester,
  ) async {
    final auth = FakeBiometricAuth(results: <bool>[true]);
    final (_, container) = await pumpAppLockApp(
      tester,
      home: const AppLockSettingsPage(),
      auth: auth,
      clock: TestClock(),
    );
    await _openSetup(tester);
    await tester.tap(find.text('4 位数字'));
    await tester.pumpAndSettle();
    expect(tester.widget<PasscodeDots>(find.byType(PasscodeDots)).length, 4);

    await tester.tap(find.text('图案'));
    await tester.pumpAndSettle();
    expect(find.text('设置解锁图案'), findsOneWidget);
    expect(find.byType(PatternPad), findsOneWidget);
    await drawPattern(tester, <int>[0, 1, 2]);
    expect(find.text('点太少了，至少连接 4 个点'), findsOneWidget);
    await waitRejectHold(tester);

    await drawPattern(tester, <int>[6, 3, 0, 1, 2]);
    expect(find.text('再画一次'), findsOneWidget);
    await drawPattern(tester, <int>[6, 3, 0, 1, 2]);
    expect(find.byType(PasscodeSetupPage), findsNothing);
    final config = container.read(appPasscodeConfigProvider);
    expect(config.kind, AppPasscodeKind.pattern);
    expect(find.text('当前：图案'), findsOneWidget);
    final store = await container.read(appPasscodeStoreProvider.future);
    expect(
      (await store.verify('6-3-0-1-2')).status,
      AppPasscodeCheckStatus.accepted,
    );
  });

  testWidgets('switching back to system verification needs the passcode', (
    tester,
  ) async {
    final auth = FakeBiometricAuth(biometricResults: <bool>[true]);
    final (_, container) = await pumpAppLockApp(
      tester,
      home: const AppLockSettingsPage(),
      auth: auth,
      clock: TestClock(),
      prefs: await presetPin('2580', biometric: true),
    );
    await tester.tap(find.text('系统验证'));
    await tester.pumpAndSettle();
    expect(find.byType(PasscodeVerifyPage), findsOneWidget);
    // 敏感操作不弹指纹、也不给指纹键。
    expect(auth.biometricReasons, isEmpty);

    await tapDigits(tester, '2580');
    expect(find.text('已改用系统验证，应用密码已清除'), findsOneWidget);
    expect(container.read(appPasscodeConfigProvider).hasPasscode, isFalse);
    expect(_choice(tester, '系统验证').selected, isTrue);
    expect(find.text('修改应用密码'), findsNothing);
  });

  testWidgets('switching to system verification needs a screen lock', (
    tester,
  ) async {
    final auth = FakeBiometricAuth(supported: false);
    final (_, container) = await pumpAppLockApp(
      tester,
      home: const AppLockSettingsPage(),
      auth: auth,
      clock: TestClock(),
      prefs: await presetPin('2580'),
    );
    await tester.tap(find.text('系统验证'));
    await tester.pumpAndSettle();
    expect(find.byType(PasscodeVerifyPage), findsNothing);
    expect(find.text('这台设备不能使用系统验证（没有设置锁屏密码）'), findsOneWidget);
    expect(container.read(appPasscodeConfigProvider).hasPasscode, isTrue);
  });

  testWidgets('changing the passcode asks for the current one first', (
    tester,
  ) async {
    final auth = FakeBiometricAuth();
    final (_, container) = await pumpAppLockApp(
      tester,
      home: const AppLockSettingsPage(),
      auth: auth,
      clock: TestClock(),
      prefs: await presetPin('2580'),
    );
    await tester.tap(find.text('修改应用密码'));
    await tester.pumpAndSettle();
    expect(find.text('验证当前密码以修改应用密码'), findsOneWidget);
    await tapDigits(tester, '2580');
    expect(find.byType(PasscodeSetupPage), findsOneWidget);
    // 修改时默认选中原来的形式（4 位）。
    expect(tester.widget<PasscodeDots>(find.byType(PasscodeDots)).length, 4);
    await tapDigits(tester, '1397');
    await tapDigits(tester, '1397');
    expect(find.text('已修改应用密码'), findsOneWidget);
    final store = await container.read(appPasscodeStoreProvider.future);
    expect(
      (await store.verify('1397')).status,
      AppPasscodeCheckStatus.accepted,
    );
  });

  testWidgets('turning off app lock with an app passcode asks for it', (
    tester,
  ) async {
    final auth = FakeBiometricAuth();
    final (settings, _) = await pumpAppLockApp(
      tester,
      home: const AppLockSettingsPage(),
      auth: auth,
      clock: TestClock(),
      prefs: await presetPin('2580', appLock: true),
    );
    expect(_appLockSwitch(tester).value, isTrue);
    await tester.tap(find.widgetWithText(SwitchListTile, '应用锁'));
    await tester.pumpAndSettle();
    await tapDigits(tester, '2580');
    expect(settings.isAppLockEnabled, isFalse);
    expect(auth.reasons, isEmpty);
  });

  testWidgets('enabling app lock without a way to verify explains why', (
    tester,
  ) async {
    final auth = FakeBiometricAuth(supported: false);
    final (settings, _) = await pumpAppLockApp(
      tester,
      home: const AppLockSettingsPage(),
      auth: auth,
      clock: TestClock(),
    );
    await tester.tap(find.widgetWithText(SwitchListTile, '应用锁'));
    await tester.pumpAndSettle();
    expect(find.textContaining('可以改用应用密码'), findsOneWidget);
    expect(settings.isAppLockEnabled, isFalse);
  });

  testWidgets('turning on fingerprint unlock checks the fingerprint', (
    tester,
  ) async {
    final auth = FakeBiometricAuth(biometricResults: <bool>[false, true]);
    final (_, container) = await pumpAppLockApp(
      tester,
      home: const AppLockSettingsPage(),
      auth: auth,
      clock: TestClock(),
      prefs: await presetPin('2580'),
    );
    final biometric = find.widgetWithText(SwitchListTile, '指纹 / 面容快速解锁');
    await tester.tap(biometric);
    await tester.pumpAndSettle();
    expect(find.text('指纹或面容验证未通过'), findsOneWidget);
    expect(container.read(appPasscodeConfigProvider).biometric, isFalse);

    await tester.tap(biometric);
    await tester.pumpAndSettle();
    expect(container.read(appPasscodeConfigProvider).biometric, isTrue);

    // 关闭不用验证。
    await tester.tap(biometric);
    await tester.pumpAndSettle();
    expect(container.read(appPasscodeConfigProvider).biometric, isFalse);
    expect(auth.biometricReasons, hasLength(2));
  });

  testWidgets('Linux can only use an app passcode and locks once it is set', (
    tester,
  ) async {
    final auth = FakeBiometricAuth(supported: false, hasBiometrics: false);
    final (settings, _) = await pumpAppLockApp(
      tester,
      home: const AppLockSettingsPage(),
      auth: auth,
      clock: TestClock(),
    );
    expect(_choice(tester, '系统验证').onTap, isNull);
    expect(find.text('这台设备没有系统验证'), findsOneWidget);
    expect(_appLockSwitch(tester).onChanged, isNull);
    expect(find.text('这台设备没有系统验证，请先在下方设置应用密码'), findsOneWidget);

    await _openSetup(tester);
    // 没有系统验证：直接设置，不先弹系统验证。
    expect(auth.reasons, isEmpty);
    await tapDigits(tester, '258036');
    await tapDigits(tester, '258036');
    expect(find.text('指纹 / 面容快速解锁'), findsNothing);

    expect(_appLockSwitch(tester).onChanged, isNotNull);
    await tester.tap(find.widgetWithText(SwitchListTile, '应用锁'));
    await tester.pumpAndSettle();
    expect(settings.isAppLockEnabled, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
