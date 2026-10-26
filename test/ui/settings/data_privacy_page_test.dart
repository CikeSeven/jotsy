import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/device_auth_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/pages/data_privacy_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';
import '../notebooks/notebook_test_support.dart' show FakeDeviceAuth;

Future<SettingsService> _pump(WidgetTester tester, FakeDeviceAuth auth) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final settings = await SettingsService.create();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsServiceProvider.overrideWith((ref) async => settings),
        deviceAuthServiceProvider.overrideWithValue(auth),
      ],
      child: MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DataPrivacyPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return settings;
}

SwitchListTile _appLockSwitch(WidgetTester tester) =>
    tester.widget<SwitchListTile>(find.byType(SwitchListTile));

void main() {
  testWidgets('enabling app lock checks support through DeviceAuthService', (
    tester,
  ) async {
    final auth = FakeDeviceAuth(supported: false);
    final settings = await _pump(tester, auth);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(find.text('当前设备不支持本地身份验证，无法启用应用锁。'), findsOneWidget);
    expect(settings.isAppLockEnabled, isFalse);

    auth.supported = true;
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(settings.isAppLockEnabled, isTrue);
    expect(_appLockSwitch(tester).value, isTrue);
  });

  testWidgets(
    'without system verification the app lock switch is disabled and explained',
    (tester) async {
      final auth = FakeDeviceAuth();
      final settings = await _pump(tester, auth);

      final tile = _appLockSwitch(tester);
      expect(tile.onChanged, isNull);
      expect(tile.value, isFalse);
      expect(find.text('这台设备没有系统身份验证（指纹、面容或系统密码），无法上锁'), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(settings.isAppLockEnabled, isFalse);
      expect(auth.reasons, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
}
