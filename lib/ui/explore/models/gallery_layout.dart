import 'gallery_level.dart';

/// 媒体画廊网格的几何（纯计算）：每组一条固定高的标题，下面是正方形格子的
/// 网格。与页面里 `SliverGridDelegateWithFixedCrossAxisCount`（1:1、间距
/// [gap]）同一公式，用来在换档前后把同一张图留在视口顶部附近。
class GalleryLayout {
  const GalleryLayout({
    required this.groups,
    required this.columns,
    required this.gridWidth,
    required this.headerExtent,
    required this.gap,
  });

  final List<GalleryGroup> groups;
  final int columns;

  /// 网格本身的宽度（已扣掉左右内边距）。
  final double gridWidth;
  final double headerExtent;
  final double gap;

  double get cellExtent => (gridWidth - gap * (columns - 1)) / columns;

  double _gridExtent(int count) {
    final rows = (count / columns).ceil();
    return rows == 0 ? 0 : rows * cellExtent + (rows - 1) * gap;
  }

  /// 滚动偏移 [offset] 处（视口顶边）的那张图在整体列表里的下标：落在标题
  /// 上取这组第一张，落在网格里取那一行第一张；没有分组时为 null。
  int? anchorAt(double offset) {
    var top = 0.0;
    for (final group in groups) {
      final bottom = top + headerExtent + _gridExtent(group.items.length);
      if (offset < bottom) {
        final intoGrid = offset - top - headerExtent;
        if (intoGrid <= 0) return group.start;
        final row = (intoGrid / (cellExtent + gap)).floor();
        final index = group.start + row * columns;
        final last = group.start + group.items.length - 1;
        return index > last ? last : index;
      }
      top = bottom;
    }
    return groups.isEmpty ? null : groups.last.start;
  }

  /// 让下标为 [index] 的图所在那一行贴着视口顶边（第一行时连同组标题）
  /// 的滚动偏移；找不到时为 null。
  double? offsetOf(int index) {
    var top = 0.0;
    for (final group in groups) {
      final end = group.start + group.items.length;
      if (index >= group.start && index < end) {
        final row = (index - group.start) ~/ columns;
        return row == 0 ? top : top + headerExtent + row * (cellExtent + gap);
      }
      top += headerExtent + _gridExtent(group.items.length);
    }
    return null;
  }
}
