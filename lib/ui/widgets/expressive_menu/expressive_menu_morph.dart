import 'dart:math' as math;
import 'dart:ui' show ImageFilter, TileMode, lerpDouble;

import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'expressive_menu_layout.dart';
import 'expressive_menu_surface.dart';

/// 按钮长成菜单（容器变换）的动效进度，参照 NexioSchedule 顶栏“更多”的
/// LiquidGlassDropdownMenu：触发按钮与菜单面板是同一块玻璃。
///
/// 三条彼此解耦的进度（都不夹到 0…1，保留弹簧的过冲）：
/// - [fraction]：尺寸，从触发按钮的圆长成面板。展开为欠阻尼弹簧
///   （阻尼比 0.77、刚度 220，末尾约 2% 的过冲回弹），收起为更硬的弹簧
///   （0.85、650）。
/// - [origin]：锚点迁移，比尺寸更快到 1（0.77、420）：先滑向面板中心再长大；
///   收起用 340ms 的 Cubic(0, 0, 0, 1)，它跑完即收起结束。
/// - 收起回弹：一条单独的欠阻尼弹簧（0.52、220）从 1 回到 0，越过 0 的那段
///   （[settlePulse]）让收回的玻璃沿收回方向冲过头一点再弹回。
///
/// 状态（[status]）与 AnimationController 同义：展开中 forward、展开完 completed、
/// 收起中 reverse、收起完 dismissed，经 [onStatusChanged] 通知锚点。
class ExpressiveMenuMorphMotion extends ChangeNotifier {
  ExpressiveMenuMorphMotion({
    required TickerProvider vsync,
    required this.onStatusChanged,
  }) : _fraction = AnimationController.unbounded(vsync: vsync),
       _origin = AnimationController.unbounded(vsync: vsync),
       _settle = AnimationController.unbounded(vsync: vsync) {
    _fraction.addListener(notifyListeners);
    _origin.addListener(notifyListeners);
    _settle.addListener(notifyListeners);
  }

