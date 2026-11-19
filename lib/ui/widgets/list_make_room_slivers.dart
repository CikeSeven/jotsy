part of 'list_make_room.dart';

/// [SliverList] 的让位版（见 [MakeRoomController]）：[makeRoom] 让位途中把
/// 预构建区里的项也画出来，并让位移大的项画在上层；平时与 [SliverList]
/// 完全相同。[makeRoom] 为 null 时就是 [SliverList]。
class MakeRoomSliverList extends SliverList {
  const MakeRoomSliverList({
    super.key,
    required super.delegate,
    required this.makeRoom,
  });

  final MakeRoomController? makeRoom;

  @override
  RenderSliverList createRenderObject(BuildContext context) =>
      _RenderMakeRoomSliverList(
        childManager: context as SliverMultiBoxAdaptorElement,
      )..makeRoom = makeRoom;

  @override
  void updateRenderObject(BuildContext context, RenderSliverList renderObject) {
    (renderObject as _RenderMakeRoomSliverList).makeRoom = makeRoom;
  }
}

/// [SliverMasonryGrid.count] 的让位版，见 [MakeRoomSliverList]。
class MakeRoomSliverMasonryGrid extends SliverMasonryGrid {
  MakeRoomSliverMasonryGrid.count({
    super.key,
    required int crossAxisCount,
    required IndexedWidgetBuilder itemBuilder,
    int? childCount,
    super.mainAxisSpacing,
    super.crossAxisSpacing,
    required this.makeRoom,
  }) : super(
         delegate: SliverChildBuilderDelegate(
           itemBuilder,
           childCount: childCount,
         ),
         gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(
           crossAxisCount: crossAxisCount,
         ),
       );

  final MakeRoomController? makeRoom;

  @override
  RenderSliverMasonryGrid createRenderObject(BuildContext context) =>
      _RenderMakeRoomSliverMasonryGrid(
        childManager: context as SliverMultiBoxAdaptorElement,
        gridDelegate: gridDelegate,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
      )..makeRoom = makeRoom;

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSliverMasonryGrid renderObject,
  ) {
    super.updateRenderObject(context, renderObject);
    (renderObject as _RenderMakeRoomSliverMasonryGrid).makeRoom = makeRoom;
  }
}

class _RenderMakeRoomSliverList extends RenderSliverList
    with _MakeRoomSliverPaint {
  _RenderMakeRoomSliverList({required super.childManager});
}

class _RenderMakeRoomSliverMasonryGrid extends RenderSliverMasonryGrid
    with _MakeRoomSliverPaint {
  _RenderMakeRoomSliverMasonryGrid({
    required super.childManager,
    required super.gridDelegate,
    required super.mainAxisSpacing,
    required super.crossAxisSpacing,
  });
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
