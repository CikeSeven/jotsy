import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_passcode/app_passcode_store.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/device_auth_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/app_lock/controllers/passcode_entry_controller.dart';
import 'package:node_diary/ui/app_lock/widgets/passcode_keypad.dart';
import 'package:node_diary/ui/app_lock/widgets/pattern_pad.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/app_passcode/app_passcode_test_support.dart';
import '../../support/expressive_test_theme.dart';
import '../notebooks/notebook_test_support.dart' show FakeDeviceAuth;

export '../../core/services/app_passcode/app_passcode_test_support.dart';

/// 设备验证的假实现，另带生物识别。
class FakeBiometricAuth extends FakeDeviceAuth {
  FakeBiometricAuth({
    super.supported,
    super.results,
    this.hasBiometrics = true,
    List<bool>? biometricResults,
  }) : biometricResults = biometricResults ?? <bool>[];

  bool hasBiometrics;
  final List<bool> biometricResults;
  final List<String> biometricReasons = <String>[];

  @override
  Future<bool> canUseBiometrics() async => hasBiometrics;

  @override
  Future<bool> authenticateBiometric({
    required String reason,
    bool persistAcrossBackgrounding = true,
  }) async {
    biometricReasons.add(reason);
    return biometricResults.isEmpty ? false : biometricResults.removeAt(0);
  }
}

/// 应用密码相关 provider 的覆盖：低迭代摘要、可拨时钟、假设备验证。
List<Override> appLockOverrides({
  required DeviceAuthService auth,
  required TestClock clock,
  SettingsService? settings,
}) => <Override>[
  deviceAuthServiceProvider.overrideWithValue(auth),
  appPasscodeHasherProvider.overrideWithValue(testPasscodeHasher),
  appPasscodeClockProvider.overrideWithValue(clock.call),
  if (settings != null)
    settingsServiceProvider.overrideWith((ref) async => settings),
];

/// 挂上 [home]（中文、测试主题），返回设置服务与容器。[prefs] 为预置的
/// 存储内容。
Future<(SettingsService, ProviderContainer)> pumpAppLockApp(
  WidgetTester tester, {
  required Widget home,
  required DeviceAuthService auth,
  required TestClock clock,
  Map<String, Object> prefs = const <String, Object>{},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final settings = await SettingsService.create();
  final container = ProviderContainer(
    overrides: appLockOverrides(auth: auth, clock: clock, settings: settings),
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (settings, container);
}

/// 在应用内数字键盘上逐个点按 [digits]。
Future<void> tapDigits(WidgetTester tester, String digits) async {
  for (final digit in digits.split('')) {
    await tester.tap(
      find.descendant(
        of: find.byType(PasscodeKeypad),
        matching: find.text(digit),
      ),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// 在图案板上依次划过 [nodes]（格子序号 0–8）后抬手。
Future<void> drawPattern(WidgetTester tester, List<int> nodes) async {
  final pad = find.byType(PatternPad);
  final origin = tester.getTopLeft(pad);
  final cell = tester.getSize(pad).width / 3;
  Offset center(int node) =>
      origin + Offset((node % 3 + 0.5) * cell, (node ~/ 3 + 0.5) * cell);
  final gesture = await tester.startGesture(center(nodes.first));
  await tester.pump();
  for (final node in nodes.skip(1)) {
    await gesture.moveTo(center(node));
    await tester.pump();
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

/// 等输错后的红色输入保留结束（被拒计时器到点）。
Future<void> waitRejectHold(WidgetTester tester) async {
  await tester.pump(PasscodeEntryController.rejectHold);
  await tester.pumpAndSettle();
}
