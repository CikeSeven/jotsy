import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/explore/models/explore_view_data.dart';
import 'package:node_diary/ui/explore/models/gallery_layout.dart';
import 'package:node_diary/ui/explore/models/gallery_level.dart';

void main() {
  ExploreMediaItem item(int i, DateTime date) =>
      ExploreMediaItem(source: '/$i.jpg', diaryId: 'd$i', date: date);

  // 新→旧：11/16 三张、11/15 两张、10/02 一张、去年一张。
  final items = <ExploreMediaItem>[
    item(0, DateTime(2026, 11, 16, 20)),
    item(1, DateTime(2026, 11, 16, 9)),
    item(2, DateTime(2026, 11, 16, 8)),
    item(3, DateTime(2026, 11, 15)),
    item(4, DateTime(2026, 11, 15)),
    item(5, DateTime(2026, 10, 2)),
    item(6, DateTime(2025, 12, 31)),
  ];

  test('groups keep list order and record where each group starts', () {
    final days = GalleryGroups.of(items, GalleryLevel.day);
    expect(days.groups.map((g) => g.key), <DateTime>[
      DateTime(2026, 11, 16),
      DateTime(2026, 11, 15),
      DateTime(2026, 10, 2),
      DateTime(2025, 12, 31),
    ]);
    expect(days.groups.map((g) => g.start), <int>[0, 3, 5, 6]);
    expect(days.ordered, items);

    final months = GalleryGroups.of(items, GalleryLevel.month);
    expect(months.groups.map((g) => g.items.length), <int>[5, 1, 1]);
    final years = GalleryGroups.of(items, GalleryLevel.year);
    expect(years.groups.map((g) => g.key), <DateTime>[
      DateTime(2026),
      DateTime(2025),
    ]);
    expect(years.groupIndexOf(6), 1);
    expect(years.groupIndexOf(7), isNull);
  });

  test('anchor and offset agree so zooming keeps the same photo on top', () {
    GalleryLayout layout(GalleryLevel level, int columns) => GalleryLayout(
      groups: GalleryGroups.of(items, level).groups,
      columns: columns,
      gridWidth: 328,
      headerExtent: 48,
      gap: 2,
    );

    final day3 = layout(GalleryLevel.day, 3);
    // 第一组 3 张一行：标题 48 + 一行；第二组从那之后开始。
    final cell = (328 - 2 * 2) / 3;
    expect(day3.offsetOf(0), 0);
    expect(day3.offsetOf(3), 48 + cell);
    expect(day3.anchorAt(0), 0);
    expect(day3.anchorAt(48 + cell + 10), 3);
    expect(day3.anchorAt(48 + cell + 48 + 1), 3);

    // 换到按月 8 列：同一张图（下标 5，10 月）所在的组标题顶到视口上沿。
    final month8 = layout(GalleryLevel.month, 8);
    final anchor = day3.anchorAt(day3.offsetOf(5)!)!;
    expect(anchor, 5);
    final month = (328 - 7 * 2) / 8;
    expect(month8.offsetOf(anchor), 48 + month);
    expect(month8.anchorAt(month8.offsetOf(anchor)!), anchor);
  });
}
