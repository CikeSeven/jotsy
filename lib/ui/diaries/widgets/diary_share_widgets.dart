import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/long_image/long_image_cover_alignment.dart';
import '../../widgets/long_image/long_image_policy.dart';
import '../../widgets/expressive_state_blend.dart';
import '../models/diary_image_embed_data.dart';

/// 分享文字预览：展示即将发出的纯文本，最多 8 行。
///
/// 底色沿用输入框填充色，与面板表面拉开层次；文字为空时显示说明而不是
/// 空白框，告诉用户这次只会发图片。
class DiaryShareTextPreview extends StatelessWidget {
  const DiaryShareTextPreview({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = colorScheme.brightness == Brightness.light;
    final empty = text.isEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: isLight
            ? colorScheme.surfaceContainerLow.withValues(alpha: 0.6)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.input),
      ),
      child: AnimatedSize(
        duration: ExpressiveMotion.durationNonZero(
          context,
          ExpressiveMotion.fast,
        ),
        curve: ExpressiveMotion.effects,
        alignment: Alignment.topCenter,
        child: Text(
          empty ? context.l10n.diaryShareTextEmpty : text,
          maxLines: 8,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: empty ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

/// 横向图片勾选条：点按切换是否随分享发出，顺序即发送顺序。
class DiaryShareImagePicker extends StatelessWidget {
  const DiaryShareImagePicker({
    super.key,
    required this.images,
    required this.selected,
    required this.onToggle,
  });

  final List<String> images;
  final Set<int> selected;
  final ValueChanged<int> onToggle;

  static const double _thumbSize = 72;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: _thumbSize,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s),
            itemBuilder: (BuildContext context, int index) => _ImageChoice(
              source: images[index],
              selected: selected.contains(index),
              label: l10n.diaryShareImageLabel(index + 1),
              size: _thumbSize,
              onTap: () => onToggle(index),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        Text(
          l10n.diaryShareImagesSelected(selected.length, images.length),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ImageChoice extends StatelessWidget {
  const _ImageChoice({
    required this.source,
    required this.selected,
    required this.label,
    required this.size,
    required this.onTap,
  });

  final String source;
  final bool selected;
  final String label;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cacheSize = (size * MediaQuery.devicePixelRatioOf(context)).round();
    final radius = BorderRadius.circular(12);
    // 缩略图只解码到显示尺寸，选中切换时不重建图片。
    final thumbnail = CoverCroppedImage(
      image: boundedImageProvider(
        resolveDiaryImageProvider(source),
        width: cacheSize,
      ),
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => ColoredBox(
        color: colorScheme.surfaceContainerHighest,
        child: Center(
          child: FaIcon(
            FontAwesomeIcons.image,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      checked: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: ExpressiveStateBlend(
          active: selected,
          child: ClipRRect(borderRadius: radius, child: thumbnail),
          builder: (BuildContext context, double t, Widget? child) {
            return Stack(
              children: <Widget>[
                // 未选中的图片压暗，一眼区分哪些会被发出去。
                Opacity(opacity: 0.45 + 0.55 * t, child: child),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(
                        color: Color.lerp(
                          colorScheme.outlineVariant,
                          colorScheme.primary,
                          t,
                        )!,
                        width: 1 + 1.5 * t,
                      ),
                    ),
                  ),
                ),
                Positioned(top: 6, right: 6, child: _CheckBadge(t: t)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.lerp(
          colorScheme.surface.withValues(alpha: 0.7),
          colorScheme.primary,
          t,
        ),
        border: Border.all(
          color: Color.lerp(colorScheme.outline, colorScheme.primary, t)!,
          width: 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: Opacity(
        opacity: t,
        child: FaIcon(
          FontAwesomeIcons.check,
          size: 10,
          color: colorScheme.onPrimary,
        ),
      ),
    );
  }
}

/// 分享目标按钮：圆形图标 + 下方名称。
///
/// 品牌图标统一用主题容器色绘制而不是品牌色，明暗主题与任意种子色下都
/// 不会出现刺眼的大色块；靠图形与名称识别应用。没有图形的品牌（小红书）
/// 传 [glyph] 文字。
class DiaryShareTargetButton extends StatelessWidget {
  const DiaryShareTargetButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.glyph,
  }) : assert(icon != null || glyph != null);

  final String label;
  final FaIconData? icon;
  final String? glyph;

  /// null 时按钮置灰不可点。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final enabled = onTap != null;
    final foreground = colorScheme.onSecondaryContainer;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.38,
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
        curve: ExpressiveMotion.effects,
        child: SizedBox(
          width: 68,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Material(
                color: colorScheme.secondaryContainer,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  child: SizedBox.square(
                    dimension: 52,
                    child: Center(
                      child: icon != null
                          ? FaIcon(icon, size: 22, color: foreground)
                          : Text(
                              glyph!,
                              maxLines: 1,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: foreground,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
