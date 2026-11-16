import 'package:appflowy_editor/appflowy_editor.dart' as quill;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_codec.dart';
import 'package:node_diary/core/database/mind_map/mind_map_blocks.dart';
import 'package:node_diary/core/database/mind_map/mind_map_document.dart';
import 'package:node_diary/core/database/mind_map/mind_map_text.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mind_map_entry_chip.dart';
import 'package:node_diary/ui/mind_maps/widgets/mind_map_workspace.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';

/// 导图日记在编辑页里：新建空白日记可以转成导图（草稿照常保存，中心主题
/// 就是标题），空导图可以转回文字，功能关闭时没有按钮；编辑已有的导图
/// 日记直接是画布，改动经日记的自动保存写库；导图日记没有预览页，“更多”
/// 里留着分享、导出与写留言。
void main() {
  late AppDatabase database;
  late SettingsService settings;

  Future<void> setUpStores(
    WidgetTester tester, {
    Map<String, Object> prefs = const <String, Object>{},
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(prefs);
    database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    settings = await SettingsService.create();
  }

  Future<void> open(WidgetTester tester, Widget page) async {
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
            quill.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<Object?>(
                  MaterialPageRoute<Object?>(builder: (_) => page),
                ),
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
  }

  Future<void> settle(WidgetTester tester, Duration duration) async {
    await tester.pump(duration);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }

  testWidgets('a blank new diary turns into a mind map whose central topic '
      'becomes the draft title', (tester) async {
    await setUpStores(tester);
    await open(
      tester,
      const EditDiaryPage(entryMode: EditDiaryEntryMode.create),
    );
    expect(find.byType(DiaryMindMapEntryChip), findsOneWidget);
    await tester.tap(find.text('Mind map'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(MindMapWorkspace), findsOneWidget);

    // 没写标题：直接编辑中心主题。
    final editor = find.descendant(
      of: find.byType(MindMapWorkspace),
      matching: find.byType(TextField),
    );
    expect(editor, findsOneWidget);
    await tester.enterText(editor, 'Summer trip');
    await tester.tap(find.text('Done'));
    await settle(tester, const Duration(milliseconds: 1500));

    final drafts = (await tester.runAsync(
      () => database.watchDiaryDrafts().first,
    ))!;
    expect(drafts, hasLength(1));
    expect(drafts.single.title, 'Summer trip');
    expect(drafts.single.contentText, 'Summer trip');
    await unmount(tester);
  });

  testWidgets('an empty map can go back to a text diary', (tester) async {
    await setUpStores(tester);
    await open(
      tester,
      const EditDiaryPage(entryMode: EditDiaryEntryMode.create),
    );
    await tester.tap(find.text('Mind map'));
    await tester.pump();
    // 等画布从按钮处展开完（展开途中裁切之外点不到）。
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back to text'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(MindMapWorkspace), findsNothing);
    expect(find.byType(DiaryMindMapEntryChip), findsOneWidget);
    // 什么都没写：不留草稿。
    await settle(tester, const Duration(milliseconds: 1500));
    final drafts = (await tester.runAsync(
      () => database.watchDiaryDrafts().first,
    ))!;
    expect(drafts, isEmpty);
    await unmount(tester);
  });

  testWidgets('turning mind maps off hides the button', (tester) async {
    await setUpStores(
      tester,
      prefs: <String, Object>{
        'app.settings.app_features': '{"mindMaps":false}',
      },
    );
    await open(
      tester,
      const EditDiaryPage(entryMode: EditDiaryEntryMode.create),
    );
    expect(find.byType(DiaryMindMapEntryChip), findsNothing);
    await unmount(tester);
  });

  testWidgets('editing a mind map diary saves through the diary autosave', (
    tester,
  ) async {
    await setUpStores(tester);
    final map = MindMapDocument.blank().copyWith(
      root: mindMapNodeFromOutline('Plan\n  Work\n  Rest')!,
    );
    final diaryId = (await tester.runAsync(
      () => database.createDiary(
        title: 'Plan',
        contentDocJson: encodeDiaryBlocks(mindMapDiaryDocument(map)),
        contentText: mindMapPlainText(map),
        metadataJson: '{}',
      ),
    ))!;
    await open(tester, EditDiaryPage(diaryId: diaryId));
    expect(find.byType(MindMapWorkspace), findsOneWidget);

    await tester.tap(find.text('Add topic'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
      find.descendant(
        of: find.byType(MindMapWorkspace),
        matching: find.byType(TextField),
      ),
      'Play',
    );
    await tester.tap(find.text('Done'));
    await settle(tester, const Duration(milliseconds: 800));

    final saved = (await tester.runAsync(
      () => database.getDiaryWithTagsByDiaryId(diaryId),
    ))!;
    final stored = diaryMindMapPage(
      decodeStoredDiaryBlocks(saved.diary.content),
    );
    expect(stored?.root.children.map((n) => n.text), ['Work', 'Rest', 'Play']);
    expect(saved.diary.contentText, 'Plan\nWork\nRest\nPlay');
    expect(saved.diary.title, 'Plan');
    await unmount(tester);
  });

  testWidgets('a mind map diary has no preview page, so More keeps share, '
      'export and writing a comment', (tester) async {
    await setUpStores(
      tester,
      prefs: <String, Object>{
        'app.settings.app_features': AppFeatures.defaults
            .copyWith(comments: true)
            .encode(),
      },
    );
    final map = MindMapDocument.blank().copyWith(
      root: mindMapNodeFromOutline('Plan\n  Work')!,
    );
    final diaryId = (await tester.runAsync(
      () => database.createDiary(
        title: 'Plan',
        contentDocJson: encodeDiaryBlocks(mindMapDiaryDocument(map)),
        contentText: mindMapPlainText(map),
        metadataJson: '{}',
      ),
    ))!;
    await open(tester, EditDiaryPage(diaryId: diaryId));
    final l10n = AppLocalizations.of(
      tester.element(find.byType(MindMapWorkspace)),
    );

    await tester.tap(find.byTooltip(l10n.diaryEditorMoreActions));
    await tester.pumpAndSettle();
    Finder item(String label) => find.widgetWithText(ExpressiveMenuItem, label);
    expect(item(l10n.mindMapExport), findsOneWidget);
    expect(item(l10n.previewShare), findsOneWidget);
    expect(item(l10n.previewExport), findsOneWidget);
    expect(item(l10n.diaryCommentSheetNew), findsOneWidget);
    await unmount(tester);
  });
}
