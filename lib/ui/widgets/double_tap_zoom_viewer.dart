import 'package:flutter/material.dart';

import '../../app/theme/expressive_motion.dart';

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
class DoubleTapZoomViewer extends StatefulWidget {
  const DoubleTapZoomViewer({
    super.key,
    required this.child,
    this.maxScale = 4,
    this.doubleTapScale = 2.5,
    this.onZoomChanged,
  });

  final Widget child;
  final double maxScale;
  final double doubleTapScale;
  final ValueChanged<bool>? onZoomChanged;

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
  bool _zoomed = false;

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
    final zoomed = _transformation.value.getMaxScaleOnAxis() > _zoomedEpsilon;
    if (zoomed == _zoomed) {
      return;
    }
    _zoomed = zoomed;
    widget.onZoomChanged?.call(zoomed);
  }

  void _applyZoomFrame() {
    final animation = _zoomAnimation;
    if (animation != null) {
      _transformation.value = animation.value;
    }
  }

  void _handleDoubleTap() {
    final current = _transformation.value;
    final target = current.getMaxScaleOnAxis() > _zoomedEpsilon
        ? Matrix4.identity()
        : _zoomedMatrixAt(
            _doubleTapPosition ?? _viewportSize.center(Offset.zero),
          );
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

  /// 以 [focal] 为不动点放大：x' = s·x + t，令 x' = x 得 t = x·(1 - s)。
  ///
  /// InteractiveViewer 默认 constrained，内容与视口同尺寸；focal 在视口内时 t
  /// 天然落在 [视口·(1 - s), 0]，放大后不会露出内容以外的空白。仍做一次夹取，
  /// 防止边缘点按的坐标略微越界。
  Matrix4 _zoomedMatrixAt(Offset focal) {
    final scale = widget.doubleTapScale;
    final dx = (focal.dx * (1 - scale)).clamp(
      _viewportSize.width * (1 - scale),
      0.0,
    );
    final dy = (focal.dy * (1 - scale)).clamp(
      _viewportSize.height * (1 - scale),
      0.0,
    );
    return Matrix4.translationValues(dx, dy, 0)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _viewportSize = constraints.biggest;
        return GestureDetector(
          onDoubleTapDown: (TapDownDetails details) {
            _doubleTapPosition = details.localPosition;
          },
          onDoubleTap: _handleDoubleTap,
          child: InteractiveViewer(
            transformationController: _transformation,
            minScale: 1,
            maxScale: widget.maxScale,
            onInteractionStart: (_) => _zoomController.stop(),
            child: widget.child,
          ),
        );
      },
    );
  }
}
