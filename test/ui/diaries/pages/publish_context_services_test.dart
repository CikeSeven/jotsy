import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/pages/publish_diary_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';
import '../../../support/fake_diary_context_services.dart';
import '../../../support/publish_panel_driver.dart';

/// 此时此地：定位与天气服务经 provider 注入，测试用假服务驱动完整流程。
void main() {
  late AppDatabase database;
  late SettingsService settings;
  late FakeLocationResolverService location;
  late FakeWeatherService weather;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
    location = FakeLocationResolverService();
    weather = FakeWeatherService();
  });
  tearDown(() => database.close());

  Future<void> openPublisher(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
          locationResolverServiceProvider.overrideWith((ref) async => location),
          weatherServiceProvider.overrideWith((ref) async => weather),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('en'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            quill.FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<Object?>(
                  MaterialPageRoute(
                    builder: (_) => const PublishDiaryPage(
                      initialDraft: NewDiaryDraft(
                        title: 'A walk',
                        contentDocJson: '[{"insert":"A walk\\n"}]',
                        contentText: 'A walk',
                      ),
                    ),
                  ),
                ),
                child: const Text('Open route'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open route'));
    await tester.pumpAndSettle();
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('locating then fetching weather fills both fields', (
    tester,
  ) async {
    await openPublisher(tester);
    final panel = PublishPanelDriver(tester);

    panel.resolveLocation();
    await settle(tester);
    expect(location.calls, 1);
    expect(panel.locationText, '北京市 · 望京街道');

    panel.resolveWeather();
    await settle(tester);
    expect(weather.requests, [(39.98941, 116.480881)]);
    expect(panel.weatherText, 'Sunny 24℃');
    expect(panel.weatherLoading, isFalse);
    await unmount(tester);
  });
}
