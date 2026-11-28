import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// [RenderStableMasonryGrid] 的子项父数据：在 [SliverMultiBoxAdaptorParentData]
/// 之上附加所属列号。
class StableMasonryGridParentData extends SliverMultiBoxAdaptorParentData {
  /// 该项所在的交叉轴列号（0 起）。
  int crossAxisIndex = 0;

  @override
  String toString() => 'crossAxisIndex=$crossAxisIndex; ${super.toString()}';
}

/// 位置稳定的瀑布流 sliver 渲染对象。
///
/// 输入：列数 [crossAxisCount]、主/交叉轴间距、有序稳定键 [itemKeys] 与子项管理器；
/// 输出：按“放入当前最短列”排布的瀑布流布局与精确/平滑估算的 [SliverGeometry]。
/// 副作用：视口上方发生增删改排或列宽变化时，通过 [SliverGeometry.scrollOffsetCorrection]
/// 与 [onScrollOffsetCorrection] 保持视口内锚点不跳动。
///
/// 为什么不直接用 `flutter_staggered_grid_view` 的 `RenderSliverMasonryGrid`：
/// 1. 它用两只平铺栈记录滚出视口的前导项，数据删改后前导记录即错位；
/// 2. 宿主为了清旧缓存而换 key 重挂时，新渲染对象 `firstChild == null` 且
///    `scrollOffset > 0` 会因空列初始为 `double.infinity` 误触发
///    `scrollOffsetCorrection: -scrollOffset`，把列表突然弹回上半部分，并导致
///    全屏卡片卸载重挂、闪烁。
///
/// 本实现按稳定键缓存当前列宽下实测过的卡片高度，增量维护槽位表：
/// - 末尾分页追加复用已算前缀，零重算、零滚动校正；
/// - 删改发生在视口内或其后时，视口以上前缀完全不变，仅视口内及后续项就地重排；
/// - 删改发生在视口严格上方或列数/列宽变化时，按首个存活的可见锚点计算精确偏移差并
///   在同一布局帧校正滚动位置，画面停在原处不跳；
/// - 配合 `findChildIndexCallback`，存活卡片的元素与图片状态全程复用、不闪烁。
class RenderStableMasonryGrid extends RenderSliverMultiBoxAdaptor {
  RenderStableMasonryGrid({
    required super.childManager,
    required int crossAxisCount,
    required double mainAxisSpacing,
    required double crossAxisSpacing,
    List<Object>? itemKeys,
    this.onScrollOffsetCorrection,
  }) : assert(crossAxisCount > 0),
       assert(mainAxisSpacing >= 0),
       assert(crossAxisSpacing >= 0),
       _crossAxisCount = crossAxisCount,
       _mainAxisSpacing = mainAxisSpacing,
       _crossAxisSpacing = crossAxisSpacing,
       _explicitKeys = itemKeys;

  static const int _maxCachedHeights = 2000;
  static const double _fallbackExtent = 200.0;

  /// 当本 sliver 主动发出坐标校正（保持视口锚点不动）时回调，供 FLIP 控制器
  /// 同步平移已记录的起点，避免把坐标系重算误判成全屏滑动动画。
  void Function(double correction)? onScrollOffsetCorrection;

  int _crossAxisCount;
  int get crossAxisCount => _crossAxisCount;
  set crossAxisCount(int value) {
    assert(value > 0);
    if (_crossAxisCount == value) return;
    _crossAxisCount = value;
    _dirtyFromIndex = 0;
    if (_lastAnchors.isNotEmpty) {
      _pendingAnchorCheck = true;
    }
    markNeedsLayout();
  }

  double _mainAxisSpacing;
  double get mainAxisSpacing => _mainAxisSpacing;
  set mainAxisSpacing(double value) {
    assert(value >= 0);
    if (_mainAxisSpacing == value) return;
    _mainAxisSpacing = value;
    _dirtyFromIndex = 0;
    if (_lastAnchors.isNotEmpty) {
      _pendingAnchorCheck = true;
    }
    markNeedsLayout();
  }

  double _crossAxisSpacing;
  double get crossAxisSpacing => _crossAxisSpacing;
  set crossAxisSpacing(double value) {
    assert(value >= 0);
    if (_crossAxisSpacing == value) return;
    _crossAxisSpacing = value;
    markNeedsLayout();
  }

