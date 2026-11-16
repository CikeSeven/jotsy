import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, lerpDouble;

import 'gallery_grid.dart';
import 'gallery_level.dart';

/// 换档途中一行日期标题：所属组 [group]、属于起点档还是终点档
/// （[fromLayer]），它在那一档里的屏幕位置 [origin]，以及它跟随的那张图
/// （这组第一张）在两档里的屏幕位置——标题随这张图一起移动。
class GalleryMorphHeader {
  const GalleryMorphHeader({
    required this.group,
    required this.fromLayer,
    required this.origin,
    required this.anchorFrom,
    required this.anchorTo,
  });

  final GalleryGroup group;
  final bool fromLayer;
  final Offset origin;
  final Offset anchorFrom;
  final Offset anchorTo;

  /// 进度 [t] 时标题行的上缘：所跟随的那张图竖直移动多少，标题就移动
  /// 多少（只竖直移动，文字不缩放）。[scale] 为以 [focal] 为原点的阻尼
  /// 缩放（只在到头的档位继续捏时偏离 1）。
  double topAt(double t, {double scale = 1, Offset focal = Offset.zero}) {
    final anchor = lerpDouble(anchorFrom.dy, anchorTo.dy, t)!;
    final placed = scale == 1 ? anchor : focal.dy + (anchor - focal.dy) * scale;
    return origin.dy + placed - (fromLayer ? anchorFrom.dy : anchorTo.dy);
  }
}

/// 换档（小米相册式）途中每张图从起点档的位置走到终点档位置的几何
/// （纯计算，屏幕坐标、相对视口左上角）。
///
/// 只记录两档里至少一档露在视口里的图：两段可见范围都包含手指下那张图，
/// 合起来是一段连续的下标 [first]…[first] + [count] − 1。起点档以滚动偏移
/// [fromOffset] 摆放、终点档以 [toOffset] 摆放（已夹到终点档的滚动范围内，
/// 换档后正式网格就停在这里），进度 t 时每张图的位置在两者之间线性插值，
/// 边长同样线性插值——t 与手指比例成线性关系（见 `GalleryPinch.progress`），
/// 格子大小正好跟随手指，手指下那张图留在手指下。
class GalleryMorphPlan {
  GalleryMorphPlan._({
    required this.first,
    required this.fromX,
    required this.fromY,
    required this.toX,
    required this.toY,
    required this.fromCell,
    required this.toCell,
    required this.headers,
    required this.drawOrder,
  });

  factory GalleryMorphPlan({
    required GalleryGrid from,
    required double fromOffset,
    required GalleryGrid to,
    required double toOffset,
    required double viewportHeight,
  }) {
    final a = from.visibleItems(fromOffset, fromOffset + viewportHeight);
    final b = to.visibleItems(toOffset, toOffset + viewportHeight);
    final ranges = <({int first, int last})>[?a, ?b];
    if (ranges.isEmpty) {
      return GalleryMorphPlan._(
        first: 0,
        fromX: Float32List(0),
        fromY: Float32List(0),
        toX: Float32List(0),
        toY: Float32List(0),
        fromCell: from.cellExtent,
        toCell: to.cellExtent,
        headers: const <GalleryMorphHeader>[],
        drawOrder: Int32List(0),
      );
    }
    final first = ranges.map((range) => range.first).reduce(math.min);
    final last = ranges.map((range) => range.last).reduce(math.max);
    final count = last - first + 1;
    final fromX = Float32List(count);
    final fromY = Float32List(count);
    final toX = Float32List(count);
    final toY = Float32List(count);
    for (var k = 0; k < count; k++) {
      final start = from.itemOrigin(first + k) ?? Offset.zero;
      final end = to.itemOrigin(first + k) ?? start;
      fromX[k] = start.dx;
      fromY[k] = start.dy - fromOffset;
      toX[k] = end.dx;
      toY[k] = end.dy - toOffset;
    }
    // 绘制顺序：移动距离大的先画、基本不动的后画——换行的图斜穿过别的图
    // 时从它们下面滑过，不会盖住原地缩放的那些。
    final distances = <double>[
      for (var k = 0; k < count; k++)
        (toX[k] - fromX[k]) * (toX[k] - fromX[k]) +
            (toY[k] - fromY[k]) * (toY[k] - fromY[k]),
    ];
    final order = List<int>.generate(count, (k) => k)
      ..sort((a, b) => distances[b].compareTo(distances[a]));
    Offset screen(GalleryGrid grid, double offset, int index) {
      final origin = grid.itemOrigin(index) ?? Offset.zero;
      return Offset(origin.dx, origin.dy - offset);
    }

    final headers = <GalleryMorphHeader>[];
    for (final (grid, offset, isFrom) in <(GalleryGrid, double, bool)>[
      (from, fromOffset, true),
      (to, toOffset, false),
    ]) {
      for (final row in grid.headerRowsIn(offset, offset + viewportHeight)) {
        final group = grid.groupOfRow(row);
        headers.add(
          GalleryMorphHeader(
            group: group,
            fromLayer: isFrom,
            origin: Offset(0, grid.rowTop(row) - offset),
            anchorFrom: screen(from, fromOffset, group.start),
            anchorTo: screen(to, toOffset, group.start),
          ),
        );
      }
    }
    return GalleryMorphPlan._(
      first: first,
      fromX: fromX,
      fromY: fromY,
      toX: toX,
      toY: toY,
      fromCell: from.cellExtent,
      toCell: to.cellExtent,
      headers: List<GalleryMorphHeader>.unmodifiable(headers),
      drawOrder: Int32List.fromList(order),
    );
  }

  /// 第一张的整体下标。
  final int first;
  final Float32List fromX;
  final Float32List fromY;
  final Float32List toX;
  final Float32List toY;
  final double fromCell;
  final double toCell;
  final List<GalleryMorphHeader> headers;

  /// 绘制顺序（相对 [first] 的序号）：移动距离从大到小。
  final Int32List drawOrder;

  int get count => fromX.length;

  /// 进度 [t] 时第 [k] 张（相对 [first]）的左上角。
  Offset originAt(int k, double t) => Offset(
    lerpDouble(fromX[k], toX[k], t)!,
    lerpDouble(fromY[k], toY[k], t)!,
  );

  /// 进度 [t] 时的格子边长。
  double cellAt(double t) => lerpDouble(fromCell, toCell, t)!;
}
