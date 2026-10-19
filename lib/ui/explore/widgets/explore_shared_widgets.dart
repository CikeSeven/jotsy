import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../../app/theme/app_effects.dart';
import '../../widgets/long_image/long_image_cover_alignment.dart';
import '../../widgets/long_image/long_image_policy.dart';

/// 探索页通用卡片容器。
///
/// 提供 [onTap] 时整张卡可点：墨水画在卡片自身的 Material 上并按 24dp 圆角
/// 裁切。外包透明 Material + InkWell 的做法会被不透明的卡片表面盖住，按下去
/// 看不到任何反馈。
class ExploreCard extends StatelessWidget {
  const ExploreCard({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppEffects.restingCardShadow(colorScheme),
      ),
      child: Card.filled(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: ExpressiveSurfaces.cardBorderSide(colorScheme),
        ),
        color: ExpressiveSurfaces.cardColor(colorScheme),
        clipBehavior: onTap == null ? Clip.none : Clip.antiAlias,
        child: onTap == null
            ? Padding(padding: const EdgeInsets.all(18), child: child)
            : InkWell(
                onTap: onTap,
                child: Padding(padding: const EdgeInsets.all(18), child: child),
              ),
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
///
/// 数字在首次出现时从 0 递增到实际值（long + effects），之后数据变化时从当前值
/// 补间到新值，而不是每次重建都重播；等宽数字避免递增时宽度抖动，读屏只读
/// 最终值。减少动画时直接显示。
class ExploreStatTile extends StatelessWidget {
  const ExploreStatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.format,
  });

  final FaIconData icon;
  final String label;
  final int value;

  /// 数字的写法（如千分位、“3 年 2 个月”）；递增过程中的每个中间值同样经它
  /// 格式化。null 时写整数。
  final String Function(int value)? format;

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
        Semantics(
          label: format?.call(value) ?? '$value',
          child: ExcludeSemantics(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: value.toDouble()),
              duration: ExpressiveMotion.duration(
                context,
                ExpressiveMotion.long,
              ),
              curve: ExpressiveMotion.effects,
              builder: (BuildContext context, double animated, Widget? _) {
                return Text(
                  format?.call(animated.round()) ?? '${animated.round()}',
                  // 格式化后的文字（“3 年 2 个月”）可能比纯数字长，窄屏下
                  // 收成一行省略，不把格子撑高。
                  maxLines: format == null ? null : 1,
                  overflow: format == null ? null : TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                );
              },
            ),
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
        // 仅按缩略图容器长边给解码器一个缓存目标（另一边只给安全上限，按比例
        // 解码，长图不会被压扁），避免按容器宽高把图片缩进容器后再 cover 裁切
        // 发糊。实际填充仍交给 BoxFit.cover 裁切，长图顶部对齐。
        final cacheExtent = _cacheExtent(
          resolvedWidth >= resolvedHeight ? resolvedWidth : resolvedHeight,
          dpr,
        );
        final cacheWidth = resolvedWidth >= resolvedHeight ? cacheExtent : null;
        final cacheHeight = resolvedWidth < resolvedHeight ? cacheExtent : null;
        final uri = Uri.tryParse(source);
        final isRemote =
            uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
        final image = CoverCroppedImage(
          image: boundedImageProvider(
            isRemote ? NetworkImage(source) : FileImage(File(source)),
            width: cacheWidth,
            height: cacheHeight,
          ),
          width: width,
          height: height,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
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
