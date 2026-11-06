import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/app_lock/controllers/app_lock_controller.dart';
import 'package:node_diary/ui/app_lock/controllers/identity_verifier.dart';
import 'package:node_diary/ui/app_lock/models/app_lock_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_lock_test_support.dart';

/// 系统验证可以挂起不返回（模拟手机锁屏密码页还开着）。
class PendingDeviceAuth extends FakeBiometricAuth {
  PendingDeviceAuth({super.results});

  Completer<bool>? pending;

  @override
  Future<bool> authenticate({
    required String reason,
    bool persistAcrossBackgrounding = true,
  }) {
    final pending = this.pending;
    if (pending != null) {
      reasons.add(reason);
      return pending.future;
    }
    return super.authenticate(
      reason: reason,
      persistAcrossBackgrounding: persistAcrossBackgrounding,
    );
  }
}

class _Harness {
  _Harness(this.controller, this.settings, this.platform, this.verifier);

  final AppLockController controller;
  final SettingsService settings;
  final FakeAppLockPlatform platform;
  final IdentityVerifier verifier;
  int unlockedCount = 0;
}

Future<_Harness> _setUp(
  WidgetTester tester, {
  required FakeBiometricAuth auth,
  required TestClock clock,
  AppLockOptions options = AppLockOptions.defaults,
  bool enabled = true,
  Map<String, Object> prefs = const <String, Object>{},
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'app.settings.app_lock_enabled': enabled,
    ...prefs,
  });
  final settings = await SettingsService.create();
  final container = ProviderContainer(
    overrides: appLockOverrides(auth: auth, clock: clock, settings: settings),
  );
  addTearDown(container.dispose);
  final platform = FakeAppLockPlatform();
  final verifier = container.read(identityVerifierProvider);
  late final _Harness harness;
  final controller = AppLockController(
    verifier: verifier,
    settings: settings,
    platform: platform,
    options: options,
    authReason: () => '解锁应用',
    clock: clock.call,
    onUnlocked: () => harness.unlockedCount++,
  );
  harness = _Harness(controller, settings, platform, verifier);
  addTearDown(controller.dispose);
  return harness;
}

