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
  testWidgets('publishing returns straight to the opener with the new id', (
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

    PublishPanelDriver(tester).triggerPublish();
    // 写库是真实异步：离开假时钟等它完成，直到发布页开始退场、结果回传。
    for (var i = 0; i < 20 && results.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }

    expect(results, hasLength(1));
    final createdId = results.single;
    expect(createdId, isA<String>());
    // 发布页正在退场，编辑页已直接移出路由栈（连 offstage 都不在）：退场露出的
    // 是打开者，而不是编辑页紧跟着再退一次场。
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byType(EditDiaryPage, skipOffstage: false), findsNothing);
    expect(find.byType(PublishDiaryPage), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(PublishDiaryPage), findsNothing);
    expect(find.text('Open editor'), findsOneWidget);
    final stored = await tester.runAsync(
      () => database.getDiaryWithTagsByDiaryId(createdId! as String),
    );
    expect(stored?.diary.title, 'Sunset by the sea');
    // 新日记默认不记录精力：用户没打开过开关，metadata 里没有精力值。
    final context = (jsonDecode(stored!.diary.metadata) as Map)['context'];
    expect((context as Map?)?['energyLevel'], isNull);
    // 编辑页虽已被移出路由栈，新建草稿仍被清除。
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    expect(settings.createDiaryDraftRaw, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('back while publishing keeps the page and publishes once', (
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
    final l10n = PublishPanelDriver(tester).l10n;

    // 写库尚未完成时按系统返回：不能带着草稿退回编辑页（否则发布页被移除、
    // onPublished 不再触发，编辑页留着草稿，打开者永远收不到新日记 id）。
    PublishPanelDriver(tester).triggerPublish();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(PublishDiaryPage), findsOneWidget);
    // 顶栏返回同样停用。
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.descendant(
                of: find.byType(PublishDiaryPage),
                matching: find.byTooltip(l10n.commonBack),
              ),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );

    for (var i = 0; i < 20 && results.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(results, hasLength(1));
    expect(results.single, isA<String>());
    // 退场途中再按返回、再点发布都不会重复发布。
    await tester.binding.handlePopRoute();
    PublishPanelDriver(tester).triggerPublish();
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    expect(find.byType(EditDiaryPage, skipOffstage: false), findsNothing);
    final diaries = await tester.runAsync(
      () => database.select(database.diaries).get(),
    );
    expect(diaries, hasLength(1));

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

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}

/// 在编辑页填写标题 → 打开发布页 → 触发发布，并等到写库完成、发布页开始退场。
Future<void> _publishFromEditor(
  WidgetTester tester,
  String title, {
  required bool Function() published,
}) async {
  await tester.enterText(find.byType(TextField).first, title);
  await tester.pump();
  final l10n = tester.element(find.byType(EditDiaryPage)).l10n;
  await tester.tap(find.byTooltip(l10n.autoT0136));
  await tester.pumpAndSettle();
  // 收起栏上的发表按钮：不展开面板就能发表。
  await tester.tap(PublishPanelDriver(tester).collapsedPublishButton);
  for (var i = 0; i < 20 && !published(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(published(), isTrue);
}

/// 挂载打开者 → 新建编辑页 → 填标题 → 打开发布页；路由结果追加到 [results]。
Future<void> _openPublisherFromEditor(
  WidgetTester tester, {
  required AppDatabase database,
  required SettingsService settings,
  required List<Object?> results,
  String title = 'Sunset by the sea',
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
                      restoreCreateDraft: false,
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
  await tester.pumpAndSettle();
  expect(find.byType(PublishDiaryPage), findsOneWidget);
}
