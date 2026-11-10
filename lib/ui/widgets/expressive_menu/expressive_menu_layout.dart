import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../glass/outer_shadow_painter.dart';
import 'expressive_menu_geometry.dart';
import 'expressive_menu_motion.dart';

export 'expressive_menu_geometry.dart'
    show ExpressiveMenuPlacement, ExpressiveMenuSide;

/// 菜单可以占用的区域：扣掉系统栏、键盘与显示特征后的安全区（不再留边距：
/// 水平方向贴着锚点对齐，竖直方向的 8dp 间距由布局按 margin 留出）。
class ExpressiveMenuArea {
  const ExpressiveMenuArea({required this.bounds});

  final Rect bounds;

  static ExpressiveMenuArea of(
    BuildContext context,
    Size overlaySize,
    Rect near,
  ) {
    // 系统栏与键盘取自视图本身：Scaffold 正文、底部面板会在局部 MediaQuery
    // 里抹掉顶部 padding，用局部值会让翻到上方的菜单钻进状态栏。
    final view = MediaQueryData.fromView(View.of(context));
    final viewport = view.padding.deflateRect(
      view.viewInsets.deflateRect(Offset.zero & overlaySize),
    );
    // 折叠屏铰链等显示特征两侧各算一块屏幕，菜单只放在离锚点最近的那块上。
    final screens = DisplayFeatureSubScreen.subScreensInBounds(
      viewport,
      DisplayFeatureSubScreen.avoidBounds(view),
    );
    final screen = screens.isEmpty
        ? viewport
        : screens.reduce(
            (Rect a, Rect b) =>
                (a.center - near.center).distanceSquared <=
                    (b.center - near.center).distanceSquared
                ? a
                : b,
          );
    return ExpressiveMenuArea(bounds: screen);
  }
}

/// 二级菜单标题行在布局时报告的“比展开完少了多少高”：变形途中标题行的高度
/// 从触发行插值到自身高度，布局据此还原二级菜单展开完的高度，落点不随帧变。
class ExpressiveSubmenuMetrics {
  double collapsedDelta = 0;
}

/// 主菜单与二级菜单的定位、缩放、裁切展开与变形（一个 render object 完成，
/// 不会有一帧从错误的角放大）。
///
/// - 输入：锚点矩形与安全区（浮层坐标）、对齐方式、阅读方向、竖直间距
///   [margin]、动效 [motion]；二级菜单打开时另有触发行在主菜单里的矩形
///   [submenuAnchor]（主菜单自身坐标，按下时取定）与它是否是最后一行。
/// - 输出：铺满浮层的盒子。主菜单按 miuix 的下拉规则放在锚点旁；二级菜单
///   以触发行为锚点（见 [placeExpressiveSubmenu]）。
/// - 绘制：两块面板都以主菜单贴着锚点的角为原点缩放（0.15 + 0.85 × enter），
///   并只画出按落点方向展开的那一段（[expressiveMenuRevealBand]）；主菜单在
///   二级菜单打开时再缩到 0.95。二级菜单按 expand 从触发行的矩形插值到自己的
///   矩形（圆角 0 → 16，触发行是首行 / 末行时那一侧保持 16），内容随之从触发行
///   滑到落点。投影只画在形状外侧、描边沿形状画，都随透明度淡入。
/// - 命中测试与绘制同一套变换，只有看得见的形状内才命中；形状外的点按穿过
///   本盒（不算点在菜单上），由外层 TapRegion 当作点外部处理。
class ExpressiveMenuCascade extends MultiChildRenderObjectWidget {
  ExpressiveMenuCascade({
    super.key,
    required this.anchor,
    required this.bounds,
    required this.placement,
    required this.textDirection,
    required this.margin,
    required this.motion,
    required this.shadowColor,
    required this.borderColor,
    required Widget primary,
    Widget? secondary,
    this.submenuAnchor,
    this.submenuAnchorIsFirst = false,
    this.submenuAnchorIsLast = false,
    this.submenuMetrics,
  }) : super(children: <Widget>[primary, ?secondary]);

