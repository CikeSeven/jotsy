import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../models/notebook_cover_crop.dart';

/// 取景页的状态：当前取景、图片与取景框的尺寸，以及把手势换算成取景。
///
/// 输入：打开时的封面样式（取其取景部分）；视图在布局时写入 [frame]，图片
/// 解码后写入 [imageSize]。输出：[crop] 与 [result]（把取景写回样式，版式与
/// 纹理原样保留）。不读写数据库，页面返回时由编辑页决定是否采用。
///
/// 手势是增量处理的：每次更新先按手指位移平移（手指下那一点跟着手指走），
/// 再以当前手指位置为中心缩放到“起手时的倍数 × 手势倍数”——这样双指边
/// 移动边缩放时，捏住的那一点始终在两指之间。图片尺寸未知（还在解码）时
/// 手势不生效。
class NotebookCoverCropController extends ChangeNotifier {
  NotebookCoverCropController(NotebookCoverStyle style)
    : _style = style,
      _crop = NotebookCoverCrop.of(style);

  final NotebookCoverStyle _style;

  NotebookCoverCrop _crop;
  NotebookCoverCrop get crop => _crop;

  /// 取景框尺寸（逻辑像素）；由视图在布局时写入，不触发通知。
  Size frame = Size.zero;

  Size? _imageSize;

  /// 图片的像素尺寸（只用到比例）；null 为还没解码好。
  Size? get imageSize => _imageSize;
  set imageSize(Size? value) {
    if (value == _imageSize) return;
    _imageSize = value;
    notifyListeners();
  }

  double _gestureStartZoom = 1;

  /// 可以“重置”：当前不是默认取景。
  bool get canReset => !_crop.isInitial;

  /// 把当前取景写回打开时的样式。
  NotebookCoverStyle get result => _crop.applyTo(_style);

  bool get _ready => _imageSize != null && !frame.isEmpty;

  void _update(NotebookCoverCrop next) {
    if (next == _crop) return;
    _crop = next;
    notifyListeners();
  }

  void beginGesture() => _gestureStartZoom = _crop.zoom;

  /// 一次缩放手势更新：[focal] 为取景框坐标里的手指中心，[focalDelta] 为
  /// 这一帧的位移，[scale] 为相对起手时的倍数（单指拖动时为 1）。
  void updateGesture({
    required Offset focal,
    required Offset focalDelta,
    required double scale,
  }) {
    if (!_ready) return;
    final image = _imageSize!;
    var next = _crop.panBy(focalDelta, frame, image);
    if (scale != 1) {
      next = next.zoomAround(_gestureStartZoom * scale, focal, frame, image);
    }
    _update(next);
  }

  /// 鼠标滚轮：向上滚放大、向下缩小，以指针为中心。
  void zoomByScroll(double scrollDelta, Offset focal) {
    if (!_ready || scrollDelta == 0) return;
    final factor = math.exp(-scrollDelta / 400);
    _update(_crop.zoomAround(_crop.zoom * factor, focal, frame, _imageSize!));
  }

  /// 缩放滑块：以取景框中心缩放。
  void zoomTo(double zoom) {
    if (!_ready) return;
    _update(
      _crop.zoomAround(zoom, frame.center(Offset.zero), frame, _imageSize!),
    );
  }

  void reset() => _update(NotebookCoverCrop.initial);
}
