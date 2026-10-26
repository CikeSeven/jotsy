import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:appflowy_editor/appflowy_editor.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/pages/publish_diary_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/location_test_support.dart';
import '../../../support/expressive_test_theme.dart';
import '../../../support/publish_panel_driver.dart';

void main() {
  const configChannel = MethodChannel('com.jotsy.diary/config');
  late AppDatabase database;
  late SettingsService settings;
  late String diaryId;
  late GeolocatorPlatform originalPlatform;
  late FakeLocationPlatform geolocator;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
    diaryId = await database.createDiary(
      title: 'Walk',
      contentDocJson: '[{"insert":"Walk\\n"}]',
      contentText: 'Walk',
      metadataJson: jsonEncode({
        'context': {'location': 'Old place'},
      }),
    );
    originalPlatform = GeolocatorPlatform.instance;
    geolocator = FakeLocationPlatform()
      ..permission = LocationPermission.denied
      ..requestedPermission = LocationPermission.denied;
    GeolocatorPlatform.instance = geolocator;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(configChannel, (_) async => 'test-key');
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(configChannel, null);
    GeolocatorPlatform.instance = originalPlatform;
    await database.close();
  });

  for (final editing in [false, true]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '${editing ? '编辑' : '发布'}页在 ${brightness.name} 主题拒绝定位后保留地点并可重试',
        (tester) async {
          tester.view.physicalSize = const Size(400, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appDatabaseProvider.overrideWithValue(database),
                settingsServiceProvider.overrideWith((ref) async => settings),
              ],
              child: MaterialApp(
                theme: expressiveTestTheme(brightness),
                locale: Locale(brightness == Brightness.light ? 'en' : 'zh'),
                localizationsDelegates: const [
                  ...AppLocalizations.localizationsDelegates,
                  quill.AppFlowyEditorLocalizations.delegate,
                ],
                supportedLocales: AppLocalizations.supportedLocales,
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => editing
                              ? EditDiaryPage(diaryId: diaryId)
                              : const PublishDiaryPage(
                                  initialDraft: NewDiaryDraft(
                                    title: 'Walk',
                                    contentDocJson: '[{"insert":"Walk\\n"}]',
                                    contentText: 'Walk',
                                    location: 'Old place',
                                  ),
                                ),
                        ),
                      ),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          final panel = PublishPanelDriver(tester);
          final l10n = panel.l10n;

          panel.resolveLocation();
          await tester.pumpAndSettle();
          expect(find.text(l10n.locationPermissionDenied), findsOneWidget);
          expect(panel.locationText, 'Old place');
          expect(geolocator.permissionRequests, 1);
          expect(geolocator.settings, isEmpty);

          expect(panel.locating, isFalse);
          panel.resolveLocation();
          await tester.pumpAndSettle();
          expect(geolocator.permissionRequests, 2);
          expect(panel.locationText, 'Old place');
          expect(tester.takeException(), isNull);
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }
}
