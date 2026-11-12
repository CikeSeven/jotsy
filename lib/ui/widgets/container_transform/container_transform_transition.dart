import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'container_transform_source.dart';

/// 容器展开的起点 / 终点：卡片（带画面）或“无处可回”时的原地淡出。
///
/// 由路由持有：推入时是点按那一刻的卡片；返回时换成重新量出的卡片，找不到
/// 时为 [fallback]。改动后通知绘制层重画，不重建页面。
class ContainerTransformGeometry extends ChangeNotifier {
  ContainerTransformGeometry(ContainerTransformShot? shot) : _closed = shot;

  ContainerTransformShot? _closed;
  ContainerTransformShot? get closed => _closed;

  /// 没有卡片可回（翻到了列表里看不到的一篇、日记已删除、卡片滑出了屏幕）：
  /// 整页原地缩小一点并淡出。
  bool get fallback => _closed == null;

  /// 换成新的起点 / 终点；旧画面在这里释放（已录进上一帧的画面由引擎持有，
  /// 释放句柄不影响那一帧）。
  void replace(ContainerTransformShot? shot) {
    final previous = _closed;
    if (identical(previous, shot)) {
      return;
    }
    _closed = shot;
    previous?.dispose();
    notifyListeners();
  }

  @override
  void dispose() {
    _closed?.dispose();
    _closed = null;
    super.dispose();
  }
}

/// [ContainerTransformTransition] 的两个子节点。
enum ContainerTransformSlot {
  /// 容器的底：与页面自己的背景一样，与页面整体淡入淡出。
  backdrop,

  /// 页面本身。
  page,
}

