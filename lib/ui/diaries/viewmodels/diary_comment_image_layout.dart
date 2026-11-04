import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:meta/meta.dart';

/// 留言图片的相册式排版：按张数选一种版式，算出整组的尺寸与每一格的位置、
/// 圆角（纯函数，供 `DiaryCommentImages` 绘制与测试）。
///
/// 视觉（DESIGN.md §5.26）：一组图片像一张拼贴相片——格与格之间只留
/// [gap] 的细缝，整组外圈是 [outerRadius] 的大圆角，格子朝内的角是
/// [innerRadius] 的小圆角。整组最宽 [maxGroupWidth]（宽窗口里不被拉成几张
/// 大图），靠起始边。
///
/// 版式（W 为整组宽度；“方格”指三列网格的一格，边长 c = (W − 2·gap) / 3）：
/// - 1 张：按原图比例，比例夹在 3:4 与 16:9 之间，落在 [singleMaxExtent]
///   见方的框里（竖图限高、横图限宽）；比例未知时按 4:3；
/// - 2 张：两格方图并排；
/// - 3 张：左边一格大方图（占 2×2 格），右边两格方图上下叠放；
/// - 4 张：上面一格 2:1 横幅，下面三格方图；
/// - 5 张：上面两格 4:3，下面三格方图；
/// - 6 张：两行各三格方图；
/// - 7 张：上面三格方图，下面四格方图；
/// - 8 张：上面两格 4:3，下面两行各三格方图；
/// - 9 张：三行各三格方图（九宫格）；
/// - 更多（备份或同步来的）：按 9 张排，最后一格叠“+N”（[DiaryCommentImageTile.overflow]）。
@immutable
class DiaryCommentImageLayout {
  const DiaryCommentImageLayout._(this.size, this.tiles);

  /// 按 [count] 张图片、可用宽度 [availableWidth] 排版。[singleAspect] 只对
  /// 1 张时有用：原图宽高比（宽 / 高），未知为 null。
  factory DiaryCommentImageLayout.compute({
    required int count,
    required double availableWidth,
    double? singleAspect,
  }) {
    if (count <= 0 || !availableWidth.isFinite || availableWidth <= 0) {
      return const DiaryCommentImageLayout._(
        Size.zero,
        <DiaryCommentImageTile>[],
      );
    }
    final width = math.min(availableWidth, maxGroupWidth);
    if (count == 1) return _single(width, singleAspect);
    final shown = math.min(count, maxVisible);
    final rects = shown == 3 ? _mosaicThree(width) : _rows(width, shown);
    final size = Size(
      width,
      rects.fold<double>(
        0,
        (double bottom, Rect r) => math.max(bottom, r.bottom),
      ),
    );
    return DiaryCommentImageLayout._(size, <DiaryCommentImageTile>[
      for (final (index, rect) in rects.indexed)
        DiaryCommentImageTile(
          index: index,
          rect: rect,
          radius: _radiusOf(rect, size),
          overflow: index == shown - 1 ? count - shown : 0,
        ),
    ]);
  }

  /// 格与格之间的细缝。
  static const double gap = 3;

  /// 整组外圈的圆角。
  static const double outerRadius = 14;

  /// 格子朝内一侧的圆角。
  static const double innerRadius = 4;

  /// 整组的最大宽度。
  static const double maxGroupWidth = 320;

  /// 1 张图时的最大宽与高。
  static const double singleMaxExtent = 280;

  /// 最多排出的格数，再多的折进最后一格的“+N”。
  static const int maxVisible = 9;

  /// 1 张图时比例的上下限（宽 / 高）：最竖 3:4，最横 16:9。
  static const double singleMinAspect = 3 / 4;
  static const double singleMaxAspect = 16 / 9;

  /// 比例未知（尺寸还没读出来、或读不出）时的 1 张图比例。
  static const double fallbackAspect = 4 / 3;