  final Rect anchor;
  final Rect bounds;
  final ExpressiveMenuPlacement placement;
  final TextDirection textDirection;
  final double margin;
  final ExpressiveMenuMotion motion;

  /// 投影与描边在完全显现时的颜色。
  final Color shadowColor;
  final Color borderColor;
  final Rect? submenuAnchor;

  /// 触发行是主菜单的首行 / 末行：变形起点就与主菜单共用那条圆角边，
  /// 对应的两个角从一开始就是 16，不从直角长出来（否则直角会从主菜单的
  /// 圆角外露出来）。
  final bool submenuAnchorIsFirst;
  final bool submenuAnchorIsLast;
  final ExpressiveSubmenuMetrics? submenuMetrics;

  @override
  RenderExpressiveMenuCascade createRenderObject(BuildContext context) =>
      RenderExpressiveMenuCascade(
        anchor: anchor,
        bounds: bounds,
        placement: placement,
        textDirection: textDirection,
        margin: margin,
        motion: motion,
        shadowColor: shadowColor,
        borderColor: borderColor,
        submenuAnchor: submenuAnchor,
        submenuAnchorIsFirst: submenuAnchorIsFirst,
        submenuAnchorIsLast: submenuAnchorIsLast,
        submenuMetrics: submenuMetrics,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderExpressiveMenuCascade renderObject,
  ) {
    renderObject
      ..anchor = anchor
      ..bounds = bounds
      ..placement = placement
      ..textDirection = textDirection
      ..margin = margin
      ..motion = motion
      ..shadowColor = shadowColor
      ..borderColor = borderColor
      ..submenuAnchor = submenuAnchor
      ..submenuAnchorIsFirst = submenuAnchorIsFirst
      ..submenuAnchorIsLast = submenuAnchorIsLast
      ..submenuMetrics = submenuMetrics;
  }
}

class _CascadeParentData extends ContainerBoxParentData<RenderBox> {}

class RenderExpressiveMenuCascade extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _CascadeParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _CascadeParentData> {
  RenderExpressiveMenuCascade({
    required this._anchor,
    required this._bounds,
    required this._placement,
    required this._textDirection,
    required this._margin,
    required this._motion,
    required this._shadowColor,
    required this._borderColor,
    this._submenuAnchor,
    this._submenuAnchorIsFirst = false,
    this._submenuAnchorIsLast = false,
    this._submenuMetrics,
  });

  /// 面板的最小高度（miuix 的 MinPopupHeight）。
  static const double minPanelHeight = 50;

  Rect _anchor;
  set anchor(Rect value) {
    if (value == _anchor) return;
    _anchor = value;
    markNeedsLayout();
  }

  Rect _bounds;
  set bounds(Rect value) {
    if (value == _bounds) return;
    _bounds = value;
    markNeedsLayout();
  }

