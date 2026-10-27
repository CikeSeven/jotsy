import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/app_platform.dart';
import '../../../app_surface/widgets/app_page_backdrop.dart';
import '../../../widgets/expressive_image_frame.dart';
import '../../controllers/notebook_cover_crop_controller.dart';
import '../notebook_cover_tile.dart';

/// 取景页的取景区：居中一个与封面同为 3:4 的取景框，图片按当前取景画在
/// 框里并延伸到框外，框外盖一层半透明的实色遮罩（页面底色 82%，不是渐变），
/// 框沿描一道 2dp primary。
///
/// 手势：单指拖动平移、双指缩放（桌面为鼠标拖动、触控板捏合），桌面另有
/// 滚轮缩放（只在 [AppPlatform.isDesktop] 生效）。整块区域都可以拖，不必
/// 按在框里。状态与换算在 [NotebookCoverCropController]。
class NotebookCoverCropViewport extends StatelessWidget {
  const NotebookCoverCropViewport({
    super.key,
    required this.controller,
    required this.image,
  });

  final NotebookCoverCropController controller;
  final ImageProvider image;

  /// 取景框四周至少留的空白，与框的最大宽度。
  static const double margin = 32;
  static const double maxFrameWidth = 360;

  /// 在 [area] 里居中、留出 [margin] 的最大 3:4 取景框。
  static Rect frameIn(Size area) {
    final width = math.max(
      0.0,
      math.min(
        math.min(area.width - margin * 2, maxFrameWidth),
        (area.height - margin * 2) * NotebookCoverTile.aspectRatio,
      ),
    );
    final size = Size(width, width / NotebookCoverTile.aspectRatio);
    return Alignment.center.inscribe(size, Offset.zero & area);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scrim = AppPageBackdrop.estimatedColorOf(
      context,
    ).withValues(alpha: 0.82);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final frame = frameIn(constraints.biggest);
        controller.frame = frame.size;
        // 与完整封面同样的圆角比例（132dp 宽时 20dp）。
        final radius = NotebookCoverTile.radius * frame.width / 132;
        Offset local(Offset point) => point - frame.topLeft;
        final viewport = ListenableBuilder(
          listenable: controller,
          builder: (BuildContext context, Widget? child) {
            final imageSize = controller.imageSize;
            final rect = imageSize == null
                ? frame
                : controller.crop
                      .imageRect(frame.size, imageSize)
                      .shift(frame.topLeft);
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: <Widget>[
                Positioned.fromRect(
                  rect: rect,
                  child: Image(
                    image: image,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                    frameBuilder: expressiveImageFrameBuilder,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: NotebookCoverCropScrimPainter(
                      frame: frame,
                      radius: radius,
                      scrim: scrim,
                      border: scheme.primary,
                    ),
                  ),
                ),
              ],
            );
          },
        );
        return ClipRect(
          child: Listener(
            onPointerSignal: (PointerSignalEvent event) {
              if (!AppPlatform.isDesktop || event is! PointerScrollEvent) {
                return;
              }
              GestureBinding.instance.pointerSignalResolver.register(event, (
                PointerSignalEvent event,
              ) {
                final scroll = event as PointerScrollEvent;
                controller.zoomByScroll(
                  scroll.scrollDelta.dy,
                  local(scroll.localPosition),
                );
              });
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: (_) => controller.beginGesture(),
              onScaleUpdate: (ScaleUpdateDetails details) =>
                  controller.updateGesture(
                    focal: local(details.localFocalPoint),
                    focalDelta: details.focalPointDelta,
                    scale: details.scale,
                  ),
              child: viewport,
            ),
          ),
        );
      },
    );
  }
}

/// 取景框外的实色半透明遮罩 + 框沿描边。
class NotebookCoverCropScrimPainter extends CustomPainter {
  const NotebookCoverCropScrimPainter({
    required this.frame,
    required this.radius,
    required this.scrim,
    required this.border,
  });

  final Rect frame;
  final double radius;
  final Color scrim;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(frame, Radius.circular(radius));
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(rrect);
    canvas.drawPath(outside, Paint()..color = scrim);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(NotebookCoverCropScrimPainter oldDelegate) =>
      oldDelegate.frame != frame ||
      oldDelegate.radius != radius ||
      oldDelegate.scrim != scrim ||
      oldDelegate.border != border;
}
