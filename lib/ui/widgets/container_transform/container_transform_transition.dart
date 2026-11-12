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

/// 按路由进度 [animation]（0 = 卡片，1 = 整页）把页面画成从卡片展开的容器。
///
/// 只在绘制阶段逐帧变化：页面按整屏尺寸布局一次，之后每帧只改裁切、缩放与
/// 透明度，页面本身既不重建也不重新布局（它在路由的 RepaintBoundary 里，连
/// 重绘都不需要，只是换一层变换重新合成）。进度为 1 时原样绘制页面，不留
/// 任何额外图层。
///
/// 每帧自下而上：
/// 1. 下层页面上的遮罩（`scrim`），随进度加深；
/// 2. 容器：圆角矩形从卡片插值到整屏，圆角从卡片圆角到 0，里面依次是
///    - 底色（不透明，盖住下层的原卡片，交叉淡入时不透出重影）；
///    - 页面：按整屏布局，宽度缩放到容器宽、顶边对齐容器顶边，随进度淡入；
///    - 卡片画面：同样按容器宽度缩放、顶边对齐，随进度淡出。
///
/// 透明度只按进度取值（不按时间），返回途中再点进入、进入途中返回都不会
/// 跳变。无处可回时（[ContainerTransformGeometry.fallback]）终点是屏幕中央
/// 缩小一点的矩形，底色与页面作为一整层一起淡出。
class ContainerTransformTransition extends SingleChildRenderObjectWidget {
  const ContainerTransformTransition({
    super.key,
    required this.animation,
    required this.geometry,
    required this.scrimColor,
    required this.surfaceColor,
    super.child,
  });

  final Animation<double> animation;
  final ContainerTransformGeometry geometry;
  final Color scrimColor;
  final Color surfaceColor;

  @override
  RenderContainerTransform createRenderObject(BuildContext context) {
    return RenderContainerTransform(
      animation: animation,
      geometry: geometry,
      scrimColor: scrimColor,
      surfaceColor: surfaceColor,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderContainerTransform renderObject,
  ) {
    renderObject
      ..animation = animation
      ..geometry = geometry
      ..scrimColor = scrimColor
      ..surfaceColor = surfaceColor;
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
    required this.contentAlpha,
    required this.imageAlpha,
    required this.imageRect,
  });

  final Rect rect;
  final double radius;

  /// 页面（整屏布局）到容器的变换：按宽度等比缩放，左上角对齐容器。
  final Matrix4 transform;
  final double scrimAlpha;

  /// 底色 + 页面整体的透明度：只在无处可回时小于 1。
  final double groupAlpha;
  final double contentAlpha;
  final double imageAlpha;

  /// 卡片画面此刻画在哪；没有画面时为 null。
  final Rect? imageRect;
}

class RenderContainerTransform extends RenderProxyBox {
  RenderContainerTransform({
    required this._animation,
    required this._geometry,
    required this._scrimColor,
    required this._surfaceColor,
  });

  /// 下层页面上遮罩的最大不透明度（M3 的遮罩约 32%，这里略轻：容器本身已
  /// 足够醒目，只需把下层压下去一点）。
  static const double _maxScrim = 0.28;

  /// 页面淡入的进度区间：展开时约在 30–130ms 之间（强调曲线前段走得快），
  /// 与卡片画面的淡出交叠，中间露出的是不透明底色而不是下层页面。
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

  Color _surfaceColor;
  set surfaceColor(Color value) {
    if (value == _surfaceColor) {
      return;
    }
    _surfaceColor = value;
    markNeedsPaint();
  }

  final LayerHandle<ClipRRectLayer> _clipLayer = LayerHandle<ClipRRectLayer>();
  final LayerHandle<OpacityLayer> _groupLayer = LayerHandle<OpacityLayer>();
  final LayerHandle<OpacityLayer> _contentLayer = LayerHandle<OpacityLayer>();
  final LayerHandle<TransformLayer> _transformLayer =
      LayerHandle<TransformLayer>();

  /// 进度到 1（整页）时与普通页面完全相同。
  bool get _settled => _animation.value >= 1;

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
    _contentLayer.layer = null;
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
      groupAlpha: fallback ? p : 1,
      // 进入时页面一开始就以近乎透明的一层画出来（被不透明的卡片画面整块
      // 盖住，看不见）：页面的首次绘制与栅格化落在起步前的等待帧里，而不是
      // 淡入开始的那一帧。
      contentAlpha: fallback ? 1 : math.max(_contentFade.transform(p), 1 / 255),
      imageAlpha: imageAlpha,
      imageRect: imageRect,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
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
    void paintPage(PaintingContext context, Offset offset) {
      context.canvas.drawRect(
        frame.rect.shift(offset),
        Paint()..color = _surfaceColor.withValues(alpha: 1),
      );
      void paintTransformed(PaintingContext context, Offset offset) {
        _transformLayer.layer = context.pushTransform(
          needsCompositing,
          offset,
          frame.transform,
          (PaintingContext context, Offset offset) =>
              context.paintChild(child, offset),
          oldLayer: _transformLayer.layer,
        );
      }

      final contentAlpha = (frame.contentAlpha * 255).round();
      if (contentAlpha >= 255) {
        _contentLayer.layer = null;
        paintTransformed(context, offset);
      } else {
        _contentLayer.layer = context.pushOpacity(
          offset,
          math.max(contentAlpha, 1),
          paintTransformed,
          oldLayer: _contentLayer.layer,
        );
      }
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
      _contentLayer.layer = null;
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
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (_settled) {
      return super.hitTest(result, position: position);
    }
    if (!size.contains(position)) {
      return false;
    }
    // 转场途中整屏都由这里接住：展开、收回的途中不会又点开下层列表的另一
    // 篇。页面已完全显出时，容器内的点按照常交给页面（展开末段长长的减速
    // 里就能开始滑动）。
    final frame = _frame();
    if (frame.contentAlpha >= 1 &&
        frame.groupAlpha >= 1 &&
        frame.rect.contains(position)) {
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
    if (!_settled) {
      transform.multiply(_frame().transform);
    }
  }
}
