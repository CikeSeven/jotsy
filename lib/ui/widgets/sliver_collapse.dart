import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../app/theme/expressive_motion.dart';

/// 可动画折叠的 sliver：按 [factor]（0 收起、1 展开）缩放子 sliver 的滚动
/// 长度，并把绘制与点按裁到缩放后的这一段里，后面的内容随之上移 / 下移。
///
/// 为什么不让分组里的每一项各自收成 0 高：一组可能有上百条，懒加载列表
/// 遇到 0 高的项会一口气构建出后面所有的项去填满视口。这里子 sliver 照常
/// 按完整长度排版（只构建屏上那几项），只是对外报告的长度乘上进度。
///
/// 进度为 1 时几何与子 sliver 完全相同、不裁剪（静止时零开销）；为 0 时
/// 不排版、不绘制、不参与点按与读屏。只支持自上而下排列的列表（其余方向
/// 只缩放长度、不裁剪）。进度由调用方驱动（[AnimatedSliverCollapse] 自带
/// 弹簧）。
class SliverCollapse extends SingleChildRenderObjectWidget {
  const SliverCollapse({
    super.key,
    required this.factor,
    required Widget sliver,
  }) : super(child: sliver);

  /// 展开进度；超出 0–1 的部分（弹簧过冲）按 0–1 截断。
  final Animation<double> factor;

  @override
  RenderSliverCollapse createRenderObject(BuildContext context) =>
      RenderSliverCollapse(factor: factor);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSliverCollapse renderObject,
  ) {
    renderObject.factor = factor;
  }
}

/// [SliverCollapse] 的渲染对象。
class RenderSliverCollapse extends RenderProxySliver {
  RenderSliverCollapse({required this._factor});

  Animation<double> _factor;
  set factor(Animation<double> value) {
    if (identical(value, _factor)) return;
    if (attached) {
      _factor.removeListener(markNeedsLayout);
      value.addListener(markNeedsLayout);
    }
    _factor = value;
    markNeedsLayout();
  }

  double get _value => _factor.value.clamp(0.0, 1.0);

  final LayerHandle<ClipRectLayer> _clip = LayerHandle<ClipRectLayer>();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _factor.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _factor.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }

  @override
  void performLayout() {
    final child = this.child;
    final value = _value;
    if (child == null || value == 0) {
      geometry = SliverGeometry.zero;
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    final childGeometry = child.geometry!;
    if (value == 1 || childGeometry.scrollOffsetCorrection != null) {
      geometry = childGeometry;
      return;
    }
    final extent = childGeometry.scrollExtent * value;
    final paintExtent = calculatePaintOffset(constraints, from: 0, to: extent);
    final cacheExtent = calculateCacheOffset(constraints, from: 0, to: extent);
    geometry = SliverGeometry(
      scrollExtent: extent,
      paintExtent: paintExtent,
      cacheExtent: math.max(cacheExtent, paintExtent),
      maxPaintExtent: math.max(extent, paintExtent),
      hitTestExtent: paintExtent,
      hasVisualOverflow: true,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null || _value == 0 || !geometry!.visible) {
      _clip.layer = null;
      return;
    }
    if (_value == 1 || constraints.axisDirection != AxisDirection.down) {
      _clip.layer = null;
      context.paintChild(child, offset);
      return;
    }
    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Rect.fromLTWH(0, 0, constraints.crossAxisExtent, geometry!.paintExtent),
      (PaintingContext context, Offset offset) =>
          context.paintChild(child, offset),
      oldLayer: _clip.layer,
    );
  }

  @override
  bool hitTestChildren(
    SliverHitTestResult result, {
    required double mainAxisPosition,
    required double crossAxisPosition,
  }) {
    if (_value == 0 || mainAxisPosition >= geometry!.hitTestExtent) {
      return false;
    }
    return super.hitTestChildren(
      result,
      mainAxisPosition: mainAxisPosition,
      crossAxisPosition: crossAxisPosition,
    );
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_value == 0) return;
    super.visitChildrenForSemantics(visitor);
  }
}

/// 自带弹簧进度的 [SliverCollapse]：[expanded] 变化时以
/// [ExpressiveMotion.springSpatial] 展开 / 收起（中途反向带着速度接着走），
/// 减少动态效果时直接到位。完全收起并停稳后不再挂子 sliver（里面的项随之
/// 卸载），再展开时重新构建。
class AnimatedSliverCollapse extends StatefulWidget {
  const AnimatedSliverCollapse({
    super.key,
    required this.expanded,
    required this.sliver,
  });

  final bool expanded;
  final Widget sliver;

  @override
  State<AnimatedSliverCollapse> createState() => _AnimatedSliverCollapseState();
}

class _AnimatedSliverCollapseState extends State<AnimatedSliverCollapse>
    with SingleTickerProviderStateMixin {
  /// 进度是 0–1 的比例，按像素量级的默认容差太粗。
  static const Tolerance _tolerance = Tolerance(distance: 1e-3, velocity: 1e-2);

  late final AnimationController _progress = AnimationController.unbounded(
    vsync: this,
    value: widget.expanded ? 1 : 0,
  )..addStatusListener(_handleStatus);

  /// 完全收起并停稳：不再挂子 sliver。
  late bool _settledCollapsed = !widget.expanded;

  /// 正在 [didUpdateWidget] 里起弹簧：这时的状态回调不 setState（本来就
  /// 要重建），由那里自己定 [_settledCollapsed]。
  bool _updating = false;

  bool get _atRestCollapsed =>
      !widget.expanded && !_progress.isAnimating && _progress.value <= 0;

  @override
  void didUpdateWidget(covariant AnimatedSliverCollapse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded == oldWidget.expanded) return;
    _updating = true;
    ExpressiveMotion.springTo(
      context,
      _progress,
      widget.expanded ? 1 : 0,
      spring: ExpressiveMotion.springSpatial,
      tolerance: _tolerance,
    );
    _updating = false;
    // 减少动画时 springTo 直接到位，没有收尾的状态回调。
    _settledCollapsed = _atRestCollapsed;
  }

  void _handleStatus(AnimationStatus status) {
    if (_updating || !mounted) return;
    final collapsed = _atRestCollapsed;
    if (collapsed != _settledCollapsed) {
      setState(() => _settledCollapsed = collapsed);
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SliverCollapse(
      factor: _progress,
      sliver: _settledCollapsed ? const SliverToBoxAdapter() : widget.sliver,
    );
  }
}