/// 切到后台：resumed → inactive → hidden → paused。
Future<void> _leave(WidgetTester tester) async {
  for (final state in <AppLifecycleState>[
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
}

/// 回到前台：paused → hidden → inactive → resumed。
Future<void> _comeBack(WidgetTester tester) async {
  for (final state in <AppLifecycleState>[
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
}

/// 冷启动检查并通过系统验证。
Future<void> _startUnlocked(WidgetTester tester, _Harness h) async {
  h.controller.start();
  await tester.pump();
  expect(h.controller.locked, isFalse);
}

void main() {
  setUp(() {
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  });

  testWidgets('cold start locks, prompts and unlocks on success', (
    tester,
  ) async {
    final auth = FakeBiometricAuth(results: <bool>[true]);
    final h = await _setUp(tester, auth: auth, clock: TestClock());
    h.controller.start();
    expect(h.controller.locked, isTrue);
    expect(h.controller.unlocking, isTrue);
    await tester.pump();
    expect(auth.reasons, <String>['解锁应用']);
    expect(h.controller.locked, isFalse);
    expect(h.unlockedCount, 1);
  });

  testWidgets('a failed prompt keeps the lock; tapping unlock retries', (
    tester,
  ) async {
    final auth = FakeBiometricAuth(results: <bool>[false, true]);
    final h = await _setUp(tester, auth: auth, clock: TestClock());
    h.controller.start();
    await tester.pump();
    expect(h.controller.locked, isTrue);
    expect(h.controller.unlocking, isFalse);

    await h.controller.manualUnlock();
    expect(auth.reasons, hasLength(2));
    expect(h.controller.locked, isFalse);
  });

  testWidgets('by default leaving the app does not lock it again', (
    tester,
  ) async {
    final clock = TestClock();
    final auth = FakeBiometricAuth(results: <bool>[true]);
    final h = await _setUp(tester, auth: auth, clock: clock);
    await _startUnlocked(tester, h);

    await _leave(tester);
    clock.now = clock.now.add(const Duration(days: 1));
    await _comeBack(tester);
    expect(h.controller.locked, isFalse);
    expect(auth.reasons, hasLength(1));
  });

  testWidgets('immediately: locks while away and prompts on return', (
    tester,
  ) async {
    final auth = FakeBiometricAuth(results: <bool>[true, true]);
    final h = await _setUp(
      tester,
      auth: auth,
      clock: TestClock(),
      options: const AppLockOptions(
        afterLeaving: AppLockAfterLeaving.immediately,
      ),
    );
    await _startUnlocked(tester, h);

    await _leave(tester);
    expect(h.controller.locked, isTrue);
    // 在后台不弹验证。
    expect(auth.reasons, hasLength(1));

    await _comeBack(tester);
    expect(auth.reasons, hasLength(2));
    expect(h.controller.locked, isFalse);
    expect(h.unlockedCount, 2);
  });

  testWidgets('a screen the app opened itself does not count as leaving', (
    tester,
  ) async {
    final auth = FakeBiometricAuth(results: <bool>[true]);
    final h = await _setUp(
      tester,
      auth: auth,
      clock: TestClock(),
      options: const AppLockOptions(
        afterLeaving: AppLockAfterLeaving.immediately,
      ),
    );
    await _startUnlocked(tester, h);
    h.platform.ownActivity = true;

    await _leave(tester);
    // 先当场盖上，原生确认是自己打开的界面后撤回。
    expect(h.controller.locked, isFalse);
    await _comeBack(tester);
    expect(h.controller.locked, isFalse);
    expect(auth.reasons, hasLength(1));
  });

  testWidgets('after a delay: short trips stay open, long ones lock', (
    tester,
  ) async {
    final clock = TestClock();
    final auth = FakeBiometricAuth(results: <bool>[true, false]);
    final h = await _setUp(
      tester,
      auth: auth,
      clock: clock,
      options: const AppLockOptions(afterLeaving: AppLockAfterLeaving.minutes1),
    );
    await _startUnlocked(tester, h);

    await _leave(tester);
    expect(h.controller.locked, isFalse);
    clock.now = clock.now.add(const Duration(seconds: 59));
    await _comeBack(tester);
    expect(h.controller.locked, isFalse);

    await _leave(tester);
    clock.now = clock.now.add(const Duration(minutes: 1));
    await _comeBack(tester);
    expect(auth.reasons, hasLength(2));
    expect(h.controller.locked, isTrue);
  });

  testWidgets('a clock set back while away counts as too long', (tester) async {
    final clock = TestClock();
    final auth = FakeBiometricAuth(results: <bool>[true]);
    final h = await _setUp(
      tester,
      auth: auth,
      clock: clock,
      options: const AppLockOptions(afterLeaving: AppLockAfterLeaving.hour1),
    );
    await _startUnlocked(tester, h);

    await _leave(tester);
    clock.now = clock.now.subtract(const Duration(hours: 3));
    await _comeBack(tester);
    expect(h.controller.locked, isTrue);
  });

  testWidgets('a system prompt in progress does not count as leaving', (
    tester,
  ) async {
    final auth = PendingDeviceAuth(results: <bool>[true]);
    final h = await _setUp(
      tester,
      auth: auth,
      clock: TestClock(),
      options: const AppLockOptions(
        afterLeaving: AppLockAfterLeaving.immediately,
      ),
    );
    await _startUnlocked(tester, h);

    // 如进入上锁的日记本：手机锁屏密码页把应用挤到后台。
    final pending = auth.pending = Completer<bool>();
    final verification = h.verifier.verifySystem(reason: '解锁「保险箱」');
    expect(h.verifier.systemPromptActive, isTrue);
    await _leave(tester);
    expect(h.controller.locked, isFalse);
    pending.complete(true);
    expect(await verification, isTrue);
    await _comeBack(tester);
    expect(h.controller.locked, isFalse);
    expect(h.verifier.systemPromptActive, isFalse);
  });

  testWidgets('screen off locks when that option is on', (tester) async {
    final auth = FakeBiometricAuth(results: <bool>[true, true]);
    final h = await _setUp(
      tester,
      auth: auth,
      clock: TestClock(),
      options: const AppLockOptions(onScreenOff: true),
    );
    expect(h.platform.watchCalls, <bool>[true]);
    await _startUnlocked(tester, h);

    await _leave(tester);
    h.platform.screenOff.add(null);
    await tester.pump();
    expect(h.controller.locked, isTrue);
    expect(auth.reasons, hasLength(1));
    await _comeBack(tester);
    expect(auth.reasons, hasLength(2));
    expect(h.controller.locked, isFalse);

    // 关掉选项后熄屏不再上锁，原生也停止监听。
    h.controller.options = AppLockOptions.defaults;
    expect(h.platform.watchCalls, <bool>[true, false]);
    h.platform.screenOff.add(null);
    await tester.pump();
    expect(h.controller.locked, isFalse);
  });

  testWidgets('screen-off watching and secure screen follow the settings', (
    tester,
  ) async {
    final auth = FakeBiometricAuth(results: <bool>[true]);
    final h = await _setUp(
      tester,
      auth: auth,
      clock: TestClock(),
      enabled: false,
      options: const AppLockOptions(onScreenOff: true, secureScreen: true),
    );
    // 防截屏与应用锁开关无关；熄屏监听只在应用锁开着时。
    expect(h.platform.secureCalls, <bool>[true]);
    expect(h.platform.watchCalls, isEmpty);

    await h.settings.setAppLockEnabled(true);
    await tester.pump();
    expect(h.platform.watchCalls, <bool>[true]);
    await h.settings.setAppLockEnabled(false);
    expect(h.platform.watchCalls, <bool>[true, false]);
    expect(h.controller.locked, isFalse);

    h.controller.options = const AppLockOptions(onScreenOff: true);
    expect(h.platform.secureCalls, <bool>[true, false]);
  });

  testWidgets('without the auto prompt the lock screen waits for a tap', (
    tester,
  ) async {
    final auth = FakeBiometricAuth(results: <bool>[true]);
    final h = await _setUp(
      tester,
      auth: auth,
      clock: TestClock(),
      options: const AppLockOptions(autoPrompt: false),
    );
    h.controller.start();
    await tester.pump();
    expect(h.controller.locked, isTrue);
    expect(h.controller.unlocking, isFalse);
    expect(auth.reasons, isEmpty);

    await h.controller.manualUnlock();
    expect(auth.reasons, hasLength(1));
    expect(h.controller.locked, isFalse);
  });

  testWidgets('app passcode: relocking never pops the system prompt', (
    tester,
  ) async {
    final auth = FakeBiometricAuth();
    final h = await _setUp(
      tester,
      auth: auth,
      clock: TestClock(),
      prefs: await presetPin('2580'),
      options: const AppLockOptions(
        afterLeaving: AppLockAfterLeaving.immediately,
      ),
    );
    h.controller.start();
    await tester.pump();
    // 遮罩里的解锁视图负责输入：控制器只盖上。
    expect(h.controller.locked, isTrue);
    expect(h.controller.unlocking, isFalse);
    h.controller.passcodeUnlocked();
    expect(h.controller.locked, isFalse);

    await _leave(tester);
    await _comeBack(tester);
    expect(h.controller.locked, isTrue);
    expect(h.controller.unlocking, isFalse);
    expect(auth.reasons, isEmpty);
  });

  testWidgets('desktop: locks after the chosen idle time without input', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final clock = TestClock();
    final auth = FakeBiometricAuth(results: <bool>[true, false]);
    final h = await _setUp(
      tester,
      auth: auth,
      clock: clock,
      options: const AppLockOptions(whenIdle: AppLockWhenIdle.minutes1),
    );
    await _startUnlocked(tester, h);

    Future<void> wait(Duration duration) async {
      clock.now = clock.now.add(duration);
      await tester.pump(duration);
    }

    await wait(const Duration(seconds: 30));
    h.controller.noteActivity();
    await wait(const Duration(seconds: 30));
    // 上一次操作在 30 秒前：还不到 1 分钟。
    expect(h.controller.locked, isFalse);
    await wait(const Duration(seconds: 30));
    expect(h.controller.locked, isTrue);
    expect(auth.reasons, hasLength(2));

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('phones ignore the idle option', (tester) async {
    final clock = TestClock();
    final auth = FakeBiometricAuth(results: <bool>[true]);
    final h = await _setUp(
      tester,
      auth: auth,
      clock: clock,
      options: const AppLockOptions(whenIdle: AppLockWhenIdle.minutes1),
    );
    await _startUnlocked(tester, h);
    clock.now = clock.now.add(const Duration(minutes: 5));
    await tester.pump(const Duration(minutes: 5));
    expect(h.controller.locked, isFalse);
  });
}