  static final SpringDescription openSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 220, ratio: 0.77);
  static final SpringDescription openOriginSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 420, ratio: 0.77);
  static final SpringDescription closeSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 650, ratio: 0.85);
  static final SpringDescription settleSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 220, ratio: 0.52);
  static const Duration closeOriginDuration = Duration(milliseconds: 340);
  static const Curve closeOriginCurve = Cubic(0, 0, 0, 1);

  /// 内容在形变中途最模糊时的 sigma。
  static const double maxContentBlurSigma = 3;

  static const Tolerance _tolerance = Tolerance(distance: 1e-4, velocity: 1e-3);

  final ValueChanged<AnimationStatus> onStatusChanged;
  final AnimationController _fraction;
  final AnimationController _origin;
  final AnimationController _settle;

  AnimationStatus get status => _status;
  AnimationStatus _status = AnimationStatus.dismissed;

  double get fraction => _fraction.value;
  double get origin => _origin.value;

  /// 收起回弹越过终点的量（0 到约 0.15）。
  double get settlePulse => math.max(0, -_settle.value);

  bool get isAnimating =>
      _fraction.isAnimating || _origin.isAnimating || _settle.isAnimating;

  /// 玻璃表面（底色、描边、投影、背景模糊）的显现：f × 5 饱和，出现早、
  /// 消失晚，小圆刚离开按钮就已是玻璃。
  late final Animation<double> surfaceReveal = _MotionValue(
    _fraction,
    () => (fraction * 5).clamp(0.0, 1.0),
  );

  /// 触发图标的不透明度：展开时 f 到 0.4 前就淡完；收起时系数更小，图标更早
  /// 回来，玻璃缩回按钮时它已在原处。
  late final Animation<double> triggerOpacity = _MotionValue(
    _fraction,
    () =>
        1 -
        (fraction * (_status == AnimationStatus.reverse ? 1.7 : 2.5)).clamp(
          0.0,
          1.0,
        ),
  );

  /// 内容的可见窗口：f < 0.3 全隐、f > 0.7 全显。
  double get contentOpacity => ((fraction - 0.3) / 0.4).clamp(0.0, 1.0);

  /// 内容模糊：清晰 → 中途最模糊 → 清晰。
  double get contentBlurSigma =>
      maxContentBlurSigma * (1 - (2 * fraction - 1).abs()).clamp(0.0, 1.0);

  void _setStatus(AnimationStatus value) {
    if (value == _status) return;
    _status = value;
    onStatusChanged(value);
  }

  /// 从当前进度与速度展开（收起途中重新展开时接着当前的速度）。
  void open() {
    _setStatus(AnimationStatus.forward);
    // 回弹量归零（值 1 的越界部分为 0），也停下收起时那条回弹。
    _settle.value = 1;
    _origin.animateWith(
      SpringSimulation(
        openOriginSpring,
        _origin.value,
        1,
        _origin.velocity,
        tolerance: _tolerance,
      ),
    );
    _fraction
        .animateWith(
          SpringSimulation(
            openSpring,
            _fraction.value,
            1,
            _fraction.velocity,
            tolerance: _tolerance,
          ),
        )
        .then((_) {
          if (_status != AnimationStatus.forward) return;
          // 弹簧停在容差内而不是正好 1：落到终点，面板不再需要变换图层。
          _fraction.value = 1;
          _origin.value = 1;
          _setStatus(AnimationStatus.completed);
        });
  }

  /// 换到新位置（右键菜单换点打开）：从按钮态重新展开。
  void restart() {
    _fraction.value = 0;
    _origin.value = 0;
    open();
  }

  /// 收起；锚点迁移的 tween 跑完即结束（与参照实现相同，尺寸弹簧此时已贴近 0）。
  void close() {
    _setStatus(AnimationStatus.reverse);
    _settle.value = 1;
    _settle.animateWith(
      SpringSimulation(settleSpring, 1, 0, 0, tolerance: _tolerance),
    );
    _fraction.animateWith(
      SpringSimulation(
        closeSpring,
        _fraction.value,
        0,
        _fraction.velocity,
        tolerance: _tolerance,
      ),
    );
    _origin
        .animateTo(0, duration: closeOriginDuration, curve: closeOriginCurve)
        .then((_) {
          if (_status != AnimationStatus.reverse) return;
          _snap(0);
          _setStatus(AnimationStatus.dismissed);
        });
  }

  /// 减少动画：瞬时展开 / 收起。
  void snapOpen() {
    _snap(1);
    _setStatus(AnimationStatus.completed);
  }

  void snapClosed() {
    _snap(0);
    _setStatus(AnimationStatus.dismissed);
  }

  void _snap(double value) {
    _fraction.value = value;
    _origin.value = value;
    // 展开态 1（越界部分为 0）、收起态 0：都没有回弹。
    _settle.value = value;
  }

  @override
  void dispose() {
    _fraction.dispose();
    _origin.dispose();
    _settle.dispose();
    super.dispose();
  }
}

/// 由某条进度换算出的值，监听与状态都转给 [parent]。
class _MotionValue extends Animation<double>
    with AnimationWithParentMixin<double> {
  _MotionValue(this.parent, this._compute);

  @override
  final Animation<double> parent;
  final double Function() _compute;

  @override
  double get value => _compute();
}

enum ExpressiveMenuMorphSlot { surface, content }

