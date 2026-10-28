import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 拖动时气泡里的标签：[primary] 为大字（月份、首字母、章节名），[caption]
/// 为写在大字上方的小字（年份等），可省略。
@immutable
class FastScrollLabel {
  const FastScrollLabel(this.primary, {this.caption});

  final String primary;
  final String? caption;

  @override
  bool operator ==(Object other) =>
      other is FastScrollLabel &&
      other.primary == primary &&
      other.caption == caption;

  @override
  int get hashCode => Object.hash(primary, caption);
}

/// 轨道上的一个分段刻度：从第 [index] 项开始的一段（年份、首字母、章节）。
/// 分段按 [index] 升序排列。
@immutable
class FastScrollSection {
  const FastScrollSection({required this.index, required this.label});

  final int index;
  final String label;
}

/// 列表 sliver（SliverList 或瀑布流）当前布局的读数，在“第几项”与滚动
/// 位置之间换算。
///
/// 输入：列表 sliver 外层 GlobalKey 的 context 与交给列表的项数；输出：连续
/// 的项序（整数部分是项，小数部分是这一项已滚过顶线的比例）与对应的滚动
/// 位置。只读渲染树，无副作用。
///
/// - 顶线：可见内容的上缘，即滚动视图上缘再往下让过固定的标签栏等
///   （sliver 约束的 overlap）；项滚到这条线才算“在最上面”。
/// - 列表只布局了视口附近的项：已布局的按实际位置换算（精确）；其余按已
///   布局项的平均高度推算（与 SliverList 估算滚动范围同一口径），等滚到
///   附近布局出来后再由调用方校正。
/// - 读数来自上一次布局：滚动位置刚变、还没重新布局时，用新位置配旧布局，
///   结果仍连续，下一帧即准确。
class FastScrollListGeometry {
  FastScrollListGeometry._(this._sliver, this.loadedCount);

  /// 在 [context] 下（只沿 sliver 往下找，不进入卡片内部）找第一个多子
  /// sliver；列表还没布局（加载中、空态）或是横向的时为 null。
  /// [loadedCount] 为交给列表的项数（渲染对象不公开子项总数）。
  static FastScrollListGeometry? of(BuildContext? context, int loadedCount) {
    final root = context?.findRenderObject();
    final sliver = root == null ? null : _findList(root);
    if (sliver == null ||
        sliver.geometry == null ||
        !sliver.attached ||
        sliver.constraints.axis != Axis.vertical) {
      return null;
    }
    return FastScrollListGeometry._(sliver, loadedCount);
  }

  static RenderSliverMultiBoxAdaptor? _findList(RenderObject node) {
    if (node is RenderSliverMultiBoxAdaptor) {
      return node;
    }
    if (node is! RenderSliver) {
      return null;
    }
    RenderSliverMultiBoxAdaptor? found;
    node.visitChildren((RenderObject child) {
      found ??= _findList(child);
    });
    return found;
  }

  final RenderSliverMultiBoxAdaptor _sliver;

  /// 已交给列表的项数（已加载的篇数）。
  final int loadedCount;

  /// 列表在整个滚动视图里的起点：前面各 sliver 的滚动范围之和。
  double get start => _sliver.constraints.precedingScrollExtent;

  /// 列表自身的滚动范围（未布局部分为估算）。
  double get extent => _sliver.geometry!.scrollExtent;

  /// 顶线以上被固定标签栏等盖住的高度。
  double get overlap => math.max(0, _sliver.constraints.overlap);

  /// 每项平均占的滚动距离（瀑布流为每项摊到的距离）。
  double get averageExtent {
    final count = loadedCount;
    return count == 0 ? 0 : extent / count;
  }

