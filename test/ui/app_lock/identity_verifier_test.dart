import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/app_lock/controllers/identity_verifier.dart';
import 'package:node_diary/ui/app_lock/pages/app_password_verify_page.dart';

import 'app_lock_test_support.dart';

/// 一个按钮：点按经 IdentityVerifier 验证一次，结果记进 [results]。
class _VerifyButton extends ConsumerWidget {
  const _VerifyButton({required this.results, required this.purpose});

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
          child: const Text('验证'),
        ),
      ),
    );
  }
}

Future<List<bool>> _pump(
  WidgetTester tester, {
  required FakeBiometricAuth auth,
  required TestClock clock,
  Map<String, Object> prefs = const <String, Object>{},
  IdentityPurpose purpose = IdentityPurpose.unlock,
}) async {
  final results = <bool>[];
  await pumpAppLockApp(
    tester,
    home: _VerifyButton(results: results, purpose: purpose),
    auth: auth,
    clock: clock,
    prefs: prefs,
  );
  await tester.tap(find.text('验证'));
  await tester.pumpAndSettle();
  return results;
}

void main() {
  testWidgets('system verification is used without an app password', (
    tester,
  ) async {
    final auth = FakeBiometricAuth(results: <bool>[true]);
    final results = await _pump(tester, auth: auth, clock: TestClock());
    expect(find.byType(AppPasswordVerifyPage), findsNothing);
    expect(auth.reasons, <String>['请验证身份以打开「旅行」']);
    expect(results, <bool>[true]);
  });

  testWidgets('an app password opens the password page instead', (
    tester,
  ) async {
    final auth = FakeBiometricAuth();
    final results = await _pump(
      tester,
      auth: auth,
      clock: TestClock(),
      prefs: await presetPassword('Secret12'),
    );
    expect(find.byType(AppPasswordVerifyPage), findsOneWidget);
    expect(find.text('验证身份'), findsOneWidget);
    expect(find.text('请验证身份以打开「旅行」'), findsOneWidget);
    expect(auth.reasons, isEmpty);

    await enterPassword(tester, 'secret12');
    expect(find.text('密码不对，请重新输入'), findsOneWidget);
    expect(find.byType(AppPasswordVerifyPage), findsOneWidget);
    // 输错后清空，可以直接重输。
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );

    await enterPassword(tester, 'Secret12');
    expect(find.byType(AppPasswordVerifyPage), findsNothing);
    expect(results, <bool>[true]);
  });

  testWidgets('going back from the password page reports a failure', (
    tester,
  ) async {
    final results = await _pump(
      tester,
      auth: FakeBiometricAuth(),
      clock: TestClock(),
      prefs: await presetPassword('Secret12'),
    );
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(AppPasswordVerifyPage), findsNothing);
    expect(results, <bool>[false]);
  });

  testWidgets('too many mistakes lock input and count down', (tester) async {
    final clock = TestClock();
    await _pump(
      tester,
      auth: FakeBiometricAuth(),
      clock: clock,
      prefs: await presetPassword('Secret12'),
    );
    for (var i = 0; i < 3; i++) {
      await enterPassword(tester, 'nope');
    }
    expect(find.text('密码不对，再错 2 次需要等待'), findsOneWidget);
    await enterPassword(tester, 'nope');
    expect(find.text('密码不对，再错 1 次需要等待'), findsOneWidget);
    await enterPassword(tester, 'nope');
    expect(find.text('输错次数太多，请 30 秒后再试'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

    clock.now = clock.now.add(const Duration(seconds: 12));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('输错次数太多，请 18 秒后再试'), findsOneWidget);

    clock.now = clock.now.add(const Duration(seconds: 18));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.textContaining('输错次数太多'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
  });

  testWidgets('a lockout is still running when the page opens again', (
    tester,
  ) async {
    final clock = TestClock();
    final prefs = await presetPassword('Secret12');
    await _pump(tester, auth: FakeBiometricAuth(), clock: clock, prefs: prefs);
    for (var i = 0; i < 5; i++) {
      await enterPassword(tester, 'nope');
    }
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    clock.now = clock.now.add(const Duration(seconds: 5));
    await tester.tap(find.text('验证'));
    await tester.pumpAndSettle();
    expect(find.text('输错次数太多，请 25 秒后再试'), findsOneWidget);
  });

  testWidgets('fingerprint is offered and tried first when unlocking', (
    tester,
  ) async {
    final auth = FakeBiometricAuth(biometricResults: <bool>[true]);
    final results = await _pump(
      tester,
      auth: auth,
      clock: TestClock(),
      prefs: await presetPassword('Secret12', biometric: true),
    );
    expect(auth.biometricReasons, <String>['请验证身份以打开「旅行」']);
    expect(find.byType(AppPasswordVerifyPage), findsNothing);
    expect(results, <bool>[true]);
  });

  testWidgets('a cancelled fingerprint falls back to the password', (
    tester,
  ) async {
    final auth = FakeBiometricAuth(biometricResults: <bool>[false, true]);
    final results = await _pump(
      tester,
      auth: auth,
      clock: TestClock(),
      prefs: await presetPassword('Secret12', biometric: true),
    );
    expect(find.byType(AppPasswordVerifyPage), findsOneWidget);
    expect(find.text('使用指纹或面容'), findsOneWidget);

    await tester.tap(find.text('使用指纹或面容'));
    await tester.pumpAndSettle();
    expect(auth.biometricReasons, hasLength(2));
    expect(results, <bool>[true]);
  });

  testWidgets('sensitive changes accept only the password', (tester) async {
    final auth = FakeBiometricAuth(biometricResults: <bool>[true]);
    final results = await _pump(
      tester,
      auth: auth,
      clock: TestClock(),
      prefs: await presetPassword('Secret12', biometric: true),
      purpose: IdentityPurpose.sensitive,
    );
    expect(auth.biometricReasons, isEmpty);
    expect(find.text('使用指纹或面容'), findsNothing);

    await enterPassword(tester, 'Secret12');
    expect(results, <bool>[true]);
  });

  testWidgets('without a fingerprint enrolled the button stays hidden', (
    tester,
  ) async {
    final auth = FakeBiometricAuth(hasBiometrics: false);
    await _pump(
      tester,
      auth: auth,
      clock: TestClock(),
      prefs: await presetPassword('Secret12', biometric: true),
    );
    expect(find.text('使用指纹或面容'), findsNothing);
    expect(auth.biometricReasons, isEmpty);
  });

  testWidgets('forgot password explains in place that it cannot be recovered', (
    tester,
  ) async {
    await _pump(
      tester,
      auth: FakeBiometricAuth(),
      clock: TestClock(),
      prefs: await presetPassword('Secret12'),
    );
    expect(find.textContaining('无法找回'), findsNothing);
    await tester.tap(find.text('忘记密码？'));
    await tester.pumpAndSettle();
    expect(find.textContaining('应用密码无法找回'), findsOneWidget);
  });

  testWidgets('the eye button reveals and hides the password', (tester) async {
    await _pump(
      tester,
      auth: FakeBiometricAuth(),
      clock: TestClock(),
      prefs: await presetPassword('Secret12'),
    );
    TextField field() => tester.widget<TextField>(find.byType(TextField));
    expect(field().obscureText, isTrue);
    expect(field().enableSuggestions, isFalse);
    expect(field().autofillHints, isNull);
    await tester.tap(find.byTooltip('显示密码'));
    await tester.pump();
    expect(field().obscureText, isFalse);
    await tester.tap(find.byTooltip('隐藏密码'));
    await tester.pump();
    expect(field().obscureText, isTrue);
  });

  testWidgets('pressing enter submits the password', (tester) async {
    final results = await _pump(
      tester,
      auth: FakeBiometricAuth(),
      clock: TestClock(),
      prefs: await presetPassword('Secret12'),
    );
    await tester.enterText(find.byType(TextField), 'Secret12');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(results, <bool>[true]);
  });
}
