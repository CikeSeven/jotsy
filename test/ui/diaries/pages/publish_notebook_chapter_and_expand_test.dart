import 'package:appflowy_editor/appflowy_editor.dart' as quill;
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_create_prefs.dart';
import 'package:node_diary/ui/diaries/models/diary_edit_prefs.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/pages/publish_diary_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_create_prefs_provider.dart';
import 'package:node_diary/ui/diaries/providers/diary_edit_prefs_provider.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';
import '../../../support/publish_panel_driver.dart';

/// 发布页自动展开详细信息面板、收进日记本时直接指定章节，以及编辑器默认小图偏好同步。
void main() {
  late AppDatabase database;
  late SettingsService settings;
  late List<Object?> results;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
    results = <Object?>[];
  });
  tearDown(() => database.close());

  Future<void> openPublisher(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const draft = NewDiaryDraft(
      title: 'A day trip',
      contentDocJson: '[{"insert":"A day trip\\n"}]',
      contentText: 'A day trip',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(brightness),
          locale: const Locale('zh'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            quill.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  results.add(
                    await Navigator.of(context).push<Object?>(
                      MaterialPageRoute(
                        builder: (_) =>
                            const PublishDiaryPage(initialDraft: draft),
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

  Future<String> leavePublisher(WidgetTester tester) async {
    for (var i = 0; i < 3 && results.isEmpty; i++) {
      await tester.binding.handlePopRoute();
      for (var j = 0; j < 15 && results.isEmpty; j++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
    await tester.pumpAndSettle();
    expect(results, hasLength(1));
    return results.single! as String;
  }

  testWidgets('publish panel stays collapsed by default', (tester) async {
    await openPublisher(tester);
    final driver = PublishPanelDriver(tester);
    expect(driver.collapsedHeader, findsOneWidget);
    expect(driver.expandedHeader, findsNothing);
    expect(tester.getTopLeft(driver.collapsedHeader).dy, greaterThan(750));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'auto-expands publish panel when enabled and saves selected chapter (${brightness.name})',
      (tester) async {
        await saveDiaryCreatePrefs(
          settings,
          const DiaryCreatePrefs(expandPublishPanel: true),
        );
        final travel = await tester.runAsync(
          () => database.createNotebook(
            name: '旅行',
            kind: NotebookKind.manual,
            payload: NotebookPayload(
              chapters: <NotebookChapter>[
                NotebookChapter(id: 'c1', title: '行前'),
                NotebookChapter(id: 'c2', title: '行程'),
              ],
            ),
          ),
        );
        await openPublisher(tester, brightness: brightness);

        // 发布后自动弹出底部详细信息面板。
        final driver = PublishPanelDriver(tester);
        expect(driver.expandedHeader, findsOneWidget);
        expect(tester.getTopLeft(driver.expandedHeader).dy, lessThan(500));
        expect(tester.takeException(), isNull);

        // 点“日记本”行 -> 勾选“旅行” -> 行内展开章节 -> 点选“行程”。
        await tester.tap(find.text('日记本'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(ValueKey<String>('publish_notebook_$travel')),
        );
        await tester.pumpAndSettle();
        expect(find.text('行前'), findsOneWidget);
        expect(find.text('行程'), findsOneWidget);

        await tester.tap(
          find.byKey(ValueKey<String>('notebook_pick_chapter_${travel}_c2')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('返回').first);
        await tester.pumpAndSettle();
        expect(find.text('旅行 · 行程'), findsOneWidget);

        // 再切换章节到“行前”，验证已写库后的发布页更新章节也会落盘。
        await tester.tap(find.text('日记本'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(ValueKey<String>('notebook_pick_chapter_${travel}_c1')),
        );
        await tester.pumpAndSettle();

        final diaryId = await leavePublisher(tester);
        final memberships = await tester.runAsync(
          () => database.getDiaryNotebookMemberships(diaryId),
        );
        expect(memberships, <String, String?>{travel!: 'c1'});

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  }

  testWidgets(
    'editing existing diary allows changing chapter while keeping position and syncs default thumbnail pref',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final travel = await database.createNotebook(
        name: '旅行',
        kind: NotebookKind.manual,
        payload: NotebookPayload(
          chapters: <NotebookChapter>[
            NotebookChapter(id: 'c1', title: '行前'),
            NotebookChapter(id: 'c2', title: '行程'),
          ],
        ),
      );
      final firstId = await database.createDiary(
        title: 'First',
        contentDocJson: '[{"insert":"First\\n"}]',
        contentText: 'First',
        metadataJson: '{}',
        notebookIds: <String>[travel],
      );
      final targetId = await database.createDiary(
        title: 'Target',
        contentDocJson: '[{"insert":"Target\\n"}]',
        contentText: 'Target',
        metadataJson: '{}',
        notebookIds: <String>[travel],
        notebookChapterIds: <String, String>{travel: 'c1'},
      );
      await saveDiaryEditPrefs(
        settings,
        const DiaryEditPrefs(defaultMediaThumbnail: true),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            settingsServiceProvider.overrideWith((ref) async => settings),
          ],
          child: MaterialApp(
            theme: expressiveTestTheme(Brightness.light),
            locale: const Locale('zh'),
            localizationsDelegates: const [
              ...AppLocalizations.localizationsDelegates,
              quill.AppFlowyEditorLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: EditDiaryPage(diaryId: targetId),
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }

      // 默认小图开关同步到编辑器控制器，且切换设置后实时更新。
      final editor = tester.widget<DiaryEditor>(find.byType(DiaryEditor));
      expect(editor.controller.defaultMediaThumbnail, isTrue);
      await saveDiaryEditPrefs(
        settings,
        const DiaryEditPrefs(defaultMediaThumbnail: false),
      );
      await tester.pump();
      expect(
        tester
            .widget<DiaryEditor>(find.byType(DiaryEditor))
            .controller
            .defaultMediaThumbnail,
        isFalse,
      );

      // 打开信息面板 -> 日记本 -> 把 Target 从 c1 改到 c2。
      final panel = PublishPanelDriver(tester);
      await panel.open();
      await tester.tap(find.text('日记本'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey<String>('notebook_pick_chapter_${travel}_c2')),
      );
      await tester.pumpAndSettle();

      // 等待自动保存落盘。
      await tester.pump(const Duration(milliseconds: 600));
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }

      final contents = await tester.runAsync(
        () => (database.select(
          database.diaryNotebooks,
        )..orderBy([(t) => OrderingTerm.asc(t.position)])).get(),
      );
      expect(contents, hasLength(2));
      expect(contents![0].chapterId, isNull); // First 仍在第一位
      expect(contents[1].chapterId, 'c2'); // Target 仍在第二位且已换到 c2
      final firstLocal = (await tester.runAsync(
        () => database.getDiaryWithTagsByDiaryId(firstId),
      ))!.diary.id;
      expect(contents[0].diaryId, firstLocal);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}