  ExpressiveMenuPlacement _placement;
  set placement(ExpressiveMenuPlacement value) {
    if (value == _placement) return;
    _placement = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  double _margin;
  set margin(double value) {
    if (value == _margin) return;
    _margin = value;
    markNeedsLayout();
  }

  ExpressiveMenuMotion _motion;
  set motion(ExpressiveMenuMotion value) {
    if (value == _motion) return;
    if (attached) _motion.removeListener(markNeedsPaint);
    _motion = value;
    if (attached) _motion.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  Color _shadowColor;
  set shadowColor(Color value) {
    if (value == _shadowColor) return;
    _shadowColor = value;
    markNeedsPaint();
  }

  Color _borderColor;
  set borderColor(Color value) {
    if (value == _borderColor) return;
    _borderColor = value;
    markNeedsPaint();
  }

  Rect? _submenuAnchor;
  set submenuAnchor(Rect? value) {
    if (value == _submenuAnchor) return;
    _submenuAnchor = value;
    markNeedsLayout();
  }

  bool _submenuAnchorIsFirst;
  set submenuAnchorIsFirst(bool value) {
    if (value == _submenuAnchorIsFirst) return;
    _submenuAnchorIsFirst = value;
    markNeedsPaint();
  }

  bool _submenuAnchorIsLast;
  set submenuAnchorIsLast(bool value) {
    if (value == _submenuAnchorIsLast) return;
    _submenuAnchorIsLast = value;
    markNeedsPaint();
  }

  ExpressiveSubmenuMetrics? _submenuMetrics;
  set submenuMetrics(ExpressiveSubmenuMetrics? value) {
    if (identical(value, _submenuMetrics)) return;
    _submenuMetrics = value;
    markNeedsLayout();
  }

  /// 本次布局的主菜单落点；测试与调试用。
  ExpressiveMenuPlacementResult? get primaryPlacement => _primary;
  ExpressiveMenuPlacementResult? _primary;

  /// 二级菜单展开完的矩形与触发行矩形（浮层坐标）；没有二级菜单时为 null。
  Rect? get submenuRect => _submenuRect;
  Rect? _submenuRect;
  Rect? get submenuAnchorRect => _submenuAnchorRect;
  Rect? _submenuAnchorRect;

  final LayerHandle<TransformLayer> _primaryTransform =
      LayerHandle<TransformLayer>();
  final LayerHandle<ClipRSuperellipseLayer> _primaryClip =
      LayerHandle<ClipRSuperellipseLayer>();
  final LayerHandle<TransformLayer> _secondaryTransform =
      LayerHandle<TransformLayer>();
  final LayerHandle<ClipRSuperellipseLayer> _secondaryClip =
      LayerHandle<ClipRSuperellipseLayer>();

  RenderBox? get _secondaryChild =>
      firstChild == null ? null : childAfter(firstChild!);

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _CascadeParentData) {
      child.parentData = _CascadeParentData();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _motion.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _motion.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _primaryTransform.layer = null;
    _primaryClip.layer = null;
    _secondaryTransform.layer = null;
    _secondaryClip.layer = null;
    super.dispose();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() {
    size = constraints.biggest;
    final primary = firstChild;
    if (primary == null) {
      _primary = null;
      _submenuRect = null;
      return;
    }
    final maxHeight = math.max(minPanelHeight, _bounds.height - 2 * _margin);
    final maxWidth = math.max(0.0, _bounds.width);
    primary.layout(
      BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
      parentUsesSize: true,
    );
    final placed = placeExpressiveMenu(
      anchor: _anchor,
      size: primary.size,
      bounds: _bounds,
      placement: _placement,
      textDirection: _textDirection,
      margin: _margin,
    );
    _primary = placed;
    (primary.parentData! as _CascadeParentData).offset = placed.rect.topLeft;

    final secondary = _secondaryChild;
    final anchorInPrimary = _submenuAnchor;
    if (secondary == null || anchorInPrimary == null) {
      _submenuRect = null;
      _submenuAnchorRect = null;
      return;
    }
    // 二级菜单至少与主菜单同宽（miuix 的 probe 以主菜单宽为最小宽）。
    secondary.layout(
      BoxConstraints(
        minWidth: math.min(primary.size.width, maxWidth),
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      ),
      parentUsesSize: true,
    );
    final fullHeight = math.min(
      maxHeight,
      secondary.size.height + (_submenuMetrics?.collapsedDelta ?? 0),
    );
    final anchorRect = anchorInPrimary.shift(placed.rect.topLeft);
    _submenuAnchorRect = anchorRect;
    _submenuRect = placeExpressiveSubmenu(
      anchor: anchorRect,
      size: Size(secondary.size.width, fullHeight),
      bounds: _bounds,
      textDirection: _textDirection,
    );
  }

  /// 以 [pivot] 为中心缩放 [scale]，再平移 [translation]（先平移后缩放）。
  static Matrix4 _scaleAbout(Offset pivot, double scale, Offset translation) =>
      Matrix4.diagonal3Values(scale, scale, 1)..setTranslationRaw(
        pivot.dx * (1 - scale) + scale * translation.dx,
        pivot.dy * (1 - scale) + scale * translation.dy,
        0,
      );

  Matrix4 _primaryMatrix(ExpressiveMenuPlacementResult placed) => _scaleAbout(
    placed.pivot,
    _motion.enterScale * _motion.primaryScale,
    placed.rect.topLeft,
  );

  /// 二级菜单内容此刻的左上角（浮层坐标）：随 expand 从触发行滑到落点。
  Offset _secondaryContentOffset() => Offset.lerp(
    _submenuAnchorRect!.topLeft,
    _submenuRect!.topLeft,
    _motion.expand.value,
  )!;

  Matrix4 _secondaryMatrix(ExpressiveMenuPlacementResult placed) =>
      _scaleAbout(placed.pivot, _motion.enterScale, _secondaryContentOffset());

  /// 二级菜单此刻的可见矩形（浮层坐标）：变形矩形与展开那一段的交集。
  Rect _secondaryVisibleRect(ExpressiveMenuPlacementResult placed) {
    final morph = lerpExpressiveRect(
      _submenuAnchorRect!,
      _submenuRect!,
      _motion.expand.value,
    );
    final union = placed.rect.expandToInclude(_submenuRect!);
    final band = expressiveMenuRevealBand(
      union.size,
      _motion.enter.value,
      placed.side,
    ).shift(union.topLeft);
    return morph.intersect(band);
  }

  ({double top, double bottom}) _secondaryRadii() {
    final f = _motion.expand.value.clamp(0.0, 1.0);
    final grown = kExpressiveMenuRadius * f;
    return (
      top: _submenuAnchorIsFirst ? kExpressiveMenuRadius : grown,
      bottom: _submenuAnchorIsLast ? kExpressiveMenuRadius : grown,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final placed = _primary;
    final primary = firstChild;
    final opacity = _motion.alpha.value.clamp(0.0, 1.0);
    if (placed == null ||
        primary == null ||
        _motion.enter.value <= 0 ||
        opacity <= 0) {
      _primaryTransform.layer = null;
      _primaryClip.layer = null;
      _secondaryTransform.layer = null;
      _secondaryClip.layer = null;
      return;
    }
    _primaryTransform.layer = context.pushTransform(
      needsCompositing,
      offset,
      _primaryMatrix(placed),
      (PaintingContext context, Offset offset) {
        final band = expressiveMenuRevealBand(
          primary.size,
          _motion.enter.value,
          placed.side,
        );
        if (band.isEmpty) {
          _primaryClip.layer = null;
          return;
        }
        final shape = expressiveMenuShape(band);
        _paintShadow(context.canvas, shape.shift(offset), opacity);
        _primaryClip.layer = context.pushClipRSuperellipse(
          needsCompositing,
          offset,
          band,
          shape,
          (PaintingContext context, Offset offset) =>
              context.paintChild(primary, offset),
          oldLayer: _primaryClip.layer,
        );
        _paintBorder(context.canvas, shape.shift(offset), opacity);
      },
      oldLayer: _primaryTransform.layer,
    );

    final secondary = _secondaryChild;
    if (secondary == null || _submenuRect == null) {
      _secondaryTransform.layer = null;
      _secondaryClip.layer = null;
      return;
    }
    final visible = _secondaryVisibleRect(placed);
    final contentOffset = _secondaryContentOffset();
    final radii = _secondaryRadii();
    final reveal = opacity * _motion.expand.value.clamp(0.0, 1.0);
    _secondaryTransform.layer = context.pushTransform(
      needsCompositing,
      offset,
      _scaleAbout(placed.pivot, _motion.enterScale, Offset.zero),
      (PaintingContext context, Offset offset) {
        if (visible.isEmpty) {
          _secondaryClip.layer = null;
          return;
        }
        final shape = expressiveMenuShape(
          visible,
          topRadius: radii.top,
          bottomRadius: radii.bottom,
        );
        _paintShadow(context.canvas, shape.shift(offset), reveal);
        _secondaryClip.layer = context.pushClipRSuperellipse(
          needsCompositing,
          offset,
          visible,
          shape,
          (PaintingContext context, Offset offset) =>
              context.paintChild(secondary, offset + contentOffset),
          oldLayer: _secondaryClip.layer,
        );
        _paintBorder(context.canvas, shape.shift(offset), reveal);
      },
      oldLayer: _secondaryTransform.layer,
    );
  }

  /// 只画在形状外侧的投影（底色半透明，普通投影会从底下透出来压暗面板）。
  void _paintShadow(Canvas canvas, RSuperellipse shape, double opacity) {
    final color = _shadowColor.withValues(alpha: _shadowColor.a * opacity);
    if (color.a == 0) return;
    const blur = OuterShadowPainter.blur;
    const shadowOffset = OuterShadowPainter.offset;
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(shape.outerRect.inflate(blur * 2 + shadowOffset.distance))
      ..addRSuperellipse(shape);
    canvas
      ..save()
      ..clipPath(outside)
      ..drawRSuperellipse(
        shape.shift(shadowOffset),
        Paint()
          ..color = color
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            Shadow.convertRadiusToSigma(blur),
          ),
      )
      ..restore();
  }

  /// 沿形状内侧的 1dp 细描边。
  void _paintBorder(Canvas canvas, RSuperellipse shape, double opacity) {
    final color = _borderColor.withValues(alpha: _borderColor.a * opacity);
    if (color.a == 0 || shape.width <= 1 || shape.height <= 1) return;
    canvas.drawRSuperellipse(
      shape.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color,
    );
  }

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final placed = _primary;
    final primary = firstChild;
    if (placed == null || primary == null || _motion.enter.value <= 0) {
      return false;
    }
    final secondary = _secondaryChild;
    if (secondary != null && _submenuRect != null) {
      final visible = _secondaryVisibleRect(placed);
      final hit = result.addWithPaintTransform(
        transform: _scaleAbout(placed.pivot, _motion.enterScale, Offset.zero),
        position: position,
        hitTest: (BoxHitTestResult result, Offset position) {
          if (!visible.contains(position)) return false;
          final contentOffset = _secondaryContentOffset();
          return result.addWithPaintOffset(
            offset: contentOffset,
            position: position,
            hitTest: (BoxHitTestResult result, Offset position) =>
                secondary.hitTest(result, position: position),
          );
        },
      );
      if (hit) return true;
    }
    return result.addWithPaintTransform(
      transform: _primaryMatrix(placed),
      position: position,
      hitTest: (BoxHitTestResult result, Offset position) {
        final band = expressiveMenuRevealBand(
          primary.size,
          _motion.enter.value,
          placed.side,
        );
        if (!band.contains(position)) return false;
        return primary.hitTest(result, position: position);
      },
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final placed = _primary;
    if (placed == null) return;
    if (child == firstChild) {
      transform.multiply(_primaryMatrix(placed));
    } else if (_submenuRect != null) {
      transform.multiply(_secondaryMatrix(placed));
    }
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) {
    // 本盒坐标（浮层坐标）下的裁切范围，语义树再经 applyPaintTransform 换算。
    final placed = _primary;
    if (placed == null) return null;
    if (child == firstChild) return placed.rect;
    final rect = _submenuRect;
    if (rect == null) return null;
    return lerpExpressiveRect(_submenuAnchorRect!, rect, _motion.expand.value);
  }
}

/// 两个数之间按 [t] 插值（供标题行等在变形时使用）。
double lerpExpressiveValue(double a, double b, double t) =>
    lerpDouble(a, b, t)!;
