part of 'list_make_room.dart';

/// [SliverList] 的让位版（见 [MakeRoomController]）：[makeRoom] 让位途中把
/// 预构建区里的项也画出来，并让位移大的项画在上层；平时与 [SliverList]
/// 完全相同。[makeRoom] 为 null 时就是 [SliverList]。
///
/// 传入 [itemKeys] 时额外启用锚点位置稳定：记录各项实测高度，视口严格上方发生
/// 增删或重排时在同一帧校正滚动偏移，保持当前阅读位置不跳动。
class MakeRoomSliverList extends SliverList {
  const MakeRoomSliverList({
    super.key,
    required super.delegate,
    required this.makeRoom,
    this.itemKeys,
  });

  final MakeRoomController? makeRoom;

  /// 与 [delegate] 顺序一致的稳定键列表；为 null 时不启用锚点偏移校正。
  final List<Object>? itemKeys;

  @override
  RenderSliverList createRenderObject(BuildContext context) =>
      _RenderMakeRoomSliverList(
          childManager: context as SliverMultiBoxAdaptorElement,
        )
        ..makeRoom = makeRoom
        ..itemKeys = itemKeys;

  @override
  void updateRenderObject(BuildContext context, RenderSliverList renderObject) {
    (renderObject as _RenderMakeRoomSliverList)
      ..makeRoom = makeRoom
      ..itemKeys = itemKeys;
  }
}

/// 位置稳定的瀑布流让位版（底层为 [RenderStableMasonryGrid]），支持
/// [findChildIndexCallback] 元素复用、[itemKeys] 高度缓存与视口锚点稳定，以及
/// [makeRoom] 预构建区绘制与按位移排序绘制。
class MakeRoomSliverMasonryGrid extends SliverMultiBoxAdaptorWidget {
  MakeRoomSliverMasonryGrid.count({
    super.key,
    required this.crossAxisCount,
    required IndexedWidgetBuilder itemBuilder,
    int? childCount,
    ChildIndexGetter? findChildIndexCallback,
    this.itemKeys,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = 0,
    required this.makeRoom,
  }) : assert(crossAxisCount > 0),
       assert(mainAxisSpacing >= 0),
       assert(crossAxisSpacing >= 0),
       super(
         delegate: SliverChildBuilderDelegate(
           itemBuilder,
           childCount: childCount,
           findChildIndexCallback: findChildIndexCallback,
         ),
       );

  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final List<Object>? itemKeys;
  final MakeRoomController? makeRoom;

  @override
  RenderStableMasonryGrid createRenderObject(BuildContext context) =>
      _RenderMakeRoomSliverMasonryGrid(
        childManager: context as SliverMultiBoxAdaptorElement,
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        itemKeys: itemKeys,
      )..makeRoom = makeRoom;

  @override
  void updateRenderObject(
    BuildContext context,
    RenderStableMasonryGrid renderObject,
  ) {
    (renderObject as _RenderMakeRoomSliverMasonryGrid)
      ..crossAxisCount = crossAxisCount
      ..mainAxisSpacing = mainAxisSpacing
      ..crossAxisSpacing = crossAxisSpacing
      ..itemKeys = itemKeys
      ..makeRoom = makeRoom;
  }
}

