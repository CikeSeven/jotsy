import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 菜单相对锚点的水平对齐方式，按阅读方向解析（RTL 下左右互换）。
enum ExpressiveMenuPlacement {
  /// 菜单起始边与锚点起始边对齐，向结束方向展开；适合行首的文本入口。
  start,

  /// 菜单结束边与锚点结束边对齐，向起始方向展开；适合顶栏与行尾的 ⋮ 按钮。
  end,
}

/// 把菜单面板放到锚点旁，并从贴着锚点的那个角缩放。
///
/// 输入：锚点矩形与安全区域（都在浮层坐标系里）、对齐方式、阅读方向、缩放进度。
/// 输出：铺满浮层的盒子，面板按真实尺寸定位在其中。
///
/// 为什么不用 CustomSingleChildLayout + ScaleTransition：缩放原点取决于菜单
/// 最终是落在锚点下方还是翻到上方，而这要等面板量出高度后才知道；放在
/// build 里的 ScaleTransition 拿不到这个结果。这里在同一个 render object 里
/// 完成“定位 → 记下贴着锚点的角 → 以该角缩放绘制与命中测试”，不会有一帧
/// 从错误的角放大。
class ExpressiveMenuPosition extends SingleChildRenderObjectWidget {
  const ExpressiveMenuPosition({
    super.key,
    required this.anchor,
    required this.bounds,
    required this.placement,
    required this.textDirection,
    required this.scale,
    this.gap = defaultGap,
    super.child,
  });

  /// 菜单与锚点之间的间距。
  static const double defaultGap = 4;

  final Rect anchor;

  /// 面板必须完整落在其中的区域（已扣除系统栏、键盘与 8dp 边距）。
  final Rect bounds;
  final ExpressiveMenuPlacement placement;
  final TextDirection textDirection;
  final Animation<double> scale;
  final double gap;

  @override
  RenderExpressiveMenuPosition createRenderObject(BuildContext context) =>
      RenderExpressiveMenuPosition(
        anchor: anchor,
        bounds: bounds,
        placement: placement,
        textDirection: textDirection,
        scale: scale,
        gap: gap,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderExpressiveMenuPosition renderObject,
  ) {
    renderObject
      ..anchor = anchor
      ..bounds = bounds
      ..placement = placement
      ..textDirection = textDirection
      ..scale = scale
      ..gap = gap;
  }
}

class RenderExpressiveMenuPosition extends RenderShiftedBox {
  RenderExpressiveMenuPosition({
    required this._anchor,
    required this._bounds,
    required this._placement,
    required this._textDirection,
    required this._scale,
    required this._gap,
    RenderBox? child,
  }) : super(child);

  Rect get anchor => _anchor;
  Rect _anchor;
  set anchor(Rect value) {
    if (value == _anchor) return;
    _anchor = value;
    markNeedsLayout();
  }

  Rect get bounds => _bounds;
  Rect _bounds;
  set bounds(Rect value) {
    if (value == _bounds) return;
    _bounds = value;
    markNeedsLayout();
  }

  ExpressiveMenuPlacement get placement => _placement;
  ExpressiveMenuPlacement _placement;
  set placement(ExpressiveMenuPlacement value) {
    if (value == _placement) return;
    _placement = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  Animation<double> get scale => _scale;
  Animation<double> _scale;
  set scale(Animation<double> value) {
    if (value == _scale) return;
    if (attached) _scale.removeListener(markNeedsPaint);
    _scale = value;
    if (attached) _scale.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  double get gap => _gap;
  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  /// 缩放原点（面板自身坐标）：贴着锚点的那个角。
  Offset _origin = Offset.zero;

  /// 本次布局是否落在锚点下方；测试与调试用。
  bool get opensBelow => _opensBelow;
  bool _opensBelow = true;

  final LayerHandle<TransformLayer> _transformLayer =
      LayerHandle<TransformLayer>();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _scale.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _scale.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _transformLayer.layer = null;
    super.dispose();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() {
    size = constraints.biggest;
    final child = this.child;
    if (child == null) return;
    child.layout(
      BoxConstraints.loose(
        Size(math.max(0, bounds.width), math.max(0, bounds.height)),
      ),
      parentUsesSize: true,
    );
    final menu = child.size;
    // start 在 LTR 下贴左缘、RTL 下贴右缘；end 相反。
    final alignLeft =
        (placement == ExpressiveMenuPlacement.start) ==
        (textDirection == TextDirection.ltr);
    var x = alignLeft ? anchor.left : anchor.right - menu.width;
    final below = anchor.bottom + gap;
    final above = anchor.top - gap - menu.height;
    double y;
    if (below + menu.height <= bounds.bottom) {
      y = below;
      _opensBelow = true;
    } else if (above >= bounds.top) {
      y = above;
      _opensBelow = false;
    } else {
      // 上下都放不下（面板高度已被限制在安全区内，只是锚点两侧都不够）：
      // 选空间更大的一侧，再夹回安全区，面板会盖住锚点的一部分。
      _opensBelow = bounds.bottom - anchor.bottom >= anchor.top - bounds.top;
      y = _opensBelow ? below : above;
    }
    x = x.clamp(bounds.left, math.max(bounds.left, bounds.right - menu.width));
    y = y.clamp(bounds.top, math.max(bounds.top, bounds.bottom - menu.height));
    (child.parentData! as BoxParentData).offset = Offset(x, y);
    _origin = Alignment(
      alignLeft ? -1 : 1,
      _opensBelow ? -1 : 1,
    ).alongSize(menu);
  }

  /// 面板自身坐标 → 本盒坐标：先以 [_origin] 为中心缩放，再平移到布局位置。
  Matrix4 _childTransform() {
    final s = scale.value;
    final offset = (child!.parentData! as BoxParentData).offset;
    return Matrix4.diagonal3Values(s, s, 1)..setTranslationRaw(
      offset.dx + _origin.dx * (1 - s),
      offset.dy + _origin.dy * (1 - s),
      0,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) {
      _transformLayer.layer = null;
      return;
    }
    if (scale.value == 1) {
      _transformLayer.layer = null;
      super.paint(context, offset);
      return;
    }
    _transformLayer.layer = context.pushTransform(
      needsCompositing,
      offset,
      _childTransform(),
      (PaintingContext context, Offset offset) =>
          context.paintChild(child, offset),
      oldLayer: _transformLayer.layer,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    return result.addWithPaintTransform(
      transform: _childTransform(),
      position: position,
      hitTest: (BoxHitTestResult result, Offset position) =>
          child.hitTest(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_childTransform());
  }
}