/// 按路由进度 [animation]（0 = 卡片，1 = 整页）把页面画成从卡片展开的容器。
///
/// 只在绘制阶段逐帧变化：页面按整屏尺寸布局一次，之后每帧只改裁切、缩放与
/// 透明度，页面本身既不重建也不重新布局（它在路由的 RepaintBoundary 里，连
/// 重绘都不需要，只是换一层变换重新合成）。进度为 1 时原样绘制页面，不留
/// 任何额外图层，[backdrop] 也不再绘制。
///
/// 每帧自下而上：
/// 1. 下层页面上的遮罩（`scrim`），随进度加深；
/// 2. 容器：圆角矩形从卡片插值到整屏，圆角从卡片圆角到 0，里面依次是
///    - 底（[backdrop]）：按整屏布局、与页面同样缩放贴顶；
///    - 页面：按整屏布局，宽度缩放到容器宽、顶边对齐容器顶边；底与页面
///      在同一透明度层里随进度淡入，返回末段一起淡去；
///    - 卡片画面：同样按容器宽度缩放、顶边对齐，随进度淡出。
///
/// 底与页面必须一起消退：卡片画面只按宽度缩放，容器高度却独立插值，返回
/// 最后一段容器仍比卡片高。单独淡去页面而保持底不透明，就会在卡片下方拖
/// 出一截白底（有背景图时是一截背景图），直到路由卸载才突然消失。一起淡去
/// 后，这一段直接露出列表，最后只剩卡片画面落回来源。
///
/// 透明度只按进度取值（不按时间），返回途中再点进入、进入途中返回都不会
/// 跳变。无处可回时（[ContainerTransformGeometry.fallback]）终点是屏幕中央
/// 缩小一点的矩形，底与页面作为一整层一起淡出。
class ContainerTransformTransition
    extends
        SlottedMultiChildRenderObjectWidget<ContainerTransformSlot, RenderBox> {
  const ContainerTransformTransition({
    super.key,
    required this.animation,
    required this.geometry,
    required this.scrimColor,
    required this.backdrop,
    required this.child,
  });

  final Animation<double> animation;
  final ContainerTransformGeometry geometry;
  final Color scrimColor;

  /// 容器的底，应与页面自己的背景一致（见类注释）；不参与点按与读屏。
  final Widget backdrop;

  /// 页面。
  final Widget child;

  @override
  Iterable<ContainerTransformSlot> get slots => ContainerTransformSlot.values;

  @override
  Widget? childForSlot(ContainerTransformSlot slot) => switch (slot) {
    ContainerTransformSlot.backdrop => backdrop,
    ContainerTransformSlot.page => child,
  };

  @override
  RenderContainerTransform createRenderObject(BuildContext context) {
    return RenderContainerTransform(
      animation: animation,
      geometry: geometry,
      scrimColor: scrimColor,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderContainerTransform renderObject,
  ) {
    renderObject
      ..animation = animation
      ..geometry = geometry
      ..scrimColor = scrimColor;
  }
}

/// 某一帧的容器几何与各层透明度（见 [ContainerTransformTransition]）。
@immutable
class _Frame {
  const _Frame({
    required this.rect,
    required this.radius,
    required this.transform,
    required this.scrimAlpha,
    required this.groupAlpha,
    required this.imageAlpha,
    required this.imageRect,
  });

  final Rect rect;
  final double radius;

  /// 页面（整屏布局）到容器的变换：按宽度等比缩放，左上角对齐容器。
  final Matrix4 transform;
  final double scrimAlpha;

  /// 底 + 页面整体的透明度，卡片画面另外叠在上方。
  final double groupAlpha;
  final double imageAlpha;

  /// 卡片画面此刻画在哪；没有画面时为 null。
  final Rect? imageRect;
}

/// 布局与页面相同（页面按父级约束布局，底按页面尺寸铺满）；点按、读屏与
/// 停稳后的绘制都只有页面，底只在转场途中画。
class RenderContainerTransform extends RenderBox
    with SlottedContainerRenderObjectMixin<ContainerTransformSlot, RenderBox> {
  RenderContainerTransform({
    required this._animation,
    required this._geometry,
    required this._scrimColor,
  });

  /// 下层页面上遮罩的最大不透明度（M3 的遮罩约 32%，这里略轻：容器本身已
  /// 足够醒目，只需把下层压下去一点）。
  static const double _maxScrim = 0.28;

  /// 页面连同底一起显隐。返回末段进度小于 0.05 时必须几乎透明，不能让
  /// 比卡片高的容器底停留到动画结束。区间仍只依赖进度，途中反向不跳变。
  static const Interval _contentFade = Interval(0.05, 0.75);

  /// 卡片画面淡出的进度区间：比页面淡入早开始、早结束。
  static const Interval _imageFade = Interval(0, 0.55);

  /// 无处可回时终点矩形相对整屏的比例与圆角。
  static const double _fallbackScale = 0.9;
  static const double _fallbackRadius = 28;

  Animation<double> _animation;
  set animation(Animation<double> value) {
    if (identical(value, _animation)) {
      return;
    }
    if (attached) {
      _animation.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _animation = value;
    markNeedsPaint();
  }

  ContainerTransformGeometry _geometry;
  set geometry(ContainerTransformGeometry value) {
    if (identical(value, _geometry)) {
      return;
    }
    if (attached) {
      _geometry.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _geometry = value;
    markNeedsPaint();
  }

  Color _scrimColor;
  set scrimColor(Color value) {
    if (value == _scrimColor) {
      return;
    }
    _scrimColor = value;
    markNeedsPaint();
  }

  RenderBox? get _backdrop => childForSlot(ContainerTransformSlot.backdrop);
  RenderBox? get _page => childForSlot(ContainerTransformSlot.page);

  final LayerHandle<ClipRRectLayer> _clipLayer = LayerHandle<ClipRRectLayer>();
  final LayerHandle<OpacityLayer> _groupLayer = LayerHandle<OpacityLayer>();
  final LayerHandle<TransformLayer> _transformLayer =
      LayerHandle<TransformLayer>();

  /// 进度到 1（整页）时与普通页面完全相同。
  bool get _settled => _animation.value >= 1;

  @override
  void performLayout() {
    final page = _page;
    if (page == null) {
      size = constraints.smallest;
    } else {
      page.layout(constraints, parentUsesSize: true);
      size = constraints.constrain(page.size);
    }
    // 底与页面同尺寸：缩放、贴顶的方式相同，背景图的取景与页面背景一致。
    _backdrop?.layout(BoxConstraints.tight(size));
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
    // 底只是转场时的画面，读屏只看页面。
    final page = _page;
    if (page != null) {
      visitor(page);
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animation.addListener(markNeedsPaint);
    _geometry.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _animation.removeListener(markNeedsPaint);
    _geometry.removeListener(markNeedsPaint);
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
    _transformLayer.layer = null;
  }

  _Frame _frame() {
    final p = _animation.value.clamp(0.0, 1.0);
    final full = Offset.zero & size;
    final closed = _geometry.closed;
    final Rect closedRect;
    final double closedRadius;
    if (closed == null || closed.rect.isEmpty) {
      closedRect = Rect.fromCenter(
        center: full.center,
        width: full.width * _fallbackScale,
        height: full.height * _fallbackScale,
      );
      closedRadius = _fallbackRadius;
    } else {
      closedRect = closed.rect;
      closedRadius = closed.radius;
    }
    final rect = Rect.lerp(closedRect, full, p)!;
    final scale = full.width <= 0 ? 1.0 : rect.width / full.width;
    final transform = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(rect.left, rect.top, 0);

    Rect? imageRect;
    var imageAlpha = 0.0;
    if (closed != null && !closedRect.isEmpty) {
      imageAlpha = 1 - _imageFade.transform(p);
      // 卡片画面与容器同步：按容器宽度等比缩放，左上角跟着容器走。
      final s = rect.width / closedRect.width;
      final source = closed.imageRect;
      imageRect = Rect.fromLTWH(
        rect.left + (source.left - closedRect.left) * s,
        rect.top + (source.top - closedRect.top) * s,
        source.width * s,
        source.height * s,
      );
    }
    final fallback = closed == null;
    return _Frame(
      rect: rect,
      radius: lerpDouble(closedRadius, 0, p)!,
      transform: transform,
      scrimAlpha: _maxScrim * p,
      // 保留 1/255 的预绘制层：起步等待帧里页面就完成首次绘制与栅格化，
      // 起点处被不透明卡片截图盖住。淡去时同样只剩这一不可感知的余量，
      // 不再把不透明的容器底拖到收回结束。
      groupAlpha: fallback ? p : math.max(_contentFade.transform(p), 1 / 255),
      imageAlpha: imageAlpha,
      imageRect: imageRect,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = _page;
    if (child == null) {
      return;
    }
    if (_settled) {
      _clearLayers();
      context.paintChild(child, offset);
      return;
    }
    final frame = _frame();
    if (frame.scrimAlpha > 0) {
      context.canvas.drawRect(
        offset & size,
        Paint()
          ..color = _scrimColor.withValues(
            alpha: _scrimColor.a * frame.scrimAlpha,
          ),
      );
    }
    final rrect = RRect.fromRectAndRadius(
      frame.rect,
      Radius.circular(frame.radius),
    );
    _clipLayer.layer = context.pushClipRRect(
      needsCompositing,
      offset,
      frame.rect,
      rrect,
      (PaintingContext context, Offset offset) =>
          _paintContainer(context, offset, frame, child),
      oldLayer: _clipLayer.layer,
    );
  }

  void _paintContainer(
    PaintingContext context,
    Offset offset,
    _Frame frame,
    RenderBox child,
  ) {
    final backdrop = _backdrop;
    void paintPage(PaintingContext context, Offset offset) {
      // 底与页面共同进入外侧的透明度层，页内玻璃仍能采到先画好的页面背景。
      _transformLayer.layer = context.pushTransform(
        needsCompositing,
        offset,
        frame.transform,
        (PaintingContext context, Offset offset) {
          if (backdrop != null) {
            context.paintChild(backdrop, offset);
          }
          context.paintChild(child, offset);
        },
        oldLayer: _transformLayer.layer,
      );
    }

    final groupAlpha = (frame.groupAlpha * 255).round();
    if (groupAlpha >= 255) {
      _groupLayer.layer = null;
      paintPage(context, offset);
    } else if (groupAlpha > 0) {
      _groupLayer.layer = context.pushOpacity(
        offset,
        groupAlpha,
        paintPage,
        oldLayer: _groupLayer.layer,
      );
    } else {
      _groupLayer.layer = null;
      _transformLayer.layer = null;
    }

    final image = _geometry.closed?.image;
    final imageRect = frame.imageRect;
    if (image != null && imageRect != null && frame.imageAlpha > 0) {
      // 推过图层之后要重新取画布：PaintingContext 已经换了一段新的录制。
      context.canvas.drawImageRect(
        image,
        Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
        imageRect.shift(offset),
        Paint()
          ..color = Color.fromRGBO(0, 0, 0, frame.imageAlpha)
          ..filterQuality = FilterQuality.medium,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // 只在停稳后经 [hitTest] 走到这里：底不接点按。
    return _page?.hitTest(result, position: position) ?? false;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (_settled) {
      return super.hitTest(result, position: position);
    }
    final child = _page;
    if (!size.contains(position)) {
      return false;
    }
    // 转场途中整屏都由这里接住：展开、收回的途中不会又点开下层列表的另一
    // 篇。页面已完全显出时，容器内的点按照常交给页面（展开末段长长的减速
    // 里就能开始滑动）。
    final frame = _frame();
    if (frame.groupAlpha >= 1 && frame.rect.contains(position)) {
      result.addWithPaintTransform(
        transform: frame.transform,
        position: position,
        hitTest: (BoxHitTestResult result, Offset position) =>
            child?.hitTest(result, position: position) ?? false,
      );
    }
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    // 两个子节点都画在原点；转场途中同样套着容器的变换。
    if (!_settled) {
      transform.multiply(_frame().transform);
    }
  }
}
