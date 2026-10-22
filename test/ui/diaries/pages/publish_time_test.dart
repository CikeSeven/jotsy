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

/// 发布页的时间规则（进入即发表）：
/// - 发表时间是写库那一刻；打开者带来的请求值（日历的按日新建）照常生效；
/// - 之后在面板里改选的时间随自动保存写回这篇日记，原样确认不算修改；
/// - 解封时间已过的胶囊不封存，按普通日记发表并提示。
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
    DateTime? capsuleUnlockAt,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final draft = NewDiaryDraft(
      title: 'A walk',
      contentDocJson: '[{"insert":"A walk\\n"}]',
      contentText: 'A walk',
      createdAtOverride: createdAtOverride,
      capsuleUnlockAt: capsuleUnlockAt,
      capsulePrecision: capsuleUnlockAt == null ? null : 'date',
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
    await tester.pump();
    await PublishPanelDriver(tester).waitUntilPublished();
    await tester.pumpAndSettle();
  }

  Future<Diary> onlyDiary(WidgetTester tester) async {
    final diaries = await tester.runAsync(
      () => database.select(database.diaries).get(),
    );
    expect(diaries, hasLength(1));
    return diaries!.single;
  }

  /// 返回：补存是真实异步，等到发布页退场、新日记 id 回传。
  Future<String> goBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    for (var i = 0; i < 20 && results.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(results, hasLength(1));
    return results.single! as String;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('opening the page publishes the diary right away', (
    tester,
  ) async {
    final before = DateTime.now();
    await openPublisher(tester);
    final driver = PublishPanelDriver(tester);

    final diary = await onlyDiary(tester);
    expect(diary.title, 'A walk');
    expect(
      diary.createdAt.isBefore(before.subtract(const Duration(seconds: 1))),
      isFalse,
    );
    // 成功不弹提示条：顶栏标题换成“日记已发表”。
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text(driver.l10n.publishSucceeded),
      ),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
    // 面板显示的就是写进去的发表时间。
    expect(
      driver.publishTimeLabel,
      driver.l10n.formatDateTimeMinute(diary.createdAt),
    );
    // 已经发表：留在本页，返回时才退场。
    expect(results, isEmpty);
    expect(find.byType(PublishDiaryPage), findsOneWidget);

    expect(await goBack(tester), diary.diaryId);
    await unmount(tester);
  });

  testWidgets('a calendar day keeps the day', (tester) async {
    await openPublisher(tester, createdAtOverride: DateTime(2025, 3, 15));
    final diary = await onlyDiary(tester);
    expect(DateUtils.dateOnly(diary.createdAt), DateTime(2025, 3, 15));
    expect(PublishPanelDriver(tester).publishTimeLabel, contains('2025'));
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

  testWidgets('confirming the same minute leaves the diary alone', (
    tester,
  ) async {
    await openPublisher(tester, createdAtOverride: requested);
    final published = await onlyDiary(tester);
    expect(published.createdAt, requested);

    PublishPanelDriver(tester).pickPublishTime();
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await goBack(tester);
    final diary = await onlyDiary(tester);
    expect(diary.createdAt, requested);
    expect(diary.updatedAt, published.updatedAt);
    await unmount(tester);
  });

  testWidgets('a picked time is saved to the published diary', (tester) async {
    await openPublisher(tester, createdAtOverride: requested);
    final driver = PublishPanelDriver(tester);
    expect(
      driver.publishTimeLabel,
      driver.l10n.formatDateTimeMinute(requested),
    );

    await pickMarch10(tester);
    expect(driver.publishTimeLabel, driver.l10n.formatDateTimeMinute(picked));

    await goBack(tester);
    expect((await onlyDiary(tester)).createdAt, picked);
    await unmount(tester);
  });

  // 例如“写给某天的胶囊”草稿在那天过后才恢复发布。
  testWidgets('a capsule whose unlock day has passed is published unsealed', (
    tester,
  ) async {
    final yesterday = DateUtils.dateOnly(
      DateTime.now(),
    ).subtract(const Duration(days: 1));
    await openPublisher(tester, capsuleUnlockAt: yesterday);
    final driver = PublishPanelDriver(tester);

    expect(find.text(driver.l10n.publishCapsuleExpired), findsOneWidget);
    final diary = await onlyDiary(tester);
    expect(diary.capsuleUnlockAt, isNull);
    expect(diary.capsuleLockedAt, isNull);
    // 面板里的胶囊也一并去掉，可以重新设置。
    expect(driver.draft.value.capsule, isNull);
    await unmount(tester);
  });
}
