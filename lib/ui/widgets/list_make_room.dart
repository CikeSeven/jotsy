import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../app/theme/expressive_motion.dart';

/// 列表“让位”动画（FLIP）：插进一张新卡片后，其余卡片从原来的位置滑到新
/// 位置，而不是瞬间跳过去。
///
/// 为什么不靠新卡片“从 0 长高”把别的卡片挤开：瀑布流（Masonry）按“放进
/// 最短的一列”排布，新卡片每长高一帧，后面的卡片都可能换列，一路来回跳；
/// 普通列表虽然不跳，也要逐帧重新排版整张列表。这里新卡片一次排到最终尺寸，
/// 别的卡片只在绘制时加一个从“原位置 − 新位置”回到 0 的位移：一次排版，
/// 之后每帧只是平移各自的图层，两种布局都一样顺滑。
///
/// 用法：
/// 1. 列表的每一项包一层 [MakeRoomItem]（按稳定的标签，如日记 id）；
/// 2. 列表还在屏上、即将被盖住时 [MakeRoomController.captureBaseline]，
///    记下每一项在屏上的位置（全局坐标）；
/// 3. 新卡片排进列表之后（盖住列表的页面开始收回时）
///    [MakeRoomController.play]：当场量出每一项的新位置，与起点之差作为
///    位移，按弹簧（[ExpressiveMotion.springSpatial]，过冲约 2%）回到 0，
///    结束后一切复原。
///
/// 为什么在 [play] 时一次量完、而不是各项绘制时自己量：每一项都在自己的
/// 重绘边界里，只是被挪了位置时列表复用它的图层、不会调用它的绘制，等不到
/// 它来量。排进新卡片到 [play] 之间列表被整页盖着，画在哪里都看不见。
///
/// 没有起点的项（新插入的、此前不在屏上的）原地出现，不参与位移。中途列表
/// 重挂（瀑布流换布局代）也不丢：位移按标签记在控制器里，新的渲染对象
/// 接着用。减少动态效果时 [play] 什么都不做（直接是新位置）。
class MakeRoomController extends ChangeNotifier {
  MakeRoomController({required TickerProvider vsync})
    : _progress = AnimationController.unbounded(vsync: vsync, value: 1) {
    _progress
      ..addListener(notifyListeners)
      ..addStatusListener(_handleStatus);
  }

  /// 0 = 停在原位置，1 = 到新位置。无界：弹簧会越过 1 一点。
  final AnimationController _progress;

  final Set<_RenderMakeRoomItem> _items = <_RenderMakeRoomItem>{};

  /// 起点：标签 → 全局坐标里的左上角。
  Map<Object, Offset> _baseline = const <Object, Offset>{};

  /// 这一次的位移：标签 → 原位置 − 新位置。
  final Map<Object, Offset> _deltas = <Object, Offset>{};

  /// 是否在让位途中。
  bool get isActive => _deltas.isNotEmpty;

  /// 记下此刻每一项在屏上的位置，作为下一次让位的起点。
  void captureBaseline() {
    final baseline = <Object, Offset>{};
    for (final item in _items) {
      final origin = item.globalOrigin();
      if (origin != null) baseline[item.tag] = origin;
    }
    _baseline = baseline;
  }

  /// 各项从起点滑向此刻的位置（须在列表排好新布局之后调用，如帧后回调或
  /// 事件里）。没有起点、或减少动态效果时什么都不做。
  void play(BuildContext context) {
    final baseline = _baseline;
    _baseline = const <Object, Offset>{};
    if (baseline.isEmpty || ExpressiveMotion.reduceMotion(context)) return;
    _deltas.clear();
    for (final item in _items) {
      final from = baseline[item.tag];
      final to = item.globalOrigin();
      if (from == null || to == null) continue;
      final delta = from - to;
      if (delta.distanceSquared > 0.25) _deltas[item.tag] = delta;
    }
    if (_deltas.isEmpty) return;
    _progress.value = 0;
    ExpressiveMotion.springTo(
      context,
      _progress,
      1,
      spring: ExpressiveMotion.springSpatial,
      tolerance: const Tolerance(distance: 1e-3, velocity: 1e-2),
    );
  }

  void _handleStatus(AnimationStatus status) {
    if (!_progress.isAnimating && _progress.value == 1 && _deltas.isNotEmpty) {
      _deltas.clear();
      notifyListeners();
    }
  }

  /// [item] 此刻的位移（绘制时调用）。
  Offset _displacementOf(_RenderMakeRoomItem item) {
    final delta = _deltas[item.tag];
    return delta == null ? Offset.zero : delta * (1 - _progress.value);
  }

  @override
  void dispose() {
    _progress.dispose();
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
