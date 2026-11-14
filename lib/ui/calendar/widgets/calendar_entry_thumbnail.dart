import 'dart:io';

import 'package:flutter/material.dart';

import '../../widgets/image_viewer_hero.dart';
import '../../widgets/long_image/long_image_cover_alignment.dart';
import '../../widgets/long_image/long_image_policy.dart';

/// 日历里日记条目的小封面缩略图（时间线、那年今日共用）。
///
/// 缩略图是预览页头图的共享元素来源：构建时把所在 context 记到 [anchor]，
/// 点按条目时由调用方 `anchor.capture` 抓取已绘制的画面，飞入预览页后展开
/// 成完整头图（与日记列表封面一致）。
class CalendarEntryThumbnail extends StatelessWidget {
  const CalendarEntryThumbnail({
    super.key,
    required this.source,
    required this.diaryId,
    required this.anchor,
    this.size = 52,
    this.radius = 10,
  });

  final String source;
  final String diaryId;
  final ImageViewerHeroAnchor anchor;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // 解码器按原图比例铺满方格；无需按猜测过度解码，也不先读一次文件头。
    final cacheWidth = (size * dpr).round();
    final uri = Uri.tryParse(source);
    final isRemote =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');

    final image = CoverCroppedImage(
      image: boundedImageProvider(
        isRemote ? NetworkImage(source) : FileImage(File(source)),
        width: cacheWidth,
        height: cacheWidth,
        cover: true,
      ),
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );

    final borderRadius = BorderRadius.all(Radius.circular(radius));
    return Builder(
      builder: (BuildContext thumbContext) {
        anchor.context = thumbContext;
        return ImageViewerHeroSource(
          tag: diaryCoverHeroTag(diaryId),
          borderRadius: borderRadius,
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Container(
              width: size,
              height: size,
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              child: image,
            ),
          ),
        );
      },
    );
  }
}
