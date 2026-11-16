import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/explore/models/explore_view_data.dart';
import 'package:node_diary/ui/explore/models/gallery_level.dart';
import 'package:node_diary/ui/explore/widgets/gallery_cell.dart';
import 'package:node_diary/ui/explore/widgets/gallery_group_header.dart';
import 'package:node_diary/ui/explore/widgets/gallery_rows_sliver.dart';
import 'package:node_diary/ui/explore/widgets/gallery_zoomable_grid.dart';
import 'package:node_diary/ui/widgets/fast_scroller/fast_scroller.dart';

import '../../../support/expressive_test_theme.dart';

/// 画廊网格本体：长列表只布局可见的行、远距离跳转直接到位，分组标题的
/// 文案随档位变化。
void main() {
  // 2000 天，每天 3 张：6000 张、2000 个日期组（新→旧）。
  final start = DateTime(2026, 11, 16, 12);
  final items = <ExploreMediaItem>[
    for (var day = 0; day < 2000; day++)
      for (var k = 0; k < 3; k++)
        ExploreMediaItem(
          source: '/missing/$day-$k.jpg',
          diaryId: 'd$day',
          date: DateTime(start.year, start.month, start.day - day, 12 - k),
        ),
  ];

  Future<ScrollController> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: GalleryZoomableGrid(
            items: items,
            generation: 0,
            scrollController: controller,
            footer: const SizedBox.shrink(),
            heroTagOf: (String source) => source,
            onOpen: (_, _) {},
            onLongPress: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  testWidgets('a long gallery only lays out the rows on screen and jumps '
      'straight to the far end', (tester) async {
    final controller = await pump(tester);
    final grid = tester
        .widget<GalleryRowsSliver>(find.byType(GalleryRowsSliver))
        .grid;
    // 每天一行标题 + 一行格子（3 张 < 4 列）。
    expect(grid.rowCount, 4000);
    expect(
      tester.widget<FastScroller>(find.byType(FastScroller)).itemCount,
      grid.rowCount,
    );
    // 一屏只建得出几十行，与总行数无关。
    expect(find.byType(GalleryCellRow).evaluate().length, lessThan(30));

    // 一步跳到最后：最后一天（最早的那天）的标题就在屏幕上。
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    final last = grid.groups.last.key;
    expect(
      find.descendant(
        of: find.byType(GalleryGroupHeader),
        matching: find.textContaining(DateFormat.yMMMd('en').format(last)),
      ),
      findsOneWidget,
    );
    expect(find.byType(GalleryCellRow).evaluate().length, lessThan(30));
    // 第 1234 天的那一行布局在 grid 算出的位置上。
    final row = grid.rowOfItem(1234 * 3)!;
    controller.jumpTo(grid.rowTop(row));
    await tester.pump();
    final cell = find.byWidgetPredicate(
      (widget) =>
          widget is GalleryCell && widget.source == '/missing/1234-0.jpg',
    );
    expect(cell, findsOneWidget);
    expect(tester.getTopLeft(cell).dy, closeTo(0, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('at the top of the list the photo under the fingers stays put '
      'in both layers while pinching', (tester) async {
    await pump(tester);
    final first = find.byWidgetPredicate(
      (widget) => widget is GalleryCell && widget.source == '/missing/0-0.jpg',
    );
    final focal = tester.getCenter(first);
    final a = await tester.startGesture(focal - const Offset(40, 0));
    final b = await tester.startGesture(focal + const Offset(40, 0));
    await a.moveBy(const Offset(6, 0));
    await b.moveBy(const Offset(-6, 0));
    await tester.pump();
    // 正式网格与 5 列预览里各有一格是这张图：对齐所需的偏移在顶部之上被
    // 夹到 0，预览先平移补上，两层里它仍在同一高度、同样大小。
    expect(first, findsNWidgets(2));
    final main = tester.getRect(first.first);
    final preview = tester.getRect(first.last);
    expect(preview.top, closeTo(main.top, 0.5));
    expect(preview.height, closeTo(main.height, 0.5));
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
  });

  testWidgets('group headings follow the level', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const SizedBox(),
      ),
    );
    final l10n = tester.element(find.byType(SizedBox)).l10n;
    final now = DateTime(2026, 11, 16, 9);
    ({String title, String? subtitle}) labels(
      DateTime date,
      GalleryLevel level,
    ) => GalleryGroupHeader.labelsFor(l10n, date, level, now: now);

    expect(labels(DateTime(2026, 11, 16), GalleryLevel.day), (
      title: l10n.calendarRelativeToday,
      subtitle: 'Mon, Nov 16',
    ));
    expect(
      labels(DateTime(2026, 11, 15), GalleryLevel.day).title,
      l10n.calendarRelativeYesterday,
    );
    // 今年的不写年份，往年的带年份；小字为星期。
    expect(labels(DateTime(2026, 3, 5), GalleryLevel.day), (
      title: 'Mar 5',
      subtitle: 'Thu',
    ));
    expect(labels(DateTime(2025, 3, 5), GalleryLevel.day).title, 'Mar 5, 2025');
    expect(labels(DateTime(2026, 3), GalleryLevel.month), (
      title: 'March 2026',
      subtitle: null,
    ));
    expect(labels(DateTime(2026), GalleryLevel.year), (
      title: '2026',
      subtitle: null,
    ));
  });
}
