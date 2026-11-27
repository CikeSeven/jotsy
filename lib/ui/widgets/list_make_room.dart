import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../app/theme/expressive_motion.dart';

part 'list_make_room_slivers.dart';

/// 列表“让位”动画（FLIP）：列表换了数据（插进新卡片、删掉、换位、改了高度）
/// 后，其余卡片从原来的位置滑到新位置，而不是瞬间跳过去。
///
/// 为什么不靠卡片“从 0 长高 / 收成 0”把别的卡片挤开：瀑布流（Masonry）按
/// “放进最短的一列”排布，卡片每变一帧高度，后面的卡片都可能换列，一路来回
/// 跳；普通列表虽然不跳，也要逐帧重新排版整张列表。这里一次排到最终布局，
/// 别的卡片只在绘制时加一个从“原位置 − 新位置”回到 0 的位移：一次排版，
/// 之后每帧只是平移各自的图层，两种布局都一样顺滑。
///
/// 两种用法：
/// - 被整页盖着时换数据（新建日记发表后落进列表）：列表还在屏上时
///   [captureBaseline] 记下每一项在屏上的位置（全局坐标），新卡片排进列表
///   之后（盖住列表的页面开始收回时）[play]：当场量出新位置，与起点之差
///   作为位移。中间列表被整页盖着，画在哪里都看不见；
/// - 列表就在眼前换数据：换数据的那一次 build 里 [animateLayoutChange]，
///   记下各项在所属 sliver 内容坐标里的位置；新布局排好后的第一次绘制时
///   量出新位置，同一帧就从原位置画起，不会先闪一下新布局。
///
/// 位移按弹簧（[ExpressiveMotion.springSpatial]，过冲约 2%）回到 0，结束后
/// 一切复原。没有起点的项（新插入的、此前不在树上的）原地出现，不参与位移，
/// 由调用方自己淡入。中途列表重挂（瀑布流换布局代）也不丢：位移按标签记在
/// 控制器里，新的渲染对象接着用。减少动态效果时调用方不调用（[play] 自己
/// 检查）。
///
/// 让位途中列表 sliver 若用 [MakeRoomSliverList] / [MakeRoomSliverMasonryGrid]，
/// 预构建区里的项也会画出来（滑进、滑出屏幕的卡片不会凭空出现或消失），
/// 并按位移从小到大绘制（换位最远的那张压在上面）。
///
/// [acrossSlivers] 为 true 时 [animateLayoutChange] 改按整个滚动视图的内容
/// 坐标记位置：一项从一个 sliver 换到另一个（待办从“今天”组移到“明天”组、
/// 从已完成组回到未完成）也能滑过去，前面的 sliver 改了高度时后面的项同样
/// 滑到新位置。默认按所属 sliver 记（日记列表），前面的区块变高时不动。
class MakeRoomController extends ChangeNotifier {
  MakeRoomController({
    required TickerProvider vsync,
    this.acrossSlivers = false,
  }) : _progress = AnimationController.unbounded(vsync: vsync, value: 1) {
    _progress
      ..addListener(notifyListeners)
      ..addStatusListener(_handleStatus);
  }

  /// 是否按整个滚动视图（而不是所属 sliver）的内容坐标记位置，见类注释。
  final bool acrossSlivers;

  /// 弹簧停稳的判定：进度是 0–1 的比例，按像素量级的默认容差太粗。
  static const Tolerance _tolerance = Tolerance(distance: 1e-3, velocity: 1e-2);

  /// 0 = 停在原位置，1 = 到新位置。无界：弹簧会越过 1 一点。
  final AnimationController _progress;

  final Set<_RenderMakeRoomItem> _items = <_RenderMakeRoomItem>{};

  /// [captureBaseline] 的起点：标签 → 全局坐标里的左上角。
  Map<Object, Offset> _baseline = const <Object, Offset>{};

  /// [animateLayoutChange] 的起点：标签 → 所在 sliver 内容坐标里的左上角
  /// （含当时的位移）。非 null 表示等着下一次绘制时量出新位置。
  Map<Object, Offset>? _pending;

  /// 这一轮 [_pending] 是否已经量过（同一帧里第一个绘制的项一次量完）。
  bool _measured = false;
  bool _finishScheduled = false;
  bool _disposed = false;

  /// 这一次的位移：标签 → 原位置 − 新位置。
  final Map<Object, Offset> _deltas = <Object, Offset>{};

  /// 列表 sliver 是否要画出全部已排版的项、并按位移排绘制顺序：等着量新
  /// 位置的那一帧与整段让位途中。
  final ValueNotifier<bool> _paintsAll = ValueNotifier<bool>(false);