  List<Object>? _explicitKeys;
  List<Object>? get itemKeys => _explicitKeys;
  set itemKeys(List<Object>? value) {
    final previous = _explicitKeys;
    if (identical(previous, value)) return;
    _explicitKeys = value;
    _keyToIndex = null;
    if (previous == null || value == null) {
      _dirtyFromIndex = 0;
      if (_lastAnchors.isNotEmpty) _pendingAnchorCheck = true;
      markNeedsLayout();
      return;
    }
    final minLen = math.min(previous.length, value.length);
    var firstDiff = 0;
    while (firstDiff < minLen && previous[firstDiff] == value[firstDiff]) {
      firstDiff += 1;
    }
    if (firstDiff == previous.length && previous.length == value.length) {
      // 键序列完全相同：高度是否变化由子项自身布局触发，无需作废槽位或锚点。
      return;
    }
    _invalidateSlotsFrom(firstDiff);
    // 只有视口首个可见项严格之前的键发生变化时才触发锚点校正；
    // 末尾分页追加或视口内删除不拉动滚动偏移。
    if (firstDiff < previous.length &&
        _lastAnchors.isNotEmpty &&
        firstDiff < _lastFirstVisibleIndex) {
      _pendingAnchorCheck = true;
    }
    markNeedsLayout();
  }

  double _stride = 0;
  int Function(int) _mapCrossAxisIndex = _identity;
  static int _identity(int index) => index;

  /// 当前列宽下已实测过的条目高度（LRU 缓存）。
  final LinkedHashMap<Object, double> _measuredHeights =
      LinkedHashMap<Object, double>();
  double _measuredSum = 0;

  /// 上一次列宽下的高度软估计：窗口拉伸或列数变化时用于估算视口以上偏移，
  /// 实际布局到该项后会被精确测量覆盖。
  final Map<Object, double> _softHeights = <Object, double>{};
  double _measuredWidth = -1;

  /// 已计算的槽位前缀（满足贪心最短列不变量，top 单调非递减）。
  final List<_MasonrySlot> _slots = <_MasonrySlot>[];
  int _dirtyFromIndex = 0;

  Map<Object, int>? _keyToIndex;
  List<_MasonryAnchor> _lastAnchors = const <_MasonryAnchor>[];
  int _lastFirstVisibleIndex = 0;
  bool _pendingAnchorCheck = false;

  int get _totalCount =>
      _explicitKeys?.length ?? (childManager.estimatedChildCount ?? 0);

  Object _keyAt(int index) {
    final keys = _explicitKeys;
    return keys != null && index < keys.length ? keys[index] : index;
  }

  int? _indexOfKey(Object key) {
    final keys = _explicitKeys;
    if (keys == null) {
      return key is int && key >= 0 && key < _totalCount ? key : null;
    }
    final map = _keyToIndex ??= <Object, int>{
      for (var i = 0; i < keys.length; i++) keys[i]: i,
    };
    return map[key];
  }

  double get _estimatedExtent => _measuredHeights.isNotEmpty
      ? _measuredSum / _measuredHeights.length
      : _fallbackExtent;

  double _heightForKey(Object key) =>
      _measuredHeights[key] ?? _softHeights[key] ?? _estimatedExtent;

  void _recordMeasuredHeight(Object key, double extent) {
    final existing = _measuredHeights.remove(key);
    if (existing != null) {
      _measuredSum -= existing;
    }
    _measuredHeights[key] = extent;
    _measuredSum += extent;
    while (_measuredHeights.length > _maxCachedHeights) {
      final oldestKey = _measuredHeights.keys.first;
      _measuredSum -= _measuredHeights.remove(oldestKey)!;
    }
  }

  void _invalidateSlotsFrom(int index) {
    if (index < _dirtyFromIndex) {
      _dirtyFromIndex = index;
    }
    if (_dirtyFromIndex < _slots.length) {
      _slots.length = _dirtyFromIndex;
    }
  }

