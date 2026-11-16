import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/ui/explore/models/explore_view_data.dart';
import 'package:node_diary/ui/explore/models/gallery_grid.dart';
import 'package:node_diary/ui/explore/models/gallery_level.dart';
import 'package:node_diary/ui/explore/models/gallery_morph_plan.dart';
import 'package:node_diary/ui/explore/models/gallery_pinch.dart';
import 'package:node_diary/ui/explore/models/gallery_scroll_index.dart';

/// 画廊的行布局、换档锚点、捏合进度与快速滚动条的标签（纯计算）。
void main() {
  ExploreMediaItem item(int index, DateTime date) =>
      ExploreMediaItem(source: '/$index.jpg', diaryId: 'd$index', date: date);

  // 三天：5 张、1 张、4 张（新→旧）。
  final items = <ExploreMediaItem>[
    for (var i = 0; i < 5; i++) item(i, DateTime(2026, 5, 3, 12 - i)),
    item(5, DateTime(2026, 5, 2)),
    for (var i = 6; i < 10; i++) item(i, DateTime(2025, 12, 31, 20 - i)),
  ];

  GalleryGrid gridOf(GalleryLevel level, int columns) => GalleryGrid(
    groups: GalleryGroups.of(items, level).groups,
    columns: columns,
    // 4 + 4 + 3 × 2 = 14：每格正好 100。
    width: 414,
    padding: 4,
    gap: 2,
    headerExtent: 40,
  );

  group('GalleryGrid', () {
    test('rows are a header per group plus rows of cells', () {
      final grid = gridOf(GalleryLevel.day, 4);
      expect(grid.cellExtent, 100);
      expect(grid.rowStride, 102);
      // 第 1 组：标题 + 2 行；第 2 组：标题 + 1 行；第 3 组：标题 + 1 行。
      expect(grid.rowCount, 7);
      expect(
        <bool>[for (var r = 0; r < grid.rowCount; r++) grid.isHeader(r)],
        <bool>[true, false, false, true, false, true, false],
      );
      expect(
        <int>[for (var r = 0; r < grid.rowCount; r++) grid.itemCountOfRow(r)],
        <int>[0, 4, 1, 0, 1, 0, 4],
      );
      expect(grid.firstItemOfRow(2), 4);
      expect(grid.rowTop(0), 0);
      expect(grid.rowTop(1), 40);
      expect(grid.rowTop(3), 40 + 102 * 2);
      expect(grid.extent, 40 * 3 + 102 * 4);
    });

    test('finding rows by offset is exact at the edges', () {
      final grid = gridOf(GalleryLevel.day, 4);
      expect(grid.rowAt(0), 0);
      expect(grid.rowAt(39.9), 0);
      expect(grid.rowAt(40), 1);
      expect(grid.lastRowBefore(40), 0);
      expect(grid.rowAt(grid.extent + 500), grid.rowCount - 1);
      expect(grid.rowOfItem(0), 1);
      expect(grid.rowOfItem(4), 2);
      expect(grid.rowOfItem(5), 4);
      expect(grid.rowOfItem(9), 6);
      expect(grid.rowOfItem(10), isNull);
    });

    test('the photo under a point keeps its place across levels', () {
      final days = gridOf(GalleryLevel.day, 4);
      // 第 1 组第 2 行（第 5 张）中间，第 1 列。
      final anchor = days.anchorAt(50, 40 + 102 + 51)!;
      expect(anchor.index, 4);
      expect(anchor.rowFraction, closeTo(0.5, 1e-9));
      // 视口里 y = 300 处：换到按年 8 列后，同一张图的同一位置仍在 300。
      final years = gridOf(GalleryLevel.year, 8);
      final offset = years.offsetForAnchor(anchor, 300)!;
      final row = years.rowOfItem(4)!;
      expect(
        offset + 300,
        closeTo(years.rowTop(row) + 0.5 * years.rowStride, 1e-9),
      );
      // 落在标题上：取这组第一行的那一列，位置在第一行之上（为负）。
      final onHeader = days.anchorAt(260, 10)!;
      expect(onHeader.index, 2);
      expect(onHeader.rowFraction, lessThan(0));
      // 行末不满时取这行最后一张。
      expect(days.anchorAt(400, 40 + 102 + 10)!.index, 4);
    });
  });

  group('GalleryPinch', () {
    test('progress follows the fingers linearly toward the next cell size', () {
      expect(GalleryPinch.progress(1, 0.8), 0);
      expect(GalleryPinch.progress(0.9, 0.8), closeTo(0.5, 1e-9));
      expect(GalleryPinch.progress(0.8, 0.8), closeTo(1, 1e-9));
      // 捏过了头：大于 1，由驱动接着换下一档。
      expect(GalleryPinch.progress(0.6, 0.8), closeTo(2, 1e-9));
      // 朝反方向捏：0。
      expect(GalleryPinch.progress(1.1, 0.8), 0);
      expect(GalleryPinch.progress(1.25, 1.25), closeTo(1, 1e-9));
    });

    test('the end levels only give a little', () {
      expect(GalleryPinch.rubberBand(1), 1);
      expect(GalleryPinch.rubberBand(2), lessThan(1.12));
      expect(GalleryPinch.rubberBand(0.5), greaterThan(0.89));
    });

    test('old headings fade out first, new ones fade in after', () {
      expect(GalleryPinch.headerOpacity(0, fromLayer: true), 1);
      expect(GalleryPinch.headerOpacity(0.5, fromLayer: true), 0);
      expect(GalleryPinch.headerOpacity(0.5, fromLayer: false), 0);
      expect(GalleryPinch.headerOpacity(0.75, fromLayer: false), 0.5);
      expect(GalleryPinch.headerOpacity(1, fromLayer: false), 1);
    });
  });

  group('GalleryMorphPlan', () {
    test('every photo on screen in either level moves between its two '
        'places; headings follow their first photo', () {
      final days = gridOf(GalleryLevel.day, 4);
      final years = gridOf(GalleryLevel.year, 8);
      final plan = GalleryMorphPlan(
        from: days,
        fromOffset: 0,
        to: years,
        toOffset: 0,
        viewportHeight: 300,
      );
      // 4 列时露出第 0–5 张，8 列时 10 张全在屏上：合起来 0–9。
      expect(plan.first, 0);
      expect(plan.count, 10);
      // 第 7 张（2025 年那组第一张）：4 列时在屏幕下方，8 列时在第二行。
      expect(plan.originAt(6, 0), const Offset(4, 426));
      expect(plan.originAt(6, 1), const Offset(4, 131));
      expect(plan.originAt(6, 0.5), const Offset(4, 278.5));
      // 格子边长线性变化（等于当前边长 × 手指比例）。
      expect(plan.cellAt(0), 100);
      expect(plan.cellAt(1), 49);
      expect(plan.cellAt(0.5), 74.5);
      // 4 列的两行标题 + 8 列的两行标题。
      expect(
        plan.headers.map((header) => (header.fromLayer, header.origin.dy)),
        <(bool, double)>[(true, 0), (true, 244), (false, 0), (false, 91)],
      );
      // 5 月 2 日那组的标题跟着它的第一张（第 6 张）往上走。
      final header = plan.headers[1];
      expect(header.topAt(0), 244);
      expect(header.topAt(1), 244 + 40 - 284);
    });

    test('nothing but a heading on screen gives an empty plan', () {
      final days = gridOf(GalleryLevel.day, 4);
      final plan = GalleryMorphPlan(
        from: days,
        fromOffset: 0,
        to: days,
        toOffset: 0,
        viewportHeight: 30,
      );
      // 视口里只有标题、两档都没有图：什么也不画，捏合照常结束。
      expect(plan.count, 0);
      expect(plan.headers, isEmpty);
    });
  });

  group('GalleryScrollIndex', () {
    setUpAll(() => initializeDateFormatting('en'));

    test('labels follow the level; sections mark the years', () {
      final days = GalleryScrollIndex(
        grid: gridOf(GalleryLevel.day, 4),
        level: GalleryLevel.day,
        locale: 'en',
      );
      expect(days.labelAt(0).primary, 'May 3');
      expect(days.labelAt(2).caption, '2026');
      expect(days.labelAt(6).primary, 'Dec 31');
      expect(
        days.sections.map((section) => (section.index, section.label)),
        <(int, String)>[(0, '2026'), (5, '2025')],
      );

      final years = GalleryScrollIndex(
        grid: gridOf(GalleryLevel.year, 8),
        level: GalleryLevel.year,
        locale: 'en',
      );
      expect(years.labelAt(0).primary, '2026');
      expect(years.labelAt(0).caption, isNull);
    });

    test('within one year the months are the sections', () {
      final grid = GalleryGrid(
        groups: GalleryGroups.of(
          items.take(6).toList(),
          GalleryLevel.day,
        ).groups,
        columns: 4,
        width: 414,
        padding: 4,
        gap: 2,
        headerExtent: 40,
      );
      // 同一个月：不分段。
      expect(
        GalleryScrollIndex(
          grid: grid,
          level: GalleryLevel.day,
          locale: 'en',
        ).sections,
        isEmpty,
      );
    });
  });
}