  /// 是否在让位途中。
  bool get isActive => _deltas.isNotEmpty;

  /// 记下此刻每一项在屏上的位置，作为下一次 [play] 的起点。
  void captureBaseline() {
    final baseline = <Object, Offset>{};
    for (final item in _items) {
      final origin = item.globalOrigin();
      if (origin != null) baseline[item.tag] = origin;
    }
    _baseline = baseline;
  }

  /// 各项从 [captureBaseline] 记下的起点滑向此刻的位置（须在列表排好新
  /// 布局之后调用，如帧后回调或事件里）。没有起点、或减少动态效果时什么
  /// 都不做。
  void play(BuildContext context) {
    final baseline = _baseline;
    _baseline = const <Object, Offset>{};
    if (baseline.isEmpty || ExpressiveMotion.reduceMotion(context)) return;
    _pending = null;
    _deltas.clear();
    for (final item in _items) {
      final from = baseline[item.tag];
      final to = item.globalOrigin();
      if (from == null || to == null) continue;
      final delta = from - to;
      if (delta.distanceSquared > 0.25) _deltas[item.tag] = delta;
    }
    _syncPaintMode();
    if (_deltas.isEmpty) return;
    _progress.value = 0;
    ExpressiveMotion.springTo(
      context,
      _progress,
      1,
      spring: ExpressiveMotion.springSpatial,
      tolerance: _tolerance,
    );
  }

  /// 列表就在眼前换数据：在换数据的那一次 build 里（新布局排版之前）调用。
  ///
  /// 记下各项此刻在所属 sliver 内容坐标里的位置（不含滚动偏移：变化恰逢
  /// 滚动时不会把滚动量当成位移；让位途中再变时加上此刻的位移，从眼前的
  /// 画面出发），让各项重画一次；新布局排好后第一个绘制的项一次量出全部
  /// 新位置，同一帧就画在原位置，帧后起弹簧。那一帧一项都没画（列表被盖
  /// 住、不在屏上）时什么都不做。
  ///
  /// 返回记下了起点的标签（此刻挂在树上、排过版的项，含预构建区）。调用方
  /// 负责减少动态效果时不调用。
  Set<Object> animateLayoutChange() {
    final from = <Object, Offset>{};
    for (final item in _items) {
      final origin = item.contentOrigin();
      if (origin != null) from[item.tag] = origin + item._current;
    }
    if (from.isEmpty) return const <Object>{};
    _pending = from;
    _measured = false;
    _deltas.clear();
    _progress.stop();
    // 归零即通知各项重画：它们在自己的重绘边界之外，只被挪动位置时列表
    // 复用图层、不会调用它们的绘制，等不到它们来量。
    _progress.value = 0;
    notifyListeners();
    _syncPaintMode();
    if (!_finishScheduled) {
      _finishScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) => _finishPending());
    }
    return from.keys.toSet();
  }

  /// 量出 [_pending] 里各项的新位置（绘制阶段调用，此时布局都已排好）。
  void _measurePending() {
    final from = _pending;
    if (from == null || _measured) return;
    _measured = true;
    for (final item in _items) {
      final start = from[item.tag];
      if (start == null) continue;
      final to = item.contentOrigin();
      if (to == null) continue;
      final delta = start - to;
      if (delta.distanceSquared > 0.25) _deltas[item.tag] = delta;
    }
  }

  /// 换数据那一帧画完：量出了位移就起弹簧，否则复原。
  void _finishPending() {
    _finishScheduled = false;
    if (_disposed || _pending == null) return;
    _pending = null;
    _measured = false;
    if (_deltas.isEmpty) {
      _progress.value = 1;
    } else {
      _progress.animateWith(
        SpringSimulation(
          ExpressiveMotion.springSpatial,
          _progress.value,
          1,
          0,
          tolerance: _tolerance,
          snapToEnd: true,
        ),
      );
    }
    _syncPaintMode();
  }

  void _handleStatus(AnimationStatus status) {
    if (!_progress.isAnimating && _progress.value == 1 && _deltas.isNotEmpty) {
      _deltas.clear();
      notifyListeners();
      _syncPaintMode();
    }
  }

  void _syncPaintMode() {
    if (_disposed) return;
    _paintsAll.value = _pending != null || _deltas.isNotEmpty;
  }

  /// [item] 此刻的位移（绘制时调用）。
  Offset _displacementOf(_RenderMakeRoomItem item) {
    _measurePending();
    final delta = _deltas[item.tag];
    return delta == null ? Offset.zero : delta * (1 - _progress.value);
  }

  @override
  void dispose() {
    _disposed = true;
    _progress.dispose();
    _paintsAll.dispose();
    _items.clear();
    super.dispose();
  }
}

