import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../models/diary_image_embed_data.dart';

/// 拖动小图时浮在最上层的截图这一帧画在哪里、什么样子。
class DiaryThumbnailFloatFrame {
  const DiaryThumbnailFloatFrame({
    required this.image,
    required this.source,
    required this.rect,
    required this.scale,
    required this.elevation,
  });

  /// 整格的截图。
  final ui.Image image;

  /// 画面在截图里的矩形（像素）。
  final Rect source;

  /// 画面未缩放时的矩形（全局坐标）。
  final Rect rect;

  /// 绕画面中心的缩放。
  final double scale;

  /// 阴影的浓淡（0–1）。
  final double elevation;
}

/// 拖动小图时的截图层（插在页面路由的 Overlay 里，盖住整页、不接触点）。
///
/// 只画不建：每帧由拖动层的 [repaint] 通知重画，位置在绘制阶段才向
/// [frame] 取——手指、自动滚动与飞行都只改数据，不重建任何 widget。
/// [frame] 返回 null 时什么都不画（拖动已结束、截图可能已释放）。
class DiaryThumbnailFloat extends LeafRenderObjectWidget {
  const DiaryThumbnailFloat({
    super.key,
    required this.frame,
    required this.repaint,
    required this.shadows,
  });

  final DiaryThumbnailFloatFrame? Function() frame;
  final Listenable repaint;

  /// 完全拿起时的阴影，随 [DiaryThumbnailFloatFrame.elevation] 淡入淡出。
  final List<BoxShadow> shadows;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderDiaryThumbnailFloat(
        frame: frame,
        repaint: repaint,
        shadows: shadows,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderDiaryThumbnailFloat renderObject,
  ) => renderObject.update(frame: frame, repaint: repaint, shadows: shadows);
}

/// [DiaryThumbnailFloat] 的绘制：铺满 Overlay，不参与命中测试。
class RenderDiaryThumbnailFloat extends RenderBox {
  RenderDiaryThumbnailFloat({
    required this.frame,
    required this.repaint,
    required this.shadows,
  });

  DiaryThumbnailFloatFrame? Function() frame;
  Listenable repaint;
  List<BoxShadow> shadows;

  void update({
    required DiaryThumbnailFloatFrame? Function() frame,
    required Listenable repaint,
    required List<BoxShadow> shadows,
  }) {
    this.frame = frame;
    this.shadows = shadows;
    if (!identical(repaint, this.repaint)) {
      if (attached) this.repaint.removeListener(markNeedsPaint);
      this.repaint = repaint;
      if (attached) repaint.addListener(markNeedsPaint);
    }
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    repaint.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    repaint.removeListener(markNeedsPaint);
    super.detach();
  }

  /// 每帧都重画：自成一层，不连带 Overlay 里的页面一起重画。
  @override
  bool get isRepaintBoundary => true;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  void paint(PaintingContext context, Offset offset) {
    final frame = this.frame();
    if (frame == null) return;
    final rect = frame.rect.shift(offset - localToGlobal(Offset.zero));
    final drawn = Rect.fromCenter(
      center: rect.center,
      width: rect.width * frame.scale,
      height: rect.height * frame.scale,
    );
    final shape = RRect.fromRectAndRadius(
      drawn,
      Radius.circular(kDiaryImageThumbnailRadius * frame.scale),
    );
    final canvas = context.canvas;
    if (frame.elevation > 0) {
      for (final shadow in shadows) {
        final paint = shadow
            .copyWith(
              color: shadow.color.withValues(
                alpha: shadow.color.a * frame.elevation,
              ),
            )
            .toPaint();
        canvas.drawRRect(
          shape
              .shift(shadow.offset * frame.elevation)
              .inflate(shadow.spreadRadius),
          paint,
        );
      }
    }
    canvas
      ..save()
      ..clipRRect(shape)
      ..drawImageRect(
        frame.image,
        frame.source,
        drawn,
        Paint()..filterQuality = FilterQuality.medium,
      )
      ..restore();
  }
}
