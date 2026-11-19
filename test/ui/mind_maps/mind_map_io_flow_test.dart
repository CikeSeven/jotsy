import 'package:appflowy_editor/appflowy_editor.dart' as quill;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_codec.dart';
import 'package:node_diary/core/database/mind_map/mind_map_blocks.dart';
import 'package:node_diary/core/database/mind_map/mind_map_document.dart';
import 'package:node_diary/core/database/mind_map/mind_map_text.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_mind_map_editing.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/mind_maps/controllers/mind_map_io_flow.dart';
import 'package:node_diary/ui/mind_maps/widgets/mind_map_workspace.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';

/// 导图的导出与转换入口：导图日记的 ⋮ 菜单打开导出面板（复制为大纲文字
/// 写进剪贴板），图片与 PDF 能画出来，文字日记能直接存成一篇新的导图日记
/// 并进入它的编辑页，空导图的起步卡上有导入按钮。
void main() {
  late AppDatabase database;
  late SettingsService settings;

  final map = MindMapDocument.blank().copyWith(
    root: mindMapNodeFromOutline('Plan\n  Work\n    Ship\n  Rest')!,
  );

  Future<void> setUpStores(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    settings = await SettingsService.create();
  }

  Future<void> pumpApp(WidgetTester tester, Widget home) async {
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
          home: home,
        ),
      ),
    );
  }

  Future<void> warmUp(WidgetTester tester) async {
    await tester.pumpAndSettle();
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }

  Future<String> createDiary(
    WidgetTester tester, {
    required String title,
    required Map<String, Object?> document,
    required String text,
  }) async => (await tester.runAsync(
    () => database.createDiary(
      title: title,
      contentDocJson: encodeDiaryBlocks(document),
      contentText: text,
      metadataJson: '{}',
    ),
  ))!;

  testWidgets('the mind map diary menu opens the export panel; copy as '
      'outline writes indented text', (tester) async {
    await setUpStores(tester);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final diaryId = await createDiary(
      tester,
      title: 'Plan',
      document: mindMapDiaryDocument(map),
      text: mindMapPlainText(map),
    );
    await pumpApp(tester, EditDiaryPage(diaryId: diaryId));
    await warmUp(tester);
    expect(find.byType(MindMapWorkspace), findsOneWidget);

    await tester.tap(find.byTooltip('More').first);
    await tester.pumpAndSettle();
    expect(find.text('Import from file'), findsOneWidget);
    await tester.tap(find.text('Export map'));
    await tester.pumpAndSettle();
    // 工作区显示的是画布：面板先列导图一类的格式。
    final sheet = find.byType(BottomSheet);
    Finder inSheet(String text) =>
        find.descendant(of: sheet, matching: find.text(text));
    for (final label in <String>['Image', 'PDF', 'XMind', 'FreeMind']) {
      expect(inSheet(label), findsOneWidget, reason: label);
    }
    expect(inSheet('Markdown'), findsNothing);
    expect(inSheet('Copy as outline'), findsNothing);

    await tester.tap(inSheet('Outline'));
    await tester.pumpAndSettle();
    for (final label in <String>[
      'PDF',
      'Word document',
      'Web page',
      'Markdown',
      'OPML',
      'Plain text',
      'Copy as outline',
    ]) {
      expect(inSheet(label), findsOneWidget, reason: label);
    }
    expect(inSheet('XMind'), findsNothing);

    await tester.tap(inSheet('Copy as outline'));
    await tester.pumpAndSettle();
    expect(copied, 'Plan\n- Work\n  - Ship\n- Rest');
    expect(find.text('Copied'), findsOneWidget);

    // 切到大纲后再打开，面板直接停在大纲一类。
    await tester.tap(find.text('Outline'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export map'));
    await tester.pumpAndSettle();
    expect(inSheet('Word document'), findsOneWidget);
    expect(inSheet('Image'), findsNothing);
    await unmount(tester);
  });

  testWidgets('the image and PDF exports render the whole map', (tester) async {
    await setUpStores(tester);
    late BuildContext context;
    await pumpApp(
      tester,
      Builder(
        builder: (BuildContext built) {
          context = built;
          return const SizedBox.shrink();
        },
      ),
    );
    final png = (await tester.runAsync(
      () => buildMindMapExport(context, map, MindMapExportKind.image),
    ))!;
    expect(png.sublist(1, 4), 'PNG'.codeUnits);
    final pdf = (await tester.runAsync(
      () => buildMindMapExport(context, map, MindMapExportKind.pdf),
    ))!;
    expect(String.fromCharCodes(pdf.sublist(0, 5)), '%PDF-');
    final l10n = AppLocalizations.of(context);
    expect(
      mindMapExportFileName(
        l10n,
        map.copyWith(root: map.root.copyWith(text: 'A/B: "C"?')),
        MindMapExportKind.xmind,
      ),
      'A B   C.xmind',
    );
    expect(
      mindMapExportFileName(
        l10n,
        MindMapDocument.blank(),
        MindMapExportKind.markdown,
      ),
      'Untitled mind map.md',
    );
  });

  testWidgets('converting a text diary saves a new mind map diary right '
      'away and opens its editor; the original is kept', (tester) async {
    await setUpStores(tester);
    final diaryId = await createDiary(
      tester,
      title: 'Monday',
      document: <String, Object?>{
        'document': <String, Object?>{
          'type': 'page',
          'children': <Object?>[
            <String, Object?>{
              'type': 'heading',
              'data': <String, Object?>{
                'level': 1,
                'delta': <Object?>[
                  <String, Object?>{'insert': 'Work'},
                ],
              },
            },
            <String, Object?>{
              'type': 'bulleted_list',
              'data': <String, Object?>{
                'delta': <Object?>[
                  <String, Object?>{'insert': 'Ship'},
                ],
              },
            },
          ],
        },
      },
      text: 'Work\nShip',
    );
    final diary = (await tester.runAsync(
      () => database.getDiaryWithTagsByDiaryId(diaryId),
    ))!.diary;
    await pumpApp(
      tester,
      Scaffold(
        body: Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? _) =>
              TextButton(
                onPressed: () => openMindMapFromDiary(context, ref, diary),
                child: const Text('Convert'),
              ),
        ),
      ),
    );
    await tester.tap(find.text('Convert'));
    await warmUp(tester);
    await warmUp(tester);

    // 已经存成一篇日记：库里多了一篇导图日记，标题是中心主题。
    final rows = (await tester.runAsync(
      () => database.select(database.diaries).get(),
    ))!;
    expect(rows, hasLength(2));
    final created = rows.singleWhere((row) => row.diaryId != diaryId);
    expect(created.title, 'Monday');
    expect(created.isDeleted, isFalse);
    expect(
      mindMapOutlineText(
        diaryMindMapPage(decodeStoredDiaryBlocks(created.content))!,
      ),
      'Monday\n- Work\n  - Ship',
    );
    expect(created.contentText, 'Monday\nWork\nShip');

    // 直接进的是这篇的编辑页（导图工作区），不是带“发布”的新建页。
    expect(find.byType(MindMapWorkspace), findsOneWidget);
    final page = tester.widget<EditDiaryPage>(find.byType(EditDiaryPage));
    expect(page.diaryId, created.diaryId);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(MindMapWorkspace)),
    );
    expect(find.byTooltip(l10n.autoT0136), findsNothing);

    final original = (await tester.runAsync(
      () => database.getDiaryWithTagsByDiaryId(diaryId),
    ))!.diary;
    expect(original.content, diary.content);
    await unmount(tester);
  });

  testWidgets('deleting the saved mind map diary from its editor offers '
      'undo on the page it was made from', (tester) async {
    await setUpStores(tester);
    await pumpApp(
      tester,
      Scaffold(
        body: Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? _) =>
              TextButton(
                onPressed: () => saveMindMapAsDiary(context, ref, map),
                child: const Text('Save'),
              ),
        ),
      ),
    );
    await tester.tap(find.text('Save'));
    await warmUp(tester);
    await warmUp(tester);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(MindMapWorkspace)),
    );
    final diaryId = tester
        .widget<EditDiaryPage>(find.byType(EditDiaryPage))
        .diaryId!;

    await tester.tap(find.byTooltip(l10n.diaryEditorMoreActions));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonDelete));
    await tester.pumpAndSettle();
    // 确认对话框的“删除”。
    await tester.tap(find.text(l10n.commonDelete).last);
    await warmUp(tester);
    await warmUp(tester);

    expect(find.byType(EditDiaryPage), findsNothing);
    expect(find.text(l10n.autoT0075), findsOneWidget);
    await tester.tap(find.text(l10n.commonUndo));
    await warmUp(tester);
    final restored = (await tester.runAsync(
      () => database.getDiaryWithTagsByDiaryId(diaryId),
    ))!.diary;
    expect(restored.isDeleted, isFalse);
    expect(restored.title, 'Plan');
    await unmount(tester);
  });

  testWidgets('the starter card of an empty map offers importing a file', (
    tester,
  ) async {
    await setUpStores(tester);
    final empty = MindMapDocument.blank();
    final diaryId = await createDiary(
      tester,
      title: '',
      document: mindMapDiaryDocument(empty),
      text: '',
    );
    await pumpApp(tester, EditDiaryPage(diaryId: diaryId));
    await warmUp(tester);
    expect(find.byTooltip('Import from file'), findsOneWidget);
    await unmount(tester);
  });
}
