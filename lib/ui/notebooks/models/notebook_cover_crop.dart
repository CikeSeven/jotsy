import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';

/// 封面图取景的几何（纯计算，不依赖组件）：cover 裁切后再放大 [zoom] 倍，
/// 按对齐点 ([x], [y]) 取景。
///
/// 显示框 `frame` 里图片的绘制矩形：
///
/// ```text
/// scale = max(frame.w / image.w, frame.h / image.h) × zoom
/// drawn = image × scale
/// left  = (frame.w − drawn.w) × (x + 1) / 2
/// top   = (frame.h − drawn.h) × (y + 1) / 2
/// ```
///
/// zoom 为 1 时与 `Image(fit: BoxFit.cover, alignment: Alignment(x, y))`
/// 完全一致，所以显示端（`NotebookCoverImage`）不必知道图片尺寸，只要把
/// 图片放进放大 zoom 倍的框再按同一个对齐点摆放；取景页（拖动、缩放）才
/// 需要图片尺寸，用这里的换算把手势位移变回对齐点。
///
/// 某一方向图片恰好铺满（溢出为 0）时，那个方向的对齐点不影响画面，平移
/// 保留原值不动，之后放大了再接着生效。
@immutable
class NotebookCoverCrop {
  const NotebookCoverCrop({this.x = 0, this.y = 0, this.zoom = 1});

  /// 取自封面样式的取景部分。
  NotebookCoverCrop.of(NotebookCoverStyle style)
    : x = style.focusX,
      y = style.focusY,
      zoom = style.zoom;

  static const NotebookCoverCrop initial = NotebookCoverCrop();

  final double x;
  final double y;
  final double zoom;

  bool get isInitial => x == 0 && y == 0 && zoom == 1;

  /// 写回封面样式（版式、纹理不变；数字由 [NotebookCoverStyle] 夹取与取整）。
  NotebookCoverStyle applyTo(NotebookCoverStyle style) =>
      style.copyWith(focusX: x, focusY: y, zoom: zoom);

  /// 图片在显示框坐标系里的绘制矩形；尺寸不合法时为整个显示框。
  Rect imageRect(Size frame, Size image) {
    if (frame.isEmpty || image.isEmpty) return Offset.zero & frame;
    final scale =
        math.max(frame.width / image.width, frame.height / image.height) * zoom;
    final drawn = image * scale;
    return Rect.fromLTWH(
      (frame.width - drawn.width) * (x + 1) / 2,
      (frame.height - drawn.height) * (y + 1) / 2,
      drawn.width,
      drawn.height,
    );
  }

  /// 图片跟着手指移动 [delta]（显示框坐标），移到边缘为止。
  NotebookCoverCrop panBy(Offset delta, Size frame, Size image) {
    final rect = imageRect(frame, image);
    return _withTopLeft(rect.topLeft + delta, rect.size, frame, zoom: zoom);
  }

  /// 以 [focal]（显示框坐标）为中心缩放到 [target]：手指下的那一点不动，
  /// 放到边缘时贴边。[target] 夹到 [NotebookCoverStyle.minZoom]..
  /// [NotebookCoverStyle.maxZoom]。
  NotebookCoverCrop zoomAround(
    double target,
    Offset focal,
    Size frame,
    Size image,
  ) {
    final next = target
        .clamp(NotebookCoverStyle.minZoom, NotebookCoverStyle.maxZoom)
        .toDouble();
    final rect = imageRect(frame, image);
    if (rect.isEmpty) return NotebookCoverCrop(x: x, y: y, zoom: next);
    // 手指下那一点在图片上的相对位置（0..1），缩放后仍要落在手指下。
    final u = (focal.dx - rect.left) / rect.width;
    final v = (focal.dy - rect.top) / rect.height;
    final size = rect.size * (next / zoom);
    final topLeft = Offset(
      focal.dx - u * size.width,
      focal.dy - v * size.height,
    );
    return _withTopLeft(topLeft, size, frame, zoom: next);
  }

  /// 由绘制矩形的左上角反推对齐点：先夹到“图片仍盖满显示框”的范围，再按
  /// `left = −overflow × (x + 1) / 2` 解出 x（y 同理）。
  NotebookCoverCrop _withTopLeft(
    Offset topLeft,
    Size drawn,
    Size frame, {
    required double zoom,
  }) {
    double solve(double offset, double overflow, double current) {
      if (overflow <= 0.0001) return current;
      final clamped = offset.clamp(-overflow, 0.0);
      return (-2 * clamped / overflow - 1).clamp(-1.0, 1.0).toDouble();
    }

    return NotebookCoverCrop(
      x: solve(topLeft.dx, drawn.width - frame.width, x),
      y: solve(topLeft.dy, drawn.height - frame.height, y),
      zoom: zoom,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NotebookCoverCrop &&
      other.x == x &&
      other.y == y &&
      other.zoom == zoom;

  @override
  int get hashCode => Object.hash(x, y, zoom);

  @override
  String toString() => 'NotebookCoverCrop($x, $y, ×$zoom)';
}
