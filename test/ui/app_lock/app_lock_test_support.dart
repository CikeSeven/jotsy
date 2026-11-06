import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_password/app_password_hasher.dart';
import 'package:node_diary/core/services/app_password/app_password_store.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/device_auth_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';
import '../notebooks/notebook_test_support.dart' show FakeDeviceAuth;

/// 测试用的摘要计算：不进 isolate、迭代次数很低。
const AppPasswordHasher testPasswordHasher = AppPasswordHasher(
  iterations: 16,
  useIsolate: false,
);

/// 可拨动的时钟（输错限流与倒数共用）。
class TestClock {
  DateTime now = DateTime(2026, 11, 6, 9);
  DateTime call() => now;
}

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

/// 预置存储里的应用密码（与界面里设置的效果相同）。
Future<Map<String, Object>> presetPassword(
  String password, {
  bool biometric = false,
  bool appLock = false,
}) async {
  final secret = await testPasswordHasher.create(password);
  return <String, Object>{
    AppPasswordStore.key: AppPasswordConfig(
      secret: secret,
      biometric: biometric,
    ).encode()!,
    if (appLock) 'app.settings.app_lock_enabled': true,
  };
}

/// 应用密码相关 provider 的覆盖：低迭代摘要、可拨时钟、假设备验证。
List<Override> appLockOverrides({
  required DeviceAuthService auth,
  required TestClock clock,
  SettingsService? settings,
}) => <Override>[
  deviceAuthServiceProvider.overrideWithValue(auth),
  appPasswordHasherProvider.overrideWithValue(testPasswordHasher),
  appPasswordClockProvider.overrideWithValue(clock.call),
  if (settings != null)
    settingsServiceProvider.overrideWith((ref) async => settings),
];

/// 挂上 [home]（中文、测试主题），返回设置服务。[prefs] 为预置的存储内容。
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

/// 在应用密码框里输入并按“解锁”（或 [button] 指定的按钮）。
Future<void> enterPassword(
  WidgetTester tester,
  String password, {
  String button = '解锁',
}) async {
  await tester.enterText(find.byType(TextField).last, password);
  await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, button));
  await tester.pumpAndSettle();
}
