import 'dart:io';

import 'package:flutter/material.dart';

import '../../widgets/expressive_image_frame.dart';
import '../../widgets/image_viewer_hero.dart';

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
    // 只限制解码宽度：同时指定 cacheWidth/cacheHeight 会按默认的
    // ResizeImagePolicy.exact 把非方形原图压成正方形，BoxFit.cover 再裁切时
    // 画面已被拉伸变形。与探索页 ExploreMediaThumb 的策略保持一致。
    final cacheWidth = (size * dpr).round();
    final uri = Uri.tryParse(source);
    final isRemote =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');

    final image = isRemote
        ? Image.network(
            source,
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            filterQuality: FilterQuality.low,
            frameBuilder: expressiveImageFrameBuilder,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          )
        : Image.file(
            File(source),
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            filterQuality: FilterQuality.low,
            frameBuilder: expressiveImageFrameBuilder,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
