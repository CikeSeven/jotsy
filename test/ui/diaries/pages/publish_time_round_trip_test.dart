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
import '../../../support/publish_panel_driver.dart';

/// 发布页的发表时间不能冻结在“打开发布页那一刻”：没选过就只带回打开者的
/// 请求值，发表时再现算；选过才带回、写入所选时间。
void main() {
  late AppDatabase database;
  late SettingsService settings;
  late List<Object?> results;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
    results = [];
  });
  tearDown(() => database.close());

  Future<void> openPublisher(
    WidgetTester tester, {
    DateTime? createdAtOverride,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final draft = NewDiaryDraft(
      title: 'A walk',
      contentDocJson: '[{"insert":"A walk\\n"}]',
      contentText: 'A walk',
      createdAtOverride: createdAtOverride,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
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
                onPressed: () async {
                  results.add(
                    await Navigator.of(context).push<Object?>(
                      MaterialPageRoute(
                        builder: (_) => PublishDiaryPage(initialDraft: draft),
                      ),
                    ),
                  );
                },
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

  Future<NewDiaryDraft> goBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(results, hasLength(1));
    return results.single! as NewDiaryDraft;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets(
    'an untouched publish time stays automatic through a round trip',
    (tester) async {
      await openPublisher(tester);
      // 没有请求值也没选过：面板显示“自动获取当前时间”。
      expect(PublishPanelDriver(tester).publishTimeLabel, isNull);

      final draft = await goBack(tester);
      expect(draft.createdAtOverride, isNull);
      await unmount(tester);
    },
  );

  testWidgets('a calendar day comes back unchanged', (tester) async {
    final day = DateTime(2025, 3, 15);
    await openPublisher(tester, createdAtOverride: day);
    final label = PublishPanelDriver(tester).publishTimeLabel;
    expect(label, isNotNull);
    expect(label, contains('2025'));

    final draft = await goBack(tester);
    expect(draft.createdAtOverride, day);
    await unmount(tester);
  });

  // 请求值带秒：选择器只到分钟，借此确认“原样确认”不会被当成新的选择。
  final requested = DateTime(2025, 3, 15, 10, 30, 45);
  final picked = DateTime(2025, 3, 10, 10, 30);

  Future<void> pickMarch10(WidgetTester tester) async {
    PublishPanelDriver(tester).pickPublishTime();
    await tester.pumpAndSettle();
    await tester.tap(find.text('10'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    // 时间选择器沿用原来的 10:30，只改日期。
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  testWidgets('confirming the same minute keeps the requested time', (
    tester,
  ) async {
    await openPublisher(tester, createdAtOverride: requested);
    PublishPanelDriver(tester).pickPublishTime();
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final draft = await goBack(tester);
    expect(draft.createdAtOverride, requested);
    await unmount(tester);
  });

  testWidgets('a picked time is carried back to the editor', (tester) async {
    await openPublisher(tester, createdAtOverride: requested);
    final driver = PublishPanelDriver(tester);
    expect(
      driver.publishTimeLabel,
      driver.l10n.formatDateTimeMinute(requested),
    );

    await pickMarch10(tester);
    expect(driver.publishTimeLabel, driver.l10n.formatDateTimeMinute(picked));

    final draft = await goBack(tester);
    expect(draft.createdAtOverride, picked);
    await unmount(tester);
  });

  testWidgets('a picked time is what the diary is published with', (
    tester,
  ) async {
    await openPublisher(tester, createdAtOverride: requested);
    await pickMarch10(tester);

    PublishPanelDriver(tester).triggerPublish();
    for (var i = 0; i < 20 && results.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(results, hasLength(1));
    final stored = await tester.runAsync(
      () => database.getDiaryWithTagsByDiaryId(results.single! as String),
    );
    expect(stored?.diary.createdAt, picked);
    await tester.pumpAndSettle();
    await unmount(tester);
  });
}
