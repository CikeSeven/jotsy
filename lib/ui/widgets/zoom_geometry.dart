import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 缩放视口的几何换算（[DoubleTapZoomViewer] 用）：纯函数，不持有状态。
///
/// 变换一律是 x' = s·x + t（没有旋转），内容左上角对齐视口左上角；缩放
/// 一律从 [Matrix4.getMaxScaleOnAxis] 读取。
/// 输入：[viewport] 视口尺寸、[content] 内容在缩放 1 时的尺寸（普通模式与
/// 视口相同，长内容宽同视口、高更高）、缩放上限 [maxScale]（下限恒为 1）。
@immutable
class ZoomGeometry {
  const ZoomGeometry({
    required this.viewport,
    required this.content,
    required this.maxScale,
  });

  static const double minScale = 1;

  /// 越界阻尼：超出范围的部分按对数空间的这个指数跟手，越捏越“沉”。
  static const double _rubberBandExponent = 0.35;

  /// 阻尼后最多缩到原始大小的这个比例，避免两指几乎并拢时缩成一个点。
  static const double _rubberBandFloor = 0.5;

  final Size viewport;
  final Size content;
  final double maxScale;

  /// 把 [scale] 与平移 [translation] 组成变换，并把平移夹回不露白的范围：
  /// 某个方向上内容放大后仍比视口长时，夹在 [视口 - 内容·s, 0]；比视口短
  /// （只出现在捏合越过下限的阻尼中）时居中。
  Matrix4 clamped(double scale, Offset translation) {
    double axis(double offset, double viewportExtent, double contentExtent) {
      final scaled = contentExtent * scale;
      if (scaled <= viewportExtent) {
        return (viewportExtent - scaled) / 2;
      }
      return offset.clamp(viewportExtent - scaled, 0.0);
    }

    return Matrix4.translationValues(
      axis(translation.dx, viewport.width, content.width),
      axis(translation.dy, viewport.height, content.height),
      0,
      // Z 轴也按同一比例缩放（与 InteractiveViewer 一致）：getMaxScaleOnAxis
      // 取三个轴的最大值，Z 留 1 时缩小到 1 以下会被读成 1。
    )..scaleByDouble(scale, scale, scale, 1);
  }

  /// 以 [focal]（视口坐标）为不动点把 [current] 缩放到 [scale]，再夹回范围。
  ///
  /// focal 对应的内容点 p = (focal - t₀) / s₀，要求缩放后仍落在 focal 下，
  /// 得 t₁ = focal - p·s₁。普通模式从原始大小起算时 t₁ = focal·(1 - s)，天然
  /// 落在范围内，夹取只防边缘点按的坐标略微越界。
  Matrix4 scaledAt(Matrix4 current, Offset focal, double scale) {
    return clamped(scale, focal - contentPointAt(current, focal) * scale);
  }

  /// 视口坐标 [focal] 在 [current] 下对应的内容坐标。
  static Offset contentPointAt(Matrix4 current, Offset focal) {
    final scale = current.getMaxScaleOnAxis();
    final translation = current.getTranslation();
    return Offset(
      (focal.dx - translation.x) / scale,
      (focal.dy - translation.y) / scale,
    );
  }

  /// 捏合中的越界阻尼：范围内原样返回；低于 1 或高于 [maxScale] 时超出的
  /// 比例取 [_rubberBandExponent] 次方，松手后回弹到边界。手指感到“到头了”，
  /// 而不是突然捏不动。
  double rubberBand(double raw) {
    if (raw < minScale) {
      final damped =
          minScale * math.pow(raw / minScale, _rubberBandExponent).toDouble();
      return math.max(damped, minScale * _rubberBandFloor);
    }
    if (raw > maxScale) {
      return maxScale *
          math.pow(raw / maxScale, _rubberBandExponent).toDouble();
    }
    return raw;
  }

  /// [rubberBand] 的逆：新一段捏合从阻尼中的画面接着开始（中途抬起一根
  /// 手指、或回弹途中又捏）时据此还原未阻尼的起点，画面不跳。
  double unband(double scale) {
    if (scale < minScale) {
      return minScale *
          math.pow(scale / minScale, 1 / _rubberBandExponent).toDouble();
    }
    if (scale > maxScale) {
      return maxScale *
          math.pow(scale / maxScale, 1 / _rubberBandExponent).toDouble();
    }
    return scale;
  }
}