  /// O(crossAxisCount) 反推 `beforeIndex` 之前各列的底部偏移。
  List<double> _columnBottomsBefore(int beforeIndex) {
    final bottoms = List<double>.filled(_crossAxisCount, 0.0);
    if (beforeIndex <= 0) return bottoms;
    final found = List<bool>.filled(_crossAxisCount, false);
    var remaining = _crossAxisCount;
    for (var i = beforeIndex - 1; i >= 0 && remaining > 0; i--) {
      final slot = _slots[i];
      if (!found[slot.column]) {
        found[slot.column] = true;
        bottoms[slot.column] = slot.top + slot.extent + _mainAxisSpacing;
        remaining -= 1;
      }
    }
    return bottoms;
  }

  static int _minColumn(List<double> bottoms) {
    var best = 0;
    var bestValue = bottoms[0];
    for (var i = 1; i < bottoms.length; i++) {
      if (bottoms[i] < bestValue) {
        best = i;
        bestValue = bottoms[i];
      }
    }
    return best;
  }

  static double _minValue(List<double> values) {
    var best = values[0];
    for (var i = 1; i < values.length; i++) {
      if (values[i] < best) best = values[i];
    }
    return best;
  }

  double _maxBottomFromColumns(List<double> bottoms) {
    var maxVal = 0.0;
    for (var i = 0; i < bottoms.length; i++) {
      final value = bottoms[i];
      if (value > 0) {
        final bottom = math.max(0.0, value - _mainAxisSpacing);
        if (bottom > maxVal) maxVal = bottom;
      }
    }
    return maxVal;
  }

  /// 确保 `_slots` 至少计算到 `targetIndex`（含）。
  void _ensureSlotsThrough(int targetIndex, int totalCount) {
    final limit = math.min(targetIndex, totalCount - 1);
    if (_slots.length > limit && _dirtyFromIndex > limit) return;
    final start = math.min(_dirtyFromIndex, _slots.length);
    _slots.length = start;
    final bottoms = _columnBottomsBefore(start);
    for (var i = start; i <= limit; i++) {
      final col = _minColumn(bottoms);
      final top = bottoms[col];
      final key = _keyAt(i);
      final measured = _measuredHeights.containsKey(key);
      final extent = measured
          ? _measuredHeights[key]!
          : (_softHeights[key] ?? _estimatedExtent);
      _slots.add(
        _MasonrySlot(top: top, column: col, extent: extent, measured: measured),
      );
      bottoms[col] = top + extent + _mainAxisSpacing;
    }
    _dirtyFromIndex = _slots.length;
  }

  /// 确保 `_slots` 至少覆盖到所有列底部超过 `targetOffset`（或到达列表末尾）。
  void _ensureSlotsUntilOffset(double targetOffset, int totalCount) {
    if (totalCount <= 0) return;
    final start = math.min(_dirtyFromIndex, _slots.length);
    _slots.length = start;
    final bottoms = _columnBottomsBefore(start);
    var i = start;
    while (i < totalCount &&
        (i == 0 || _minValue(bottoms) - _mainAxisSpacing < targetOffset)) {
      final col = _minColumn(bottoms);
      final top = bottoms[col];
      final key = _keyAt(i);
      final measured = _measuredHeights.containsKey(key);
      final extent = measured
          ? _measuredHeights[key]!
          : (_softHeights[key] ?? _estimatedExtent);
      _slots.add(
        _MasonrySlot(top: top, column: col, extent: extent, measured: measured),
      );
      bottoms[col] = top + extent + _mainAxisSpacing;
      i += 1;
    }
    _dirtyFromIndex = _slots.length;
  }

