import 'package:flutter/material.dart';

import '../../../app/theme/expressive_surfaces.dart';
import '../models/diary_card_style/diary_card_style.dart';
import 'diary_card_colors.dart';
import 'diary_card_shadows.dart';
import 'diary_card_surface_spec.dart';

/// 一张卡片的颜色（表面 + 各层文字与小部件）。
///
/// 由 [DiaryCardAppearanceResolver] 按“样式 × 主题 × 置顶/胶囊/心情/首个标签色”
/// 解析；默认样式下每个值都与改版前写死的颜色相同。
@immutable
class DiaryCardAppearance {
  const DiaryCardAppearance({
    required this.surface,
    required this.titleColor,
    required this.bodyColor,
    required this.eyebrowColor,
    required this.previewColor,
    required this.footerColor,
    required this.mutedColor,
    required this.accentColor,
    required this.chipFill,
    required this.chipBorder,
    required this.dividerColor,
    required this.panelColor,
    required this.inverted,
    this.accentBarColor,
  });

  final DiaryCardSurfaceSpec surface;
  final Color titleColor;

  /// 正文基色：标签文字、印章图标与媒体角标；摘要/眉线/底栏在它的基础上
  /// 取不同透明度。
  final Color bodyColor;
  final Color eyebrowColor;
  final Color previewColor;
  final Color footerColor;

  /// 选择模式下未选中的空心圆。
  final Color mutedColor;

  /// 置顶徽章、置顶眉线与选中勾的强调色。
  final Color accentColor;

  /// 心情天气印章与 +N 汇总胶囊的底色和描边。
  final Color chipFill;
  final Color chipBorder;

  /// 通栏顶部封面下的分隔线。
  final Color dividerColor;

  /// 背景封面模式下正文底板的颜色（未乘遮罩不透明度）。
  final Color panelColor;
  final Color? accentBarColor;

  /// 底色深浅与主题相反，文字已翻转为反色语义色；标签行等自带配色的部件
  /// 据此改用基于文字色的配色。
  final bool inverted;
}

/// 解析某一类卡片外观时用到的上下文。
class DiaryCardAppearanceContext {
  const DiaryCardAppearanceContext({
    required this.pinned,
    required this.locked,
    this.moodColor,
    this.tagColor,
  });

  final bool pinned;

  /// 未解封的时间胶囊：心情色与标签色不参与着色，避免从卡片颜色上透露
  /// 封存内容。
  final bool locked;
  final Color? moodColor;
  final Color? tagColor;
}

/// 卡片外观解析器（纯函数，按主题与页面底色实例化）。
class DiaryCardAppearanceResolver {
  DiaryCardAppearanceResolver(this.style, this.scheme, {Color? pageBackground})
    : pageBackground =
          pageBackground ?? ExpressiveSurfaces.pageBackground(scheme);

  final DiaryCardStyle style;
  final ColorScheme scheme;

  /// 卡片实际叠在的颜色：半透明卡片的文字对比度按“卡片底色叠在它上面”
  /// 计算。页面设了背景色 / 背景图时由宿主传入估计色（见
  /// `AppPageBackdrop.estimatedColor`）——深色背景图上的半透明卡片若仍按
  /// 浅色页面底色计算，文字会保持深色而看不清。缺省为主题页面底色，即
  /// 接入背景前的行为。
  final Color pageBackground;

  bool get _isLight => scheme.brightness == Brightness.light;

