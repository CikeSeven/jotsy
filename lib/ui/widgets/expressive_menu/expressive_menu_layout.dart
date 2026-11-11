import 'dart:math' as math;
import 'dart:ui' show ImageFilter, TileMode, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'expressive_menu_geometry.dart';
import 'expressive_menu_motion.dart';
import 'expressive_menu_row.dart';

export 'expressive_menu_geometry.dart'
    show ExpressiveMenuPlacement, ExpressiveMenuSide;

/// 菜单可以占用的区域：扣掉系统栏、键盘与显示特征后的安全区。
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

/// 主菜单与二级菜单的定位与形变（一个 render object 完成，不会有一帧从错误的
/// 角长出来）。
///
/// - 输入：锚点矩形与安全区（浮层坐标）；[cover] 为 true 时面板盖住触发控件、
///   从起点 [seed] 长出来（[placeCoveringMenu]），否则放在锚点旁 [gap] 处、
///   从贴着锚点那个角上的小圆长出来（[placeOutsideMenu]）；动效 [motion]；
///   二级菜单打开时另有触发行的胶囊 [submenuPill]（主菜单内容坐标，按下时取定）。
/// - 子节点依次为：主菜单玻璃、主菜单内容，以及（二级菜单打开时）二级菜单
///   玻璃、二级菜单内容。内容按最终尺寸布局一次；玻璃按面板（或主菜单与
///   二级菜单的并集）外扩 [overshootRoom] 布局，裁成此刻的面板形状。
/// - 绘制（NexioSchedule 的 ListPopupContent）：面板矩形见
///   [expressiveMenuMorphRect]；先画只在外侧的环形投影，再裁成 22 圆角的超椭圆
///   画玻璃，内容以“矩形宽 / 面板宽”等比缩放到矩形中心、按 contentAlpha 淡入、
///   中途模糊；最后沿形状画细描边。图标按钮收起时整组沿收回方向回弹。
///   二级菜单打开时主菜单以贴着起点的角缩到 0.95；二级菜单从触发行的胶囊
///   （16 圆角）插值到落点（22 圆角），内容随之从胶囊滑到落点。按住时被按的
///   那块面板有按压形变（[ExpressiveMenuJelly]）。
/// - 命中测试与绘制同一套变换，只有看得见的形状内才命中；形状外的点按穿过
///   本盒，由外层 TapRegion 当作点外部处理。
class ExpressiveMenuCascade extends MultiChildRenderObjectWidget {
  const ExpressiveMenuCascade({
    super.key,
    required this.anchor,
    required this.bounds,
    required this.cover,
    required this.placement,
    required this.textDirection,
    required this.motion,
    required this.shadowColor,
    required this.borderColor,
    required super.children,
    this.seed,
    this.gap = 0,
    this.submenuPill,
  }) : assert(children.length == 2 || children.length == 4),
       assert(!cover || seed != null);

  /// 玻璃比面板每边多出的余量，容纳弹簧过冲与锚点迁移。
  static const double overshootRoom = 14;

  final Rect anchor;
  final Rect bounds;
  final bool cover;
  final Rect? seed;
  final double gap;
  final ExpressiveMenuPlacement placement;
  final TextDirection textDirection;
  final ExpressiveMenuMotion motion;

  /// 投影与描边在完全显现时的颜色。
  final Color shadowColor;
  final Color borderColor;
  final Rect? submenuPill;

  @override
  RenderExpressiveMenuCascade createRenderObject(BuildContext context) =>
      RenderExpressiveMenuCascade(
        anchor: anchor,
        bounds: bounds,
        cover: cover,
        seed: seed,
        gap: gap,
        placement: placement,
        textDirection: textDirection,
        motion: motion,
        shadowColor: shadowColor,
        borderColor: borderColor,
        submenuPill: submenuPill,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderExpressiveMenuCascade renderObject,
  ) {
    renderObject
      ..anchor = anchor
      ..bounds = bounds
      ..cover = cover
      ..seed = seed
      ..gap = gap
      ..placement = placement
      ..textDirection = textDirection
      ..motion = motion
      ..shadowColor = shadowColor
      ..borderColor = borderColor
      ..submenuPill = submenuPill;
  }
}

class _CascadeParentData extends ContainerBoxParentData<RenderBox> {}

