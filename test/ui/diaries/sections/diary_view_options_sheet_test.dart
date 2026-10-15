import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';
import 'package:node_diary/ui/diaries/sections/diary_view_options_sheet.dart';

import '../../../support/expressive_test_theme.dart';

typedef _Calls = ({List<DiarySortMode> sorts, List<DiaryLayoutMode> layouts});

/// 经真实入口打开面板（zh），记录两类回调。
Future<_Calls> _openSheet(
  WidgetTester tester, {
  DiarySortMode sortMode = DiarySortMode.updatedDesc,
  double textScale = 1,
}) async {
  final calls = (sorts: <DiarySortMode>[], layouts: <DiaryLayoutMode>[]);
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(Brightness.light),
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showDiaryViewOptionsSheet(
                context,
                sortMode: sortMode,
                layoutMode: DiaryLayoutMode.list,
                onSortModeChanged: calls.sorts.add,
                onLayoutModeChanged: calls.layouts.add,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return calls;
}

Color? _tileColor(WidgetTester tester, String label) => tester
    .widget<ListTile>(
      find.ancestor(of: find.text(label), matching: find.byType(ListTile)),
    )
    .tileColor;

void main() {
  testWidgets('options apply on tap while the sheet stays open', (
    tester,
  ) async {
    final calls = await _openSheet(tester);
    expect(find.text('最近更新的在前'), findsOneWidget);

    await tester.tap(find.text('发表时间'));
    await tester.pumpAndSettle();
    // 换排序依据保留当前方向（倒序），说明文字随之更新，面板不关闭。
    expect(calls.sorts, <DiarySortMode>[DiarySortMode.createdDesc]);
    expect(find.text('最新发表的在前'), findsOneWidget);
    expect(find.text('最近更新的在前'), findsNothing);
    expect(find.byType(DiaryViewOptionsSheet), findsOneWidget);

    await tester.tap(find.text('正序'));
    await tester.pumpAndSettle();
    expect(calls.sorts.last, DiarySortMode.createdAsc);
    expect(find.text('最早发表的在前'), findsOneWidget);

    await tester.tap(find.text('标题'));
    await tester.pumpAndSettle();
    expect(calls.sorts.last, DiarySortMode.titleAsc);
    expect(find.text('标题 A → Z，无标题的在最后'), findsOneWidget);

    // 再点当前选项不会重复触发换序。
    await tester.tap(find.text('标题'));
    await tester.tap(find.text('正序'));
    await tester.pumpAndSettle();
    expect(calls.sorts, hasLength(3));

    await tester.tap(find.text('瀑布流'));
    await tester.pumpAndSettle();
    expect(calls.layouts, <DiaryLayoutMode>[DiaryLayoutMode.waterfall]);
    expect(find.byType(DiaryViewOptionsSheet), findsOneWidget);
  });

  testWidgets('the selected tile blends its color instead of switching', (
    tester,
  ) async {
    await _openSheet(tester);
    expect(_tileColor(tester, '发表时间')!.a, 0);

    await tester.tap(find.text('发表时间'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final midAlpha = _tileColor(tester, '发表时间')!.a;
    expect(midAlpha, greaterThan(0));
    expect(midAlpha, lessThan(1));

    await tester.pumpAndSettle();
    expect(_tileColor(tester, '发表时间')!.a, 1);
    expect(_tileColor(tester, '更新时间')!.a, 0);
  });

  testWidgets('a short screen with large text scrolls instead of overflowing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final calls = await _openSheet(tester, textScale: 2);
    expect(tester.takeException(), isNull);

    final lastOption = find.text('瀑布流');
    // 内容确实超出屏幕，最后一项需要滚动才能看到。
    expect(tester.getTopLeft(lastOption).dy, greaterThan(480));
    await tester.scrollUntilVisible(
      lastOption,
      120,
      scrollable: find.descendant(
        of: find.byType(DiaryViewOptionsSheet),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(lastOption);
    await tester.pumpAndSettle();
    expect(calls.layouts, <DiaryLayoutMode>[DiaryLayoutMode.waterfall]);
  });
}
