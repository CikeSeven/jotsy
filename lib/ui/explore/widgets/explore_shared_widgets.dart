import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_surfaces.dart';

/// 探索页通用卡片容器。
class ExploreCard extends StatelessWidget {
  const ExploreCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = colorScheme.brightness == Brightness.light;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: isLight
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.032),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Card.filled(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: ExpressiveSurfaces.cardBorderSide(colorScheme),
        ),
        color: ExpressiveSurfaces.cardColor(colorScheme),
        child: Padding(padding: const EdgeInsets.all(18), child: child),
      ),
    );
  }
}

/// 探索页模块标题（彩色徽章图标 + 标题文案）。
class ExploreSectionTitle extends StatelessWidget {
  const ExploreSectionTitle({
    super.key,
    required this.icon,
    required this.title,
  });

  final FaIconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(9),
          ),
          child: FaIcon(
            icon,
            size: 13,
            color: colorScheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

/// 顶部看板单项。
class ExploreStatTile extends StatelessWidget {
  const ExploreStatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final FaIconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            FaIcon(icon, size: 11, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

/// 媒体缩略图（支持本地与网络）。
class ExploreMediaThumb extends StatelessWidget {
  const ExploreMediaThumb({
    super.key,
    required this.source,
    required this.width,
    required this.height,
    required this.radius,
  });

  final String source;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final resolvedWidth = _resolveFiniteDimension(
          explicit: width,
          constrained: constraints.maxWidth,
        );
        final resolvedHeight = _resolveFiniteDimension(
          explicit: height,
          constrained: constraints.maxHeight,
        );
        final dpr = MediaQuery.devicePixelRatioOf(context);
        // 仅按缩略图容器长边给解码器一个缓存目标，避免同时指定
        // cacheWidth/cacheHeight 把图片预缩放成容器比例，导致后续展示看起来被拉伸。
        // 实际填充仍交给 BoxFit.cover 裁切，从而保留原图比例。
        final cacheExtent = _cacheExtent(
          resolvedWidth >= resolvedHeight ? resolvedWidth : resolvedHeight,
          dpr,
        );
        final cacheWidth = resolvedWidth >= resolvedHeight ? cacheExtent : null;
        final cacheHeight = resolvedWidth < resolvedHeight ? cacheExtent : null;
        final uri = Uri.tryParse(source);
        final isRemote =
            uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
        final image = isRemote
            ? Image.network(
                source,
                width: width,
                height: height,
                fit: BoxFit.cover,
                cacheWidth: cacheWidth,
                cacheHeight: cacheHeight,
                filterQuality: FilterQuality.low,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              )
            : Image.file(
                File(source),
                width: width,
                height: height,
                fit: BoxFit.cover,
                cacheWidth: cacheWidth,
                cacheHeight: cacheHeight,
                filterQuality: FilterQuality.low,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              );

        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            width: width,
            height: height,
            color: colorScheme.surfaceContainer,
            child: image,
          ),
        );
      },
    );
  }

  double _resolveFiniteDimension({
    required double explicit,
    required double constrained,
  }) {
    if (explicit.isFinite && explicit > 0) {
      return explicit;
    }
    if (constrained.isFinite && constrained > 0) {
      return constrained;
    }
    return 0;
  }

  int? _cacheExtent(double displayExtent, double devicePixelRatio) {
    if (!displayExtent.isFinite || displayExtent <= 0) {
      return null;
    }
    final effectiveRatio = devicePixelRatio.isFinite && devicePixelRatio > 0
        ? devicePixelRatio
        : 1.0;
    final extent = (displayExtent * effectiveRatio).round();
    return extent > 0 ? extent : null;
  }
}