  /// 滚动位置为 [metrics] 时的按钮位置（0–1）：顶线所在项 / [total]。
  ///
  /// 全部加载完时，最后几项到不了顶线：最后一屏（内容很短时为滚动范围的
  /// 一半）里按钮平滑走到底。读不到列表布局时退回按像素换算。
  static double fractionFor(
    ScrollMetrics metrics,
    FastScrollListGeometry? geometry,
    int total,
  ) {
    final pixels = metrics.pixels;
    final max = metrics.maxScrollExtent;
    if (geometry == null || total <= 0) {
      return max <= 0 ? 0 : (pixels / max).clamp(0.0, 1.0);
    }
    var fraction = (geometry.indexAt(pixels) / total).clamp(0.0, 1.0);
    if (geometry.loadedCount >= total) {
      final window = math.min(metrics.viewportDimension, max / 2);
      if (window > 0) {
        final blend = ((pixels - (max - window)) / window).clamp(0.0, 1.0);
        fraction += (1 - fraction) * blend;
      }
    }
    return fraction;
  }

  /// 整份列表（[total] 项）的估计滚动范围：当前的范围，加上还没加载的项
  /// 按已加载部分的平均高度推算。
  static double estimatedRange(
    ScrollMetrics metrics,
    FastScrollListGeometry? geometry,
    int total,
  ) {
    var range = metrics.maxScrollExtent;
    if (geometry != null && total > geometry.loadedCount) {
      range += (total - geometry.loadedCount) * geometry.averageExtent;
    }
    return range;
  }

  /// 已布局项沿滚动方向的高度（列表是竖向的，见 [of]）。
  static double _heightOf(RenderBox child) => child.size.height;

  /// 滚动位置为 [pixels] 时顶线所在的连续项序。列表还没滚到顶线（上面还有
  /// 顶栏、日记本头部）时为 0。
  double indexAt(double pixels) {
    final top = pixels - start + overlap;
    if (top <= 0 || loadedCount == 0) {
      return 0;
    }
    final average = averageExtent;
    RenderBox? child = _sliver.firstChild;
    RenderBox? last;
    while (child != null) {
      final offset = _sliver.childScrollOffset(child);
      if (offset != null) {
        final index = _sliver.indexOf(child);
        final height = _heightOf(child);
        // 按项序第一个底边越过顶线的：顶线落在它上面（瀑布流另一列、间隙
        // 或还没布局到的前面几项）时往前按平均高度推。
        if (offset + height > top) {
          if (offset <= top) {
            return index + (height > 0 ? (top - offset) / height : 0.0);
          }
          final back = average > 0 ? (offset - top) / average : 0.0;
          return math.max(0.0, index - back);
        }
        last = child;
      }
      child = _sliver.childAfter(child);
    }
    if (last == null) {
      return average > 0 ? top / average : 0;
    }
    final lastEnd = _sliver.childScrollOffset(last)! + _heightOf(last);
    final ahead = average > 0 ? (top - lastEnd) / average : 0.0;
    return _sliver.indexOf(last) + 1 + ahead;
  }

  /// 第 [index] 项（连续值，小数部分为项内比例）落到顶线时的滚动位置。
  /// [exact] 为 true 表示这一项已布局、位置是精确的；否则是估算，项还可能
  /// 在已加载的范围之外（超出时位置也超过当前最大滚动范围）。
  ({double pixels, bool exact}) pixelsFor(double index) {
    if (index <= 0) {
      return (pixels: 0, exact: true);
    }
    final whole = index.floor();
    final fraction = index - whole;
    RenderBox? nearest;
    var nearestDistance = double.infinity;
    RenderBox? child = _sliver.firstChild;
    while (child != null) {
      final offset = _sliver.childScrollOffset(child);
      if (offset != null) {
        final childIndex = _sliver.indexOf(child);
        if (childIndex == whole) {
          final height = _heightOf(child);
          return (
            pixels: start + offset + fraction * height - overlap,
            exact: true,
          );
        }
        final distance = (childIndex - whole).abs().toDouble();
        if (distance < nearestDistance) {
          nearestDistance = distance;
          nearest = child;
        }
      }
      child = _sliver.childAfter(child);
    }
    final average = averageExtent;
    final double offset;
    if (nearest == null) {
      offset = index * average;
    } else {
      offset =
          _sliver.childScrollOffset(nearest)! +
          (index - _sliver.indexOf(nearest)) * average;
    }
    return (pixels: start + offset - overlap, exact: false);
  }
}
