import 'package:appflowy_editor/appflowy_editor.dart' as quill;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/ai/ai_models.dart';
import 'package:node_diary/core/services/ai/ai_provider_store.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/ai/providers/ai_providers.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/widgets/diary_ai/diary_ai_writing_panel.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';
import '../../../support/fake_ai.dart';

/// 编辑页的 AI 写作：工具只在 AI 可用时出现；面板里的指令流式生成，
/// “替换”一次写回正文并关闭面板；关掉 AI 后入口全部消失。
void main() {
  late AppDatabase database;
  late SettingsService settings;
  late AiProviderStore store;
  late String diaryId;
  late List<AiRequest> requests;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
    store = await AiProviderStore.create();
    requests = <AiRequest>[];
    await settings.setDiaryToolbarAlwaysVisible(true);
    // AI 写作放在工具栏最前，不必去「更多」里找。
    await settings.setDiaryToolbarOrderRaw('ai,bold');
    diaryId = await database.createDiary(
      title: 'AI probe',
      contentDocJson: '[{"insert":"teh sentence\\n"}]',
      contentText: 'teh sentence',
      metadataJson: '{}',
    );
  });
  tearDown(() async {
    store.dispose();
    await database.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> pumpPage(WidgetTester tester, {EditDiaryPage? page}) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
          aiProviderStoreProvider.overrideWith((ref) async => store),
          aiServiceProvider.overrideWith(
            (ref) async => fakeAiService(
              store,
              reply: (_) => 'the sentence',
              requests: requests,
            ),
          ),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('en'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            quill.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: page ?? EditDiaryPage(diaryId: diaryId),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }

  final l10n = lookupAppLocalizations(const Locale('en'));
  Finder aiTool() => find.byTooltip(l10n.aiToolbarLabel);

  testWidgets('no AI tool while the feature is off', (tester) async {
    await tester.runAsync(() => seedFakeAiProvider(store));
    await pumpPage(tester);
    expect(aiTool(), findsNothing);
    await unmount(tester);
  });

  testWidgets('no AI tool when on but nothing is configured', (tester) async {
    await settings.setAppFeaturesRaw('{"ai":true}');
    await pumpPage(tester);
    expect(aiTool(), findsNothing);
    await unmount(tester);
  });

  testWidgets('a command streams a result that replaces the paragraph', (
    tester,
  ) async {
    await settings.setAppFeaturesRaw('{"ai":true}');
    await tester.runAsync(() => seedFakeAiProvider(store));
    await pumpPage(tester);
    expect(aiTool(), findsOneWidget);

    await tester.tap(aiTool());
    await settle(tester);
    expect(find.byType(DiaryAiWritingPanel), findsOneWidget);

    await tester.tap(find.text(l10n.aiActionPolish));
    await settle(tester);
    expect(requests, hasLength(1));
    expect(requests.single.messages.single.text, contains('teh sentence'));
    expect(find.text('the sentence'), findsWidgets);

    await tester.tap(find.text(l10n.aiPanelReplace));
    await settle(tester);
    expect(find.byType(DiaryAiWritingPanel), findsNothing);
    // 自动保存把写回的正文存进数据库。
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 700)),
    );
    await settle(tester);
    final saved = await tester.runAsync(() => database.getAiDiary(diaryId));
    expect(saved!.contentText, 'the sentence');
    await unmount(tester);
  });

  const image =
      'data:image/png;base64,'
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6l1sAAAAASUVORK5CYII=';

  for (final visibility in [
    NotebookVisibility.hidden,
    NotebookVisibility.locked,
  ]) {
    testWidgets('image description blocks inherited $visibility diaries', (
      tester,
    ) async {
      await settings.setAppFeaturesRaw('{"ai":true}');
      await settings.setAiPrefsRaw('{"on":["vision"]}');
      await tester.runAsync(() async {
        await seedFakeAiProvider(store);
        final parent = await database.createNotebook(
          name: 'private',
          visibility: visibility,
        );
        final child = await database.createNotebook(
          name: 'child',
          parentId: parent,
        );
        await database.updateDiary(
          diaryId: diaryId,
          title: '',
          contentDocJson: '',
          contentText: '正文',
          metadataJson: '{}',
          notebookIds: [child],
        );
      });
      await pumpPage(tester);
      final editor = tester
          .widget<DiaryEditor>(find.byType(DiaryEditor))
          .controller;
      expect(editor.aiImageDescriber, isNotNull);
      final result = await tester.runAsync(
        () => editor.aiImageDescriber!(image),
      );
      await settle(tester);
      expect(result, isNull);
      expect(requests, isEmpty);
      expect(find.text(l10n.aiPanelPrivateBlocked), findsOneWidget);
      await unmount(tester);
    });
  }

  testWidgets('explicit private permission allows image description', (
    tester,
  ) async {
    await settings.setAppFeaturesRaw('{"ai":true}');
    await settings.setAiPrefsRaw(
      '{"on":["vision"],"privacy":{"allowPrivate":true}}',
    );
    await tester.runAsync(() async {
      await seedFakeAiProvider(store);
      final notebook = await database.createNotebook(
        name: 'private',
        visibility: NotebookVisibility.hidden,
      );
      await database.updateDiary(
        diaryId: diaryId,
        title: '',
        contentDocJson: '',
        contentText: '正文',
        metadataJson: '{}',
        notebookIds: [notebook],
      );
    });
    await pumpPage(tester);
    final editor = tester
        .widget<DiaryEditor>(find.byType(DiaryEditor))
        .controller;
    final result = editor.aiImageDescriber!(image);
    await settle(tester);
    expect(requests, hasLength(1));
    expect(await result, 'the sentence');
    expect(
      requests.single.messages.single.parts.whereType<AiImagePart>(),
      hasLength(1),
    );
    await unmount(tester);
  });

  for (final private in [false, true]) {
    testWidgets(
      'a draft can check notebook privacy with the feature off, private=$private',
      (tester) async {
        await settings.setAppFeaturesRaw('{"ai":true,"notebooks":false}');
        await tester.runAsync(() => seedFakeAiProvider(store));
        final draftId = (await tester.runAsync(() async {
          final parent = await database.createNotebook(
            name: 'parent',
            visibility: private
                ? NotebookVisibility.hidden
                : NotebookVisibility.normal,
          );
          final child = await database.createNotebook(
            name: 'child',
            parentId: parent,
          );
          final draft = NewDiaryDraft(
            title: 'draft',
            contentDocJson: '[{"insert":"draft text\\n"}]',
            contentText: 'draft text',
            notebookIds: [child],
          ).toSnapshot();
          return database.saveDiaryDraft(
            title: draft.title,
            contentText: draft.contentText,
            payload: draft.payload,
          );
        }))!;
        await pumpPage(
          tester,
          page: EditDiaryPage(
            entryMode: EditDiaryEntryMode.create,
            createDraftId: draftId,
          ),
        );
        await tester.tap(aiTool());
        await settle(tester);
        expect(
          find.byType(DiaryAiWritingPanel),
          private ? findsNothing : findsOneWidget,
        );
        if (private) {
          expect(find.text(l10n.aiPanelPrivateBlocked), findsOneWidget);
        } else {
          await tester.tap(find.byTooltip(l10n.commonClose));
          await settle(tester);
          await tester.tap(find.byTooltip(l10n.diaryEditorMoreActions));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.aiSuggestTitle));
          await settle(tester);
          expect(requests, hasLength(1));
        }
        await unmount(tester);
      },
    );
  }
}