/// 按钮长成菜单的布局与绘制。
///
/// 输入：触发按钮的圆所在的矩形 [seed]（右键菜单为指针处的零尺寸矩形）、
/// 可用区域、对齐方式、阅读方向与 [motion]。输出：铺满浮层的盒子。
///
/// - 面板（内容按最终尺寸布局一次）盖住触发按钮：贴着按钮的那个角与按钮
///   的同一个角对齐（end 对齐时为右上角），下方放不下时改为下角对齐向上长，
///   再夹进安全区。
/// - 每帧按 [ExpressiveMenuMorphMotion] 算出玻璃此刻的矩形：尺寸在按钮与面板
///   之间插值；位置在“贴角生长”与“以面板中心生长”之间按锚点迁移进度插值；
///   收起回弹沿贴角方向外推。玻璃表面 [ExpressiveMenuMorphSlot.surface] 按这个
///   矩形重新布局（只有一层空玻璃，代价很小），圆角 28 由 Skia 按尺寸自动收成
///   正圆 / 胶囊。
/// - 内容 [ExpressiveMenuMorphSlot.content] 不重新布局：以玻璃中心为中心、按
///   “玻璃宽 / 面板宽”等比缩放，裁在玻璃的圆角矩形里，叠上淡入与中途模糊；
///   命中测试走同一个变换。展开结束后不再有任何变换或裁切图层。
class ExpressiveMenuMorph
    extends
        SlottedMultiChildRenderObjectWidget<
          ExpressiveMenuMorphSlot,
          RenderBox
        > {
  const ExpressiveMenuMorph({
    super.key,
    required this.seed,
    required this.bounds,
    required this.placement,
    required this.textDirection,
    required this.motion,
    required this.surface,
    required this.content,
  });

  /// 收起回弹的最大位移（乘以 [ExpressiveMenuMorphMotion.settlePulse]）。
  static const double settleDistance = 12;

  final Rect seed;
  final Rect bounds;
  final ExpressiveMenuPlacement placement;
  final TextDirection textDirection;
  final ExpressiveMenuMorphMotion motion;
  final Widget surface;
  final Widget content;

  @override
  Iterable<ExpressiveMenuMorphSlot> get slots => ExpressiveMenuMorphSlot.values;

  @override
  Widget? childForSlot(ExpressiveMenuMorphSlot slot) => switch (slot) {
    ExpressiveMenuMorphSlot.surface => surface,
    ExpressiveMenuMorphSlot.content => content,
  };

  @override
  RenderExpressiveMenuMorph createRenderObject(BuildContext context) =>
      RenderExpressiveMenuMorph(
        seed: seed,
        bounds: bounds,
        placement: placement,
        textDirection: textDirection,
        motion: motion,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderExpressiveMenuMorph renderObject,
  ) {
    renderObject
      ..seed = seed
      ..bounds = bounds
      ..placement = placement
      ..textDirection = textDirection
      ..motion = motion;
  }
}

