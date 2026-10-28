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
/// 输入：列表 sliver 外层 GlobalKey 的 context、交给列表的项数与顶部固定栏
/// 的高度；输出：连续的项序与对应的滚动位置。只读渲染树，无副作用。
///
/// - 顶线：滚动视图上缘再往下让过始终固定的栏（[pinnedExtent]，由宿主
///   给出）；项滚到这条线才算“在最上面”。不读 sliver 约束的 overlap：列表
///   刚从顶栏下方滑进去时它随滚动位置在 0 与栏高之间变，换算出的位置又反过
///   来改变它，跳转会每帧在两处之间来回（实机上刊头随之反复弹出收起、整屏
///   闪烁）；浮动的刊头时有时无，也不算在内。
/// - 项序 i + t 对应第 i 项上缘与第 i + 1 项上缘之间 t 处，而不是第 i 项
///   自身高度的 t 处：单列时两者相同；瀑布流两列交错，第 i 项可能比第 i + 1
///   项高出一截，按自身高度换算会让项序增大时位置反而后退（拖动时列表
///   来回抖）。瀑布流总把下一项放进最短的一列，上缘按项序不递减，所以这样
///   换算在两种排布里都是单调的。
/// - 列表只布局了视口附近的项：已布局的按实际位置换算（精确）；其余按已
///   布局项的平均高度推算（与 SliverList 估算滚动范围同一口径），等滚到
///   附近布局出来后再由调用方校正。
/// - 读数来自上一次布局：滚动位置刚变、还没重新布局时，用新位置配旧布局，
///   结果仍连续，下一帧即准确。
class FastScrollListGeometry {
  FastScrollListGeometry._(this._sliver, this.loadedCount, this.pinnedExtent);

  /// 在 [context] 下（只沿 sliver 往下找，不进入卡片内部）找第一个多子
  /// sliver；列表还没布局（加载中、空态）或是横向的时为 null。
  /// [loadedCount] 为交给列表的项数（渲染对象不公开子项总数）。
  static FastScrollListGeometry? of(
    BuildContext? context,
    int loadedCount, {
    double pinnedExtent = 0,
  }) {
    final root = context?.findRenderObject();
    final sliver = root == null ? null : _findList(root);
    if (sliver == null ||
        sliver.geometry == null ||
        !sliver.attached ||
        sliver.constraints.axis != Axis.vertical) {
      return null;
    }
    return FastScrollListGeometry._(sliver, loadedCount, pinnedExtent);
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

  /// 顶线以上始终固定的栏（标签栏等）的高度，见类注释。
  final double pinnedExtent;

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

  /// 已布局的项（按项序），带上缘与高度（列表是竖向的，见 [of]）。
  List<_Placed> _placed() {
    final placed = <_Placed>[];
    RenderBox? child = _sliver.firstChild;
    while (child != null) {
      final offset = _sliver.childScrollOffset(child);
      if (offset != null) {
        placed.add(_Placed(_sliver.indexOf(child), offset, child.size.height));
      }
      child = _sliver.childAfter(child);
    }
    return placed;
  }

  /// 第 [k] 个已布局项的上缘到下一项上缘的距离；下一项没布局时取它自己的
  /// 高度（单列时正好相等，瀑布流里是上限）。
  static double _stepAfter(List<_Placed> placed, int k) {
    final current = placed[k];
    if (k + 1 < placed.length && placed[k + 1].index == current.index + 1) {
      return math.max(0, placed[k + 1].top - current.top);
    }
    return current.height;
  }

  /// 滚动位置为 [pixels] 时顶线所在的连续项序。列表还没滚到顶线（上面还有
  /// 顶栏、日记本头部）时为 0。顶线在已布局范围之外时按平均高度推算。
  double indexAt(double pixels) {
    final line = pixels - start + pinnedExtent;
    if (line <= 0 || loadedCount == 0) {
      return 0;
    }
    final average = averageExtent;
    final placed = _placed();
    if (placed.isEmpty) {
      return average > 0 ? line / average : 0;
    }
    if (line < placed.first.top) {
      final back = average > 0 ? (placed.first.top - line) / average : 0.0;
      return math.max(0.0, placed.first.index - back);
    }
    // 最后一个上缘不低于顶线的项。
    var k = 0;
    while (k + 1 < placed.length && placed[k + 1].top <= line) {
      k++;
    }
    final current = placed[k];
    final step = _stepAfter(placed, k);
    final into = line - current.top;
    if (into <= step) {
      return current.index + (step > 0 ? into / step : 0.0);
    }
    // 顶线越过了已布局的最后一项。
    final ahead = average > 0 ? (into - step) / average : 0.0;
    return current.index + 1 + ahead;
  }

  /// 第 [index] 项（连续值）落到顶线时的滚动位置，与 [indexAt] 互逆。
  /// [exact] 为 true 表示这一项已布局、位置是精确的；否则是估算，项还可能
  /// 在已加载的范围之外（超出时位置也超过当前最大滚动范围）。
  ({double pixels, bool exact}) pixelsFor(double index) {
    if (index <= 0) {
      return (pixels: 0, exact: true);
    }
    final whole = index.floor();
    final fraction = index - whole;
    final placed = _placed();
    _Placed? nearest;
    for (var k = 0; k < placed.length; k++) {
      final entry = placed[k];
      if (entry.index == whole) {
        final offset = entry.top + fraction * _stepAfter(placed, k);
        return (pixels: start + offset - pinnedExtent, exact: true);
      }
      if (nearest == null ||
          (entry.index - whole).abs() < (nearest.index - whole).abs()) {
        nearest = entry;
      }
    }
    final average = averageExtent;
    final offset = nearest == null
        ? index * average
        : nearest.top + (index - nearest.index) * average;
    return (pixels: start + offset - pinnedExtent, exact: false);
  }
}

/// 一个已布局的项：项序、在列表 sliver 里的上缘与高度。
class _Placed {
  const _Placed(this.index, this.top, this.height);

  final int index;
  final double top;
  final double height;
}
