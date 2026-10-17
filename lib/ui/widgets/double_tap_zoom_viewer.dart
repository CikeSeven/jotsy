import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/expressive_motion.dart';

/// 长内容的构建函数：[contentSize] 为内容尺寸，[visible] 为当前可见区域
/// （内容坐标，已按缩放换算）。
typedef DoubleTapZoomContentBuilder =
    Widget Function(BuildContext context, Size contentSize, Rect visible);

/// 支持双击缩放的 [InteractiveViewer]。
///
/// 输入：[child] 为铺满视口的内容（通常是 `Center(Image)`）；[onZoomChanged] 在
/// “是否处于放大态”翻转时回调。副作用：无。
///
/// - 双击未放大的内容：以点按位置为不动点放大到 [doubleTapScale]；已放大时双击
///   回到原始大小。过程是 Matrix4 补间（medium + effects），不是瞬间跳变；减少
///   动画时直接落位。
/// - 捏合/平移开始时立即停止进行中的补间，手指永远拥有最高优先级。
/// - 宿主应在放大态禁用外层 PageView 的翻页：手势竞技场里 PageView 的水平拖动
///   识别器（触摸阈值 18）总是先于 InteractiveViewer 的缩放识别器（平移阈值 36）
///   胜出，放大后左右拖动会直接翻页，无法平移查看细节。
///
/// [DoubleTapZoomViewer.tall] 用于比视口高的内容（长图）：内容宽度铺满视口、
/// 高度为宽 × [contentHeightFactor]，从顶部开始，原始大小下拖动即上下滚动（带
/// 惯性）；双击放大/复原同样以点按处为不动点，复原时保留当前滚动位置。
/// [builder] 拿到内容尺寸与当前可见区域（内容坐标），只需构建可见的部分。
/// 宿主应关闭下拉关闭手势（竖向拖动要留给滚动），并可经 [onScrolledChanged]
/// 得知是否已离开顶部。
class DoubleTapZoomViewer extends StatefulWidget {
  const DoubleTapZoomViewer({
    super.key,
    required Widget this.child,
    this.maxScale = 4,
    this.doubleTapScale = 2.5,
    this.onZoomChanged,
  }) : contentHeightFactor = null,
       builder = null,
       onScrolledChanged = null;

  const DoubleTapZoomViewer.tall({
    super.key,
    required double this.contentHeightFactor,
    required DoubleTapZoomContentBuilder this.builder,
    this.maxScale = 4,
    this.doubleTapScale = 2.5,
    this.onZoomChanged,
    this.onScrolledChanged,
  }) : child = null;

  final Widget? child;

  /// 长内容的高宽比；为 null 时内容与视口同尺寸。
  final double? contentHeightFactor;
  final DoubleTapZoomContentBuilder? builder;
  final double maxScale;
  final double doubleTapScale;
  final ValueChanged<bool>? onZoomChanged;

  /// 长内容是否已离开顶部（滚动或放大后平移过）。
  final ValueChanged<bool>? onScrolledChanged;

  @override
  State<DoubleTapZoomViewer> createState() => _DoubleTapZoomViewerState();
}

