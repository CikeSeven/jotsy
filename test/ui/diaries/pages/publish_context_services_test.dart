import '../../../support/diary_content_test_helpers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/pages/publish_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/publish_location_precision_picker.dart';
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

  Future<void> openRoute(WidgetTester tester, WidgetBuilder builder) async {
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
            quill.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).push<Object?>(MaterialPageRoute(builder: builder)),
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

  Future<void> openPublisher(WidgetTester tester) => openRoute(
    tester,
    (_) => const PublishDiaryPage(
      initialDraft: NewDiaryDraft(
        title: 'A walk',
        contentDocJson: '[{"insert":"A walk\\n"}]',
        contentText: 'A walk',
      ),
    ),
  );

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

  // 发布新日记时“此时此地”就是现在：定位成功后顺带取一次天气。
  testWidgets('locating on the publish page also fills the weather', (
    tester,
  ) async {
    await openPublisher(tester);
    final panel = PublishPanelDriver(tester);

    panel.resolveLocation();
    await settle(tester);
    expect(location.calls, 1);
    expect(panel.locationText, '北京市 · 望京街道');
    expect(weather.requests, [(39.98941, 116.480881)]);
    expect(panel.weatherText, 'Sunny 24℃');
    expect(panel.weatherLoading, isFalse);

    // 已有天气时再定位不覆盖；手动按钮照常重新获取。
    panel.resolveLocation();
    await settle(tester);
    expect(weather.requests, hasLength(1));
    panel.resolveWeather();
    await settle(tester);
    expect(weather.requests, hasLength(2));
    await unmount(tester);
  });

  // 编辑旧日记时重新定位不能把今天的天气写进去。
  testWidgets('locating on the edit page leaves the weather alone', (
    tester,
  ) async {
    final diaryId = await tester.runAsync(
      () => database.createDiary(
        title: 'Old walk',
        contentDocJson: '[{"insert":"Old walk\\n"}]',
        contentText: 'Old walk',
        metadataJson: '{}',
      ),
    );
    await openRoute(tester, (_) => EditDiaryPage(diaryId: diaryId));
    final panel = PublishPanelDriver(tester);

    panel.resolveLocation();
    await settle(tester);
    expect(panel.locationText, '北京市 · 望京街道');
    expect(weather.requests, isEmpty);
    expect(panel.weatherText, isEmpty);
    await tester.pump(const Duration(milliseconds: 600));
    await unmount(tester);
  });

  testWidgets('the address level appears once there is a place', (
    tester,
  ) async {
    await openPublisher(tester);
    final panel = PublishPanelDriver(tester);
    await panel.expand();
    expect(find.byType(PublishLocationPrecisionPicker), findsNothing);

    panel.typeLocation('Park');
    await tester.pumpAndSettle();
    expect(find.byType(PublishLocationPrecisionPicker), findsOneWidget);

    panel.typeLocation('');
    await tester.pumpAndSettle();
    expect(find.byType(PublishLocationPrecisionPicker), findsNothing);
    await unmount(tester);
  });

  // 面板字段由 DiaryMetaDraftController 局部通知：拖动精力、打字、选心情
  // 都不该重建整页（含只读正文预览）。
  testWidgets('panel input does not rebuild the body preview', (tester) async {
    await openPublisher(tester);
    final panel = PublishPanelDriver(tester);
    final previewBefore = tester.widget(find.byType(DiaryEditor));

    panel.setEnergy(3);
    panel.setMood('🙂');
    panel.typeLocation('Park');
    await tester.pump();

    expect(
      identical(tester.widget(find.byType(DiaryEditor)), previewBefore),
      isTrue,
    );
    await unmount(tester);
  });
}
