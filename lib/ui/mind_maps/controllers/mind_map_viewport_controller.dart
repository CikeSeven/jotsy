import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart' show Matrix4;

/// 导图画布的视口：缩放与平移（屏幕坐标 = 导图坐标 × [scale] + [translation]）。
///
/// 职责边界：只管变换本身与它的动画（适应屏幕、跟到选中节点），不处理手势；
/// 手势在画布里换算成 [panBy] / [zoomAt]。画布是无限的，不做硬边界：只在
/// 松手后（[settle]）把完全跑出视口的内容拉回来一截，保证至少露出一部分。
/// 动画经 [attach] 拿到的 vsync 驱动，时长与曲线由调用方按 ExpressiveMotion
/// 给出（减少动态效果时传 0 即直接到位）。
class MindMapViewportController extends ChangeNotifier {
  static const double minScale = 0.12;
  static const double maxScale = 4;

  double _scale = 1;
  Offset _translation = Offset.zero;
  bool _initialized = false;
  AnimationController? _animation;
  VoidCallback? _animationListener;

  double get scale => _scale;
  Offset get translation => _translation;

  /// 是否已经按内容摆好过初始位置。
  bool get initialized => _initialized;

  Matrix4 get transform => Matrix4.identity()
    ..translateByDouble(_translation.dx, _translation.dy, 0, 1)
    ..scaleByDouble(_scale, _scale, 1, 1);

  Offset toContent(Offset screen) => (screen - _translation) / _scale;

  Offset toScreen(Offset content) => content * _scale + _translation;

  Rect toScreenRect(Rect content) =>
      Rect.fromPoints(toScreen(content.topLeft), toScreen(content.bottomRight));

  void attach(TickerProvider vsync) {
    _animation?.dispose();
    _animation = AnimationController.unbounded(vsync: vsync);
  }

  void detach() {
    _stopAnimation();
    _animation?.dispose();
    _animation = null;
  }

  void _set(double scale, Offset translation) {
    if (scale == _scale && translation == _translation) return;
    _scale = scale;
    _translation = translation;
    notifyListeners();
  }

  /// 手势平移（屏幕像素）。
  void panBy(Offset delta) {
    _stopAnimation();
    _set(_scale, _translation + delta);
  }

  /// 以屏幕点 [focal] 为中心缩放 [factor] 倍（焦点下的内容不动）。
  void zoomAt(Offset focal, double factor) {
    _stopAnimation();
    final next = (_scale * factor).clamp(minScale, maxScale);
    final content = toContent(focal);
    _set(next, focal - content * next);
  }

  /// 首次显示时摆放：缩放取“能看全”的倍数，夹在 0.5 到 1 之间；内容居中，
  /// 放不下时再平移到让根节点 [focus] 留在可见区里（时间线、逻辑图这类
  /// 根在一端的结构从根看起）。在画布的布局阶段调用，不通知监听者（这一帧
  /// 本来就按新值绘制）。
  void initializeSilently(
    Rect bounds,
    Size viewport,
    Rect focus,
    EdgeInsets padding,
  ) {
    _initialized = true;
    final scale = _fitScale(bounds, viewport, padding).clamp(0.5, 1.0);
    final area = padding.deflateRect(Offset.zero & viewport);
    var translation = area.center - bounds.center * scale;
    final root = Rect.fromPoints(
      focus.topLeft * scale + translation,
      focus.bottomRight * scale + translation,
    );
    final safe = area.deflate(math.min(24, area.shortestSide / 4));
    var dx = 0.0;
    var dy = 0.0;
    if (root.left < safe.left) dx = safe.left - root.left;
    if (root.right > safe.right) dx = safe.right - root.right;
    if (root.top < safe.top) dy = safe.top - root.top;
    if (root.bottom > safe.bottom) dy = safe.bottom - root.bottom;
    translation += Offset(dx, dy);
    _scale = scale;
    _translation = translation;
  }

  /// 下次布局时重新按内容摆放（换了一张图）。
  void resetPlacement() => _initialized = false;

  /// 适应屏幕：整张图放进视口（最大 [maxFitScale] 倍）。
  void fit(
    Rect bounds,
    Size viewport, {
    EdgeInsets padding = EdgeInsets.zero,
    double maxFitScale = 1.2,
    Duration duration = Duration.zero,
    Curve curve = Curves.easeOutCubic,
  }) {
    final scale = _fitScale(
      bounds,
      viewport,
      padding,
    ).clamp(minScale, maxFitScale);
    final area = padding.deflateRect(Offset.zero & viewport);
    animateTo(
      scale,
      area.center - bounds.center * scale,
      duration: duration,
      curve: curve,
    );
  }