class _RenderMakeRoomSliverList extends RenderSliverList
    with _MakeRoomSliverPaint {
  _RenderMakeRoomSliverList({required super.childManager});

  static const int _maxCachedHeights = 2000;
  static const double _fallbackExtent = 160.0;

  final LinkedHashMap<Object, double> _measuredHeights =
      LinkedHashMap<Object, double>();
  double _measuredSum = 0;
  double _measuredWidth = -1;

  List<Object>? _itemKeys;
  List<_ListAnchor> _lastAnchors = const <_ListAnchor>[];
  int _lastFirstVisibleIndex = 0;

  double? _pendingCorrection;
  double? _pendingAnchorTargetTop;
  int? _pendingAnchorNewIndex;

  double get _estimatedExtent => _measuredHeights.isNotEmpty
      ? _measuredSum / _measuredHeights.length
      : _fallbackExtent;

  double _heightOf(Object key) => _measuredHeights[key] ?? _estimatedExtent;

  void _recordMeasuredHeight(Object key, double extent) {
    final existing = _measuredHeights.remove(key);
    if (existing != null) _measuredSum -= existing;
    _measuredHeights[key] = extent;
    _measuredSum += extent;
    while (_measuredHeights.length > _maxCachedHeights) {
      final oldest = _measuredHeights.keys.first;
      _measuredSum -= _measuredHeights.remove(oldest)!;
    }
  }

  set itemKeys(List<Object>? value) {
    final previous = _itemKeys;
    if (identical(previous, value)) return;
    _itemKeys = value;
    if (previous == null || value == null || _lastAnchors.isEmpty) return;

    final minLen = math.min(previous.length, value.length);
    var firstDiff = 0;
    while (firstDiff < minLen && previous[firstDiff] == value[firstDiff]) {
      firstDiff += 1;
    }
    if (firstDiff == previous.length) {
      // 未变或仅在末尾分页追加，无需锚点校正。
      return;
    }
    if (firstDiff >= _lastFirstVisibleIndex) {
      // 变更发生在视口首个可见项及其后，让后续卡片自然补位。
      return;
    }

    final indexByKey = <Object, int>{
      for (var i = 0; i < value.length; i++) value[i]: i,
    };
    for (final anchor in _lastAnchors) {
      final newIndex = indexByKey[anchor.key];
      if (newIndex == null) continue;
      final delta = _prefixHeightDelta(previous, anchor.index, value, newIndex);
      if (delta.abs() > precisionErrorTolerance || newIndex != anchor.index) {
        _pendingCorrection = delta;
        _pendingAnchorTargetTop = anchor.top + delta;
        _pendingAnchorNewIndex = newIndex;
      }
      break;
    }
  }

  /// 计算锚点之前所有条目的净高度变化：两份前缀共有的键自动抵消，
  /// 即使更早的未滚动条目从未测量也不影响精度。
  double _prefixHeightDelta(
    List<Object> oldKeys,
    int oldAnchorIndex,
    List<Object> newKeys,
    int newAnchorIndex,
  ) {
    final oldPrefix = <Object>{
      for (var i = 0; i < oldAnchorIndex && i < oldKeys.length; i++) oldKeys[i],
    };
    final newPrefix = <Object>{
      for (var i = 0; i < newAnchorIndex && i < newKeys.length; i++) newKeys[i],
    };
    var delta = 0.0;
    for (final key in oldPrefix) {
      if (!newPrefix.contains(key)) {
        delta -= _heightOf(key);
      }
    }
    for (final key in newPrefix) {
      if (!oldPrefix.contains(key)) {
        delta += _heightOf(key);
      }
    }
    return delta;
  }

  @override
  void performLayout() {
    final keys = _itemKeys;
    if (keys == null) {
      super.performLayout();
      return;
    }
    if ((_measuredWidth - constraints.crossAxisExtent).abs() >
        precisionErrorTolerance) {
      if (_measuredWidth >= 0) {
        _measuredHeights.clear();
        _measuredSum = 0;
      }
      _measuredWidth = constraints.crossAxisExtent;
    }

    final pending = _pendingCorrection;
    if (pending != null) {
      final anchorNewIndex = _pendingAnchorNewIndex;
      final anchorTargetTop = _pendingAnchorTargetTop;
      _pendingCorrection = null;
      _pendingAnchorNewIndex = null;
      _pendingAnchorTargetTop = null;

      if (constraints.scrollOffset > 0 &&
          anchorNewIndex != null &&
          anchorTargetTop != null) {
        var correction = pending;
        if (constraints.scrollOffset + correction < 0) {
          correction = -constraints.scrollOffset;
        }
        // 同步修正 firstChild 的 layoutOffset，抵消 SliverMultiBoxAdaptorElement
        // 按旧下标槽位回填产生的偏移漂移。
        final first = firstChild;
        if (first != null && keys.isNotEmpty) {
          final firstIdx = indexOf(first);
          final adjustedAnchorTop = anchorTargetTop - (pending - correction);
          double? newFirstTop;
          if (firstIdx <= anchorNewIndex) {
            var before = 0.0;
            for (var i = firstIdx; i < anchorNewIndex && i < keys.length; i++) {
              before += _heightOf(keys[i]);
            }
            newFirstTop = adjustedAnchorTop - before;
          } else {
            var after = 0.0;
            for (var i = anchorNewIndex; i < firstIdx && i < keys.length; i++) {
              after += _heightOf(keys[i]);
            }
            newFirstTop = adjustedAnchorTop + after;
          }
          final firstParentData =
              first.parentData! as SliverMultiBoxAdaptorParentData;
          firstParentData.layoutOffset = newFirstTop >= 0 ? newFirstTop : null;
        }
        if (correction.abs() > precisionErrorTolerance) {
          _makeRoom?.adjustPendingForScrollCorrection(
            correction,
            axis: constraints.axis,
          );
          geometry = SliverGeometry(scrollOffsetCorrection: correction);
          return;
        }
      }
    }

    super.performLayout();

    final visibleStart = constraints.scrollOffset;
    final visibleEnd = visibleStart + constraints.remainingPaintExtent;
    final anchors = <_ListAnchor>[];
    RenderBox? walker = firstChild;
    while (walker != null) {
      final idx = indexOf(walker);
      if (idx >= 0 && idx < keys.length) {
        final key = keys[idx];
        final extent = paintExtentOf(walker);
        _recordMeasuredHeight(key, extent);
        final top = childScrollOffset(walker);
        if (top != null && top + extent > visibleStart && top < visibleEnd) {
          anchors.add(_ListAnchor(key: key, top: top, index: idx));
        }
      }
      walker = childAfter(walker);
    }
    _lastAnchors = anchors;
    _lastFirstVisibleIndex = anchors.isEmpty ? 0 : anchors.first.index;
  }
}