class _DoubleTapZoomViewerState extends State<DoubleTapZoomViewer>
    with SingleTickerProviderStateMixin {
  /// 判定“已放大”的缩放下限：捏合回到 1 时浮点误差可能停在 1.000x。
  static const double _zoomedEpsilon = 1.01;

  final TransformationController _transformation = TransformationController();
  late final AnimationController _zoomController = AnimationController(
    vsync: this,
  )..addListener(_applyZoomFrame);
  Animation<Matrix4>? _zoomAnimation;

  /// 最近一次双击按下的位置（视口坐标）；onDoubleTap 本身不带坐标。
  Offset? _doubleTapPosition;
  Size _viewportSize = Size.zero;
  Size _contentSize = Size.zero;
  bool _zoomed = false;
  bool _scrolled = false;

  bool get _tall => widget.contentHeightFactor != null;

  @override
  void initState() {
    super.initState();
    _transformation.addListener(_handleTransformationChanged);
  }

  @override
  void dispose() {
    _zoomController.dispose();
    _transformation.dispose();
    super.dispose();
  }

  void _handleTransformationChanged() {
    final matrix = _transformation.value;
    final zoomed = matrix.getMaxScaleOnAxis() > _zoomedEpsilon;
    if (zoomed != _zoomed) {
      _zoomed = zoomed;
      widget.onZoomChanged?.call(zoomed);
    }
    if (_tall) {
      final scrolled = matrix.getTranslation().y < -0.5;
      if (scrolled != _scrolled) {
        _scrolled = scrolled;
        widget.onScrolledChanged?.call(scrolled);
      }
    }
  }

  void _applyZoomFrame() {
    final animation = _zoomAnimation;
    if (animation != null) {
      _transformation.value = animation.value;
    }
  }

  void _handleDoubleTap() {
    final current = _transformation.value;
    final focal = _doubleTapPosition ?? _viewportSize.center(Offset.zero);
    final zoomedIn = current.getMaxScaleOnAxis() > _zoomedEpsilon;
    final Matrix4 target;
    if (!zoomedIn) {
      target = _scaledMatrixAt(current, focal, widget.doubleTapScale);
    } else if (_tall) {
      // 长内容复原时保留滚动位置：点按处的那一行留在手指下。
      target = _scaledMatrixAt(current, focal, 1);
    } else {
      target = Matrix4.identity();
    }
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    _zoomController.stop();
    if (duration == Duration.zero) {
      _zoomAnimation = null;
      _transformation.value = target;
      return;
    }
    _zoomAnimation = Matrix4Tween(begin: current, end: target).animate(
      CurvedAnimation(parent: _zoomController, curve: ExpressiveMotion.effects),
    );
    _zoomController
      ..duration = duration
      ..forward(from: 0);
  }

  /// 以 [focal]（视口坐标）为不动点把 [current] 缩放到 [scale]。
  ///
  /// 设变换为 x' = s·x + t：focal 对应的内容点 p = (focal - t₀) / s₀，要求缩放后
  /// 仍落在 focal 下，得 t₁ = focal - p·s₁。再把 t₁ 夹到 [视口 - 内容·s₁, 0]，
  /// 放大后不会露出内容以外的空白。普通模式从原始大小起算时 t₁ = focal·(1 - s)，
  /// 天然落在范围内，夹取只防边缘点按的坐标略微越界。
  Matrix4 _scaledMatrixAt(Matrix4 current, Offset focal, double scale) {
    final currentScale = current.getMaxScaleOnAxis();
    final translation = current.getTranslation();
    final contentPoint = Offset(
      (focal.dx - translation.x) / currentScale,
      (focal.dy - translation.y) / currentScale,
    );
    final dx = (focal.dx - contentPoint.dx * scale).clamp(
      _viewportSize.width - _contentSize.width * scale,
      0.0,
    );
    // 内容比视口矮（普通模式缩放到 1 时恰好等高）时下限取 0，不留空白。
    final double minDy = math.min(
      0.0,
      _viewportSize.height - _contentSize.height * scale,
    );
    final dy = (focal.dy - contentPoint.dy * scale).clamp(minDy, 0.0);
    return Matrix4.translationValues(dx, dy, 0)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _viewportSize = constraints.biggest;
        final factor = widget.contentHeightFactor;
        _contentSize = factor == null
            ? _viewportSize
            : Size(_viewportSize.width, _viewportSize.width * factor);
        return GestureDetector(
          onDoubleTapDown: (TapDownDetails details) {
            _doubleTapPosition = details.localPosition;
          },
          onDoubleTap: _handleDoubleTap,
          child: factor == null
              ? InteractiveViewer(
                  transformationController: _transformation,
                  minScale: 1,
                  maxScale: widget.maxScale,
                  onInteractionStart: (_) => _zoomController.stop(),
                  child: widget.child!,
                )
              : InteractiveViewer.builder(
                  transformationController: _transformation,
                  minScale: 1,
                  maxScale: widget.maxScale,
                  onInteractionStart: (_) => _zoomController.stop(),
                  builder: (BuildContext context, viewport) {
                    // 视口四角映射回内容坐标后的外接矩形即可见区域。
                    final corners = <Offset>[
                      Offset(viewport.point0.x, viewport.point0.y),
                      Offset(viewport.point1.x, viewport.point1.y),
                      Offset(viewport.point2.x, viewport.point2.y),
                      Offset(viewport.point3.x, viewport.point3.y),
                    ];
                    return SizedBox.fromSize(
                      size: _contentSize,
                      child: widget.builder!(
                        context,
                        _contentSize,
                        _boundsOf(corners),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  static Rect _boundsOf(List<Offset> corners) {
    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;
    for (final corner in corners) {
      left = math.min(left, corner.dx);
      top = math.min(top, corner.dy);
      right = math.max(right, corner.dx);
      bottom = math.max(bottom, corner.dy);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }
}
