import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/services/app_passcode/app_passcode_store.dart';
import 'package:node_diary/ui/app_lock/controllers/identity_verifier.dart';
import 'package:node_diary/ui/app_lock/pages/passcode_verify_page.dart';
import 'package:node_diary/ui/app_lock/widgets/passcode_dots.dart';
import 'package:node_diary/ui/app_lock/widgets/passcode_keypad.dart';

import 'app_lock_test_support.dart';

/// 首页上的一个按钮：经统一入口验证一次，结果记在 [results]。
class _Opener extends ConsumerWidget {
  const _Opener(this.results, {this.purpose = IdentityPurpose.unlock});

  final List<bool> results;
  final IdentityPurpose purpose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () async {
            results.add(
              await ref
                  .read(identityVerifierProvider)
                  .verify(context, reason: '请验证身份以打开「旅行」', purpose: purpose),
            );
          },
          child: const Text('open'),
        ),
      ),
    );
  }
}

Future<(List<bool>, ProviderContainer)> _open(
  WidgetTester tester, {
  required Map<String, Object> prefs,
  FakeBiometricAuth? auth,
  TestClock? clock,
  IdentityPurpose purpose = IdentityPurpose.unlock,
}) async {
  final results = <bool>[];
  final (_, container) = await pumpAppLockApp(
    tester,
    home: _Opener(results, purpose: purpose),
    auth: auth ?? FakeBiometricAuth(hasBiometrics: false),
    clock: clock ?? TestClock(),
    prefs: prefs,
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(find.byType(PasscodeVerifyPage), findsOneWidget);
  return (results, container);
}

int _filled(WidgetTester tester) =>
    tester.widget<PasscodeDots>(find.byType(PasscodeDots)).filled;

Finder _faIcon(FaIconData icon) => find.byIcon(icon.data);

void main() {
  testWidgets('a PIN unlocks as soon as the last digit is entered', (
    tester,
  ) async {
    final (results, _) = await _open(tester, prefs: await presetPin('2580'));
    expect(find.text('验证身份'), findsOneWidget);
    expect(find.text('输入应用密码'), findsOneWidget);
    expect(find.text('请验证身份以打开「旅行」'), findsOneWidget);
    expect(tester.widget<PasscodeDots>(find.byType(PasscodeDots)).length, 4);
    expect(find.byType(TextField), findsNothing);

    await tapDigits(tester, '258');
    expect(_filled(tester), 3);
    expect(results, isEmpty);
    await tapDigits(tester, '0');
    expect(results, <bool>[true]);
    expect(find.byType(PasscodeVerifyPage), findsNothing);
  });

  testWidgets('a wrong PIN shakes, explains and clears for the next try', (
    tester,
  ) async {
    final (results, container) = await _open(
      tester,
      prefs: await presetPin('258036'),
    );
    await tapDigits(tester, '111111');
    expect(find.text('密码不对，请重新输入'), findsOneWidget);
    // 被拒的输入先保留（圆点全红），到点后清空。
    expect(
      tester.widget<PasscodeDots>(find.byType(PasscodeDots)).error,
      isTrue,
    );
    await waitRejectHold(tester);
    expect(_filled(tester), 0);
    expect(container.read(appPasscodeConfigProvider).failedCount, 1);

    await tapDigits(tester, '258036');
    expect(results, <bool>[true]);
    expect(container.read(appPasscodeConfigProvider).failedCount, 0);
  });

  testWidgets('typing again right after a miss starts a fresh entry', (
    tester,
  ) async {
    await _open(tester, prefs: await presetPin('2580'));
    await tapDigits(tester, '1111');
    await tapDigits(tester, '2');
    expect(_filled(tester), 1);
    expect(find.text('密码不对，请重新输入'), findsNothing);
  });

  testWidgets('five misses lock the keypad and count down', (tester) async {
    final clock = TestClock();
    final (results, _) = await _open(
      tester,
      prefs: await presetPin('2580'),
      clock: clock,
    );
    for (var i = 0; i < 3; i++) {
      await tapDigits(tester, '1111');
      await waitRejectHold(tester);
    }
    expect(find.text('不对，再错 2 次需要等待'), findsOneWidget);
    for (var i = 0; i < 2; i++) {
      await tapDigits(tester, '1111');
      await waitRejectHold(tester);
    }
    expect(find.text('请 30 秒后再试'), findsOneWidget);
    expect(
      tester.widget<PasscodeKeypad>(find.byType(PasscodeKeypad)).enabled,
      isFalse,
    );
    await tapDigits(tester, '2580');
    expect(results, isEmpty);

    clock.now = clock.now.add(const Duration(seconds: 12));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('请 18 秒后再试'), findsOneWidget);

    clock.now = clock.now.add(const Duration(seconds: 20));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(
      tester.widget<PasscodeKeypad>(find.byType(PasscodeKeypad)).enabled,
      isTrue,
    );
    await tapDigits(tester, '2580');
    expect(results, <bool>[true]);
  });

  testWidgets('delete removes one digit and a long press clears all', (
    tester,
  ) async {
    await _open(tester, prefs: await presetPin('258036'));
    await tapDigits(tester, '123');
    await tester.tap(_faIcon(FontAwesomeIcons.deleteLeft));
    await tester.pumpAndSettle();
    expect(_filled(tester), 2);
    await tester.longPress(_faIcon(FontAwesomeIcons.deleteLeft));
    await tester.pumpAndSettle();
    expect(_filled(tester), 0);
  });

  testWidgets('a desktop keyboard types digits and deletes them', (
    tester,
  ) async {
    final (results, _) = await _open(tester, prefs: await presetPin('2580'));
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad9);
    await tester.pump();
    expect(_filled(tester), 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(_filled(tester), 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad5);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit8);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.pumpAndSettle();
    expect(results, <bool>[true]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('Esc leaves the page without passing', (tester) async {
    final (results, _) = await _open(tester, prefs: await presetPin('2580'));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(results, <bool>[false]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('a pattern unlocks when the finger lifts', (tester) async {
    final (results, _) = await _open(
      tester,
      prefs: await presetPattern(<int>[0, 1, 2, 5, 8]),
    );
    expect(find.text('绘制解锁图案'), findsOneWidget);
    expect(find.byType(PasscodeKeypad), findsNothing);
    await drawPattern(tester, <int>[0, 1, 2, 5, 8]);
    expect(results, <bool>[true]);
  });

  testWidgets('a short pattern is explained but not counted', (tester) async {
    final (results, container) = await _open(
      tester,
      prefs: await presetPattern(<int>[0, 1, 2, 5]),
    );
    await drawPattern(tester, <int>[0, 1, 2]);
    expect(find.text('点太少了，至少连接 4 个点'), findsOneWidget);
    expect(container.read(appPasscodeConfigProvider).failedCount, 0);
    await waitRejectHold(tester);

    await drawPattern(tester, <int>[0, 1, 2, 4]);
    expect(find.text('图案不对，请重新绘制'), findsOneWidget);
    expect(container.read(appPasscodeConfigProvider).failedCount, 1);
    await waitRejectHold(tester);
    expect(results, isEmpty);
  });

  testWidgets('crossing a dot connects it too', (tester) async {
    final (results, _) = await _open(
      tester,
      prefs: await presetPattern(<int>[0, 1, 2, 5]),
    );
    // 从 0 直接划到 2，经过的 1 自动连上。
    await drawPattern(tester, <int>[0, 2, 5]);
    expect(results, <bool>[true]);
  });

  testWidgets('quick unlock offers the fingerprint key', (tester) async {
    final auth = FakeBiometricAuth(biometricResults: <bool>[false, true]);
    final (results, _) = await _open(
      tester,
      auth: auth,
      prefs: await presetPin('2580', biometric: true),
    );
    // 进入验证页先自动弹一次；取消后停在键盘上，左下角是指纹键。
    expect(auth.biometricReasons, hasLength(1));
    expect(results, isEmpty);
    await tester.tap(_faIcon(FontAwesomeIcons.fingerprint));
    await tester.pumpAndSettle();
    expect(auth.biometricReasons, hasLength(2));
    expect(results, <bool>[true]);
  });

  testWidgets('sensitive checks never offer the fingerprint', (tester) async {
    final auth = FakeBiometricAuth(biometricResults: <bool>[true]);
    final (results, _) = await _open(
      tester,
      auth: auth,
      purpose: IdentityPurpose.sensitive,
      prefs: await presetPin('2580', biometric: true),
    );
    expect(_faIcon(FontAwesomeIcons.fingerprint), findsNothing);
    expect(auth.biometricReasons, isEmpty);
    await tapDigits(tester, '2580');
    expect(results, <bool>[true]);
  });

  testWidgets('forgot passcode explains in place', (tester) async {
    await _open(tester, prefs: await presetPin('2580'));
    expect(find.textContaining('无法找回'), findsNothing);
    // 测试窗口只有 600 高：内容超出可见区域时整列可滚动。
    await tester.ensureVisible(find.text('忘记密码？'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('忘记密码？'));
    await tester.pumpAndSettle();
    expect(find.textContaining('无法找回'), findsOneWidget);
  });
}
