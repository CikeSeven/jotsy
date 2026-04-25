import 'dart:io';

import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/image_cache_extent.dart';

/// 发布页头图 Sliver。
///
/// 提供“上滑逐渐淡出 + 高度收起”的视觉效果。
class PublishDiaryCoverSliver extends StatelessWidget {
  const PublishDiaryCoverSliver({
    super.key,
    required this.cover,
    this.maxExtentHeight = 220,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 8),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
  });

  final String cover;
  final double maxExtentHeight;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: false,
      delegate: _PublishDiaryCoverHeaderDelegate(
        cover: cover,
        maxExtentHeight: maxExtentHeight,
        padding: padding,
        borderRadius: borderRadius,
      ),
    );
  }
}

class _PublishDiaryCoverHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _PublishDiaryCoverHeaderDelegate({
    required this.cover,
    required this.maxExtentHeight,
    required this.padding,
    required this.borderRadius,
  });

  final String cover;
  final double maxExtentHeight;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;

  @override
  double get minExtent => 0;

  @override
  double get maxExtent => maxExtentHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // 计算 0~1 收起进度，用于统一驱动透明度与缩放。
    final extentDelta = (maxExtent - minExtent).abs();
    final collapseProgress =
        (extentDelta <= 0
                ? 0.0
                : (1 - (shrinkOffset / extentDelta)).clamp(0.0, 1.0))
            .toDouble();

    return Padding(
      padding: padding,
      child: Opacity(
        opacity: collapseProgress,
        child: Transform.scale(
          // 收起阶段同时轻微缩放，降低突兀感。
          scale: 0.96 + (collapseProgress * 0.04),
          alignment: Alignment.topCenter,
          child: ClipRRect(
            borderRadius: borderRadius,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
              ),
              child: _CoverImage(cover: cover, displayHeight: maxExtentHeight),
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PublishDiaryCoverHeaderDelegate oldDelegate) {
    return oldDelegate.cover != cover ||
        oldDelegate.maxExtentHeight != maxExtentHeight ||
        oldDelegate.padding != padding ||
        oldDelegate.borderRadius != borderRadius;
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.cover, required this.displayHeight});

  final String cover;
  final double displayHeight;

  bool get _isNetworkImage {
    final uri = Uri.tryParse(cover);
    if (uri == null) {
      return false;
    }
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  @override
  Widget build(BuildContext context) {
    // 封面规则：完整展示原图，不做裁切。
    // 使用 BoxFit.contain 保留图片全部尺寸比例。
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = ImageCacheExtent.fromDisplaySize(
      MediaQuery.sizeOf(context).width,
      dpr,
    );
    final cacheHeight = ImageCacheExtent.fromDisplaySize(displayHeight, dpr);
    if (_isNetworkImage) {
      return Image.network(
        cover,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        errorBuilder: (_, __, ___) => const _CoverFallback(),
      );
    }

    return Image.file(
      File(cover),
      fit: BoxFit.contain,
      alignment: Alignment.center,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      errorBuilder: (_, __, ___) => const _CoverFallback(),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Text(
          context.l10n.autoT0156,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
