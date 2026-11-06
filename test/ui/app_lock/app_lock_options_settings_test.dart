import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/app_lock/models/app_lock_options.dart';
import 'package:node_diary/ui/app_lock/pages/app_lock_settings_page.dart';
import 'package:node_diary/ui/app_lock/providers/app_lock_options_provider.dart';
import 'package:node_diary/ui/widgets/expressive_choice_tile.dart';

import 'app_lock_test_support.dart';

const String _lockEnabledKey = 'app.settings.app_lock_enabled';
const String _optionsKey = 'app.settings.app_lock_options';

/// 设置页较长：用高一些的窗口，整页一次排完。
void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required FakeBiometricAuth auth,
  Map<String, Object> prefs = const <String, Object>{},
}) async {
  _tallView(tester);
  final (_, container) = await pumpAppLockApp(
    tester,
    home: const AppLockSettingsPage(),
    auth: auth,
    clock: TestClock(),
    prefs: prefs,
  );
  return container;
}

SwitchListTile _switch(WidgetTester tester, String title) =>
    tester.widget(find.widgetWithText(SwitchListTile, title));

Future<void> _choose(WidgetTester tester, String row, String option) async {
  await tester.tap(find.text(row));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ExpressiveChoiceTile, option));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lock timing rows show under the switch only while it is on', (
    tester,
  ) async {
    final auth = FakeBiometricAuth(results: <bool>[true]);
    await _pump(
      tester,
      auth: auth,
      prefs: const <String, Object>{_lockEnabledKey: true},
    );
    expect(find.text('离开应用后上锁'), findsOneWidget);
    expect(find.text('从不（只在打开应用时）'), findsOneWidget);
    expect(find.text('锁屏时上锁'), findsOneWidget);
    expect(find.text('自动弹出验证'), findsOneWidget);
    // 闲置时上锁只在桌面。
    expect(find.text('闲置时上锁'), findsNothing);
    expect(find.text('防截屏'), findsOneWidget);

    await tester.tap(find.widgetWithText(SwitchListTile, '应用锁'));
    await tester.pumpAndSettle();
    expect(auth.reasons, <String>['请验证身份后关闭应用锁']);
    expect(find.text('离开应用后上锁'), findsNothing);
    expect(find.text('锁屏时上锁'), findsNothing);
    // 防截屏与应用锁开关无关。
    expect(find.text('防截屏'), findsOneWidget);
  });

  testWidgets('locking sooner saves at once; relaxing asks to verify first', (
    tester,
  ) async {
    final auth = FakeBiometricAuth(results: <bool>[true]);
    final container = await _pump(
      tester,
      auth: auth,
      prefs: const <String, Object>{_lockEnabledKey: true},
    );

    await _choose(tester, '离开应用后上锁', '1 分钟后');
    expect(auth.reasons, isEmpty);
    expect(
      container.read(appLockOptionsProvider).afterLeaving,
      AppLockAfterLeaving.minutes1,
    );
    expect(find.text('1 分钟后'), findsOneWidget);

    await _choose(tester, '离开应用后上锁', '从不（只在打开应用时）');
    expect(auth.reasons, <String>['验证身份以放宽应用锁']);
    expect(
      container.read(appLockOptionsProvider).afterLeaving,
      AppLockAfterLeaving.never,
    );
  });

  testWidgets('a failed check keeps the stricter setting', (tester) async {
    final auth = FakeBiometricAuth(results: <bool>[false]);
    final container = await _pump(
      tester,
      auth: auth,
      prefs: <String, Object>{
        _lockEnabledKey: true,
        _optionsKey: const AppLockOptions(onScreenOff: true).encode(),
      },
    );
    expect(_switch(tester, '锁屏时上锁').value, isTrue);

    await tester.tap(find.widgetWithText(SwitchListTile, '锁屏时上锁'));
    await tester.pumpAndSettle();
    expect(auth.reasons, <String>['验证身份以放宽应用锁']);
    expect(find.text('验证未通过，设置没有改变'), findsOneWidget);
    expect(container.read(appLockOptionsProvider).onScreenOff, isTrue);
    expect(_switch(tester, '锁屏时上锁').value, isTrue);
  });

  testWidgets('with app lock off the privacy switch needs no check', (
    tester,
  ) async {
    final auth = FakeBiometricAuth();
    final container = await _pump(tester, auth: auth);

    await tester.tap(find.widgetWithText(SwitchListTile, '防截屏'));
    await tester.pumpAndSettle();
    expect(container.read(appLockOptionsProvider).secureScreen, isTrue);
    await tester.tap(find.widgetWithText(SwitchListTile, '防截屏'));
    await tester.pumpAndSettle();
    expect(container.read(appLockOptionsProvider).secureScreen, isFalse);
    expect(auth.reasons, isEmpty);
  });

  testWidgets('desktop offers idle locking instead of screen lock', (
    tester,
  ) async {
    final auth = FakeBiometricAuth(supported: false, hasBiometrics: false);
    final container = await _pump(
      tester,
      auth: auth,
      prefs: await presetPin('2580', appLock: true),
    );
    expect(find.text('闲置时上锁'), findsOneWidget);
    expect(find.text('关闭'), findsOneWidget);
    expect(find.text('锁屏时上锁'), findsNothing);
    expect(find.text('防截屏'), findsNothing);

    await _choose(tester, '闲置时上锁', '5 分钟后');
    expect(
      container.read(appLockOptionsProvider).whenIdle,
      AppLockWhenIdle.minutes5,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
