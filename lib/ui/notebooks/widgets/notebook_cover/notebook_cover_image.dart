import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../widgets/expressive_image_frame.dart';
import '../../../widgets/long_image/long_image_cover_alignment.dart';
import '../../../widgets/long_image/long_image_policy.dart';

/// 封面图：按显示尺寸保持比例解码、cover 裁切、首次解码淡入。文件已不存在
/// 或解码失败时什么也不画，露出底下的容器色。
///
/// 取景（[style] 的对齐点与放大）：
/// - 默认取景（居中、不放大）沿用 [CoverCroppedImage]：长图顶部对齐露出
///   开头，其余居中；
/// - 自定义取景时以取景为准：图片放进放大 zoom 倍的框里 cover 裁切，框与
///   图片按同一个对齐点摆放，再裁到显示框——与 `NotebookCoverCrop` 的
///   几何一致，不需要预先知道图片尺寸。
///
/// 解码尺寸：只给 [width] 且默认取景时与改版前一致（按宽度解码）。给了
/// [height] 或自定义取景时按长边 × 放大倍数 × 1.5 解码——竖框里的横图
/// cover 时按高度铺满，只按宽度解码会被放大发糊；不知道图片比例，1.5 倍
/// 兜住常见的 4:3 与 16:9（封面数量少，多出的内存可以接受）。
class NotebookCoverImage extends StatelessWidget {
  const NotebookCoverImage({
    super.key,
    required this.path,
    required this.width,
    this.height,
    this.style = NotebookCoverStyle.defaults,
  });

  final String path;

  /// 显示宽度（逻辑像素），决定解码尺寸。
  final double width;

  /// 显示高度；竖长的显示框（满版、贴签、极简）给出，解码更清楚。
  final double? height;

  /// 只读取景部分（对齐点与放大）。
  final NotebookCoverStyle style;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final file = FileImage(File(path));
    if (style.hasDefaultCrop && height == null) {
      return CoverCroppedImage(
        image: boundedImageProvider(file, width: (width * dpr).round()),
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }
    final extent = math.max(width, height ?? 0) * style.zoom * 1.5;
    final image = boundedImageProvider(file, width: (extent * dpr).round());
    if (style.hasDefaultCrop) {
      return CoverCroppedImage(
        image: image,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }
    final alignment = Alignment(style.focusX, style.focusY);
    return ClipRect(
      // 放大 zoom 倍的框按对齐点摆放（可超出显示框），框里再 cover 裁切。
      child: FractionallySizedBox(
        widthFactor: style.zoom,
        heightFactor: style.zoom,
        alignment: alignment,
        child: Image(
          image: image,
          fit: BoxFit.cover,
          alignment: alignment,
          filterQuality: FilterQuality.medium,
          frameBuilder: expressiveImageFrameBuilder,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
