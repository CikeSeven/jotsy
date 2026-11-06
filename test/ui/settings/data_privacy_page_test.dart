import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/app_lock/pages/app_lock_settings_page.dart';
import 'package:node_diary/ui/settings/pages/data_privacy_page.dart';

import '../app_lock/app_lock_test_support.dart';

void main() {
  testWidgets('the app lock entry shows the state and opens its page', (
    tester,
  ) async {
    final (settings, _) = await pumpAppLockApp(
      tester,
      home: const DataPrivacyPage(),
      auth: FakeBiometricAuth(),
      clock: TestClock(),
    );
    expect(find.text('应用锁与密码'), findsOneWidget);
    expect(find.text('未开启'), findsOneWidget);
    // 开关收进了三级页，这一页不再直接开关应用锁。
    expect(find.byType(SwitchListTile), findsNothing);

    await settings.setAppLockEnabled(true);
    await tester.pumpAndSettle();
    expect(find.text('已开启 · 系统验证'), findsOneWidget);

    await tester.tap(find.text('应用锁与密码'));
    await tester.pumpAndSettle();
    expect(find.byType(AppLockSettingsPage), findsOneWidget);
  });

  testWidgets('the entry names the app passcode when one is set', (
    tester,
  ) async {
    await pumpAppLockApp(
      tester,
      home: const DataPrivacyPage(),
      auth: FakeBiometricAuth(),
      clock: TestClock(),
      prefs: await presetPin('2580', appLock: true),
    );
    expect(find.text('已开启 · 应用密码'), findsOneWidget);
  });

  testWidgets('with app lock off an app passcode still shows', (tester) async {
    await pumpAppLockApp(
      tester,
      home: const DataPrivacyPage(),
      auth: FakeBiometricAuth(),
      clock: TestClock(),
      prefs: await presetPin('2580'),
    );
    expect(find.text('未开启 · 上锁的日记本使用应用密码'), findsOneWidget);
  });
}