class _ListAnchor {
  const _ListAnchor({
    required this.key,
    required this.top,
    required this.index,
  });

  final Object key;
  final double top;
  final int index;
}

class _RenderMakeRoomSliverMasonryGrid extends RenderStableMasonryGrid
    with _MakeRoomSliverPaint {
  _RenderMakeRoomSliverMasonryGrid({
    required super.childManager,
    required super.crossAxisCount,
    required super.mainAxisSpacing,
    required super.crossAxisSpacing,
    super.itemKeys,
  }) {
    onScrollOffsetCorrection = _handleScrollOffsetCorrection;
  }

  void _handleScrollOffsetCorrection(double correction) {
    _makeRoom?.adjustPendingForScrollCorrection(
      correction,
      axis: constraints.axis,
    );
  }
}

/// 让位途中的列表绘制。
///
/// 为什么要画预构建区：sliver 只画排版位置落在可见区里的项。新布局里被挤
/// 出屏幕的卡片（原本在屏上）不画就会当场消失，而它上面的卡片还在往下滑，
/// 屏幕底部先空一块；从预构建区换位进来的卡片同理。让位途中改为画出全部
/// 已排版的项，各项按自己的位移画在途中的位置，屏外的部分由视口裁掉。
///
/// 为什么调绘制顺序：sliver 按下标顺序绘制，换到前面的卡片（如刚编辑过、
/// 排到最前的那篇）会从后面卡片的底下钻过去。按位移从小到大绘制，换位
/// 最远的那张压在上面飞过去；位移相同的仍按下标顺序。
///
/// 只支持自上而下排列（日记列表）；其余方向、或不在让位途中时与原来的
/// 绘制完全相同。
mixin _MakeRoomSliverPaint on RenderSliverMultiBoxAdaptor {
  MakeRoomController? _makeRoom;
  set makeRoom(MakeRoomController? value) {
    if (identical(value, _makeRoom)) return;
    if (attached) {
      _makeRoom?._paintsAll.removeListener(markNeedsPaint);
      value?._paintsAll.addListener(markNeedsPaint);
    }
    _makeRoom = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _makeRoom?._paintsAll.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _makeRoom?._paintsAll.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final controller = _makeRoom;
    if (controller == null ||
        !controller._paintsAll.value ||
        firstChild == null ||
        applyGrowthDirectionToAxisDirection(
              constraints.axisDirection,
              constraints.growthDirection,
            ) !=
            AxisDirection.down) {
      super.paint(context, offset);
      return;
    }
    controller._measurePending();
    final children = <({RenderBox child, int index, double lift})>[];
    for (
      RenderBox? child = firstChild;
      child != null;
      child = childAfter(child)
    ) {
      children.add((
        child: child,
        index: children.length,
        lift: _liftOf(controller, child),
      ));
    }
    children.sort(
      (a, b) => a.lift != b.lift
          ? a.lift.compareTo(b.lift)
          : a.index.compareTo(b.index),
    );
    for (final entry in children) {
      final child = entry.child;
      context.paintChild(
        child,
        offset.translate(
          childCrossAxisPosition(child),
          childMainAxisPosition(child),
        ),
      );
    }
  }

  /// [child]（列表的直接子项）里那一项的位移大小；不是让位项时为 0。
  /// 让位项在列表包的重绘边界、语义下标这几层单子节点之下。
  static double _liftOf(MakeRoomController controller, RenderBox child) {
    RenderObject? node = child;
    for (var depth = 0; depth < 4 && node != null; depth++) {
      if (node is _RenderMakeRoomItem) {
        return controller._deltas[node.tag]?.distanceSquared ?? 0;
      }
      node = node is RenderObjectWithChildMixin<RenderBox> ? node.child : null;
    }
    return 0;
  }
}
