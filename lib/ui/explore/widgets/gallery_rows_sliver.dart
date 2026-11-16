import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../models/gallery_grid.dart';

/// 媒体画廊的整份网格：一个按行排布的 sliver，第 i 个子项是 [grid] 的第
/// i 行（日期标题或一行格子），行高由 [grid] 给出、不必先布局子项。
///
/// 与 `SliverVariedExtentList` 同一套布局流程，但行的位置取自 [grid] 预先
/// 算好的前缀和（二分查找），而不是每次从第 0 行逐行累加：几千行时滚动、
/// 快速滚动条跳转与换档的每帧布局只与可见行数有关。子项数必须等于
/// `grid.rowCount`。
class GalleryRowsSliver extends SliverMultiBoxAdaptorWidget {
  const GalleryRowsSliver({
    super.key,
    required this.grid,
    required super.delegate,
  });

  final GalleryGrid grid;

  @override
  RenderGalleryRows createRenderObject(BuildContext context) =>
      RenderGalleryRows(
        childManager: context as SliverMultiBoxAdaptorElement,
        grid: grid,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGalleryRows renderObject,
  ) {
    renderObject.grid = grid;
  }

  @override
  double estimateMaxScrollOffset(
    SliverConstraints? constraints,
    int firstIndex,
    int lastIndex,
    double leadingScrollOffset,
    double trailingScrollOffset,
  ) => grid.extent;
}

/// [GalleryRowsSliver] 的渲染对象：覆写按行号 / 位置换算的几个入口，其余
/// （增删子项、命中测试、绘制）沿用 [RenderSliverFixedExtentBoxAdaptor]。
class RenderGalleryRows extends RenderSliverFixedExtentBoxAdaptor {
  RenderGalleryRows({required super.childManager, required this._grid});

  GalleryGrid get grid => _grid;
  GalleryGrid _grid;
  set grid(GalleryGrid value) {
    if (identical(_grid, value)) return;
    _grid = value;
    markNeedsLayout();
  }

  @override
  double? get itemExtent => null;

  @override
  ItemExtentBuilder? get itemExtentBuilder => _extentOf;

  double? _extentOf(int index, SliverLayoutDimensions dimensions) =>
      index < _grid.rowCount ? _grid.rowExtent(index) : null;

  @override
  double indexToLayoutOffset(double itemExtent, int index) =>
      _grid.rowTop(index);

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset, double itemExtent) =>
      _grid.rowAt(scrollOffset);

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset, double itemExtent) =>
      _grid.lastRowBefore(scrollOffset);

  @override
  double computeMaxScrollOffset(
    SliverConstraints constraints,
    double itemExtent,
  ) => _grid.extent;

  @override
  double estimateMaxScrollOffset(
    SliverConstraints constraints, {
    int? firstIndex,
    int? lastIndex,
    double? leadingScrollOffset,
    double? trailingScrollOffset,
  }) => _grid.extent;
}
