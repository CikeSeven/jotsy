import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/expressive_motion.dart';
import '../../core/services/app_platform.dart';
import 'pinch_zoom_gesture_recognizer.dart';
import 'zoom_geometry.dart';

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
/// - 双指捏合由 [PinchZoomGestureRecognizer] 接管：第二根手指落下即胜出，不再
///   被翻页 / 下拉关闭抢走（#252）。以两指中点为不动点缩放、两指同移即平移；
///   越过 1 或 [maxScale] 时阻尼跟手（[ZoomGeometry.rubberBand]），松手后以
///   medium + effects 回弹到边界。单指平移、触控板捏合与滚轮缩放仍由
///   InteractiveViewer 处理（放大后先单指拖动再落第二指时，第一根手指已归它，
///   这次捏合也由它完成）。
/// - 捏合/平移开始时立即停止进行中的补间，手指永远拥有最高优先级。
/// - 宿主应在放大态禁用外层 PageView 的翻页：手势竞技场里 PageView 的水平拖动
///   识别器（触摸阈值 18）总是先于 InteractiveViewer 的平移识别器（平移阈值 36）
///   胜出，放大后左右拖动会直接翻页，无法平移查看细节。
///
/// [DoubleTapZoomViewer.tall] 用于比视口高的内容（长图）：内容宽度铺满视口、
/// 高度为宽 × [contentHeightFactor]，从顶部开始，原始大小下拖动即上下滚动（带
/// 惯性）；双击放大/复原同样以点按处为不动点，复原时保留当前滚动位置。
/// [builder] 拿到内容尺寸与当前可见区域（内容坐标），只需构建可见的部分。
/// 宿主应关闭下拉关闭手势（竖向拖动要留给滚动），并可经 [onScrolledChanged]
/// 得知是否已离开顶部。
///
/// 鼠标滚轮：普通模式沿用 InteractiveViewer，滚轮即缩放；长内容在桌面上普通
/// 滚轮改为上下滚动（按住 Ctrl / ⌘ 时仍缩放，触控板捏合照常缩放、双指滑动
/// 照常平移）。InteractiveViewer 的滚轮缩放不经 pointerSignalResolver，无法
/// 抢先拦下，所以没按修饰键时把它的滚轮缩放倍率设成近乎无穷（每格缩放
/// 系数恒为 1），平移由里层的 Listener 完成。
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

  /// 桌面长内容：普通滚轮用来滚动，只有按住 Ctrl / ⌘ 时滚轮才缩放。
  bool get _wheelScrolls => _tall && AppPlatform.isDesktop;

  /// Ctrl / ⌘ 是否按着（[_wheelScrolls] 时跟踪，决定滚轮缩放倍率）。
  bool _zoomModifier = false;

  static bool _modifierPressed() {
    final keyboard = HardwareKeyboard.instance;
    return keyboard.isControlPressed || keyboard.isMetaPressed;
  }

  bool _handleKey(KeyEvent event) {
    final pressed = _modifierPressed();
    if (pressed != _zoomModifier && mounted) {
      setState(() => _zoomModifier = pressed);
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _transformation.addListener(_handleTransformationChanged);
    if (_wheelScrolls) {
      _zoomModifier = _modifierPressed();
      HardwareKeyboard.instance.addHandler(_handleKey);
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _zoomController.dispose();
    _transformation.dispose();
    super.dispose();
  }

  ZoomGeometry get _geometry => ZoomGeometry(
    viewport: _viewportSize,
    content: _contentSize,
    maxScale: widget.maxScale,
  );

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
      target = _geometry.scaledAt(current, focal, widget.doubleTapScale);
    } else if (_tall) {
      // 长内容复原时保留滚动位置：点按处的那一行留在手指下。
      target = _geometry.scaledAt(current, focal, 1);
    } else {
      target = Matrix4.identity();
    }
    _animateTo(target);
  }

  /// 从当前变换补间到 [target]（medium + effects）；减少动画时直接落位。
  void _animateTo(Matrix4 target) {
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
    _zoomAnimation =
        Matrix4Tween(begin: _transformation.value.clone(), end: target).animate(
          CurvedAnimation(
            parent: _zoomController,
            curve: ExpressiveMotion.effects,
          ),
        );
    _zoomController
      ..duration = duration
      ..forward(from: 0);
  }

  // ---- 双指捏合（PinchZoomGestureRecognizer）----
  //
  // 每段捏合（两指落下，或中途抬起一指后剩下那根再动）开始时记下起点变换、
  // 未阻尼的起点缩放与焦点；更新时按“起点焦点下的内容点跟着当前焦点走”求
  // 平移，缩放经阻尼；最后一根手指离开时（onRelease）把越界的缩放补间回
  // 边界。平移在更新时已夹回范围，范围内松手不需要动画。

  /// 本段捏合开始时的变换；为 null 表示没有进行中的一段。
  Matrix4? _pinchStart;

  /// 本段开始时未经阻尼的缩放（从阻尼中的画面接着捏时不跳）。
  double _pinchRawStartScale = 1;
  Offset _pinchStartFocal = Offset.zero;

  /// 最近一次的焦点：松手回弹以它为不动点。
  Offset _pinchFocal = Offset.zero;

  void _handlePinchStart(ScaleStartDetails details) {
    _zoomController.stop();
    final current = _transformation.value.clone();
    _pinchStart = current;
    _pinchRawStartScale = _geometry.unband(current.getMaxScaleOnAxis());
    _pinchStartFocal = details.localFocalPoint;
    _pinchFocal = details.localFocalPoint;
  }

  void _handlePinchUpdate(ScaleUpdateDetails details) {
    final start = _pinchStart;
    if (start == null) {
      return;
    }
    final geometry = _geometry;
    final scale = geometry.rubberBand(_pinchRawStartScale * details.scale);
    final contentPoint = ZoomGeometry.contentPointAt(start, _pinchStartFocal);
    _pinchFocal = details.localFocalPoint;
    _transformation.value = geometry.clamped(
      scale,
      details.localFocalPoint - contentPoint * scale,
    );
  }

  void _handlePinchEnd(ScaleEndDetails details) {
    _pinchStart = null;
  }

  void _handlePinchRelease() {
    _pinchStart = null;
    final current = _transformation.value;
    final scale = current.getMaxScaleOnAxis();
    final target = scale.clamp(ZoomGeometry.minScale, widget.maxScale);
    if (target != scale) {
      _animateTo(_geometry.scaledAt(current, _pinchFocal, target));
    }
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
        final viewer = factor == null
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
                scaleFactor: _wheelScrolls && !_zoomModifier
                    ? double.maxFinite
                    : kDefaultMouseScrollToScaleFactor,
                onInteractionStart: (_) => _zoomController.stop(),
                builder: (BuildContext context, viewport) {
                  // 视口四角映射回内容坐标后的外接矩形即可见区域。
                  final corners = <Offset>[
                    Offset(viewport.point0.x, viewport.point0.y),
                    Offset(viewport.point1.x, viewport.point1.y),
                    Offset(viewport.point2.x, viewport.point2.y),
                    Offset(viewport.point3.x, viewport.point3.y),
                  ];
                  final content = SizedBox.fromSize(
                    size: _contentSize,
                    child: widget.builder!(
                      context,
                      _contentSize,
                      _boundsOf(corners),
                    ),
                  );
                  if (!_wheelScrolls) {
                    return content;
                  }
                  return Listener(
                    onPointerSignal: _handlePointerSignal,
                    child: content,
                  );
                },
              );
        return GestureDetector(
          onDoubleTapDown: (TapDownDetails details) {
            _doubleTapPosition = details.localPosition;
          },
          onDoubleTap: _handleDoubleTap,
          // 与 InteractiveViewer 同一个盒子：识别器的本地坐标即视口坐标。
          child: RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: <Type, GestureRecognizerFactory>{
              PinchZoomGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    PinchZoomGestureRecognizer
                  >(
                    () => PinchZoomGestureRecognizer(debugOwner: this),
                    (PinchZoomGestureRecognizer recognizer) => recognizer
                      ..onStart = _handlePinchStart
                      ..onUpdate = _handlePinchUpdate
                      ..onEnd = _handlePinchEnd
                      ..onRelease = _handlePinchRelease,
                  ),
            },
            child: viewer,
          ),
        );
      },
    );
  }

  /// 长内容在桌面上的滚轮：没按 Ctrl / ⌘ 时按滚动量平移（夹在内容范围内）；
  /// 登记到 pointerSignalResolver，外层的滚动视图不再响应同一格滚轮。按住
  /// 修饰键时不处理，由 InteractiveViewer 缩放。
  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || _modifierPressed()) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (
      PointerSignalEvent event,
    ) {
      final delta = (event as PointerScrollEvent).scrollDelta;
      _zoomController.stop();
      final current = _transformation.value;
      final scale = current.getMaxScaleOnAxis();
      final translation = current.getTranslation();
      final double minDx = math.min(
        0.0,
        _viewportSize.width - _contentSize.width * scale,
      );
      final double minDy = math.min(
        0.0,
        _viewportSize.height - _contentSize.height * scale,
      );
      final dx = (translation.x - delta.dx).clamp(minDx, 0.0);
      final dy = (translation.y - delta.dy).clamp(minDy, 0.0);
      _transformation.value = Matrix4.translationValues(dx, dy, 0)
        ..scaleByDouble(scale, scale, 1, 1);
    });
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
