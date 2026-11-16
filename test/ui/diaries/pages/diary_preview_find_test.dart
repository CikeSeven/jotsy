import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_find_query.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_find_highlight.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_find_revealer.dart';
import 'package:node_diary/ui/diaries/widgets/diary_find_bar/diary_find_bar.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

/// 预览页的正文查找（只找不替换）：“更多 → 查找”打开页面底部的悬浮
/// 查找栏（没有替换），匹配处换成搜索结果的高亮样式；返回键先关查找；
/// 从搜索结果打开时带着搜索词、跳到第一处且不弹键盘，正文没有时不打开；
/// 桌面 Ctrl + F 在单篇与翻页器里都打开当前这一篇的查找。
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

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => database.close());

  Future<String> seed(List<String> paragraphs, {String title = '周末'}) =>
      database.createDiary(
        title: title,
        contentDocJson: _content(paragraphs),
        contentText: paragraphs.join('\n'),
        metadataJson: '{}',
      );

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
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
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
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  AppLocalizations l10nOf(WidgetTester tester) =>
      tester.element(find.byType(DiaryPreviewPage)).l10n;

  Finder field() => find.descendant(
    of: find.byKey(const ValueKey<String>('diary-find-field')),
    matching: find.byType(TextField),
  );

  String? count(WidgetTester tester) {
    final label = find.byKey(const ValueKey<String>('diary-find-count'));
    return label.evaluate().isEmpty ? null : tester.widget<Text>(label).data;
  }

  /// 正文里底色是 [style] 底色的文字片段。
  List<String> highlighted(WidgetTester tester, TextStyle style) {
    final out = <String>[];
    for (final element
        in find
            .descendant(
              of: find.byType(DiaryEditor),
              matching: find.byType(RichText),
            )
            .evaluate()) {
      (element.widget as RichText).text.visitChildren((span) {
        if (span is TextSpan &&
            span.text != null &&
            span.style?.backgroundColor == style.backgroundColor) {
          out.add(span.text!);
        }
        return true;
      });
    }
    return out;
  }

  DiaryFindHighlightStyles stylesOf(WidgetTester tester) =>
      DiaryFindHighlightStyles.of(
        Theme.of(tester.element(find.byType(DiaryEditor))).colorScheme,
      );

  /// 当前匹配此刻在屏幕上的矩形。
  List<Rect> currentRects(WidgetTester tester) {
    final editor = tester.widget<DiaryEditor>(find.byType(DiaryEditor));
    return diaryFindMatchGlobalRects(editor.controller.find.current!);
  }

  Future<void> pressCtrlF(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  testWidgets('the more menu opens find without replace; back closes it', (
    tester,
  ) async {
    final id = await tester.runAsync(() => seed(['春天的猫', '没有', '猫又来了']));
    await openPage(tester, DiaryPreviewPage(diaryId: id!));
    final l10n = l10nOf(tester);

    await tester.tap(find.byTooltip(l10n.autoT0125));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.diaryFind));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryFindBar), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('diary-find-replace-toggle')),
      findsNothing,
    );
    expect(tester.widget<TextField>(field()).focusNode!.hasFocus, isTrue);

    await tester.enterText(field(), '猫');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(count(tester), '1/2');
    final styles = stylesOf(tester);
    expect(highlighted(tester, styles.current), ['猫']);
    expect(highlighted(tester, styles.match), ['猫']);

    // 返回键先关查找（卡片降下后拿掉），页面还在；高亮随之消失。
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(DiaryFindBar), findsNothing);
    expect(find.byType(DiaryPreviewPage), findsOneWidget);
    expect(highlighted(tester, styles.current), isEmpty);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(DiaryPreviewPage), findsNothing);
    await unmount(tester);
  });

  testWidgets('a search result jumps to the first hit without the keyboard', (
    tester,
  ) async {
    final id = await tester.runAsync(
      () => seed([
        for (var i = 0; i < 80; i++) 'Filler paragraph $i',
        'the needle is here',
        'another Needle',
      ]),
    );
    await openPage(
      tester,
      DiaryPreviewPage(
        diaryId: id!,
        initialFind: DiaryFindQuery.fromSearchTerms(const ['needle']),
      ),
    );
    expect(find.byType(DiaryFindBar), findsOneWidget);
    expect(count(tester), '1/2');
    expect(tester.widget<TextField>(field()).focusNode!.hasFocus, isFalse);
    expect(highlighted(tester, stylesOf(tester).current), ['needle']);

    final rects = currentRects(tester);
    expect(rects, isNotEmpty);
    expect(rects.first.top, greaterThanOrEqualTo(0));
    // 停在查找栏上方，没有被底部的卡片盖住。
    expect(
      rects.first.bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(DiaryFindBar)).top),
    );
    await unmount(tester);
  });

  testWidgets('a search hit outside the body leaves find closed', (
    tester,
  ) async {
    final id = await tester.runAsync(() => seed(['正文没有'], title: '标题里的词'));
    await openPage(
      tester,
      DiaryPreviewPage(
        diaryId: id!,
        initialFind: DiaryFindQuery.fromSearchTerms(const ['标题']),
      ),
    );
    expect(find.byType(DiaryFindBar), findsNothing);
    await unmount(tester);
  });

  testWidgets('ctrl+f opens find on the current page, single or paged', (
    tester,
  ) async {
    final first = await tester.runAsync(() => seed(['first cat']));
    final second = await tester.runAsync(() => seed(['second cat']));
    await openPage(
      tester,
      DiaryPreviewPage(diaryId: first!),
      size: const Size(1280, 900),
    );
    await pressCtrlF(tester);
    expect(find.byType(DiaryFindBar), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(DiaryFindBar), findsNothing);
    expect(find.byType(DiaryPreviewPage), findsOneWidget);
    await unmount(tester);

    final items = await tester.runAsync(
      () => Future.wait([
        database.getDiaryWithTagsByDiaryId(first),
        database.getDiaryWithTagsByDiaryId(second!),
      ]),
    );
    await openPage(
      tester,
      DiaryPreviewPage(
        diaryId: second!,
        sequence: DiaryPreviewSequence.fromItems(items!.nonNulls),
      ),
      size: const Size(1280, 900),
    );
    await pressCtrlF(tester);
    final bar = find.byType(DiaryFindBar);
    expect(bar, findsOneWidget);
    // 打开的是当前（第二篇）那一页的查找。
    final view = tester.widget<DiaryPreviewView>(
      find.ancestor(of: bar, matching: find.byType(DiaryPreviewView)),
    );
    expect(view.diaryId, second);
    await unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
