import 'package:intl/intl.dart';

import '../../widgets/fast_scroller/fast_scroller.dart';
import 'gallery_grid.dart';
import 'gallery_level.dart';

/// 媒体画廊快速滚动条的内容：第几行的气泡标签与轨道上的分段（纯数据）。
///
/// 滚动条按“行”换算位置（画廊的 sliver 子项是行：日期标题行与格子行）。
/// 标签取这一行所在组的日期，精度跟随档位：按天时大字为几月几日、小字为
/// 年份；按月时大字为月份、小字为年份；按年时只有年份。分段：跨年时为
/// 各年的第一行，同一年里跨月时为各月的第一行，否则不分段。
class GalleryScrollIndex {
  GalleryScrollIndex({
    required this.grid,
    required this.level,
    required String locale,
  }) : _day = DateFormat.MMMd(locale),
       _month = DateFormat.MMM(locale),
       _year = DateFormat.y(locale) {
    sections = _buildSections();
  }

  final GalleryGrid grid;
  final GalleryLevel level;
  final DateFormat _day;
  final DateFormat _month;
  final DateFormat _year;
  late final List<FastScrollSection> sections;

  int get length => grid.rowCount;

  FastScrollLabel labelAt(int row) {
    final date = grid.groupOfRow(row.clamp(0, grid.rowCount - 1)).key;
    return switch (level) {
      GalleryLevel.day => FastScrollLabel(
        _day.format(date),
        caption: _year.format(date),
      ),
      GalleryLevel.month => FastScrollLabel(
        _month.format(date),
        caption: _year.format(date),
      ),
      GalleryLevel.year => FastScrollLabel(_year.format(date)),
    };
  }

  List<FastScrollSection> _buildSections() {
    final groups = grid.groups;
    if (groups.isEmpty) return const <FastScrollSection>[];
    final years = <int>{for (final group in groups) group.key.year};
    final byYear = years.length > 1;
    if (!byYear) {
      final months = <int>{for (final group in groups) group.key.month};
      if (months.length < 2) return const <FastScrollSection>[];
    }
    final sections = <FastScrollSection>[];
    int? previous;
    var row = 0;
    for (final group in groups) {
      final key = byYear ? group.key.year : group.key.month;
      if (key != previous) {
        previous = key;
        sections.add(
          FastScrollSection(
            index: row,
            // 轨道刻度与日记列表同一写法：年份只写数字。
            label: byYear ? '${group.key.year}' : _month.format(group.key),
          ),
        );
      }
      // 标题行加上这组的格子行。
      row += 1 + (group.items.length + grid.columns - 1) ~/ grid.columns;
    }
    return List<FastScrollSection>.unmodifiable(sections);
  }
}