  /// 以 [content] 的中心对准视口中心，缩放到 [scale]（缺省不变）。
  void centerOn(
    Offset content,
    Size viewport, {
    double? scale,
    EdgeInsets padding = EdgeInsets.zero,
    Duration duration = Duration.zero,
    Curve curve = Curves.easeOutCubic,
  }) {
    final next = (scale ?? _scale).clamp(minScale, maxScale);
    final area = padding.deflateRect(Offset.zero & viewport);
    animateTo(
      next,
      area.center - content * next,
      duration: duration,
      curve: curve,
    );
  }

  /// [content] 在屏幕上出了 [padding] 留出的可见区时，平移到刚好露出来。
  void ensureVisible(
    Rect content,
    Size viewport, {
    EdgeInsets padding = EdgeInsets.zero,
    Duration duration = Duration.zero,
    Curve curve = Curves.easeOutCubic,
  }) {
    final area = padding.deflateRect(Offset.zero & viewport);
    if (area.isEmpty) return;
    final rect = toScreenRect(content);
    var dx = 0.0;
    var dy = 0.0;
    if (rect.width > area.width) {
      dx = area.left - rect.left;
    } else if (rect.left < area.left) {
      dx = area.left - rect.left;
    } else if (rect.right > area.right) {
      dx = area.right - rect.right;
    }
    if (rect.height > area.height) {
      dy = area.top - rect.top;
    } else if (rect.top < area.top) {
      dy = area.top - rect.top;
    } else if (rect.bottom > area.bottom) {
      dy = area.bottom - rect.bottom;
    }
    if (dx == 0 && dy == 0) return;
    animateTo(
      _scale,
      _translation + Offset(dx, dy),
      duration: duration,
      curve: curve,
    );
  }

  /// 松手后：内容整个跑出视口时拉回来，至少露出 [keep] 像素。
  void settle(
    Rect bounds,
    Size viewport, {
    double keep = 96,
    Duration duration = Duration.zero,
  }) {
    final rect = toScreenRect(bounds);
    var dx = 0.0;
    var dy = 0.0;
    if (rect.right < keep) dx = keep - rect.right;
    if (rect.left > viewport.width - keep) {
      dx = viewport.width - keep - rect.left;
    }
    if (rect.bottom < keep) dy = keep - rect.bottom;
    if (rect.top > viewport.height - keep) {
      dy = viewport.height - keep - rect.top;
    }
    if (dx == 0 && dy == 0) return;
    animateTo(_scale, _translation + Offset(dx, dy), duration: duration);
  }

  /// 动画到指定变换；[duration] 为 0 时直接到位。
  void animateTo(
    double scale,
    Offset translation, {
    Duration duration = Duration.zero,
    Curve curve = Curves.easeOutCubic,
  }) {
    _stopAnimation();
    final controller = _animation;
    if (duration == Duration.zero || controller == null) {
      _set(scale, translation);
      return;
    }
    final fromScale = _scale;
    final fromTranslation = _translation;
    // 缩放在对数空间插值：放大缩小的速度感一致。
    final logFrom = math.log(fromScale);
    final logTo = math.log(scale);
    void listener() {
      final t = curve.transform(controller.value.clamp(0.0, 1.0));
      final s = math.exp(logFrom + (logTo - logFrom) * t);
      // 平移与缩放一起插值时，用“视口中心对应的内容点”插值才不会先甩
      // 出去再回来；这里两端都是同一视口，直接按端点插值已足够平滑。
      _set(s, Offset.lerp(fromTranslation, translation, t)!);
    }

    _animationListener = listener;
    controller
      ..value = 0
      ..addListener(listener);
    controller.animateTo(1, duration: duration, curve: Curves.linear);
  }

  void _stopAnimation() {
    final controller = _animation;
    if (controller == null) return;
    if (_animationListener case final listener?) {
      controller.removeListener(listener);
      _animationListener = null;
    }
    controller.stop();
  }

  static double _fitScale(Rect bounds, Size viewport, EdgeInsets padding) {
    final area = padding.deflateRect(Offset.zero & viewport);
    if (bounds.isEmpty || area.isEmpty) return 1;
    return math.min(area.width / bounds.width, area.height / bounds.height);
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }
}
