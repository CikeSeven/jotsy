import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/app_effects.dart';

/// 探索页通用卡片容器。
class ExploreCard extends StatelessWidget {
  const ExploreCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final cardBackground =
        isDark
            ? colorScheme.surfaceContainerHigh
            : colorScheme.surfaceContainerLow;
    final cardBorderColor =
        isDark
            ? colorScheme.outlineVariant.withValues(alpha: 0.5)
            : colorScheme.outlineVariant.withValues(alpha: 0.42);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorderColor, width: 0.9),
          boxShadow: <BoxShadow>[
            ...AppEffects.softShadow.take(1),
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: isDark ? 0.12 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    );
  }
}

/// 探索页模块标题（小图标 + 文案）。
class ExploreSectionTitle extends StatelessWidget {
  const ExploreSectionTitle({
    super.key,
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        FaIcon(icon, size: 13),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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

  final IconData icon;
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
            FaIcon(icon, size: 10, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
        final image =
            isRemote
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
    final effectiveRatio =
        devicePixelRatio.isFinite && devicePixelRatio > 0
            ? devicePixelRatio
            : 1.0;
    final extent = (displayExtent * effectiveRatio).round();
    return extent > 0 ? extent : null;
  }
}
