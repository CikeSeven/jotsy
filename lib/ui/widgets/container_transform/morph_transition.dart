import 'dart:ui' show ImageFilter;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'morph_landing.dart';

/// [MorphTransition] 的三个子节点。
enum MorphSlot {
  /// 容器的底：与页面自己的背景一样，垫在页面下面。
  backdrop,

  /// 页面本身。
  page,

  /// 小控件落点 / 起点的样子（`MorphTarget.appearance`），原尺寸画在容器正中。
  appearance,
}

/// 按路由进度 [animation]（0 = 落点，1 = 整页）把页面画成从小控件展开、
/// 收回到小控件或活卡片里的容器（`MorphPageRoute` 用）。几何与各层透明度
/// 见 [MorphGeometry.frame]。
///
/// 与卡片展开（`ContainerTransformTransition`）同一套绘制原则：只在绘制阶段
/// 逐帧变化，页面按整屏布局一次，之后每帧只改裁切与缩放（缩放以位图方式
/// 施加，文字不随缩放重新栅格化）；容器的形状始终不透明，下层的列表与背景
/// 从不透过容器透出来。
///
/// 每帧自下而上：
/// 1. 下层页面上的遮罩，随进度加深；
/// 2. 容器（圆角矩形），里面依次是
///    - 小控件落点 / 起点：控件的底色（不透明），页面在
///      [MorphGeometry.anchorGroupFade] 里淡入 / 淡出到它上面；控件的样子
///      （[appearance]）在末段淡入，原尺寸画在正中——收成控件那一刻与屏上
///      的控件逐像素一致；
///    - 活卡片落点：页面始终不透明，卡片拍下的图（`MorphTarget.image`）按
///      容器宽度缩放、贴顶盖在上面，在 [MorphGeometry.liveCardFade] 里与
///      页面互相渐变（拍不了图时退而把页面淡出、露出下面的卡片）；
///    - 无处可落：页面原地缩小一点并整体淡出。
///
/// [active] 为 false（按主题转场推入、还没开始收回）时原样绘制页面，不留
/// 任何额外图层，[backdrop] 与 [appearance] 也不绘制；进度为 1 时同样如此。
class MorphTransition
    extends SlottedMultiChildRenderObjectWidget<MorphSlot, RenderBox> {
  const MorphTransition({
    super.key,
    required this.animation,
    required this.active,
    required this.geometry,
    required this.scrimColor,
    required this.backdrop,
    required this.child,
    this.appearance,
    this.pageRadius = BorderRadius.zero,
  });

  final Animation<double> animation;
  final bool active;
  final MorphGeometry geometry;
  final Color scrimColor;

  /// 整页时容器的圆角（屏幕自带的圆角）。
  final BorderRadius pageRadius;

  /// 容器的底，应与页面自己的背景一致；不参与点按与读屏。
  final Widget backdrop;

  /// 小控件的样子（见 [MorphSlot.appearance]）；不参与点按与读屏。
  final Widget? appearance;

  /// 页面。
  final Widget child;

  @override
  Iterable<MorphSlot> get slots => MorphSlot.values;

  @override
  Widget? childForSlot(MorphSlot slot) => switch (slot) {
    MorphSlot.backdrop => backdrop,
    MorphSlot.page => child,
    MorphSlot.appearance => appearance,
  };

  @override
  RenderMorphTransition createRenderObject(BuildContext context) {
    return RenderMorphTransition(
      animation: animation,
      active: active,
      geometry: geometry,
      scrimColor: scrimColor,
      pageRadius: pageRadius,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderMorphTransition renderObject,
  ) {
    renderObject
      ..animation = animation
      ..active = active
      ..geometry = geometry
      ..scrimColor = scrimColor
      ..pageRadius = pageRadius;
  }
}

class RenderMorphTransition extends RenderBox
    with SlottedContainerRenderObjectMixin<MorphSlot, RenderBox> {
  RenderMorphTransition({
    required this._animation,
    required this._active,
    required this._geometry,
    required this._scrimColor,
    this._pageRadius = BorderRadius.zero,
  });

  /// 进度达到这里之后容器里的点按交给页面（展开末段长长的减速里就能开始
  /// 输入）；更早时一律由容器接住，不会误点到页面或下层列表。
  static const double _interactiveFrom = 0.75;

  Animation<double> _animation;
  set animation(Animation<double> value) {
    if (identical(value, _animation)) return;
    if (attached) {
      _animation.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _animation = value;
    markNeedsPaint();
  }

  bool _active;
  set active(bool value) {
    if (value == _active) return;
    _active = value;
    markNeedsPaint();
  }

  MorphGeometry _geometry;
  set geometry(MorphGeometry value) {
    if (identical(value, _geometry)) return;
    if (attached) {
      _geometry.removeListener(markNeedsLayout);
      value.addListener(markNeedsLayout);
    }
    _geometry = value;
    markNeedsLayout();
  }

  Color _scrimColor;
  set scrimColor(Color value) {
    if (value == _scrimColor) return;
    _scrimColor = value;
    markNeedsPaint();
  }

  BorderRadius _pageRadius;
  set pageRadius(BorderRadius value) {
    if (value == _pageRadius) return;
    _pageRadius = value;
    markNeedsPaint();
  }

  RenderBox? get _backdrop => childForSlot(MorphSlot.backdrop);
  RenderBox? get _page => childForSlot(MorphSlot.page);
  RenderBox? get _appearance => childForSlot(MorphSlot.appearance);

  final LayerHandle<ClipRRectLayer> _clipLayer = LayerHandle<ClipRRectLayer>();
  final LayerHandle<OpacityLayer> _groupLayer = LayerHandle<OpacityLayer>();
  final LayerHandle<ImageFilterLayer> _scaleLayer =
      LayerHandle<ImageFilterLayer>();
  final LayerHandle<OpacityLayer> _appearanceLayer =
      LayerHandle<OpacityLayer>();

  /// 按页面原样绘制：没在转场，或进度到了整页。
  bool get _plain => !_active || _animation.value >= 1;

  /// 测试用：此刻的容器（本地坐标）。
  @visibleForTesting
  MorphFrame get debugFrame => _frame();

  MorphFrame _frame() => _geometry.frame(_animation.value, size, _pageRadius);

  @override
  void performLayout() {
    final page = _page;
    if (page == null) {
      size = constraints.smallest;
    } else {
      page.layout(constraints, parentUsesSize: true);
      size = constraints.constrain(page.size);
    }
    _backdrop?.layout(BoxConstraints.tight(size));
    final appearance = _appearance;
    if (appearance != null) {
      final target = _geometry.target?.rect.size ?? Size.zero;
      appearance.layout(BoxConstraints.tight(target));
    }
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final page = _page;
    return page == null
        ? constraints.smallest
        : constraints.constrain(page.getDryLayout(constraints));
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _page?.getMinIntrinsicWidth(height) ?? 0;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _page?.getMaxIntrinsicWidth(height) ?? 0;

  @override
  double computeMinIntrinsicHeight(double width) =>
      _page?.getMinIntrinsicHeight(width) ?? 0;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _page?.getMaxIntrinsicHeight(width) ?? 0;

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    // 底与外观只是转场时的画面，读屏只看页面。
    final page = _page;
    if (page != null) visitor(page);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animation.addListener(markNeedsPaint);
    _geometry.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _animation.removeListener(markNeedsPaint);
    _geometry.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void dispose() {
    _clearLayers();
    super.dispose();
  }

  void _clearLayers() {
    _clipLayer.layer = null;
    _groupLayer.layer = null;
    _scaleLayer.layer = null;
    _appearanceLayer.layer = null;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final page = _page;
    if (page == null) return;
    if (_plain) {
      _clearLayers();
      context.paintChild(page, offset);
      return;
    }
    final frame = _frame();
    final target = _geometry.target;
    if (frame.scrimAlpha > 0) {
      context.canvas.drawRect(
        offset & size,
        Paint()
          ..color = _scrimColor.withValues(
            alpha: _scrimColor.a * frame.scrimAlpha,
          ),
      );
    }
    _clipLayer.layer = context.pushClipRRect(
      needsCompositing,
      offset,
      frame.rect,
      frame.rrect,
      (PaintingContext context, Offset offset) =>
          _paintContainer(context, offset, frame, target, page),
      oldLayer: _clipLayer.layer,
    );
  }

  void _paintContainer(
    PaintingContext context,
    Offset offset,
    MorphFrame frame,
    MorphTarget? target,
    RenderBox page,
  ) {
    final groupAlpha = (frame.groupAlpha * 255).round();
    final color = target?.color;
    if (color != null && groupAlpha < 255) {
      // 小控件的底色：页面淡出后容器就是控件的颜色。
      context.canvas.drawRect(frame.rect.shift(offset), Paint()..color = color);
    }
    final backdrop = _backdrop;
    void paintGroup(PaintingContext context, Offset offset) {
      // 缩放以位图方式施加（理由同 ContainerTransformTransition）：底与页面
      // 按原尺寸画进一张离屏纹理再整张缩放，文字不必逐帧换字号重新栅格化。
      final scale = frame.scaleFor(size);
      final matrix =
          Matrix4.translationValues(
              offset.dx + frame.rect.left,
              offset.dy + frame.rect.top,
              0,
            )
            ..scaleByDouble(scale, scale, 1, 1)
            ..translateByDouble(-offset.dx, -offset.dy, 0, 1);
      final layer = _scaleLayer.layer ??= ImageFilterLayer();
      layer.imageFilter = ImageFilter.matrix(
        matrix.storage,
        filterQuality: FilterQuality.low,
      );
      context.pushLayer(layer, (PaintingContext context, Offset offset) {
        if (backdrop != null) context.paintChild(backdrop, offset);
        context.paintChild(page, offset);
      }, offset);
    }

    if (groupAlpha >= 255) {
      _groupLayer.layer = null;
      paintGroup(context, offset);
    } else if (groupAlpha > 0) {
      _groupLayer.layer = context.pushOpacity(
        offset,
        groupAlpha,
        paintGroup,
        oldLayer: _groupLayer.layer,
      );
    } else {
      _groupLayer.layer = null;
      _scaleLayer.layer = null;
    }

    final image = target?.image;
    if (target != null && image != null && frame.imageAlpha > 0) {
      // 卡片图按容器宽度缩放、贴顶（与页面同一种缩放），盖在不透明的
      // 页面上；推过图层之后要重新取画布。
      final width = frame.rect.width;
      final height = width * target.rect.height / target.rect.width;
      context.canvas.drawImageRect(
        image,
        Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(
          frame.rect.left,
          frame.rect.top,
          width,
          height,
        ).shift(offset),
        Paint()
          ..color = Color.fromRGBO(0, 0, 0, frame.imageAlpha)
          ..filterQuality = FilterQuality.medium,
      );
    }

    final appearance = _appearance;
    final appearanceAlpha = (frame.appearanceAlpha * 255).round();
    if (appearance != null && appearanceAlpha > 0) {
      // 原尺寸画在容器正中：收成控件时与控件重合，大时就是一个加号（或
      // 数字）浮在控件颜色的容器中间。
      final at =
          offset + frame.rect.center - appearance.size.center(Offset.zero);
      if (appearanceAlpha >= 255) {
        _appearanceLayer.layer = null;
        context.paintChild(appearance, at);
      } else {
        _appearanceLayer.layer = context.pushOpacity(
          at,
          appearanceAlpha,
          (PaintingContext context, Offset offset) =>
              context.paintChild(appearance, offset),
          oldLayer: _appearanceLayer.layer,
        );
      }
    } else {
      _appearanceLayer.layer = null;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // 只在原样绘制时经 [hitTest] 走到这里：底与外观不接点按。
    return _page?.hitTest(result, position: position) ?? false;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (_plain) {
      return super.hitTest(result, position: position);
    }
    final page = _page;
    if (!size.contains(position)) return false;
    // 转场途中整屏都由这里接住：展开、收回途中不会又点到下层列表。展开到
    // [_interactiveFrom] 之后容器内的点按交给页面；收回途中页面不再接点按。
    final frame = _frame();
    final opening = _animation.status == AnimationStatus.forward;
    if (opening &&
        _animation.value >= _interactiveFrom &&
        frame.rect.contains(position)) {
      final scale = frame.scaleFor(size);
      final transform = Matrix4.translationValues(
        frame.rect.left,
        frame.rect.top,
        0,
      )..scaleByDouble(scale, scale, 1, 1);
      result.addWithPaintTransform(
        transform: transform,
        position: position,
        hitTest: (BoxHitTestResult result, Offset position) =>
            page?.hitTest(result, position: position) ?? false,
      );
    }
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (_plain) return;
    final frame = _frame();
    if (identical(child, _appearance)) {
      final at = frame.rect.center - child.size.center(Offset.zero);
      transform.translateByDouble(at.dx, at.dy, 0, 1);
      return;
    }
    final scale = frame.scaleFor(size);
    transform
      ..translateByDouble(frame.rect.left, frame.rect.top, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }
}