  double _estimateMaxScrollOffset({
    required int lastIndex,
    required int totalCount,
    required List<double> colBottoms,
    required double endScrollOffset,
  }) {
    if (lastIndex >= totalCount - 1) return endScrollOffset;
    var sum = 0.0;
    for (var i = 0; i < colBottoms.length; i++) {
      sum += colBottoms[i];
    }
    final remaining = totalCount - lastIndex - 1;
    // 尽量累加已知高度与平滑均值，让回滚或滚动途中最大滚动范围稳定不抖动。
    if (_explicitKeys != null && remaining <= 512) {
      for (var i = lastIndex + 1; i < totalCount; i++) {
        sum += _heightForKey(_explicitKeys![i]) + _mainAxisSpacing;
      }
    } else {
      sum += remaining * (_estimatedExtent + _mainAxisSpacing);
    }
    final averageBottom = sum / _crossAxisCount - _mainAxisSpacing;
    return math.max(endScrollOffset, averageBottom);
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! StableMasonryGridParentData) {
      child.parentData = StableMasonryGridParentData();
    }
  }

  @override
  double childCrossAxisPosition(RenderBox child) {
    final parentData = child.parentData! as StableMasonryGridParentData;
    return _mapCrossAxisIndex(parentData.crossAxisIndex) * _stride;
  }

  @override
  void performLayout() {
    childManager.didStartLayout();
    childManager.setDidUnderflow(false);

    final totalCount = _totalCount;
    if (totalCount <= 0) {
      if (childCount > 0) {
        collectGarbage(childCount, 0);
      }
      _slots.clear();
      _dirtyFromIndex = 0;
      _lastAnchors = const <_MasonryAnchor>[];
      _lastFirstVisibleIndex = 0;
      _pendingAnchorCheck = false;
      geometry = SliverGeometry.zero;
      childManager.didFinishLayout();
      return;
    }

    final columns = _crossAxisCount;
    _mapCrossAxisIndex = axisDirectionIsReversed(constraints.crossAxisDirection)
        ? (int index) => columns - index - 1
        : _identity;
    _stride = (constraints.crossAxisExtent + _crossAxisSpacing) / columns;
    final childCrossAxisExtent = math.max(0.0, _stride - _crossAxisSpacing);
    final childConstraints = constraints.asBoxConstraints(
      crossAxisExtent: childCrossAxisExtent,
    );

    if ((_measuredWidth - childCrossAxisExtent).abs() >
        precisionErrorTolerance) {
      if (_measuredWidth >= 0) {
        _softHeights
          ..clear()
          ..addAll(_measuredHeights);
        _measuredHeights.clear();
        _measuredSum = 0;
        _invalidateSlotsFrom(0);
        if (constraints.scrollOffset > 0 && _lastAnchors.isNotEmpty) {
          _pendingAnchorCheck = true;
        }
      }
      _measuredWidth = childCrossAxisExtent;
    }

    // 视口严格上方发生增删或列宽变化：先按首个存活可见锚点校正滚动偏移，
    // 同一帧重排后画面停在原处不跳动。
    if (_pendingAnchorCheck) {
      _pendingAnchorCheck = false;
      if (constraints.scrollOffset > 0 && _lastAnchors.isNotEmpty) {
        for (final anchor in _lastAnchors) {
          final newIndex = _indexOfKey(anchor.key);
          if (newIndex == null) continue;
          _ensureSlotsThrough(newIndex, totalCount);
          var correction = _slots[newIndex].top - anchor.top;
          if (constraints.scrollOffset + correction < 0) {
            correction = -constraints.scrollOffset;
          }
          if (correction.abs() > precisionErrorTolerance) {
            onScrollOffsetCorrection?.call(correction);
            geometry = SliverGeometry(scrollOffsetCorrection: correction);
            return;
          }
          break;
        }
      }
    }

    final scrollOffset = constraints.scrollOffset + constraints.cacheOrigin;
    assert(scrollOffset >= 0.0);
    final remainingExtent = constraints.remainingCacheExtent;
    assert(remainingExtent >= 0.0);
    final targetEndScrollOffset = scrollOffset + remainingExtent;

    _ensureSlotsUntilOffset(targetEndScrollOffset, totalCount);

    // 找到首个底边（含间距）触及 cache 起点的槽位；若滚动已越过列表末尾，
    // 保留最后一项作为尾部锚点，与 RenderSliverList 保持一致。
    var startIndex = _slots.length - 1;
    for (var i = 0; i < _slots.length; i++) {
      final slot = _slots[i];
      if (slot.top + slot.extent + _mainAxisSpacing >= scrollOffset) {
        startIndex = i;
        break;
      }
    }

    // 记录本次布局前视口内首个存活锚点，用于向上滚进“此前未测量过”区域时
    // 消除估计高度与真实高度差异带来的画面抖动。
    int? scrollUpAnchorIndex;
    double? scrollUpAnchorOldTop;
    if (constraints.scrollOffset > 0 && _lastAnchors.isNotEmpty) {
      for (final anchor in _lastAnchors) {
        final idx = _indexOfKey(anchor.key);
        if (idx != null && idx < _slots.length) {
          scrollUpAnchorIndex = idx;
          scrollUpAnchorOldTop = _slots[idx].top;
          break;
        }
      }
    }

    // 将当前已挂载子链表对齐到 startIndex，尽量复用所有重叠子元素。
    if (firstChild != null) {
      final leadingToDrop = calculateLeadingGarbage(firstIndex: startIndex);
      if (leadingToDrop > 0) {
        collectGarbage(leadingToDrop, 0);
      }
    }
    if (firstChild != null && indexOf(firstChild!) > startIndex) {
      final firstExistingIndex = indexOf(firstChild!);
      // 若现有子项全部在目标缓存区间之外（例如快速滚动条远距离跳转），
      // 整批回收后直接从 startIndex 建起，避免把中间数百项全部实例化。
      final disjoint =
          firstExistingIndex >= _slots.length ||
          _slots[firstExistingIndex].top > targetEndScrollOffset;
      if (disjoint) {
        collectGarbage(0, childCount);
      } else {
        while (firstChild != null && indexOf(firstChild!) > startIndex) {
          final inserted = insertAndLayoutLeadingChild(
            childConstraints,
            parentUsesSize: true,
          );
          if (inserted == null) break;
        }
      }
    }
    if (firstChild == null) {
      if (!addInitialChild(
        index: startIndex,
        layoutOffset: _slots[startIndex].top,
      )) {
        geometry = SliverGeometry.zero;
        childManager.didFinishLayout();
        return;
      }
    }

    // 若 startIndex 之后首项仍高于 startIndex（极端空列表退化），回退校正。
    final actualStart = indexOf(firstChild!);
    if (actualStart > startIndex) {
      startIndex = actualStart;
      _ensureSlotsThrough(startIndex, totalCount);
    }

    final colBottoms = _columnBottomsBefore(startIndex);
    var child = firstChild;
    var index = startIndex;
    late RenderBox lastLaidOut;
    var reachedEnd = false;
    var unmeasuredAboveAnchorChanged = false;

    while (child != null) {
      // 确保 slot[index] 与最新列底一致。
      if (index >= _slots.length) {
        final col = _minColumn(colBottoms);
        final top = colBottoms[col];
        final key = _keyAt(index);
        final measured = _measuredHeights.containsKey(key);
        final extent = measured
            ? _measuredHeights[key]!
            : (_softHeights[key] ?? _estimatedExtent);
        _slots.add(
          _MasonrySlot(
            top: top,
            column: col,
            extent: extent,
            measured: measured,
          ),
        );
        _dirtyFromIndex = _slots.length;
      }

      child.layout(childConstraints, parentUsesSize: true);
      lastLaidOut = child;

      final slot = _slots[index];
      final actualExtent = paintExtentOf(child);
      final key = _keyAt(index);
      final wasMeasured = slot.measured;
      final heightChanged =
          (actualExtent - slot.extent).abs() > precisionErrorTolerance;
      _recordMeasuredHeight(key, actualExtent);
      if (!wasMeasured || heightChanged) {
        slot
          ..extent = actualExtent
          ..measured = true;
        if (heightChanged) {
          _invalidateSlotsFrom(index + 1);
          if (scrollUpAnchorIndex != null && index < scrollUpAnchorIndex) {
            unmeasuredAboveAnchorChanged = true;
          }
        }
      }

      final parentData = child.parentData! as StableMasonryGridParentData;
      parentData
        ..layoutOffset = slot.top
        ..crossAxisIndex = slot.column;
      colBottoms[slot.column] = slot.top + actualExtent + _mainAxisSpacing;

      if (index == totalCount - 1) {
        reachedEnd = true;
        break;
      }
      if (_minValue(colBottoms) - _mainAxisSpacing >= targetEndScrollOffset) {
        break;
      }

      index += 1;
      final next = childAfter(lastLaidOut);
      if (next == null || indexOf(next) != index) {
        final inserted = insertAndLayoutChild(
          childConstraints,
          after: lastLaidOut,
          parentUsesSize: true,
        );
        if (inserted == null) {
          reachedEnd = true;
          index -= 1;
          break;
        }
        child = inserted;
      } else {
        child = next;
      }
    }

    // 清理尾部多余子项，以及因高度缩小而滚出 cache 起点的前导子项。
    var trailingGarbage = 0;
    RenderBox? trailing = childAfter(lastLaidOut);
    while (trailing != null) {
      trailingGarbage += 1;
      trailing = childAfter(trailing);
    }
    var extraLeadingGarbage = 0;
    RenderBox? leading = firstChild;
    while (leading != null && leading != lastLaidOut) {
      final slot = _slots[indexOf(leading)];
      if (slot.top + slot.extent + _mainAxisSpacing < scrollOffset) {
        extraLeadingGarbage += 1;
        leading = childAfter(leading);
      } else {
        break;
      }
    }
    collectGarbage(extraLeadingGarbage, trailingGarbage);
    assert(debugAssertChildListIsNonEmptyAndContiguous());

    // 若向上滚动时刚刚首次实测了锚点上方的估算项且高度偏差超过误差，
    // 在同一帧修正滚动位置，确保视口内卡片纹丝不动。
    if (unmeasuredAboveAnchorChanged &&
        scrollUpAnchorIndex != null &&
        scrollUpAnchorOldTop != null) {
      _ensureSlotsThrough(scrollUpAnchorIndex, totalCount);
      var correction = _slots[scrollUpAnchorIndex].top - scrollUpAnchorOldTop;
      if (constraints.scrollOffset + correction < 0) {
        correction = -constraints.scrollOffset;
      }
      if (correction.abs() > precisionErrorTolerance) {
        onScrollOffsetCorrection?.call(correction);
        geometry = SliverGeometry(scrollOffsetCorrection: correction);
        return;
      }
    }

    final firstIndex = indexOf(firstChild!);
    final lastIndex = indexOf(lastChild!);
    final leadingScrollOffset = _slots[firstIndex].top;
    // 防浮点误差（a + spacing - spacing 略小于 a）触发 calculatePaintOffset 断言。
    final endScrollOffset = math.max(
      leadingScrollOffset,
      _maxBottomFromColumns(colBottoms),
    );
    final estimatedMaxScrollOffset = reachedEnd
        ? endScrollOffset
        : _estimateMaxScrollOffset(
            lastIndex: lastIndex,
            totalCount: totalCount,
            colBottoms: colBottoms,
            endScrollOffset: endScrollOffset,
          );
    final paintExtent = calculatePaintOffset(
      constraints,
      from: leadingScrollOffset,
      to: endScrollOffset,
    );
    final cacheExtent = calculateCacheOffset(
      constraints,
      from: leadingScrollOffset,
      to: endScrollOffset,
    );
    final targetEndScrollOffsetForPaint =
        constraints.scrollOffset + constraints.remainingPaintExtent;

    geometry = SliverGeometry(
      scrollExtent: estimatedMaxScrollOffset,
      paintExtent: paintExtent,
      cacheExtent: cacheExtent,
      maxPaintExtent: estimatedMaxScrollOffset,
      hasVisualOverflow:
          endScrollOffset > targetEndScrollOffsetForPaint ||
          constraints.scrollOffset > 0.0,
    );
    if (estimatedMaxScrollOffset == endScrollOffset) {
      childManager.setDidUnderflow(true);
    }

    // 记录当前真正露在视口里的锚点列表，供下一次视口上方变更时保持位置。
    final visibleStart = constraints.scrollOffset;
    final visibleEnd = visibleStart + constraints.remainingPaintExtent;
    final anchors = <_MasonryAnchor>[];
    RenderBox? walker = firstChild;
    while (walker != null) {
      final idx = indexOf(walker);
      final slot = _slots[idx];
      if (slot.top + slot.extent > visibleStart && slot.top < visibleEnd) {
        anchors.add(
          _MasonryAnchor(key: _keyAt(idx), top: slot.top, index: idx),
        );
      }
      walker = childAfter(walker);
    }
    _lastAnchors = anchors;
    _lastFirstVisibleIndex = anchors.isEmpty ? 0 : anchors.first.index;
    childManager.didFinishLayout();
  }
}

class _MasonrySlot {
  _MasonrySlot({
    required this.top,
    required this.column,
    required this.extent,
    required this.measured,
  });

  double top;
  int column;
  double extent;
  bool measured;
}

class _MasonryAnchor {
  const _MasonryAnchor({
    required this.key,
    required this.top,
    required this.index,
  });

  final Object key;
  final double top;
  final int index;
}