/// 一块面板这一帧的绘制参数（浮层坐标）。
class _PanelFrame {
  const _PanelFrame({
    required this.transform,
    required this.shape,
    required this.surfaceOffset,
    required this.contentTransform,
    required this.shadowOpacity,
  });

  /// 整块面板（投影、玻璃、内容、描边）的变换。
  final Matrix4 transform;

  /// 此刻的形状（在 [transform] 之内）。
  final RSuperellipse shape;
  final Offset surfaceOffset;

  /// 内容从布局位置到此刻位置的变换（在 [transform] 之内，含布局偏移）。
  final Matrix4 contentTransform;
  final double shadowOpacity;
}

class RenderExpressiveMenuCascade extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _CascadeParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _CascadeParentData> {
  RenderExpressiveMenuCascade({
    required this._anchor,
    required this._bounds,
    required this._cover,
    required this._seed,
    required this._gap,
    required this._placement,
    required this._textDirection,
    required this._motion,
    required this._shadowColor,
    required this._borderColor,
    required this._submenuPill,
  });

  /// 面板的最小高度（miuix 的 MinPopupHeight）。
  static const double minPanelHeight = 50;

  /// 环形投影：外扩 2、模糊半径 12（NexioSchedule 的 popupPanelShadow）。
  static const double shadowSpread = 2;
  static const double shadowBlur = 12;

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

  bool _cover;
  set cover(bool value) {
    if (value == _cover) return;
    _cover = value;
    markNeedsLayout();
  }

  Rect? _seed;
  set seed(Rect? value) {
    if (value == _seed) return;
    _seed = value;
    markNeedsLayout();
  }

  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
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

  Rect? _submenuPill;
  set submenuPill(Rect? value) {
    if (value == _submenuPill) return;
    _submenuPill = value;
    markNeedsLayout();
  }

  /// 本次布局的主菜单落点；测试与调试用。
  ExpressiveMenuPlacementResult? get primaryPlacement => _primary;
  ExpressiveMenuPlacementResult? _primary;

  /// 二级菜单展开完的矩形与触发行胶囊（浮层坐标）；没有二级菜单时为 null。
  Rect? get submenuRect => _submenuRect;
  Rect? _submenuRect;
  Rect? get submenuPillRect => _pillRect;
  Rect? _pillRect;
  Rect _union = Rect.zero;

  final LayerHandle<TransformLayer> _primaryLayer =
      LayerHandle<TransformLayer>();
  final LayerHandle<ClipRSuperellipseLayer> _primaryClip =
      LayerHandle<ClipRSuperellipseLayer>();
  final LayerHandle<OpacityLayer> _primaryOpacity = LayerHandle<OpacityLayer>();
  final LayerHandle<ImageFilterLayer> _primaryBlur =
      LayerHandle<ImageFilterLayer>();
  final LayerHandle<TransformLayer> _primaryContent =
      LayerHandle<TransformLayer>();
  final LayerHandle<TransformLayer> _secondaryLayer =
      LayerHandle<TransformLayer>();
  final LayerHandle<ClipRSuperellipseLayer> _secondaryClip =
      LayerHandle<ClipRSuperellipseLayer>();
  final LayerHandle<OpacityLayer> _secondaryOpacity =
      LayerHandle<OpacityLayer>();
  final LayerHandle<ImageFilterLayer> _secondaryBlur =
      LayerHandle<ImageFilterLayer>();
  final LayerHandle<TransformLayer> _secondaryContent =
      LayerHandle<TransformLayer>();

  List<RenderBox> get _children => getChildrenAsList();

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

  void _clearLayers() {
    for (final handle in <LayerHandle<Layer>>[
      _primaryLayer,
      _primaryClip,
      _primaryOpacity,
      _primaryBlur,
      _primaryContent,
      _secondaryLayer,
      _secondaryClip,
      _secondaryOpacity,
      _secondaryBlur,
      _secondaryContent,
    ]) {
      handle.layer = null;
    }
  }

