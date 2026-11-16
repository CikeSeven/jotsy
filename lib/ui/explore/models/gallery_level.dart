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
/// 联动。张开放大到 [day]（默认），捏合缩小到 [year]，到头不再越界。
///
/// [columns] 是手机宽度下的列数；宽窗口按 [columnsFor] 加列，格子保持手机
/// 上的大小，不会被放大成几张大图。
enum GalleryZoom {
  /// 4 列，按天分组（默认，最大的格子）。
  day(columns: 4, level: GalleryLevel.day, cornerRadius: 4),

  /// 5 列，按天分组。
  dayDense(columns: 5, level: GalleryLevel.day, cornerRadius: 4),

  /// 8 列，按月分组。
  month(columns: 8, level: GalleryLevel.month, cornerRadius: 2),

  /// 16 列，按年分组（最小的格子，不切圆角：一屏几百格，每格一次圆角
  /// 裁切的开销不值得）。
  year(columns: 16, level: GalleryLevel.year, cornerRadius: 0);

  const GalleryZoom({
    required this.columns,
    required this.level,
    required this.cornerRadius,
  });

  /// 打开画廊时的档位。
  static const GalleryZoom initial = day;

  final int columns;
  final GalleryLevel level;

  /// 缩略图圆角。
  final double cornerRadius;

  /// 按网格可用宽度 [width] 算列数：每列至少 `480 / columns`（4 列档为
  /// 120），且不少于 [columns]。手机宽度（≤ 480）下就是 [columns]。
  int columnsFor(double width) {
    final byWidth = (width * columns / 480).floor();
    return byWidth > columns ? byWidth : columns;
  }

  /// 缩略图按哪一档的格子大小解码：同一族的档位共用一份解码（4 / 5 列按
  /// 4 列、8 / 16 列按 8 列），捏合在族内换档时缓存直接命中、不重新解码；
  /// 16 列多占的内存在图像缓存的预算内。
  GalleryZoom get decodeReference => switch (this) {
    GalleryZoom.day || GalleryZoom.dayDense => GalleryZoom.day,
    GalleryZoom.month || GalleryZoom.year => GalleryZoom.month,
  };

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

  int get end => start + items.length;
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
}