  /// 整组的尺寸；没有图片时为 [Size.zero]。
  final Size size;

  /// 每一格，[DiaryCommentImageTile.index] 即图片下标（从 0 起）。
  final List<DiaryCommentImageTile> tiles;

  static DiaryCommentImageLayout _single(double width, double? aspect) {
    final ratio = (aspect == null || !aspect.isFinite || aspect <= 0)
        ? fallbackAspect
        : aspect.clamp(singleMinAspect, singleMaxAspect);
    final maxWidth = math.min(width, singleMaxExtent);
    var w = maxWidth;
    var h = w / ratio;
    if (h > singleMaxExtent) {
      h = singleMaxExtent;
      w = h * ratio;
    }
    final rect = Rect.fromLTWH(0, 0, w, h);
    return DiaryCommentImageLayout._(Size(w, h), <DiaryCommentImageTile>[
      DiaryCommentImageTile(
        index: 0,
        rect: rect,
        radius: BorderRadius.circular(outerRadius),
      ),
    ]);
  }

  /// 3 张：左边大方图占 2×2 格，右边两格方图。
  static List<Rect> _mosaicThree(double width) {
    final cell = (width - 2 * gap) / 3;
    final big = 2 * cell + gap;
    final right = big + gap;
    return <Rect>[
      Rect.fromLTWH(0, 0, big, big),
      Rect.fromLTWH(right, 0, cell, cell),
      Rect.fromLTWH(right, cell + gap, cell, cell),
    ];
  }

  /// 每行（格数，格子宽高比）。
  static const Map<int, List<(int, double)>> _templates =
      <int, List<(int, double)>>{
        2: <(int, double)>[(2, 1)],
        4: <(int, double)>[(1, 2), (3, 1)],
        5: <(int, double)>[(2, 4 / 3), (3, 1)],
        6: <(int, double)>[(3, 1), (3, 1)],
        7: <(int, double)>[(3, 1), (4, 1)],
        8: <(int, double)>[(2, 4 / 3), (3, 1), (3, 1)],
        9: <(int, double)>[(3, 1), (3, 1), (3, 1)],
      };

  static List<Rect> _rows(double width, int count) {
    final rects = <Rect>[];
    var top = 0.0;
    for (final (cells, aspect) in _templates[count]!) {
      final cellWidth = (width - (cells - 1) * gap) / cells;
      final height = cellWidth / aspect;
      for (var i = 0; i < cells; i++) {
        // 最后一格贴齐右边，免得浮点误差在右缘留下一道发丝缝。
        final left = i * (cellWidth + gap);
        final right = i == cells - 1 ? width : left + cellWidth;
        rects.add(Rect.fromLTRB(left, top, right, top + height));
      }
      top += height + gap;
    }
    return rects;
  }

  /// 格子落在整组四角的那个角用大圆角，其余用小圆角。
  static BorderRadius _radiusOf(Rect rect, Size group) {
    const epsilon = 0.5;
    final left = rect.left <= epsilon;
    final top = rect.top <= epsilon;
    final right = rect.right >= group.width - epsilon;
    final bottom = rect.bottom >= group.height - epsilon;
    Radius corner(bool outer) =>
        Radius.circular(outer ? outerRadius : innerRadius);
    return BorderRadius.only(
      topLeft: corner(top && left),
      topRight: corner(top && right),
      bottomLeft: corner(bottom && left),
      bottomRight: corner(bottom && right),
    );
  }
}

/// 一格：画第 [index] 张图片，位置 [rect]（相对整组左上角），圆角 [radius]。
@immutable
class DiaryCommentImageTile {
  const DiaryCommentImageTile({
    required this.index,
    required this.rect,
    required this.radius,
    this.overflow = 0,
  });

  final int index;
  final Rect rect;
  final BorderRadius radius;

  /// 大于 0 时这一格还要叠“+N”：之后还有 N 张没排出来。
  final int overflow;
}
