import 'explore_view_data.dart';

/// 媒体画廊的分组层级：按天 / 按月 / 按年聚合。
enum GalleryLevel {
  day,
  month,
  year;

  /// 聚合成组用的时间桶键（这一天 / 这个月 / 这一年的零点，本地时间）。
  DateTime bucket(DateTime date) {
    final local = date.toLocal();
    return switch (this) {
      GalleryLevel.day => DateTime(local.year, local.month, local.day),
      GalleryLevel.month => DateTime(local.year, local.month),
      GalleryLevel.year => DateTime(local.year),
    };
  }
}

/// 双指捏合（桌面为 Ctrl + 滚轮 / 触控板捏合）切换的四档：列数与分组层级
/// 联动。张开放大到 [closeUp]，捏合缩小到 [yearGrid]，到头不再越界。
///
/// [columns] 是手机宽度下的列数；宽窗口按 [columnsFor] 加列，格子保持手机
/// 上的大小，不会被放大成几张大图。
enum GalleryZoom {
  /// 3 列，按天分组（默认，最大的格子）。
  closeUp(columns: 3, level: GalleryLevel.day),

  /// 4 列，按天分组。
  dayGrid(columns: 4, level: GalleryLevel.day),

  /// 8 列，按月分组。
  monthGrid(columns: 8, level: GalleryLevel.month),

  /// 10 列，按年分组（最小的格子）。
  yearGrid(columns: 10, level: GalleryLevel.year);

  const GalleryZoom({required this.columns, required this.level});

  final int columns;
  final GalleryLevel level;

  /// 按网格实际可用宽度 [width] 算列数：每列至少 `480 / columns`（3 列档为
  /// 160，即改版前 `max(3, 宽 ÷ 160)`），且不少于 [columns]。
  int columnsFor(double width) {
    final byWidth = (width * columns / 480).floor();
    return byWidth > columns ? byWidth : columns;
  }

  /// 捏合缩小一档（格子变小、分组变粗）；已是最小一档时为 null。
  GalleryZoom? get zoomedOut =>
      index < values.length - 1 ? values[index + 1] : null;

  /// 张开放大一档；已是最大一档时为 null。
  GalleryZoom? get zoomedIn => index > 0 ? values[index - 1] : null;
}

/// 一个时间桶里的媒体：[key] 为桶键，[start] 为这组第一张在整份有序列表
/// （[GalleryGroups.ordered]）里的下标，看图页按它把“组内第几张”换回整体
/// 下标。
class GalleryGroup {
  const GalleryGroup({
    required this.key,
    required this.items,
    required this.start,
  });

  final DateTime key;
  final List<ExploreMediaItem> items;
  final int start;
}

/// 按层级聚合后的分组与网格显示顺序的扁平列表（纯函数结果）。
class GalleryGroups {
  const GalleryGroups({required this.groups, required this.ordered});

  /// 把 [items] 按 [level] 聚合。[items] 已按发表时间排好（新→旧或旧→新），
  /// 同一桶的媒体相邻，分组沿用原顺序，组内也保持原顺序；没有日期的项
  /// （不该出现，防御）归到 1970 年那一组。
  factory GalleryGroups.of(List<ExploreMediaItem> items, GalleryLevel level) {
    final groups = <GalleryGroup>[];
    var current = <ExploreMediaItem>[];
    DateTime? currentKey;
    var start = 0;
    for (final item in items) {
      final key = level.bucket(item.date ?? DateTime(1970));
      if (key != currentKey) {
        if (currentKey != null) {
          groups.add(
            GalleryGroup(key: currentKey, items: current, start: start),
          );
          start += current.length;
        }
        currentKey = key;
        current = <ExploreMediaItem>[];
      }
      current.add(item);
    }
    if (currentKey != null) {
      groups.add(GalleryGroup(key: currentKey, items: current, start: start));
    }
    return GalleryGroups(
      groups: List<GalleryGroup>.unmodifiable(groups),
      ordered: List<ExploreMediaItem>.unmodifiable(items),
    );
  }

  static const GalleryGroups empty = GalleryGroups(
    groups: <GalleryGroup>[],
    ordered: <ExploreMediaItem>[],
  );

  final List<GalleryGroup> groups;
  final List<ExploreMediaItem> ordered;

  /// 包含整体下标 [index] 的那一组的序号；越界时为 null。
  int? groupIndexOf(int index) {
    for (var i = 0; i < groups.length; i++) {
      final group = groups[i];
      if (index >= group.start && index < group.start + group.items.length) {
        return i;
      }
    }
    return null;
  }
}
