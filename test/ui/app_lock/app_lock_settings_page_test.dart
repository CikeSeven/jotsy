import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_password/app_password_store.dart';
import 'package:node_diary/ui/app_lock/pages/app_lock_settings_page.dart';
import 'package:node_diary/ui/app_lock/pages/app_password_setup_page.dart';
import 'package:node_diary/ui/app_lock/pages/app_password_verify_page.dart';
import 'package:node_diary/ui/widgets/expressive_choice_tile.dart';

import 'app_lock_test_support.dart';

ExpressiveChoiceTile _choice(WidgetTester tester, String label) =>
    tester.widget<ExpressiveChoiceTile>(
      find.widgetWithText(ExpressiveChoiceTile, label),
    );

SwitchListTile _appLockSwitch(WidgetTester tester) =>
    tester.widget(find.widgetWithText(SwitchListTile, '应用锁'));

Future<void> _setPassword(WidgetTester tester, String password) async {
  await enterPassword(tester, password, button: '下一步');
  await enterPassword(tester, password, button: '完成');
}

void main() {
  testWidgets('switching to an app password verifies first, then sets it', (
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

    await tester.tap(find.text('应用密码'));
    await tester.pumpAndSettle();
    expect(auth.reasons, <String>['请验证身份后改用应用密码']);
    expect(find.byType(AppPasswordSetupPage), findsOneWidget);
    expect(find.text('输入新密码'), findsOneWidget);
    expect(find.textContaining('无法找回'), findsOneWidget);

    await _setPassword(tester, 'Diary2026');
    expect(find.byType(AppPasswordSetupPage), findsNothing);
    expect(find.text('应用密码已设置'), findsOneWidget);
    final config = container.read(appPasswordConfigProvider);
    expect(config.method, AppVerificationMethod.password);
    // 设备有指纹时首次设置默认开启快捷解锁。
    expect(config.biometric, isTrue);
    expect(_choice(tester, '应用密码').selected, isTrue);
    expect(find.text('修改应用密码'), findsOneWidget);
    expect(find.text('指纹 / 面容解锁'), findsOneWidget);
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
    expect(find.byType(AppPasswordSetupPage), findsNothing);
    expect(find.text('身份验证未通过，验证方式没有改变。'), findsOneWidget);
    expect(container.read(appPasswordConfigProvider).hasPassword, isFalse);
  });

  testWidgets('the setup page checks the rules and the confirmation', (
    tester,
  ) async {
    final auth = FakeBiometricAuth(results: <bool>[true]);
    final (_, container) = await pumpAppLockApp(
      tester,
      home: const AppLockSettingsPage(),
      auth: auth,
      clock: TestClock(),
    );
    await tester.tap(find.text('应用密码'));
    await tester.pumpAndSettle();

    await enterPassword(tester, 'abc', button: '下一步');
    expect(find.text('至少 4 位'), findsOneWidget);
    await enterPassword(tester, 'ab cd', button: '下一步');
    expect(find.text('不能包含空格'), findsOneWidget);
    await enterPassword(tester, 'a' * 17, button: '下一步');
    expect(find.text('最多 16 位'), findsOneWidget);

    await enterPassword(tester, 'first1', button: '下一步');
    expect(find.text('再输入一次'), findsOneWidget);
    await enterPassword(tester, 'second2', button: '完成');
    expect(find.text('两次输入不一致，请重新设置'), findsOneWidget);
    expect(find.text('输入新密码'), findsOneWidget);
    expect(container.read(appPasswordConfigProvider).hasPassword, isFalse);

    // 第二步按返回回到第一步，而不是离开页面。
    await enterPassword(tester, 'first1', button: '下一步');
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(AppPasswordSetupPage), findsOneWidget);
    expect(find.text('输入新密码'), findsOneWidget);
  });

  testWidgets('switching back to system verification needs the password', (
    tester,
  ) async {
    final auth = FakeBiometricAuth(biometricResults: <bool>[true]);
    final (_, container) = await pumpAppLockApp(
      tester,
      home: const AppLockSettingsPage(),
      auth: auth,
      clock: TestClock(),
      prefs: await presetPassword('Secret12', biometric: true),
    );
    await tester.tap(find.text('系统验证'));
    await tester.pumpAndSettle();
    expect(find.byType(AppPasswordVerifyPage), findsOneWidget);
    // 敏感操作不弹指纹、也不给指纹按钮。
    expect(auth.biometricReasons, isEmpty);
    expect(find.text('使用指纹或面容'), findsNothing);

    await enterPassword(tester, 'Secret12');
    expect(find.text('已改用系统验证'), findsOneWidget);
    expect(container.read(appPasswordConfigProvider).hasPassword, isFalse);
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
      prefs: await presetPassword('Secret12'),
    );
    await tester.tap(find.text('系统验证'));
    await tester.pumpAndSettle();
    expect(find.byType(AppPasswordVerifyPage), findsNothing);
    expect(find.text('这台设备不能使用系统验证（没有设置锁屏密码）。'), findsOneWidget);
    expect(container.read(appPasswordConfigProvider).hasPassword, isTrue);
  });

  testWidgets('changing the password asks for the current one', (tester) async {
    final auth = FakeBiometricAuth();
    final (_, container) = await pumpAppLockApp(
      tester,
      home: const AppLockSettingsPage(),
      auth: auth,
      clock: TestClock(),
      prefs: await presetPassword('Secret12'),
    );
    await tester.tap(find.text('修改应用密码'));
    await tester.pumpAndSettle();
    expect(find.text('输入当前的应用密码'), findsOneWidget);
    await enterPassword(tester, 'Secret12');
    expect(find.text('修改应用密码'), findsWidgets);
    await _setPassword(tester, 'Newer123');
    expect(find.text('应用密码已修改'), findsOneWidget);
    final store = await container.read(appPasswordStoreProvider.future);
    expect(
      (await store.verify('Newer123')).status,
      AppPasswordCheckStatus.accepted,
    );
  });

  testWidgets('turning off app lock with an app password asks for it', (
    tester,
  ) async {
    final auth = FakeBiometricAuth();
    final (settings, _) = await pumpAppLockApp(
      tester,
      home: const AppLockSettingsPage(),
      auth: auth,
      clock: TestClock(),
      prefs: await presetPassword('Secret12', appLock: true),
    );
    expect(_appLockSwitch(tester).value, isTrue);
    await tester.tap(find.widgetWithText(SwitchListTile, '应用锁'));
    await tester.pumpAndSettle();
    await enterPassword(tester, 'Secret12');
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
    expect(find.textContaining('现在无法验证身份'), findsOneWidget);
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
      prefs: await presetPassword('Secret12'),
    );
    final biometric = find.widgetWithText(SwitchListTile, '指纹 / 面容解锁');
    await tester.tap(biometric);
    await tester.pumpAndSettle();
    expect(find.text('未能验证指纹或面容'), findsOneWidget);
    expect(container.read(appPasswordConfigProvider).biometric, isFalse);

    await tester.tap(biometric);
    await tester.pumpAndSettle();
    expect(container.read(appPasswordConfigProvider).biometric, isTrue);

    // 关闭不用验证。
    await tester.tap(biometric);
    await tester.pumpAndSettle();
    expect(container.read(appPasswordConfigProvider).biometric, isFalse);
    expect(auth.biometricReasons, hasLength(2));
  });

  testWidgets('Linux can only use an app password and locks once it is set', (
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
    expect(find.text('这台设备没有系统验证，设置应用密码后才能开启'), findsOneWidget);

    await tester.tap(find.text('应用密码'));
    await tester.pumpAndSettle();
    // 没有系统验证：直接设置，不先弹系统验证。
    expect(auth.reasons, isEmpty);
    await _setPassword(tester, 'Linux123');
    expect(find.text('指纹 / 面容解锁'), findsNothing);

    expect(_appLockSwitch(tester).onChanged, isNotNull);
    await tester.tap(find.widgetWithText(SwitchListTile, '应用锁'));
    await tester.pumpAndSettle();
    expect(settings.isAppLockEnabled, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
