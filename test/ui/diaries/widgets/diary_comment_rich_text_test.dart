import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/rich_text/inline_rich_text.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_comments/diary_comment_sheet.dart';
import 'package:node_diary/ui/diaries/widgets/diary_comments/diary_comment_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

/// 留言的格式与链接：写留言面板的格式条、链接对话框、`@` / `[[` 候选，
/// 以及时间线上的显示与点按。用真实的内存数据库查候选。
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
    }
  }

  Future<String> seedDiary(WidgetTester tester, String title) async {
    return (await tester.runAsync(
      () => db.createDiary(
        title: title,
        contentDocJson: '[{"insert":"body\\n"}]',
        contentText: 'body',
        metadataJson: '{}',
      ),
    ))!;
  }

  /// 打开面板，返回取得结果的 future（保存后完成）。
  Future<(AppLocalizations, Future<DiaryCommentDraft?>)> openSheet(
    WidgetTester tester, {
    String? diaryId,
  }) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = (await tester.runAsync(SettingsService.create))!;
    late Future<DiaryCommentDraft?> result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => result = showDiaryCommentSheet(
                  context,
                  title: 'Comment',
                  moodOptions: const <String>[],
                  diaryId: diaryId,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('open'));
    await settle(tester);
    final l10n = tester.element(find.byType(DiaryCommentSheet)).l10n;
    return (l10n, result);
  }

  Finder field() => find.descendant(
    of: find.byType(DiaryCommentSheet),
    matching: find.byType(TextField),
  );

  TextEditingController controller(WidgetTester tester) =>
      tester.widget<TextField>(field()).controller!;

  Future<DiaryCommentDraft?> save(
    WidgetTester tester,
    AppLocalizations l10n,
    Future<DiaryCommentDraft?> result,
  ) async {
    await tester.tap(find.text(l10n.commonSave));
    await settle(tester);
    return result;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('bold on a selection is saved with the comment', (tester) async {
    final (l10n, result) = await openSheet(tester);
    await tester.enterText(field(), 'hello world');
    controller(tester).selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 5,
    );
    await tester.pump();
    await tester.tap(find.byTooltip(l10n.autoT0008));
    await tester.pump();

    final draft = await save(tester, l10n, result);
    expect(draft!.content, 'hello world');
    expect(draft.runs, const <InlineTextRun>[
      InlineTextRun('hello', InlineTextMarks(bold: true)),
      InlineTextRun(' world'),
    ]);
    await unmount(tester);
  });

  testWidgets('the link button links the selection to a web address', (
    tester,
  ) async {
    final (l10n, result) = await openSheet(tester);
    await tester.enterText(field(), 'see docs');
    controller(tester).selection = const TextSelection(
      baseOffset: 4,
      extentOffset: 8,
    );
    await tester.pump();
    await tester.tap(find.byTooltip(l10n.autoT0024));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, l10n.diaryEditorLinkUrl),
      'example.com',
    );
    await tester.tap(find.text(l10n.commonConfirm));
    await settle(tester);

    final draft = await save(tester, l10n, result);
    expect(draft!.runs, const <InlineTextRun>[
      InlineTextRun('see '),
      InlineTextRun('docs', InlineTextMarks(href: 'https://example.com')),
    ]);
    await unmount(tester);
  });

  testWidgets('typing @ lists diaries and picking one writes a diary link', (
    tester,
  ) async {
    final target = await seedDiary(tester, 'Beach day');
    final self = await seedDiary(tester, 'This one');
    final (l10n, result) = await openSheet(tester, diaryId: self);
    await tester.enterText(field(), 'see ');
    await tester.enterText(field(), 'see @');
    await settle(tester);
    expect(find.text('Beach day'), findsOneWidget);
    // 留言所属的那篇不出现在候选里。
    expect(find.text('This one'), findsNothing);

    await tester.tap(find.text('Beach day'));
    await settle(tester);
    expect(controller(tester).text, 'see Beach day');
    // 链接后面接着打字不会延长链接。
    await tester.enterText(field(), 'see Beach day!');
    final draft = await save(tester, l10n, result);
    expect(draft!.runs, <InlineTextRun>[
      const InlineTextRun('see '),
      InlineTextRun(
        'Beach day',
        InlineTextMarks(href: 'jotsy://diary/$target'),
      ),
      const InlineTextRun('!'),
    ]);
    await unmount(tester);
  });

  testWidgets('[[ opens the same candidates and a typed return picks one', (
    tester,
  ) async {
    final target = await seedDiary(tester, 'Beach day');
    final (l10n, result) = await openSheet(tester);
    await tester.enterText(field(), 'a [');
    await tester.enterText(field(), 'a [[');
    await settle(tester);
    expect(find.text('Beach day'), findsOneWidget);
    // 软键盘的回车写入高亮的第一项。
    await tester.enterText(field(), 'a [[\n');
    await settle(tester);
    expect(controller(tester).text, 'a Beach day');

    final draft = await save(tester, l10n, result);
    expect(
      draft!.runs!.last,
      InlineTextRun(
        'Beach day',
        InlineTextMarks(href: 'jotsy://diary/$target'),
      ),
    );
    await unmount(tester);
  });

  testWidgets('desktop: Ctrl + B formats and arrow keys pick a candidate', (
    tester,
  ) async {
    // 平台覆盖须在测试体内复原（框架在 tearDown 之前核对调试变量）。
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final older = await seedDiary(tester, 'Older trip');
    await seedDiary(tester, 'Newer trip');
    final (l10n, result) = await openSheet(tester);
    await tester.enterText(field(), 'go ');
    controller(tester).selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 2,
    );
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    await tester.enterText(field(), 'go @');
    await settle(tester);
    // 候选按更新时间新 → 旧：↓ 移到第二项（较早的那篇），回车写入。
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(controller(tester).text, 'go Older trip');

    final draft = await save(tester, l10n, result);
    expect(draft!.runs, <InlineTextRun>[
      const InlineTextRun('go', InlineTextMarks(bold: true)),
      const InlineTextRun(' '),
      InlineTextRun(
        'Older trip',
        InlineTextMarks(href: 'jotsy://diary/$older'),
      ),
    ]);
    debugDefaultTargetPlatformOverride = null;
    await unmount(tester);
  });

  testWidgets('@ inside a word does not open candidates', (tester) async {
    await seedDiary(tester, 'Beach day');
    await openSheet(tester);
    await tester.enterText(field(), 'mail');
    await tester.enterText(field(), 'mail@');
    await settle(tester);
    expect(find.text('Beach day'), findsNothing);
    await unmount(tester);
  });

  group('DiaryCommentText', () {
    Future<List<String>> pumpText(
      WidgetTester tester,
      List<InlineTextRun> runs, {
      bool notebookLinks = true,
    }) async {
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          home: Scaffold(
            body: DiaryCommentText(
              runs: runs,
              style: const TextStyle(fontSize: 16),
              onOpenLink: opened.add,
              notebookLinks: notebookLinks,
            ),
          ),
        ),
      );
      return opened;
    }

    TextSpan spanOf(WidgetTester tester, String text) {
      final rich = tester.widget<RichText>(find.byType(RichText));
      TextSpan? found;
      rich.text.visitChildren((span) {
        if (span is TextSpan && span.text == text) found = span;
        return found == null;
      });
      return found!;
    }

    testWidgets('formats are drawn and links open on tap', (tester) async {
      final opened = await pumpText(tester, const <InlineTextRun>[
        InlineTextRun('Bold', InlineTextMarks(bold: true)),
        InlineTextRun(' and '),
        InlineTextRun('trip', InlineTextMarks(href: 'jotsy://diary/d-1')),
      ]);
      expect(spanOf(tester, 'Bold').style?.fontWeight, FontWeight.w700);
      await tester.tapOnText(find.textRange.ofSubstring('trip'));
      expect(opened, <String>['jotsy://diary/d-1']);
    });

    testWidgets('a bare web address in plain text is tappable', (tester) async {
      final opened = await pumpText(tester, const <InlineTextRun>[
        InlineTextRun('see https://example.com/a, ok'),
      ]);
      await tester.tapOnText(
        find.textRange.ofSubstring('https://example.com/a'),
      );
      expect(opened, <String>['https://example.com/a']);
    });

    testWidgets('with notebooks off a notebook link is plain text', (
      tester,
    ) async {
      final opened = await pumpText(tester, const <InlineTextRun>[
        InlineTextRun('shelf', InlineTextMarks(href: 'jotsy://notebook/n-1')),
      ], notebookLinks: false);
      expect(spanOf(tester, 'shelf').recognizer, isNull);
      await tester.tapOnText(find.textRange.ofSubstring('shelf'));
      expect(opened, isEmpty);
    });
  });
}
