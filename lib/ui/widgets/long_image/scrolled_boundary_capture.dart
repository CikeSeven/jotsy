import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 纯 Dart 的长图截取：把 [boundary] 里可滚动的内容逐屏截图，再用
/// [ui.PictureRecorder] 拼成一张 PNG。
///
/// 用在没有原生拼图的平台（桌面；widget_screenshot_plus 的合并只有 Android /
/// iOS 实现）。手机仍走插件，这里不改变手机上的长图。
///
/// - 输入：包住整个可滚动区域的截图边界（通常与视口等高）、该区域的
///   [scrollController]、期望像素比与底色；
/// - 输出：PNG 字节；
/// - 副作用：截图期间会逐屏 `jumpTo` 滚动，结束后滚回开始时的位置。
///
/// 每一屏按它真实的滚动位置画到画布上，最后一屏停在滚动末端、与上一屏重叠
/// 的部分内容相同，直接覆盖即可，不用像插件那样另算偏移。内容只截到
/// [maxLogicalHeight]（与手机上的上限一致）；总像素高超过 [maxPixelHeight]
/// （常见 GPU 纹理上限 16384）时整体降低像素比，宁可略糊也不让超长内容被
/// 截断或生成失败。
Future<Uint8List> captureScrolledBoundary(
  RenderRepaintBoundary boundary, {
  ScrollController? scrollController,
  required double pixelRatio,
  required Color background,
  double maxLogicalHeight = 22000,
  int maxPixelHeight = 16384,
}) async {
  final size = boundary.size;
  if (size.isEmpty) {
    throw StateError('Capture boundary has an empty size');
  }
  final position = scrollController != null && scrollController.hasClients
      ? scrollController.position
      : null;
  final maxExtent = position?.maxScrollExtent ?? 0;
  final contentHeight = math.min(size.height + maxExtent, maxLogicalHeight);
  final ratio = math.min(
    pixelRatio,
    maxPixelHeight / math.max(contentHeight, size.width),
  );

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size.width * ratio, contentHeight * ratio),
    Paint()..color = background,
  );

  final images = <ui.Image>[];
  final start = position?.pixels ?? 0;
  try {
    if (position == null || maxExtent <= 0) {
      final image = await boundary.toImage(pixelRatio: ratio);
      images.add(image);
      canvas.drawImage(image, Offset.zero, Paint());
    } else {
      // 每屏前进一个视口高；最后一屏停在既不超过滚动末端、也不超过截取
      // 上限的位置。
      final step = math.max(1.0, position.viewportDimension);
      final lastOffset = math.max(
        0.0,
        math.min(maxExtent, contentHeight - size.height),
      );
      var offset = 0.0;
      while (true) {
        final target = math.min(offset, lastOffset);
        await _settleAt(scrollController!, target);
        final image = await boundary.toImage(pixelRatio: ratio);
        images.add(image);
        canvas.drawImage(
          image,
          Offset(0, scrollController.position.pixels * ratio),
          Paint(),
        );
        if (target >= lastOffset) break;
        offset += step;
      }
    }
    final picture = recorder.endRecording();
    final stitched = await picture.toImage(
      (size.width * ratio).ceil(),
      (contentHeight * ratio).ceil(),
    );
    picture.dispose();
    try {
      final data = await stitched.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('Long image encoding returned no bytes');
      }
      return data.buffer.asUint8List();
    } finally {
      stitched.dispose();
    }
  } finally {
    for (final image in images) {
      image.dispose();
    }
    if (position != null && scrollController!.hasClients) {
      scrollController.jumpTo(start);
    }
  }
}

/// 滚到 [offset] 并等这一屏真正绘制出来：跳转后的那一帧才会重新布局与
/// 绘制，正文里新进入视口的图片还要再给一帧完成解码后的重绘。这里的
/// 等待是截图同步，不是动画时长。
Future<void> _settleAt(ScrollController controller, double offset) async {
  controller.jumpTo(offset);
  await WidgetsBinding.instance.endOfFrame;
  await Future<void>.delayed(const Duration(milliseconds: 32));
  await WidgetsBinding.instance.endOfFrame;
}
