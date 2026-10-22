import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/pages/publish_diary_page.dart';
import 'package:node_diary/ui/widgets/list_item_presence.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';
import '../../../support/publish_panel_driver.dart';

void main() {
  testWidgets('opening publishes, back returns straight to the opener', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = await SettingsService.create();
    final results = <Object?>[];

    await _openPublisherFromEditor(
      tester,
      database: database,
      settings: settings,
      results: results,
    );
    final panel = PublishPanelDriver(tester);

    // 进入即发表：库里已有这篇日记，草稿已从草稿箱删除，并提示已发表；
    // 页面留在原地，编辑页仍在下面。
    final diaries = await tester.runAsync(
      () => database.select(database.diaries).get(),
    );
    expect(diaries, hasLength(1));
    final diary = diaries!.single;
    expect(diary.title, 'Sunset by the sea');
    // 新日记默认不记录精力：用户没打开过开关，metadata 里没有精力值。
    final context = (jsonDecode(diary.metadata) as Map)['context'];
    expect((context as Map?)?['energyLevel'], isNull);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    expect(await tester.runAsync(database.countDiaryDrafts), 0);
    expect(find.text(panel.l10n.publishSucceeded), findsOneWidget);
    expect(find.byType(PublishDiaryPage), findsOneWidget);
    expect(find.byType(EditDiaryPage, skipOffstage: false), findsOneWidget);
    expect(results, isEmpty);

    // 面板改动像编辑页一样直接保存，返回时补存。
    panel.setMood('🙂');
    await tester.binding.handlePopRoute();
    for (var i = 0; i < 20 && results.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(results, <Object?>[diary.diaryId]);
    // 发布页正在退场，编辑页已直接移出路由栈（连 offstage 都不在）：退场露出的
    // 是打开者，而不是编辑页紧跟着再退一次场。
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byType(EditDiaryPage, skipOffstage: false), findsNothing);
    expect(find.byType(PublishDiaryPage), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(PublishDiaryPage), findsNothing);
    expect(find.text('Open editor'), findsOneWidget);
    final stored = await tester.runAsync(
      () => database.getDiaryWithTagsByDiaryId(diary.diaryId),
    );
    final saved = (jsonDecode(stored!.diary.metadata) as Map)['context'];
    expect((saved as Map)['moodEmoji'], '🙂');
    expect(
      await tester.runAsync(() => database.select(database.diaries).get()),
      hasLength(1),
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('back waits until the diary is written', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final database = _GatedDatabase();
    addTearDown(database.close);
    final settings = await SettingsService.create();
    final results = <Object?>[];
    await _openPublisherFromEditor(
      tester,
      database: database,
      settings: settings,
      results: results,
      settle: false,
    );
    final l10n = PublishPanelDriver(tester).l10n;
    Finder backTooltip() => find.descendant(
      of: find.byType(PublishDiaryPage),
      matching: find.byTooltip(l10n.commonBack),
    );
    IconButton backButton() => tester.widget<IconButton>(
      find.ancestor(of: backTooltip(), matching: find.byType(IconButton)),
    );

    // 写库完成之前按系统返回：既不能退回编辑页（草稿会留着，可以再发一次），
    // 也不能就此离开（面板还没开始自动保存）。顶栏返回同样停用。
    // 写库卡住时等待遮罩会一直转圈：只推够入场转场的时间，不等 settle。
    await tester.pump(const Duration(seconds: 1));
    expect(PublishPanelDriver(tester).busy, isTrue);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(PublishDiaryPage), findsOneWidget);
    expect(backButton().onPressed, isNull);
    expect(results, isEmpty);

    database.gate.complete();
    await PublishPanelDriver(tester).waitUntilPublished();
    await tester.pumpAndSettle();
    expect(results, isEmpty);
    expect(backButton().onPressed, isNotNull);

    // 退场途中再按返回不会重复退场或发布。
    await tester.tap(backTooltip());
    await tester.binding.handlePopRoute();
    for (var i = 0; i < 20 && results.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(results, hasLength(1));
    expect(results.single, isA<String>());
    expect(find.text('Open editor'), findsOneWidget);
    final diaries = await tester.runAsync(
      () => database.select(database.diaries).get(),
    );
    expect(diaries, hasLength(1));

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('a failed publish returns to the editor with the draft', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = await SettingsService.create();
    await tester.runAsync(() => _rejectDiaryInserts(database));
    final results = <Object?>[];
    await _openPublisherFromEditor(
      tester,
      database: database,
      settings: settings,
      results: results,
      settle: false,
    );
    final l10n = tester.element(find.byType(EditDiaryPage)).l10n;
    for (
      var i = 0;
      i < 30 && find.byType(PublishDiaryPage).evaluate().isNotEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    // 退回编辑页：内容原样，提示可读的本地化文案（SQL 错误只写调试日志）。
    expect(find.byType(PublishDiaryPage), findsNothing);
    expect(find.byType(EditDiaryPage), findsOneWidget);
    expect(find.text('Sunset by the sea'), findsOneWidget);
    expect(find.text(l10n.publishFailed), findsOneWidget);
    expect(find.textContaining('disk unavailable'), findsNothing);
    expect(results, isEmpty);

    // 修好之后可以再次发布。
    await tester.runAsync(
      () => database.customStatement('DROP TRIGGER reject_diary_insert'),
    );
    await tester.tap(find.byTooltip(l10n.autoT0136));
    await tester.pump();
    await PublishPanelDriver(tester).waitUntilPublished();
    expect(
      await tester.runAsync(() => database.select(database.diaries).get()),
      hasLength(1),
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('the new card grows in only after the publish page has left', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = await SettingsService.create();
    await tester.runAsync(
      () => database.createDiary(
        title: 'Earlier note',
        contentDocJson: '[{"insert":"before\\n"}]',
        contentText: 'before',
        metadataJson: '{}',
      ),
    );
    Future<void> Function()? createAction;
    final theme = expressiveTestTheme(Brightness.light);
    // 发布页自己也显示标题，只看列表里的卡片。
    Finder newCardTitle() => find.descendant(
      of: find.byType(DiariesPage),
      matching: find.text('Sunset by the sea'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: MaterialApp(
          theme: theme,
          locale: const Locale('en'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            quill.FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiariesPage(
            pageBackgroundColor: theme.colorScheme.surface,
            onCreateActionChanged: (action) => createAction = action,
          ),
        ),
      ),
    );
    for (
      var i = 0;
      i < 10 && find.text('Earlier note').evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(find.text('Earlier note'), findsOneWidget);

    unawaited(createAction!());
    await tester.pumpAndSettle();
    expect(find.byType(EditDiaryPage), findsOneWidget);

    await _publishFromEditor(
      tester,
      'Sunset by the sea',
      published: () =>
          find.byType(EditDiaryPage, skipOffstage: false).evaluate().isEmpty,
    );
    // 发布页退场途中：列表已随路由露出，但新卡片先被压住，不与转场叠在一起。
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.byType(PublishDiaryPage), findsOneWidget);
      expect(newCardTitle(), findsNothing);
    }

    // 退场结束后新卡片以展开动画出现。
    var sawGrowing = false;
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      final title = newCardTitle();
      if (title.evaluate().isEmpty) {
        continue;
      }
      final presence = tester.state(
        find.ancestor(of: title, matching: find.byType(ListItemPresence)),
      );
      final fade = tester.widget<FadeTransition>(
        find
            .descendant(
              of: find.byWidget(presence.widget),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      if (fade.opacity.value < 1) {
        sawGrowing = true;
        expect(find.byType(PublishDiaryPage), findsNothing);
        break;
      }
    }
    expect(sawGrowing, isTrue);
    await tester.pumpAndSettle();
    expect(newCardTitle(), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}

/// 新建日记卡在 [gate] 上的数据库：发布页停在“写库中”，直到测试放行。
class _GatedDatabase extends AppDatabase {
  _GatedDatabase() : super.forTesting(NativeDatabase.memory());

  final Completer<void> gate = Completer<void>();

  @override
  Future<String> createDiary({
    required String title,
    required String contentDocJson,
    required String contentText,
    required String metadataJson,
    String? cover,
    List<int> tagIds = const <int>[],
    DateTime? createdAtOverride,
    DateTime? capsuleUnlockAt,
    DateTime? capsuleLockedAt,
    List<String>? notebookIds,
    Map<String, String> notebookChapterIds = const <String, String>{},
  }) async {
    await gate.future;
    return super.createDiary(
      title: title,
      contentDocJson: contentDocJson,
      contentText: contentText,
      metadataJson: metadataJson,
      cover: cover,
      tagIds: tagIds,
      createdAtOverride: createdAtOverride,
      capsuleUnlockAt: capsuleUnlockAt,
      capsuleLockedAt: capsuleLockedAt,
      notebookIds: notebookIds,
      notebookChapterIds: notebookChapterIds,
    );
  }
}

Future<void> _rejectDiaryInserts(AppDatabase database) =>
    database.customStatement('''
      CREATE TRIGGER reject_diary_insert BEFORE INSERT ON diaries
      BEGIN SELECT RAISE(ABORT, 'disk unavailable'); END;
    ''');

/// 在编辑页填写标题 → 点“发布”（进入发布页即写库）→ 停在发布页上一会儿
/// 再返回，并等到发布页开始退场。
Future<void> _publishFromEditor(
  WidgetTester tester,
  String title, {
  required bool Function() published,
}) async {
  await tester.enterText(find.byType(TextField).first, title);
  await tester.pump();
  final l10n = tester.element(find.byType(EditDiaryPage)).l10n;
  await tester.tap(find.byTooltip(l10n.autoT0136));
  await tester.pump();
  await PublishPanelDriver(tester).waitUntilPublished();
  await tester.pumpAndSettle();
  // 在发布页上停留超过列表放出新卡片的兜底时限：新卡片仍要等发布页退场。
  await tester.pump(const Duration(seconds: 3));
  await tester.binding.handlePopRoute();
  for (var i = 0; i < 20 && !published(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(published(), isTrue);
}

/// 挂载打开者 → 新建编辑页 → 填标题 → 点“发布”打开发布页（进入即写库）；
/// 路由结果追加到 [results]。[settle] 为 false 时只推两帧：发布页刚开始
/// 入场，写库可能还没完成（内存数据库很快，失败时页面可能已经退回）。
Future<void> _openPublisherFromEditor(
  WidgetTester tester, {
  required AppDatabase database,
  required SettingsService settings,
  required List<Object?> results,
  String title = 'Sunset by the sea',
  bool settle = true,
}) async {
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
                final result = await Navigator.of(context).push<Object?>(
                  MaterialPageRoute<Object?>(
                    builder: (_) => const EditDiaryPage(
                      entryMode: EditDiaryEntryMode.create,
                    ),
                  ),
                );
                results.add(result);
              },
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open editor'));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField).first, title);
  await tester.pump();
  final l10n = tester.element(find.byType(EditDiaryPage)).l10n;
  await tester.tap(find.byTooltip(l10n.autoT0136));
  // 第一帧新路由还在 offstage（Hero 测量），再推一帧才可见。
  await tester.pump();
  await tester.pump();
  if (settle) {
    await PublishPanelDriver(tester).waitUntilPublished();
    await tester.pumpAndSettle();
    expect(find.byType(PublishDiaryPage), findsOneWidget);
  }
}
