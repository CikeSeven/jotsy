import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../app_surface/widgets/app_glass_field.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../../app/theme/app_effects.dart';
import '../../app_surface/widgets/app_glass_scope.dart';
import '../../app_surface/widgets/app_glass_surface.dart';
import '../../diaries/widgets/diary_image_source.dart';
import '../../widgets/long_image/long_image_cover_alignment.dart';
import '../../widgets/long_image/long_image_policy.dart';
import '../models/explore_appearance.dart';
import 'explore_appearance_scope.dart';

/// 探索页通用卡片容器。
///
/// 外观按 [ExploreAppearanceScope]：圆角、内边距与表面（填充 / 色调 / 描边）；
/// 不在探索页里时为默认外观（填充卡片、24 圆角、18 内边距，与改版前一致）。
/// 材质设为玻璃时一律是内容玻璃（[AppGlassSurface]），表面选项不再生效。
///
/// 提供 [onTap] 时整张卡可点：墨水画在卡片自身的 Material 上并按圆角裁切。
/// 外包透明 Material + InkWell 的做法会被不透明的卡片表面盖住，按下去看不到
/// 任何反馈。
class ExploreCard extends StatelessWidget {
  const ExploreCard({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final look = ExploreAppearanceScope.of(context);
    final radius = BorderRadius.circular(look.radius);
    final padded = Padding(
      padding: EdgeInsets.all(look.cardPadding),
      child: child,
    );
    final content = onTap == null
        ? padded
        : InkWell(onTap: onTap, child: padded);
    if (AppGlass.of(context).isGlass(AppGlassComponent.cards)) {
      // 玻璃：内容玻璃（共用页面背景读取、无背景图不模糊）。表面自带一层
      // canvas Material 并按圆角裁切，水波纹照常画在玻璃上。
      return AppGlassSurface(
        component: AppGlassComponent.cards,
        borderRadius: radius,
        shadow: true,
        child: content,
      );
    }
    final clip = onTap == null ? Clip.none : Clip.antiAlias;
    switch (look.surface) {
      case ExploreCardSurface.filled:
        return Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: AppEffects.restingCardShadow(colorScheme),
          ),
          child: Card.filled(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: ExpressiveSurfaces.cardBorderSide(colorScheme),
            ),
            color: ExpressiveSurfaces.cardColor(colorScheme),
            clipBehavior: clip,
            child: content,
          ),
        );
      case ExploreCardSurface.tonal:
        return Card.filled(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: radius),
          color: colorScheme.brightness == Brightness.light
              ? colorScheme.surfaceContainer
              : colorScheme.surfaceContainerHigh,
          clipBehavior: clip,
          child: content,
        );
      case ExploreCardSurface.outlined:
        return Card.outlined(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          color: colorScheme.surface,
          clipBehavior: clip,
          child: content,
        );
    }
  }
}

/// 探索页模块标题：按外观里的标题样式画成彩色徽章图标 + 标题（默认）、
/// 仅图标 + 标题、仅标题，或不画。
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
    final look = ExploreAppearanceScope.of(context);
    final text = Flexible(
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
    );
    return switch (look.heading) {
      ExploreHeadingStyle.hidden => const SizedBox.shrink(),
      ExploreHeadingStyle.text => Row(children: <Widget>[text]),
      ExploreHeadingStyle.icon => Row(
        children: <Widget>[
          FaIcon(icon, size: 14, color: look.accentOf(colorScheme)),
          const SizedBox(width: 8),
          text,
        ],
      ),
      ExploreHeadingStyle.badge => Row(
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
          text,
        ],
      ),
    };
  }
}

/// 探索页卡片的标题行：标题（按外观样式）+ 行尾操作，下方留出与内容的间距。
///
/// 标题样式为“隐藏”时只剩行尾操作；连操作也没有时整行与间距都不占位。
/// [gap] 为 null 时取外观的标题间距。
class ExploreCardHeader extends StatelessWidget {
  const ExploreCardHeader({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    this.gap,
  });

  final FaIconData icon;
  final String title;
  final Widget? trailing;
  final double? gap;

  @override
  Widget build(BuildContext context) {
    final look = ExploreAppearanceScope.of(context);
    final trailing = this.trailing;
    final hidden = look.heading == ExploreHeadingStyle.hidden;
    if (hidden && trailing == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: gap ?? look.headerGap),
      child: Row(
        children: <Widget>[
          Expanded(
            child: hidden
                ? const SizedBox.shrink()
                : ExploreSectionTitle(icon: icon, title: title),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// 标题行尾的小字（如“近 30 天”“共 42 篇”）。
class ExploreHeaderNote extends StatelessWidget {
  const ExploreHeaderNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 8),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// 标题行尾的“查看全部”箭头按钮。
class ExploreHeaderArrow extends StatelessWidget {
  const ExploreHeaderArrow({
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.icon = FontAwesomeIcons.angleRight,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final FaIconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        minimumSize: const Size(28, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: FaIcon(icon, size: 14),
    );
  }
}

/// 卡片里的空态说明：一段弱化文字，可带一个次要按钮。
class ExploreInlineHint extends StatelessWidget {
  const ExploreInlineHint({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actionLabel = this.actionLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        if (actionLabel != null) ...<Widget>[
          const SizedBox(height: 10),
          FilledButton.tonal(
            style: AppGlassField.tonalButtonStyle(context),
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ],
    );
  }
}

/// 顶部看板单项。
///
/// 数字在首次出现时从 0 递增到实际值（long + effects），之后数据变化时从当前值
/// 补间到新值，而不是每次重建都重播；等宽数字避免递增时宽度抖动，读屏只读
/// 最终值。减少动画（或探索页外观关掉了动画）时直接显示。颜色取外观的强调色。
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
    final look = ExploreAppearanceScope.of(context);
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
              duration: look.animations
                  ? ExpressiveMotion.duration(context, ExpressiveMotion.long)
                  : Duration.zero,
              curve: ExpressiveMotion.effects,
              builder: (BuildContext context, double animated, Widget? _) {
                return Text(
                  format?.call(animated.round()) ?? '${animated.round()}',
                  // 格式化后的文字（“3 年 2 个月”）可能比纯数字长，窄屏下
                  // 收成一行省略，不把格子撑高。
                  maxLines: format == null ? null : 1,
                  overflow: format == null ? null : TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: look.accentOf(colorScheme),
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

/// 媒体缩略图（本地文件、网络图片与应用内置示例图，见 [diaryImageProvider]）。
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
        final image = CoverCroppedImage(
          image: boundedImageProvider(
            diaryImageProvider(source),
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
