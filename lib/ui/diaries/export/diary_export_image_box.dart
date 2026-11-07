import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

import '../../widgets/long_image/long_image_policy.dart';
import '../models/diary_image_embed_data.dart';
import '../models/diary_thumbnail_rows.dart';
import 'diary_export_blocks.dart';

/// 正文图片在导出里的显示框：PDF、Word 与网页共用同一口径，与应用里看到的
/// 一致（`DiaryEmbeddedImage` / `DiaryImageThumbnail`）。纯计算，无 IO。
///
/// 单位是应用的逻辑像素：应用把原图的像素当逻辑像素显示、不放大小图；纸面
/// 按 96 DPI 换算（1px = 0.75pt，与 Word 的 EMU 换算同一口径）。
/// - 小图（[ExportBlock.imageThumbnail]）见方、带圆角，边长与应用同一口径
///   （[diaryThumbnailExtentFor]：版心放得下一排三张，最大
///   [kDiaryImageThumbnailExtent]，单独一张也取这个边长），画面按 cover
///   裁切：长图保留顶部，其余居中，裁去的比例见 [cropLeft] 等（Word 写成
///   `a:srcRect`）；并排的一排由写出器摆放（[exportThumbnailRowEnd]），每张
///   仍按这里的框画；
/// - 其余按原始尺寸，缩放菜单或导入写入的宽高（[ExportBlock.imageMaxWidth] /
///   [ExportBlock.imageMaxHeight]）与写出器给的版心（`maxWidth` /
///   `maxHeight`）都只作上限，按原比例缩小、从不放大。
@immutable
class ExportImageBox {
  const ExportImageBox._(
    this.width,
    this.height, {
    this.thumbnail = false,
    this.cropLeft = 0,
    this.cropTop = 0,
    this.cropRight = 0,
    this.cropBottom = 0,
  });

  /// [block] 是图片块，[width] × [height] 为原图像素（都大于 0）。
  factory ExportImageBox.of(
    ExportBlock block,
    int width,
    int height, {
    double maxWidth = double.infinity,
    double maxHeight = double.infinity,
  }) {
    final w = width.toDouble();
    final h = height.toDouble();
    if (block.imageThumbnail) {
      final side = diaryThumbnailExtentFor(maxWidth);
      if (w > h) {
        final cut = (1 - h / w) / 2;
        return ExportImageBox._(
          side,
          side,
          thumbnail: true,
          cropLeft: cut,
          cropRight: cut,
        );
      }
      if (h > w) {
        final cut = 1 - w / h;
        // 长图与应用一样露出开头（LongImageCoverAlignment）。
        final top = isLongImageSize(Size(w, h)) ? 0.0 : cut / 2;
        return ExportImageBox._(
          side,
          side,
          thumbnail: true,
          cropTop: top,
          cropBottom: cut - top,
        );
      }
      return ExportImageBox._(side, side, thumbnail: true);
    }
    final scale = <double>[
      1,
      (block.imageMaxWidth ?? double.infinity) / w,
      (block.imageMaxHeight ?? double.infinity) / h,
      maxWidth / w,
      maxHeight / h,
    ].reduce(math.min);
    return ExportImageBox._(w * scale, h * scale);
  }

  /// 显示宽高（逻辑像素）。
  final double width;
  final double height;

  /// 以小图显示：方形、圆角为 [kDiaryImageThumbnailRadius]。
  final bool thumbnail;

  /// 小图 cover 裁切时原图各边裁去的比例（0–1）；不裁切时都为 0。
  final double cropLeft;
  final double cropTop;
  final double cropRight;
  final double cropBottom;

  /// 裁切时保留的是图片顶部（长图的小图），否则居中。
  bool get keepsTop => cropTop == 0 && cropBottom > 0;

  /// 圆角半径（逻辑像素）：小图与应用一致，其余不加。
  double get radius => thumbnail ? kDiaryImageThumbnailRadius : 0;
}
