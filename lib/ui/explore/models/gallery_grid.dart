import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'gallery_level.dart';

/// 画廊网格里一张图的锚点：整体下标 [index]，与它所在那一行上缘到锚点的
/// 距离（以行距为单位；落在这组标题上时为负，表示在这组第一行之上）。
typedef GalleryAnchor = ({int index, double rowFraction});

/// 媒体画廊某一档的行布局（纯计算）：每组一行日期标题，下面是若干行正方形
/// 格子。整个画廊只有一个 sliver，按行排布（见 `GalleryRowsSliver`）。
///
/// 每行的上缘预先算成前缀和，按位置找行用二分查找：滚动、跳转与换档都与
/// 图片总数无关（改版前每组一个 sliver，几千组时每帧都要逐组布局）。
///
/// 行高：标题行为 [headerExtent]；格子行为格子边长加一个间距 [gap]（间距
/// 算在行的下方，一组最后一行下面同样留一个间距，再接下一组的标题）。
class GalleryGrid {
  GalleryGrid({
    required this.groups,
    required this.columns,
    required this.width,
    required this.padding,
    required this.gap,
    required this.headerExtent,
  }) : cellExtent = cellExtentFor(
         width: width,
         columns: columns,
         padding: padding,
         gap: gap,
       ) {
    var rowCount = 0;
    for (final group in groups) {
      rowCount += 1 + (group.items.length + columns - 1) ~/ columns;
    }
    _rowFirst = Int32List(rowCount);
    _rowGroup = Int32List(rowCount);
    _rowTop = Float64List(rowCount + 1);
    _groupHeaderRow = Int32List(groups.length);
    var row = 0;
    var top = 0.0;
    for (var g = 0; g < groups.length; g++) {
      final group = groups[g];
      _groupHeaderRow[g] = row;
      _rowFirst[row] = -1;
      _rowGroup[row] = g;
      _rowTop[row] = top;
      top += headerExtent;
      row++;
      for (var first = group.start; first < group.end; first += columns) {
        _rowFirst[row] = first;
        _rowGroup[row] = g;
        _rowTop[row] = top;
        top += rowStride;
        row++;
      }
    }
    _rowTop[rowCount] = top;
  }

  /// 整宽 [width]（含左右内边距）里排 [columns] 列时的格子边长。
  static double cellExtentFor({
    required double width,
    required int columns,
    required double padding,
    required double gap,
  }) => math.max(0, (width - padding * 2 - gap * (columns - 1)) / columns);

  final List<GalleryGroup> groups;
  final int columns;

  /// 网格所在区域的整宽（含左右内边距 [padding]）。
  final double width;
  final double padding;
  final double gap;
  final double headerExtent;
  final double cellExtent;

  late final Int32List _rowFirst;
  late final Int32List _rowGroup;
  late final Float64List _rowTop;
  late final Int32List _groupHeaderRow;

  /// 相邻两行格子上缘之间的距离。
  double get rowStride => cellExtent + gap;

  int get rowCount => _rowGroup.length;

  /// 全部行的总高度。
  double get extent => _rowTop[rowCount];

  double rowTop(int row) => _rowTop[row.clamp(0, rowCount)];

  double rowExtent(int row) => _rowTop[row + 1] - _rowTop[row];

  bool isHeader(int row) => _rowFirst[row] < 0;

  GalleryGroup groupOfRow(int row) => groups[_rowGroup[row]];

  /// 格子行的第一张图的整体下标（标题行为 -1）。
  int firstItemOfRow(int row) => _rowFirst[row];

  /// 格子行的图片张数（标题行为 0）。
  int itemCountOfRow(int row) {
    final first = _rowFirst[row];
    if (first < 0) return 0;
    return math.min(columns, groupOfRow(row).end - first);
  }

  /// 上缘不超过 [offset] 的最后一行（落在某行内即这一行）；没有行时为 0。
  int rowAt(double offset) => _lastRowWhere(offset, inclusive: true);

  /// 上缘在 [offset] 之前的最后一行：可见范围的下边界正好落在行边界上时，
  /// 不把下一行算进来。
  int lastRowBefore(double offset) => _lastRowWhere(offset, inclusive: false);

  int _lastRowWhere(double offset, {required bool inclusive}) {
    var low = 0;
    var high = rowCount - 1;
    var found = 0;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final top = _rowTop[mid];
      if (inclusive ? top <= offset : top < offset) {
        found = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return found;
  }

  /// 整体下标为 [index] 的图所在的行；越界时为 null。
  int? rowOfItem(int index) {
    var low = 0;
    var high = groups.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final group = groups[mid];
      if (index < group.start) {
        high = mid - 1;
      } else if (index >= group.end) {
        low = mid + 1;
      } else {
        return _groupHeaderRow[mid] + 1 + (index - group.start) ~/ columns;
      }
    }
    return null;
  }

  /// 整体下标为 [index] 的格子左上角的内容坐标；越界时为 null。
  Offset? itemOrigin(int index) {
    final row = rowOfItem(index);
    if (row == null) return null;
    final column = index - _rowFirst[row];
    return Offset(padding + column * rowStride, _rowTop[row]);
  }

  /// 内容坐标 [top]–[bottom] 之间（含部分露出）的格子的下标范围；其间
  /// 只有标题或没有行时为 null。
  ({int first, int last})? visibleItems(double top, double bottom) {
    if (rowCount == 0 || bottom <= top) return null;
    var first = rowAt(math.max(0, top));
    var last = lastRowBefore(bottom);
    while (first <= last && isHeader(first)) {
      first++;
    }
    while (last >= first && isHeader(last)) {
      last--;
    }
    if (first > last) return null;
    return (
      first: _rowFirst[first],
      last: _rowFirst[last] + itemCountOfRow(last) - 1,
    );
  }

  /// 内容坐标 [top]–[bottom] 之间（含部分露出）的标题行。
  Iterable<int> headerRowsIn(double top, double bottom) sync* {
    if (rowCount == 0 || bottom <= top) return;
    final last = lastRowBefore(bottom);
    for (var row = rowAt(math.max(0, top)); row <= last; row++) {
      if (isHeader(row)) yield row;
    }
  }

  /// 内容坐标 ([x], [y]) 处的图：落在格子行上取那一列（行末不满时取这行
  /// 最后一张），落在标题上取这组第一行的那一列；没有图时为 null。
  GalleryAnchor? anchorAt(double x, double y) {
    if (rowCount == 0) return null;
    var row = rowAt(y);
    if (isHeader(row)) row += 1;
    final column = ((x - padding) / rowStride).floor().clamp(0, columns - 1);
    final index = math.min(
      firstItemOfRow(row) + column,
      groupOfRow(row).end - 1,
    );
    final fraction = rowStride > 0 ? (y - _rowTop[row]) / rowStride : 0.0;
    return (index: index, rowFraction: fraction);
  }

  /// 让锚点 [anchor] 落在视口里 [viewportY] 处的滚动偏移（未夹到滚动
  /// 范围内）；锚点那张图不在本布局里时为 null。
  double? offsetForAnchor(GalleryAnchor anchor, double viewportY) {
    final row = rowOfItem(anchor.index);
    if (row == null) return null;
    return _rowTop[row] + anchor.rowFraction * rowStride - viewportY;
  }
}