/// 让位动画里的一项，见 [MakeRoomController]。子树包在 [RepaintBoundary]
/// 里：滑动时每帧只平移它的图层，不重新录制卡片的绘制。
class MakeRoomItem extends StatelessWidget {
  const MakeRoomItem({
    super.key,
    required this.tag,
    required this.controller,
    required this.child,
  });

  final Object tag;
  final MakeRoomController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) => _MakeRoomItem(
    tag: tag,
    controller: controller,
    child: RepaintBoundary(child: child),
  );
}

class _MakeRoomItem extends SingleChildRenderObjectWidget {
  const _MakeRoomItem({
    required this.tag,
    required this.controller,
    required super.child,
  });

  final Object tag;
  final MakeRoomController controller;

  @override
  _RenderMakeRoomItem createRenderObject(BuildContext context) =>
      _RenderMakeRoomItem(tag: tag, controller: controller);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMakeRoomItem renderObject,
  ) {
    renderObject
      ..tag = tag
      ..controller = controller;
  }
}

class _RenderMakeRoomItem extends RenderProxyBox {
  _RenderMakeRoomItem({required this.tag, required this._controller});

  Object tag;

  MakeRoomController _controller;
  set controller(MakeRoomController value) {
    if (identical(value, _controller)) return;
    if (attached) {
      _controller._items.remove(this);
      _controller.removeListener(_changed);
      value._items.add(this);
      value.addListener(_changed);
    }
    _controller = value;
    markNeedsPaint();
  }

  /// 只在让位途中重画（平移图层）；平时进度变化与它无关。
  void _changed() => markNeedsPaint();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller._items.add(this);
    _controller.addListener(_changed);
  }

  @override
  void detach() {
    _controller._items.remove(this);
    _controller.removeListener(_changed);
    super.detach();
  }

  /// 本项左上角在全局坐标里的位置（不含自己的位移）；还没排版时为 null。
  Offset? globalOrigin() {
    if (!attached || !hasSize) return null;
    return localToGlobal(Offset.zero);
  }

  /// 本项左上角在所属 sliver 内容坐标里的位置（不含自己的位移，也不含
  /// 滚动偏移）；还没排版时为 null。不在 sliver 里、或 sliver 不是自上而下
  /// / 自左而右排时退回全局坐标。控制器 [MakeRoomController.acrossSlivers]
  /// 时改按所在滚动视图的内容坐标（[_viewportContentOrigin]）。
  Offset? contentOrigin() {
    if (!attached || !hasSize) return null;
    if (_controller.acrossSlivers) {
      final origin = _viewportContentOrigin();
      if (origin != null) return origin;
    }
    RenderObject? node = parent;
    while (node != null && node is! RenderSliver) {
      node = node.parent;
    }
    if (node is! RenderSliver) return localToGlobal(Offset.zero);
    final origin = MatrixUtils.transformPoint(
      getTransformTo(node),
      Offset.zero,
    );
    final constraints = node.constraints;
    return switch (applyGrowthDirectionToAxisDirection(
      constraints.axisDirection,
      constraints.growthDirection,
    )) {
      AxisDirection.down => origin.translate(0, constraints.scrollOffset),
      AxisDirection.right => origin.translate(constraints.scrollOffset, 0),
      _ => localToGlobal(Offset.zero),
    };
  }

  /// 本项左上角在所在滚动视图内容坐标里的位置：相对视口的位置加上视口
  /// 此刻的滚动量（变化恰逢滚动时不把滚动量当成位移）。各 sliver 共用这一
  /// 套坐标，换了 sliver 的项也能量出位移。不在视口里、或视口不是自上而下
  /// / 自左而右排时为 null（退回按所属 sliver 记）。
  Offset? _viewportContentOrigin() {
    RenderObject? node = parent;
    while (node != null && node is! RenderViewportBase) {
      node = node.parent;
    }
    if (node is! RenderViewportBase) return null;
    final origin = MatrixUtils.transformPoint(
      getTransformTo(node),
      Offset.zero,
    );
    final pixels = node.offset.hasPixels ? node.offset.pixels : 0.0;
    return switch (node.axisDirection) {
      AxisDirection.down => origin.translate(0, pixels),
      AxisDirection.right => origin.translate(pixels, 0),
      _ => null,
    };
  }

  Offset _current = Offset.zero;

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    _current = _controller._displacementOf(this);
    context.paintChild(child, offset + _current);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    return result.addWithPaintOffset(
      offset: _current,
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) =>
          child.hitTest(result, position: transformed),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(_current.dx, _current.dy, 0, 1);
  }
}