  DiaryCardAppearance resolve(DiaryCardAppearanceContext context) {
    final surfaceStyle = style.surface;
    final pinnedTinted = context.pinned && surfaceStyle.pinnedTint;
    final themedBase = ExpressiveSurfaces.cardColor(scheme);

    Color tint(Color raw) => pinnedTinted
        ? Color.alphaBlend(scheme.primary.withAlpha(14), raw)
        : raw;
    Color layer(DiaryCardColorSpec spec) {
      final source = _sourceColor(spec, DiaryCardColorRole.surface, context);
      return tint(
        source == null
            ? themedBase
            : Color.alphaBlend(
                source.withValues(alpha: spec.strength),
                themedBase,
              ),
      );
    }

    final background = layer(surfaceStyle.background);
    final gradientEnd = surfaceStyle.gradient
        ? layer(surfaceStyle.gradientEnd)
        : null;
    final opacity = surfaceStyle.opacity;
    final themedSurface =
        _sourceColor(
              surfaceStyle.background,
              DiaryCardColorRole.surface,
              context,
            ) ==
            null &&
        gradientEnd == null &&
        opacity >= 1;

    // 文字对比度按“观感上的底色”计算：渐变取中点，半透明叠到卡片实际所在
    // 的页面颜色上（[pageBackground]）。
    var effective = gradientEnd == null
        ? background
        : Color.lerp(background, gradientEnd, 0.5)!;
    if (opacity < 1) {
      effective = Color.alphaBlend(
        effective.withValues(alpha: opacity),
        pageBackground,
      );
    }

    // 底色足够深（或在暗色主题里足够浅）时整套文字翻转为反色语义色。
    final inverted =
        !themedSurface &&
        DiaryCardColors.contrastOver(scheme.onSurface, effective) < 4.5 &&
        DiaryCardColors.contrastOver(scheme.onInverseSurface, effective) >
            DiaryCardColors.contrastOver(scheme.onSurface, effective);
    final autoTitle = inverted ? scheme.onInverseSurface : scheme.onSurface;
    final autoBody = inverted
        ? scheme.onInverseSurface
        : scheme.onSurfaceVariant;

    final typography = style.typography;
    final titleColor = _textColor(
      typography.titleColor,
      autoTitle,
      effective,
      context,
    );
    final bodyColor = _textColor(
      typography.bodyColor,
      autoBody,
      effective,
      context,
    );

    var accent = scheme.primary;
    if (!themedSurface && DiaryCardColors.contrastOver(accent, effective) < 3) {
      accent = DiaryCardColors.bestContrast(<Color>[
        scheme.primary,
        scheme.inversePrimary,
      ], effective);
      if (DiaryCardColors.contrastOver(accent, effective) < 3) {
        accent = titleColor;
      }
    }

    final surfaceSpec = DiaryCardSurfaceSpec(
      color: background.withValues(alpha: background.a * opacity),
      radius: surfaceStyle.cornerRadius,
      borderColor: _borderColor(pinnedTinted, context),
      borderWidth: surfaceStyle.borderWidth,
      shadows: diaryCardShadows(
        surface: surfaceStyle,
        scheme: scheme,
        pinnedTinted: pinnedTinted,
        color: _sourceColor(
          surfaceStyle.shadowColor,
          DiaryCardColorRole.accent,
          context,
        ),
        // 玻璃底色本就要透出背景（模糊后的图），投影一律只画外侧，免得
        // 从卡片底下透出来压暗玻璃。
        translucent: opacity < 1 || surfaceStyle.isGlass,
      ),
      gradientColors: gradientEnd == null
          ? null
          : <Color>[
              background.withValues(alpha: background.a * opacity),
              gradientEnd.withValues(alpha: gradientEnd.a * opacity),
            ],
      gradientBegin: switch (surfaceStyle.gradientDirection) {
        DiaryCardGradientDirection.vertical => Alignment.topCenter,
        DiaryCardGradientDirection.horizontal =>
          AlignmentDirectional.centerStart,
        DiaryCardGradientDirection.diagonal => AlignmentDirectional.topStart,
      },
      gradientEnd: switch (surfaceStyle.gradientDirection) {
        DiaryCardGradientDirection.vertical => Alignment.bottomCenter,
        DiaryCardGradientDirection.horizontal => AlignmentDirectional.centerEnd,
        DiaryCardGradientDirection.diagonal => AlignmentDirectional.bottomEnd,
      },
      glass: surfaceStyle.isGlass,
      blurSigma: surfaceStyle.isGlass
          ? DiaryCardStyleLimits.blurSigma.clamp(surfaceStyle.blurSigma)
          : 0,
    );

    final accentBarColor = surfaceStyle.accentBar == DiaryCardAccentBar.none
        ? null
        : (_sourceColor(
                    surfaceStyle.accentColor,
                    DiaryCardColorRole.accent,
                    context,
                  ) ??
                  scheme.primary)
              .withValues(alpha: surfaceStyle.accentColor.strength);

    final useThemedChips = !inverted;
    return DiaryCardAppearance(
      surface: surfaceSpec,
      titleColor: titleColor,
      bodyColor: bodyColor,
      eyebrowColor: pinnedTinted
          ? accent
          : bodyColor.withValues(alpha: bodyColor.a * 0.82),
      previewColor: bodyColor.withValues(alpha: bodyColor.a * 0.88),
      footerColor: bodyColor.withValues(alpha: bodyColor.a * 0.72),
      mutedColor: bodyColor.withValues(alpha: bodyColor.a * 0.6),
      accentColor: accent,
      chipFill: useThemedChips
          ? scheme.surfaceContainerHighest.withValues(
              alpha: _isLight ? 0.6 : 0.45,
            )
          : titleColor.withValues(alpha: 0.1),
      chipBorder: useThemedChips
          ? scheme.outlineVariant.withValues(alpha: _isLight ? 0.25 : 0.2)
          : titleColor.withValues(alpha: 0.18),
      dividerColor: useThemedChips
          ? scheme.outlineVariant.withValues(alpha: _isLight ? 0.25 : 0.2)
          : titleColor.withValues(alpha: 0.16),
      panelColor: background,
      accentBarColor: accentBarColor,
      inverted: inverted,
    );
  }

