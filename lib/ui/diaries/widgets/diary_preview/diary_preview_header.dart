import 'dart:ui' as ui show Image;

import 'package:flutter/material.dart';

import '../../../widgets/image_viewer_hero.dart';
import '../../models/diary_preview_style/diary_preview_style.dart';
import '../../viewmodels/diary_preview_resolved_style.dart';
import '../../viewmodels/diary_text_appearance.dart';
import '../diary_image_source.dart';
import '../publish_diary_cover_sliver.dart';

/// 预览页头图（sliver）：通栏或内嵌的 [PublishDiaryCoverSliver]，是列表封面
/// 共享元素的落点。分享长图期间换成固定高度的静态头图，避免折叠动画在长图
/// 拼接处留下拖影。
class DiaryPreviewCover extends StatelessWidget {
  const DiaryPreviewCover({
    super.key,
    required this.heroTag,
    required this.source,
    required this.resolved,
    required this.staticCover,
    required this.onTap,
    this.placeholder,
  });

  /// 共享元素标签（列表封面飞入的落点、点按进看图页的起点）。
  final Object? heroTag;
  final String source;
  final DiaryPreviewResolvedStyle resolved;
  final bool staticCover;

  /// 列表封面抓取的画面：飞入的落点与解码前的占位。
  final ui.Image? placeholder;
  final ValueChanged<ImageViewerHero?> onTap;

  @override
  Widget build(BuildContext context) {
    final cover = resolved.style.cover;
    final inset = cover.mode == DiaryPreviewCoverMode.inset;
    final padding = inset
        ? EdgeInsets.fromLTRB(
            resolved.horizontalPadding,
            4,
            resolved.horizontalPadding,
            0,
          )
        : EdgeInsets.zero;
    final radius = inset
        ? BorderRadius.circular(cover.radius)
        : BorderRadius.zero;
    final fill = cover.fit == DiaryPreviewCoverFit.cover;
    if (staticCover) {
      Widget image = SizedBox(
        width: double.infinity,
        height: resolved.coverHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(color: resolved.background),
          child: _StaticCoverImage(
            source: source,
            height: resolved.coverHeight,
            fill: fill,
          ),
        ),
      );
      if (inset) {
        image = Padding(
          padding: padding,
          child: ClipRRect(borderRadius: radius, child: image),
        );
      }
      return SliverToBoxAdapter(child: image);
    }
    return PublishDiaryCoverSliver(
      cover: source,
      maxExtentHeight: resolved.coverHeight,
      padding: padding,
      borderRadius: radius,
      heroTag: heroTag,
      placeholder: placeholder,
      onTap: onTap,
      background: resolved.background,
      fillFrame: fill,
      collapseEffect: cover.fadeOnScroll,
    );
  }
}

/// 分享长图用的静态头图：不淡入（截图不等解码，淡入中途会截到半透明）。
class _StaticCoverImage extends StatelessWidget {
  const _StaticCoverImage({
    required this.source,
    required this.height,
    required this.fill,
  });

  final String source;
  final double height;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    // 按头图框高度与设备像素比换算解码上限，避免把原图整张解码进内存
    // （多图日记内存峰值会明显升高）。
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Image(
      image: ResizeImage.resizeIfNeeded(
        null,
        (height * dpr).round(),
        diaryImageProvider(source),
      ),
      fit: fill ? BoxFit.cover : BoxFit.contain,
      alignment: Alignment.center,
      width: fill ? double.infinity : null,
      height: fill ? double.infinity : null,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}

/// 预览页标题（sliver）：以 headlineSmall 为基准按样式缩放字号、设字重、
/// 对齐与颜色；字体跟随正文字体设置（[DiaryTextAppearance.titleStyle]）。
class DiaryPreviewTitle extends StatelessWidget {
  const DiaryPreviewTitle({
    super.key,
    required this.title,
    required this.appearance,
    required this.resolved,
    required this.topPadding,
  });

  final String title;
  final DiaryTextAppearance appearance;
  final DiaryPreviewResolvedStyle resolved;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final style = resolved.style.title;
    final base = Theme.of(context).textTheme.headlineSmall;
    final weight = switch (style.weight) {
      DiaryPreviewTitleWeight.regular => FontWeight.w400,
      DiaryPreviewTitleWeight.medium => FontWeight.w500,
      DiaryPreviewTitleWeight.bold => FontWeight.w700,
      DiaryPreviewTitleWeight.heavy => FontWeight.w800,
    };
    final fontSize = base?.fontSize;
    final scaled = base?.copyWith(
      fontWeight: weight,
      fontSize: style.scale == 1 || fontSize == null
          ? null
          : fontSize * style.scale,
      color: resolved.titleColor,
    );
    return DiaryPreviewSection(
      resolved: resolved,
      top: topPadding,
      child: Text(
        title,
        textAlign: style.align == DiaryPreviewAlign.center
            ? TextAlign.center
            : null,
        style: appearance.titleStyle(scaled),
      ),
    );
  }
}

/// 预览页里的一段内容（sliver）：左右按样式留边，开启“限制正文宽度”时在
/// 宽屏上居中排到最大宽度。
class DiaryPreviewSection extends StatelessWidget {
  const DiaryPreviewSection({
    super.key,
    required this.resolved,
    required this.child,
    this.top = 0,
    this.bottom = 0,
  });

  final DiaryPreviewResolvedStyle resolved;
  final Widget child;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final padded = Padding(
      padding: EdgeInsets.fromLTRB(
        resolved.horizontalPadding,
        top,
        resolved.horizontalPadding,
        bottom,
      ),
      child: child,
    );
    final maxWidth = resolved.maxContentWidth;
    return SliverToBoxAdapter(
      child: maxWidth == null
          ? padded
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: padded,
              ),
            ),
    );
  }
}
