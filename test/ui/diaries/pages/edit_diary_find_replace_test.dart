import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_find_replace.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_find_highlight.dart';
import 'package:node_diary/ui/diaries/widgets/diary_find_bar/diary_find_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

/// 编辑页的查找与替换（#231）：“更多”菜单打开后顶栏换成查找栏，输入防抖
/// 后计数、高亮画在块里，上一个 / 下一个，全部替换后提示条可撤销；返回键
/// 先关查找、选中当前匹配交还正文；新建页同样有入口；桌面 Ctrl + F / Ctrl
/// + H 打开、Esc 关闭；文末的匹配滚进视野。
///
/// 编辑器拿到焦点后光标闪烁，pumpAndSettle 等不到静止，这里一律固定帧数。
String _content(List<String> paragraphs) => jsonEncode({
  'document': {
    'type': 'page',
    'children': [
      for (final text in paragraphs)
        {
          'type': 'paragraph',
          'data': {
            'delta': [
              if (text.isNotEmpty) {'insert': text},
            ],
          },
        },
    ],
  },
});

void main() {
  late AppDatabase database;
  late SettingsService settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
  });
  tearDown(() => database.close());

  Future<String> seed(List<String> paragraphs) => database.createDiary(
    title: 'Probe',
    contentDocJson: _content(paragraphs),
    contentText: paragraphs.join('\n'),
    metadataJson: '{}',
  );

  Future<void> settle(WidgetTester tester, [int frames = 20]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> openPage(
    WidgetTester tester,
    Widget page, {
    Size size = const Size(400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
            af.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => page)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  AppLocalizations l10nOf(WidgetTester tester) =>
      tester.element(find.byType(EditDiaryPage)).l10n;

  DiaryEditorController body(WidgetTester tester) =>
      tester.widget<DiaryEditor>(find.byType(DiaryEditor)).controller;

  List<String> texts(WidgetTester tester) => [
    for (final node in body(tester).document.root.children)
      node.delta?.toPlainText() ?? '',
  ];

  Finder field(String key) => find.descendant(
    of: find.byKey(ValueKey<String>(key)),
    matching: find.byType(TextField),
  );

  String? count(WidgetTester tester) {
    final label = find.byKey(const ValueKey<String>('diary-find-count'));
    return label.evaluate().isEmpty ? null : tester.widget<Text>(label).data;
  }

  Future<void> typeFind(WidgetTester tester, String text) async {
    await tester.enterText(field('diary-find-field'), text);
    await tester.pump(kDiaryFindDebounce);
    await settle(tester, 4);
  }

  Future<void> openFromMenu(WidgetTester tester, String moreTooltip) async {
    await tester.tap(find.byTooltip(moreTooltip));
    await settle(tester, 8);
    await tester.tap(find.text(l10nOf(tester).diaryFindReplace));
    await settle(tester, 8);
  }

  testWidgets('find, highlight, replace all with undo and close on back', (
    tester,
  ) async {
    final id = await tester.runAsync(
      () => seed(['a cat sat', 'no match', 'the cat']),
    );
    await openPage(tester, EditDiaryPage(diaryId: id!));
    final l10n = l10nOf(tester);
    expect(find.byTooltip(l10n.previewShare), findsOneWidget);

    await openFromMenu(tester, l10n.autoT0125);
    expect(find.byType(DiaryFindBar), findsOneWidget);
    // 顶栏换成了查找栏，查找框拿到焦点。
    expect(find.byTooltip(l10n.previewShare), findsNothing);
    expect(
      tester.widget<TextField>(field('diary-find-field')).focusNode!.hasFocus,
      isTrue,
    );

    await typeFind(tester, 'cat');
    expect(count(tester), '1/2');
    final find0 = body(tester).find;
    expect(find0.matches, hasLength(2));
    // 第一块里画着当前匹配（带描边的深色）。
    final first = body(tester).document.root.children.first;
    final highlight = find.byWidgetPredicate(
      (widget) =>
          widget is DiaryFindHighlight && identical(widget.block, first),
    );
    final colors = tester.widget<DiaryFindHighlight>(highlight).colors;
    expect(
      tester.renderObject(highlight),
      paints
        ..rrect(color: colors.current)
        ..rrect(color: colors.currentBorder),
    );

    await tester.tap(find.byKey(const ValueKey<String>('diary-find-next')));
    await settle(tester, 4);
    expect(count(tester), '2/2');

    await tester.tap(
      find.byKey(const ValueKey<String>('diary-find-replace-toggle')),
    );
    await settle(tester, 8);
    await tester.enterText(field('diary-replace-field'), 'dog');
    await tester.tap(find.byKey(const ValueKey<String>('diary-replace-all')));
    await settle(tester, 6);
    expect(texts(tester), ['a dog sat', 'no match', 'the dog']);
    expect(find.text(l10n.diaryReplaceAllDone(2)), findsOneWidget);
    expect(count(tester), l10n.diaryFindNoResults);

    await tester.tap(find.text(l10n.commonUndo));
    await settle(tester, 6);
    expect(texts(tester), ['a cat sat', 'no match', 'the cat']);

    // 返回键先关掉查找，页面还在；当前匹配选中交还正文。
    await typeFind(tester, 'the');
    final current = body(tester).find.current!;
    await tester.binding.handlePopRoute();
    await settle(tester, 8);
    expect(find.byType(DiaryFindBar), findsNothing);
    expect(find.byType(EditDiaryPage), findsOneWidget);
    expect(find.byTooltip(l10n.previewShare), findsOneWidget);
    expect(body(tester).find.isOpen, isFalse);
    final selection = body(tester).selection!;
    expect(selection.start.path, current.path);
    expect(selection.start.offset, current.start);
    expect(selection.end.offset, current.end);

    await unmount(tester);
  });

  testWidgets('the create page menu opens find and regex counts groups', (
    tester,
  ) async {
    await openPage(
      tester,
      const EditDiaryPage(entryMode: EditDiaryEntryMode.create),
    );
    final l10n = l10nOf(tester);
    final controller = body(tester);
    final node = controller.document.root.children.first;
    controller.apply(
      controller.state.transaction..insertText(node, 0, 'Call 010-1234 now'),
    );
    await settle(tester, 4);

    await openFromMenu(tester, l10n.diaryEditorMoreActions);
    await typeFind(tester, r'(\d+)-(\d+)');
    expect(count(tester), l10n.diaryFindNoResults);
    await tester.tap(find.byKey(const ValueKey<String>('diary-find-regex')));
    await settle(tester, 4);
    expect(count(tester), '1/1');

    await typeFind(tester, r'(\d+');
    expect(count(tester), l10n.diaryFindInvalidRegex);

    await tester.tap(find.byTooltip(l10n.diaryFindClose));
    await settle(tester, 8);
    expect(find.byType(DiaryFindBar), findsNothing);
    await unmount(tester);
  });

  testWidgets('ctrl+f and ctrl+h open find and replace, escape closes it', (
    tester,
  ) async {
    final id = await tester.runAsync(() => seed(['first cat', 'second cat']));
    await openPage(
      tester,
      EditDiaryPage(diaryId: id!),
      size: const Size(1280, 900),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester, 6);
    expect(find.byType(DiaryFindBar), findsOneWidget);
    expect(
      tester.widget<TextField>(field('diary-find-field')).focusNode!.hasFocus,
      isTrue,
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester, 8);
    expect(
      tester
          .widget<TextField>(field('diary-replace-field'))
          .focusNode!
          .hasFocus,
      isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester, 8);
    expect(find.byType(DiaryFindBar), findsNothing);
    expect(find.byType(EditDiaryPage), findsOneWidget);
    await unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('a match near the end is scrolled into view', (tester) async {
    final id = await tester.runAsync(
      () => seed([
        for (var i = 0; i < 80; i++) 'Paragraph number $i with filler text',
        'the needle is here',
      ]),
    );
    await openPage(tester, EditDiaryPage(diaryId: id!));
    await openFromMenu(tester, l10nOf(tester).autoT0125);
    await typeFind(tester, 'needle');
    await settle(tester, 6);
    final match = body(tester).find.current!;
    final rects = diaryFindMatchGlobalRects(match);
    expect(rects, isNotEmpty);
    final editorBox = tester.getRect(find.byType(DiaryEditor));
    expect(rects.first.top, greaterThanOrEqualTo(editorBox.top));
    expect(rects.first.bottom, lessThanOrEqualTo(editorBox.bottom));
    await unmount(tester);
  });
}
