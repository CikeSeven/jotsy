import 'dart:io';
import 'dart:ui' as ui show Image;

import 'package:flutter/material.dart';

import '../../../widgets/image_viewer_hero.dart';
import '../../viewmodels/diary_text_appearance.dart';
import '../publish_diary_cover_sliver.dart';

/// 预览页头图（sliver）：随滚动折叠的 [PublishDiaryCoverSliver]，是列表封面
/// 共享元素的落点。分享长图期间换成固定高度的静态头图，避免折叠动画在长图
/// 拼接处留下拖影。
class DiaryPreviewCover extends StatelessWidget {
  const DiaryPreviewCover({
    super.key,
    required this.diaryId,
    required this.source,
    required this.staticCover,
    required this.onTap,
    this.placeholder,
  });

  /// 头图框高度。
  static const double height = 420;

  final String diaryId;
  final String source;
  final bool staticCover;

  /// 列表封面抓取的画面：飞入的落点与解码前的占位。
  final ui.Image? placeholder;
  final ValueChanged<ImageViewerHero?> onTap;

  @override
  Widget build(BuildContext context) {
    if (staticCover) {
      return SliverToBoxAdapter(
        child: SizedBox(
          width: double.infinity,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
            ),
            child: _StaticCoverImage(source: source),
          ),
        ),
      );
    }
    return PublishDiaryCoverSliver(
      cover: source,
      maxExtentHeight: height,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.zero,
      heroTag: diaryCoverHeroTag(diaryId),
      placeholder: placeholder,
      onTap: onTap,
    );
  }
}

/// 分享长图用的静态头图：不淡入（截图不等解码，淡入中途会截到半透明）。
class _StaticCoverImage extends StatelessWidget {
  const _StaticCoverImage({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(source);
    final isRemote =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    // 头图框固定高 420，按设备像素比换算解码上限，避免把原图整张解码进
    // 内存（多图日记内存峰值会明显升高）。
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheHeight = (DiaryPreviewCover.height * dpr).round();
    if (isRemote) {
      return Image.network(
        source,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        cacheHeight: cacheHeight,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }
    return Image.file(
      File(source),
      fit: BoxFit.contain,
      alignment: Alignment.center,
      cacheHeight: cacheHeight,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}

/// 预览页标题（sliver）：headlineSmall 特粗，字体跟随正文字体设置。
class DiaryPreviewTitle extends StatelessWidget {
  const DiaryPreviewTitle({
    super.key,
    required this.title,
    required this.appearance,
  });

  final String title;
  final DiaryTextAppearance appearance;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Text(
          title,
          style: appearance.titleStyle(
            Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
