import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/explore/models/explore_view_data.dart';
import 'package:node_diary/ui/explore/models/gallery_level.dart';
import 'package:node_diary/ui/explore/widgets/gallery_cell.dart';
import 'package:node_diary/ui/explore/widgets/gallery_group_header.dart';
import 'package:node_diary/ui/explore/widgets/gallery_morph_layer.dart';
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

  testWidgets('mid-list, the photo under the fingers stays under them while '
      'every photo slides to the next level', (tester) async {
    final controller = await pump(tester);
    controller.jumpTo(20000);
    await tester.pump();
    // 视口中间那一格。
    final cells = find.byType(GalleryCell);
    final middle = tester
        .widgetList<GalleryCell>(cells)
        .map((cell) => (cell, tester.getRect(find.byWidget(cell))))
        .firstWhere((entry) => entry.$2.contains(const Offset(150, 400)));
    final name = middle.$1.source.split('/').last.split('.').first;
    final parts = name.split('-').map(int.parse).toList();
    final index = parts[0] * 3 + parts[1];
    final focal = middle.$2.center;
    final a = await tester.startGesture(focal - const Offset(80, 0));
    final b = await tester.startGesture(focal + const Offset(80, 0));
    // 捏到一半多：160 → 140，比例 0.875。
    for (var step = 0; step < 5; step++) {
      await a.moveBy(const Offset(2, 0));
      await b.moveBy(const Offset(-2, 0));
      await tester.pump();
    }
    final layer = tester.widget<GalleryMorphLayer>(
      find.byType(GalleryMorphLayer),
    );
    final plan = layer.morph.plan;
    final t = layer.driver.progress;
    expect(t, greaterThan(0.3));
    expect(t, lessThan(1));
    final origin = plan.originAt(index - plan.first, t);
    final cell = plan.cellAt(t);
    // 竖直方向上手指仍落在这张图的中线（换到哪一列是另一回事）。
    expect((focal.dy - origin.dy) / cell, closeTo(0.5, 0.02));
    expect(cell, closeTo(middle.$2.height * 140 / 160, 0.01));
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(find.byType(GalleryMorphLayer), findsNothing);
    expect(
      tester
          .widget<GalleryRowsSliver>(find.byType(GalleryRowsSliver))
          .grid
          .columns,
      5,
    );
    // 换档后同一张图回到了手指附近。
    final after = find.byWidgetPredicate(
      (widget) => widget is GalleryCell && widget.source == middle.$1.source,
    );
    expect(tester.getRect(after).center.dy, closeTo(focal.dy, cell));
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