  /// 颜色来源对应的具体颜色；theme 来源（或拿不到心情/标签色时）返回 null，
  /// 由调用方用该颜色位的主题默认值。
  Color? _sourceColor(
    DiaryCardColorSpec spec,
    DiaryCardColorRole role,
    DiaryCardAppearanceContext context,
  ) {
    switch (spec.source) {
      case DiaryCardColorSource.theme:
        return null;
      case DiaryCardColorSource.primary:
        return scheme.primary;
      case DiaryCardColorSource.secondary:
        return scheme.secondary;
      case DiaryCardColorSource.tertiary:
        return scheme.tertiary;
      case DiaryCardColorSource.mood:
        return context.locked ? null : context.moodColor;
      case DiaryCardColorSource.firstTag:
        return context.locked ? null : context.tagColor;
      case DiaryCardColorSource.custom:
        final light = spec.light;
        if (light == null) {
          return null;
        }
        if (_isLight) {
          return Color(light);
        }
        final dark = spec.dark;
        return dark != null
            ? Color(dark)
            : DiaryCardColors.deriveDark(Color(light), role);
    }
  }

  Color _textColor(
    DiaryCardColorSpec spec,
    Color auto,
    Color background,
    DiaryCardAppearanceContext context,
  ) {
    final source = _sourceColor(spec, DiaryCardColorRole.text, context);
    if (source == null) {
      return auto;
    }
    if (style.typography.ensureContrast &&
        DiaryCardColors.contrastOver(source, background) < 3) {
      return auto;
    }
    return source;
  }

  Color _borderColor(bool pinnedTinted, DiaryCardAppearanceContext context) {
    final spec = style.surface.borderColor;
    final source = _sourceColor(spec, DiaryCardColorRole.accent, context);
    if (source != null) {
      return source.withValues(alpha: spec.strength);
    }
    return pinnedTinted
        ? scheme.primary.withValues(alpha: _isLight ? 0.35 : 0.45)
        : ExpressiveSurfaces.cardBorderColor(scheme);
  }
}