class RenderExpressiveMenuMorph extends RenderBox
    with SlottedContainerRenderObjectMixin<ExpressiveMenuMorphSlot, RenderBox> {
  RenderExpressiveMenuMorph({
    required this._seed,
    required this._bounds,
    required this._placement,
    required this._textDirection,
    required this._motion,
  });

  Rect get seed => _seed;
  Rect _seed;
  set seed(Rect value) {
    if (value == _seed) return;
    _seed = value;
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

  ExpressiveMenuMorphMotion get motion => _motion;
  ExpressiveMenuMorphMotion _motion;
  set motion(ExpressiveMenuMorphMotion value) {
    if (value == _motion) return;
    if (attached) _motion.removeListener(markNeedsLayout);
    _motion = value;
    if (attached) _motion.addListener(markNeedsLayout);
    markNeedsLayout();
  }

  RenderBox? get _surface => childForSlot(ExpressiveMenuMorphSlot.surface);
  RenderBox? get _content => childForSlot(ExpressiveMenuMorphSlot.content);

  /// 面板展开后的位置（按内容尺寸）。
  Rect get targetRect => _target;
  Rect _target = Rect.zero;

  /// 玻璃此刻的矩形；测试与调试用。
  Rect get morphRect => _box;
  Rect _box = Rect.zero;

  /// 面板是否向下长（贴着按钮的上角）。
  bool get opensDown => _opensDown;
  bool _opensDown = true;

  /// 贴着按钮的那个角相对面板中心的方向（x：结束边为 +1；y：上角为 −1）。
  double _cornerX = 1;
  double _cornerY = -1;

  final LayerHandle<ClipRRectLayer> _clipLayer = LayerHandle<ClipRRectLayer>();
  final LayerHandle<OpacityLayer> _opacityLayer = LayerHandle<OpacityLayer>();
  final LayerHandle<ImageFilterLayer> _filterLayer =
      LayerHandle<ImageFilterLayer>();
  final LayerHandle<TransformLayer> _transformLayer =
      LayerHandle<TransformLayer>();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _motion.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _motion.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void dispose() {
    _clearLayers();
    super.dispose();
  }

  void _clearLayers() {
    _clipLayer.layer = null;
    _opacityLayer.layer = null;
    _filterLayer.layer = null;
    _transformLayer.layer = null;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() {
    size = constraints.biggest;
    final content = _content;
    if (content == null) return;
    // 内容只在自身或可用区域变化时重新布局；逐帧的形变不会让它重排。
    content.layout(
      BoxConstraints.loose(
        Size(math.max(0, bounds.width), math.max(0, bounds.height)),
      ),
      parentUsesSize: true,
    );
    _layoutTarget(content.size);
    _box = _morphBox();
    (content.parentData! as BoxParentData).offset = _target.topLeft;
    final surface = _surface;
    if (surface != null) {
      surface.layout(BoxConstraints.tight(_box.size));
      (surface.parentData! as BoxParentData).offset = _box.topLeft;
    }
  }

  void _layoutTarget(Size menu) {
    // start 在 LTR 下贴左缘、RTL 下贴右缘；end 相反。
    final alignLeft =
        (placement == ExpressiveMenuPlacement.start) ==
        (textDirection == TextDirection.ltr);
    var x = alignLeft ? seed.left : seed.right - menu.width;
    final down = seed.top;
    final up = seed.bottom - menu.height;
    double y;
    if (down + menu.height <= bounds.bottom) {
      y = down;
      _opensDown = true;
    } else if (up >= bounds.top) {
      y = up;
      _opensDown = false;
    } else {
      // 上下都放不下：选空间更大的一侧，再夹回安全区。
      _opensDown = bounds.bottom - seed.top >= seed.bottom - bounds.top;
      y = _opensDown ? down : up;
    }
    x = x.clamp(bounds.left, math.max(bounds.left, bounds.right - menu.width));
    y = y.clamp(bounds.top, math.max(bounds.top, bounds.bottom - menu.height));
    _target = Rect.fromLTWH(x, y, menu.width, menu.height);
    _cornerX = alignLeft ? -1 : 1;
    _cornerY = _opensDown ? -1 : 1;
  }

  Offset _cornerOf(Rect rect) => Offset(
    _cornerX > 0 ? rect.right : rect.left,
    _cornerY > 0 ? rect.bottom : rect.top,
  );

  Rect _morphBox() {
    // 展开结束直接取面板矩形：插值换算会差出浮点尾数，留下多余的变换图层。
    if (_settled) return _target;
    final f = motion.fraction;
    final width = math.max(0.0, lerpDouble(seed.width, _target.width, f)!);
    final height = math.max(0.0, lerpDouble(seed.height, _target.height, f)!);
    // 贴角生长：玻璃的这个角从按钮的角移到面板的角（多数时候两者重合）。
    final corner = Offset.lerp(_cornerOf(seed), _cornerOf(_target), f)!;
    final cornerAnchored =
        corner - Offset(_cornerX * width / 2, _cornerY * height / 2);
    // 锚点迁移：迁移进度跑得比尺寸快，玻璃先滑向面板中心、再在那里长大。
    // f = 1 时两种位置重合，迁移进度不影响终点。
    var center = Offset.lerp(cornerAnchored, _target.center, motion.origin)!;
    center +=
        Offset(_cornerX, _cornerY) *
        (motion.settlePulse * ExpressiveMenuMorph.settleDistance);
    return Rect.fromCenter(center: center, width: width, height: height);
  }

  /// 展开结束：玻璃与面板重合，内容不需要任何变换（f = 1 时迁移进度不影响位置）。
  bool get _settled => motion.fraction == 1 && motion.settlePulse == 0;

  RRect _clipRRect() {
    final radius = math.min(
      ExpressiveMenuSurface.radius,
      math.min(_box.width, _box.height) / 2,
    );
    return RRect.fromRectAndRadius(_box, Radius.circular(radius));
  }

  /// 内容自身坐标 → 本盒坐标：以玻璃中心为中心，按玻璃宽 / 面板宽等比缩放
  /// （高度方向同一倍率，保留弹簧过冲时的放大）。
  Matrix4 _contentTransform(RenderBox content) {
    final menu = content.size;
    final scale = menu.width > 0 ? _box.width / menu.width : 1.0;
    final center = _box.center;
    return Matrix4.diagonal3Values(scale, scale, 1)..setTranslationRaw(
      center.dx - scale * menu.width / 2,
      center.dy - scale * menu.height / 2,
      0,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final surface = _surface;
    if (surface != null) {
      context.paintChild(
        surface,
        offset + (surface.parentData! as BoxParentData).offset,
      );
    }
    final content = _content;
    if (content == null) return;
    final opacity = motion.contentOpacity;
    if (opacity <= 0) {
      _clearLayers();
      return;
    }
    if (_settled) {
      _clearLayers();
      context.paintChild(content, offset + _target.topLeft);
      return;
    }
    _clipLayer.layer = context.pushClipRRect(
      needsCompositing,
      offset,
      _box,
      _clipRRect(),
      (PaintingContext context, Offset offset) =>
          _paintFaded(context, offset, content, opacity),
      oldLayer: _clipLayer.layer,
    );
  }

  void _paintFaded(
    PaintingContext context,
    Offset offset,
    RenderBox content,
    double opacity,
  ) {
    if (opacity >= 1) {
      _opacityLayer.layer = null;
      _paintBlurred(context, offset, content);
      return;
    }
    _opacityLayer.layer = context.pushOpacity(
      offset,
      Color.getAlphaFromOpacity(opacity),
      (PaintingContext context, Offset offset) =>
          _paintBlurred(context, offset, content),
      oldLayer: _opacityLayer.layer,
    );
  }

  void _paintBlurred(
    PaintingContext context,
    Offset offset,
    RenderBox content,
  ) {
    final sigma = motion.contentBlurSigma;
    if (sigma < 0.05) {
      _filterLayer.layer = null;
      _paintTransformed(context, offset, content);
      return;
    }
    final layer = _filterLayer.layer ??= ImageFilterLayer();
    layer
      ..imageFilter = ImageFilter.blur(
        sigmaX: sigma,
        sigmaY: sigma,
        tileMode: TileMode.decal,
      )
      ..offset = offset;
    context.pushLayer(
      layer,
      (PaintingContext context, Offset offset) =>
          _paintTransformed(context, offset, content),
      Offset.zero,
    );
  }

  void _paintTransformed(
    PaintingContext context,
    Offset offset,
    RenderBox content,
  ) {
    _transformLayer.layer = context.pushTransform(
      needsCompositing,
      offset,
      _contentTransform(content),
      (PaintingContext context, Offset offset) =>
          context.paintChild(content, offset),
      oldLayer: _transformLayer.layer,
    );
  }

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // 玻璃表面不接收点按（由调用方包 IgnorePointer）；只有裁切范围里的内容
    // 可点，范围外的点按落到菜单外（关闭菜单）。
    final content = _content;
    if (content == null || !_clipRRect().contains(position)) return false;
    return result.addWithPaintTransform(
      transform: _contentTransform(content),
      position: position,
      hitTest: (BoxHitTestResult result, Offset position) =>
          content.hitTest(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (child == _content) {
      transform.multiply(_contentTransform(child));
      return;
    }
    final offset = (child.parentData! as BoxParentData).offset;
    transform.multiply(Matrix4.translationValues(offset.dx, offset.dy, 0));
  }
}