  @override
  void dispose() {
    _clearLayers();
    super.dispose();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() {
    size = constraints.biggest;
    final children = _children;
    if (children.length < 2) {
      _primary = null;
      _submenuRect = null;
      return;
    }
    final room = ExpressiveMenuCascade.overshootRoom;
    final verticalReserve = _cover ? 0.0 : 2 * _gap;
    final horizontalReserve = _cover ? 0.0 : 2 * kExpressiveMenuScreenMargin;
    final maxHeight = math.max(
      minPanelHeight,
      _bounds.height - verticalReserve,
    );
    final maxWidth = math.max(0.0, _bounds.width - horizontalReserve);
    final content = children[1];
    content.layout(
      BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
      parentUsesSize: true,
    );
    final placed = _cover
        ? placeCoveringMenu(
            seed: _seed!,
            size: content.size,
            bounds: _bounds,
            placement: _placement,
            textDirection: _textDirection,
          )
        : placeOutsideMenu(
            anchor: _anchor,
            size: content.size,
            bounds: _bounds,
            placement: _placement,
            textDirection: _textDirection,
            gap: _gap,
          );
    _primary = placed;
    children[0].layout(
      BoxConstraints.tight(placed.rect.size + Offset(room * 2, room * 2)),
    );

    final pill = _submenuPill;
    if (children.length < 4 || pill == null) {
      _submenuRect = null;
      _pillRect = null;
      _union = placed.rect;
      return;
    }
    final secondary = children[3];
    secondary.layout(
      BoxConstraints(
        minWidth: math.min(content.size.width, maxWidth),
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      ),
      parentUsesSize: true,
    );
    final pillRect = pill.shift(placed.rect.topLeft);
    _pillRect = pillRect;
    final submenu = placeExpressiveSubmenu(
      pill: pillRect,
      size: secondary.size,
      bounds: _bounds,
      textDirection: _textDirection,
      inset: ExpressiveMenuRowMetrics.inset,
    );
    _submenuRect = submenu;
    _union = placed.rect.expandToInclude(submenu);
    children[2].layout(
      BoxConstraints.tight(_union.size + Offset(room * 2, room * 2)),
    );
  }

  /// 以 [pivot] 为中心缩放 [scale]。
  static Matrix4 _scaleAbout(Offset pivot, double scale) =>
      Matrix4.diagonal3Values(scale, scale, 1)
        ..setTranslationRaw(pivot.dx * (1 - scale), pivot.dy * (1 - scale), 0);

  /// 把 [local]（以 [rect] 左上角为原点、[rect] 大小的形变）移到 [rect] 上。
  static Matrix4 _at(Rect rect, Matrix4 local) =>
      Matrix4.translationValues(rect.left, rect.top, 0)
        ..multiply(local)
        ..multiply(Matrix4.translationValues(-rect.left, -rect.top, 0));

  /// 图标按钮收起时的回弹位移：沿收回方向（贴着起点的那个角）。
  Offset _settleOffset(ExpressiveMenuPlacementResult placed) {
    final b = _motion.settlePulse * ExpressiveMenuMotion.settleDistance;
    if (b == 0) return Offset.zero;
    return Offset(
      placed.alignRight ? b : -b,
      placed.side == ExpressiveMenuSide.above ? b : -b,
    );
  }

  /// 此刻的主菜单矩形（浮层坐标）。
  Rect _primaryRect(ExpressiveMenuPlacementResult placed) {
    final natural = placed.rect;
    return expressiveMenuMorphRect(
      size: natural.size,
      seed: placed.seed.shift(-natural.topLeft),
      fraction: _motion.fraction.value,
      origin: _motion.origin.value,
      side: placed.side,
      alignRight: placed.alignRight,
    ).shift(natural.topLeft);
  }

  /// 面板布局矩形 → 此刻矩形：以宽度比等比缩放到此刻矩形的中心。
  static Matrix4 _morphTransform(Rect natural, Rect current) {
    final s = natural.width > 0 ? current.width / natural.width : 1.0;
    return Matrix4.diagonal3Values(s, s, 1)..setTranslationRaw(
      current.center.dx - s * natural.center.dx,
      current.center.dy - s * natural.center.dy,
      0,
    );
  }

  _PanelFrame? _primaryFrame() {
    final placed = _primary;
    if (placed == null) return null;
    final room = ExpressiveMenuCascade.overshootRoom;
    final rect = _primaryRect(placed);
    final group = Matrix4.translationValues(
      _settleOffset(placed).dx,
      _settleOffset(placed).dy,
      0,
    )..multiply(_scaleAbout(placed.pivot, _motion.primaryScale));
    final jelly = _motion.primaryJelly.transformFor(
      rect.size,
      _motion.fraction.value,
    );
    return _PanelFrame(
      transform: group..multiply(_at(rect, jelly)),
      shape: expressiveMenuShape(rect, kExpressiveMenuRadius),
      surfaceOffset: placed.rect.topLeft - const Offset(1, 1) * room,
      contentTransform: _morphTransform(placed.rect, rect)
        ..multiply(
          Matrix4.translationValues(placed.rect.left, placed.rect.top, 0),
        ),
      shadowOpacity: _motion.containerAlpha,
    );
  }

  _PanelFrame? _secondaryFrame() {
    final placed = _primary;
    final submenu = _submenuRect;
    final pill = _pillRect;
    if (placed == null || submenu == null || pill == null) return null;
    final room = ExpressiveMenuCascade.overshootRoom;
    final e = _motion.expand.value;
    final rect = lerpExpressiveRect(pill, submenu, e);
    const inset = ExpressiveMenuRowMetrics.inset;
    final contentOffset = Offset.lerp(
      pill.topLeft - const Offset(inset, inset),
      submenu.topLeft,
      e,
    )!;
    final settle = _settleOffset(placed);
    final group = Matrix4.translationValues(settle.dx, settle.dy, 0)
      ..multiply(_morphTransform(placed.rect, _primaryRect(placed)));
    final jelly = _motion.secondaryJelly.transformFor(
      rect.size,
      _motion.fraction.value,
    );
    return _PanelFrame(
      transform: group..multiply(_at(rect, jelly)),
      shape: expressiveMenuShape(
        rect,
        lerpDouble(kExpressiveMenuRowRadius, kExpressiveMenuRadius, e)!,
      ),
      surfaceOffset: _union.topLeft - const Offset(1, 1) * room,
      contentTransform: Matrix4.translationValues(
        contentOffset.dx,
        contentOffset.dy,
        0,
      ),
      shadowOpacity: _motion.containerAlpha * e.clamp(0.0, 1.0),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final children = _children;
    final primary = _primaryFrame();
    final containerAlpha = _motion.containerAlpha;
    final contentAlpha = _motion.contentAlpha;
    if (primary == null ||
        children.length < 2 ||
        (containerAlpha <= 0 && contentAlpha <= 0)) {
      _clearLayers();
      return;
    }
    _paintPanel(
      context,
      offset,
      primary,
      surface: children[0],
      content: children[1],
      layer: _primaryLayer,
      clip: _primaryClip,
      opacity: _primaryOpacity,
      blur: _primaryBlur,
      contentLayer: _primaryContent,
    );
    final secondary = _secondaryFrame();
    if (secondary == null || children.length < 4) {
      _secondaryLayer.layer = null;
      _secondaryClip.layer = null;
      _secondaryOpacity.layer = null;
      _secondaryBlur.layer = null;
      _secondaryContent.layer = null;
      return;
    }
    _paintPanel(
      context,
      offset,
      secondary,
      surface: children[2],
      content: children[3],
      layer: _secondaryLayer,
      clip: _secondaryClip,
      opacity: _secondaryOpacity,
      blur: _secondaryBlur,
      contentLayer: _secondaryContent,
    );
  }

  void _paintPanel(
    PaintingContext context,
    Offset offset,
    _PanelFrame frame, {
    required RenderBox surface,
    required RenderBox content,
    required LayerHandle<TransformLayer> layer,
    required LayerHandle<ClipRSuperellipseLayer> clip,
    required LayerHandle<OpacityLayer> opacity,
    required LayerHandle<ImageFilterLayer> blur,
    required LayerHandle<TransformLayer> contentLayer,
  }) {
    final contentAlpha = _motion.contentAlpha;
    final sigma = _motion.contentBlurSigma;
    layer.layer = context.pushTransform(
      needsCompositing,
      offset,
      frame.transform,
      (PaintingContext context, Offset offset) {
        final shape = frame.shape;
        if (shape.width <= 0 || shape.height <= 0) {
          clip.layer = null;
          return;
        }
        _paintShadow(context.canvas, shape.shift(offset), frame.shadowOpacity);
        clip.layer = context.pushClipRSuperellipse(
          needsCompositing,
          offset,
          shape.outerRect,
          shape,
          (PaintingContext context, Offset offset) {
            context.paintChild(surface, offset + frame.surfaceOffset);
            if (contentAlpha <= 0) {
              opacity.layer = null;
              blur.layer = null;
              contentLayer.layer = null;
              return;
            }
            void paintContent(PaintingContext context, Offset offset) {
              contentLayer.layer = context.pushTransform(
                needsCompositing,
                offset,
                frame.contentTransform,
                (PaintingContext context, Offset offset) =>
                    context.paintChild(content, offset),
                oldLayer: contentLayer.layer,
              );
            }

            void paintBlurred(PaintingContext context, Offset offset) {
              if (sigma < 0.05) {
                blur.layer = null;
                paintContent(context, offset);
                return;
              }
              final layer = blur.layer ?? ImageFilterLayer();
              layer.imageFilter = ImageFilter.blur(
                sigmaX: sigma,
                sigmaY: sigma,
                tileMode: TileMode.decal,
              );
              blur.layer = layer;
              context.pushLayer(layer, paintContent, offset);
            }

            if (contentAlpha >= 1) {
              opacity.layer = null;
              paintBlurred(context, offset);
            } else {
              opacity.layer = context.pushOpacity(
                offset,
                (contentAlpha * 255).round(),
                paintBlurred,
                oldLayer: opacity.layer,
              );
            }
          },
          oldLayer: clip.layer,
        );
        _paintBorder(context.canvas, shape.shift(offset), frame.shadowOpacity);
      },
      oldLayer: layer.layer,
    );
  }

  /// 环形投影：外圈（外扩 [shadowSpread]）减去面板本身，再整体模糊。
  void _paintShadow(Canvas canvas, RSuperellipse shape, double opacity) {
    final s = opacity.clamp(0.0, 1.0);
    final color = _shadowColor.withValues(alpha: _shadowColor.a * s);
    if (color.a <= 0.002) return;
    final spread = shadowSpread * s;
    final radius = shape.tlRadiusX;
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addRSuperellipse(
        RSuperellipse.fromRectAndRadius(
          shape.outerRect.inflate(spread),
          Radius.circular(radius + spread),
        ),
      )
      ..addRSuperellipse(shape);
    canvas.drawPath(
      ring,
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          Shadow.convertRadiusToSigma(math.max(0.1, shadowBlur * s)),
        ),
    );
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
    final children = _children;
    if (children.length >= 4) {
      final secondary = _secondaryFrame();
      if (secondary != null &&
          _hitPanel(result, position, secondary, children[3])) {
        return true;
      }
    }
    final primary = _primaryFrame();
    if (primary == null || children.length < 2) return false;
    return _hitPanel(result, position, primary, children[1]);
  }

  bool _hitPanel(
    BoxHitTestResult result,
    Offset position,
    _PanelFrame frame,
    RenderBox content,
  ) => result.addWithPaintTransform(
    transform: frame.transform,
    position: position,
    hitTest: (BoxHitTestResult result, Offset position) {
      if (!frame.shape.contains(position)) return false;
      return result.addWithPaintTransform(
        transform: frame.contentTransform,
        position: position,
        hitTest: (BoxHitTestResult result, Offset position) =>
            content.hitTest(result, position: position),
      );
    },
  );

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final children = _children;
    final index = children.indexOf(child);
    final frame = index < 2 ? _primaryFrame() : _secondaryFrame();
    if (frame == null) return;
    transform.multiply(frame.transform);
    if (index.isOdd) {
      transform.multiply(frame.contentTransform);
    } else {
      transform.multiply(
        Matrix4.translationValues(
          frame.surfaceOffset.dx,
          frame.surfaceOffset.dy,
          0,
        ),
      );
    }
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) {
    final children = _children;
    final index = children.indexOf(child as RenderBox);
    final frame = index < 2 ? _primaryFrame() : _secondaryFrame();
    if (frame == null) return null;
    // 本盒坐标下的裁切范围，语义树再经 applyPaintTransform 换算到子节点。
    return MatrixUtils.transformRect(frame.transform, frame.shape.outerRect);
  }
}
