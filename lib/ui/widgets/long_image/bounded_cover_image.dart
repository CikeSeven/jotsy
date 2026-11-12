import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// cover 缩略图的解码器包装：在编码头给出原图尺寸后，计算铺满容器所需的
/// 最小等比尺寸，不必先读一遍文件来判断横竖，也不按猜测放大两倍解码。
///
/// 只处理像素尺寸；文件/网络读取、动画帧与错误仍交给原 provider。缓存键
/// 包含原图键和目标尺寸，布局与长图对齐监听共用同一次解码。失败后逐出缓存，
/// 下次进入可重试。超长图除纹理边长上限外再限总像素，防止一张小封面占去
/// 大片图像缓存；原图与看图页的解码不受影响。
class BoundedCoverImage extends ImageProvider<BoundedCoverImageKey> {
  const BoundedCoverImage(
    this.imageProvider, {
    required this.width,
    required this.height,
    required this.maxExtent,
  });

  final ImageProvider imageProvider;
  final int width;
  final int height;
  final int maxExtent;
  static const int maxPixels = 4 * 1024 * 1024;

  @override
  Future<BoundedCoverImageKey> obtainKey(ImageConfiguration configuration) =>
      imageProvider
          .obtainKey(configuration)
          .then((key) => BoundedCoverImageKey(key, width, height, maxExtent));

  @override
  ImageStreamCompleter loadImage(
    BoundedCoverImageKey key,
    ImageDecoderCallback decode,
  ) {
    final completer = imageProvider.loadImage(key.source, (
      buffer, {
      getTargetSize,
    }) {
      assert(getTargetSize == null, 'Do not nest image resize providers.');
      return decode(
        buffer,
        getTargetSize: (intrinsicWidth, intrinsicHeight) {
          final scale = <double>[
            1,
            math.max(width / intrinsicWidth, height / intrinsicHeight),
            maxExtent / intrinsicWidth,
            maxExtent / intrinsicHeight,
            math.sqrt(maxPixels / (intrinsicWidth * intrinsicHeight)),
          ].reduce(math.min);
          return ui.TargetImageSize(
            width: (intrinsicWidth * scale).ceil().clamp(1, maxExtent),
            height: (intrinsicHeight * scale).ceil().clamp(1, maxExtent),
          );
        },
      );
    });
    completer.addEphemeralErrorListener((error, stack) {
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
    });
    return completer;
  }

  @override
  bool operator ==(Object other) =>
      other is BoundedCoverImage &&
      imageProvider == other.imageProvider &&
      width == other.width &&
      height == other.height &&
      maxExtent == other.maxExtent;

  @override
  int get hashCode => Object.hash(imageProvider, width, height, maxExtent);
}

@immutable
class BoundedCoverImageKey {
  const BoundedCoverImageKey(
    this.source,
    this.width,
    this.height,
    this.maxExtent,
  );

  final Object source;
  final int width;
  final int height;
  final int maxExtent;

  @override
  bool operator ==(Object other) =>
      other is BoundedCoverImageKey &&
      source == other.source &&
      width == other.width &&
      height == other.height &&
      maxExtent == other.maxExtent;

  @override
  int get hashCode => Object.hash(source, width, height, maxExtent);
}
