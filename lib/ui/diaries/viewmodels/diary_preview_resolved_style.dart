import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_breakpoints.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/seeded_theme_cache.dart';
import '../models/diary_mood_palette.dart';
import '../models/diary_preview_style/diary_preview_style.dart';
import 'diary_card_colors.dart';

/// 预览页样式在当前主题、屏幕与这篇日记下的具体取值。
///
/// 输入：样式、应用主题与种子色、屏幕尺寸、是否减少动画、心情色板，以及这篇
/// 日记的心情与首个标签色（配色基调用）。输出：页面主题、底色、正文与标题
/// 颜色、实际边距、正文最大宽度与头图高度。纯计算；主题实例经
/// [SeededThemeCache] 复用。
///
/// 着色规则：
/// - 配色基调不是“跟随应用”、或纸色与应用主题深浅相反时，整页换成由种子色
///   装配的另一套主题（深色纸上是深色主题），信息栏、胶囊、引用条、勾选框等
///   所有语义色一起变化，不会出现深色纸上的深色文字；
/// - 基调颜色：心情取心情色板的原色（[DiaryMoodPalette.seedOf]，十档各有
///   色相），标签取首个标签色，自定义取用户的颜色；装配主题的配色方案按
///   “着色强度”（[DiaryPreviewSeedIntensity]）换用 tonalSpot / fidelity /
///   vibrant；
/// - 心情 / 首个标签取不到颜色时：回退为“跟随应用”则沿用应用主题，回退为
///   “中性灰”则换成由应用种子色推出的 neutral 主题（低饱和的灰调）；
/// - 纸张为主题底色、开了“随基调染色”且取到了基调颜色时，底色在 surface 上
///   叠一层同色相的浅色（[tintedPaper]），正文仍是主题 onSurface；
/// - 默认样式（跟随应用 + 主题底色）原样返回应用主题，渲染与改版前一致；
/// - 自定义正文 / 标题颜色按纸色检查对比度（正文 4.5:1、标题 3:1，WCAG 2.x），
///   不足时回退为主题色，未设深色值时按色相推导。
///
/// 版式（边距、正文列宽、头图）按内容实际可用的宽度换算：[resolve] 先按屏幕
/// 宽度算一遍，`DiaryPreviewContent` 再经 [atWidth] 按自己拿到的宽度重算
/// （嵌在列表–详情双栏里时比屏幕窄）。手机上两者相同，结果与改版前一致：
/// - 宽于 [wideReadingThreshold] 时正文列默认收到 [AppContentWidth.reading]
///   并居中；用户开了“限制正文宽度”时以用户的宽度为准；
/// - 宽度 ≥ [AppBreakpoints.medium] 时头图不再通栏，改为正文列里的圆角卡片
///   （见 [coverInColumn]）。
@immutable
class DiaryPreviewResolvedStyle {
  const DiaryPreviewResolvedStyle._({
    required this.style,
    required this.theme,
    required this.themed,
    required this.background,
    required this.paperFollowsTheme,
    required this.bodyColor,
    required this.titleColor,
    required this.horizontalPadding,
    required this.maxContentWidth,
    required this.coverHeight,
    required this.coverInColumn,
    required this._layoutWidth,
    required this._screenHeight,
  });

  /// 宽于它（正文列默认宽度加两侧各 16）时正文列默认收窄居中。
  static const double wideReadingThreshold = AppContentWidth.reading + 32;

  /// 正文列内头图的上边距。
  static const double columnCoverTop = 16;

  /// 正文列内头图的最大高度。
  static const double columnCoverMaxHeight = 420;

  /// 正文列内头图的高宽比上限（高 = 宽 × 它）。
  static const double columnCoverAspect = 0.6;

  /// 正文与背景的最低对比度。
  static const double bodyContrast = 4.5;

  /// 标题（大字）与背景的最低对比度。
  static const double titleContrast = 3;

  /// 纸张随基调染色时叠在 surface 上的浅色层不透明度：浅色主题叠
  /// `primaryFixed`（色调 90），深色主题叠 `onPrimaryFixedVariant`（色调
  /// 30）。两者在各配色方案里色调固定，只随基调的色相与浓淡变化，染出来的
  /// 纸始终是浅色约 93、深色约 16 的色调，正文对比度不受着色强度影响。
  static const double paperTintLight = 0.55;
  static const double paperTintDark = 0.45;

  /// 内置纸色：（浅色主题，深色主题）。墨色两种主题下都是深色纸。
  static const Map<DiaryPreviewPaper, (int, int)> paperColors =
      <DiaryPreviewPaper, (int, int)>{
        DiaryPreviewPaper.warm: (0xFFFBF7EE, 0xFF24221D),
        DiaryPreviewPaper.sepia: (0xFFF4ECD8, 0xFF2B2620),
        DiaryPreviewPaper.mint: (0xFFE9F3EB, 0xFF1C2620),
        DiaryPreviewPaper.gray: (0xFFF1F1EF, 0xFF1F2022),
        DiaryPreviewPaper.ink: (0xFF1E2126, 0xFF121417),
      };

  factory DiaryPreviewResolvedStyle.resolve({
    required DiaryPreviewStyle style,
    required ThemeData appTheme,
    required Color appSeed,
    required Size screenSize,
    required bool reduceMotion,
    required DiaryMoodPalette moodPalette,
    String? moodEmoji,
    int? firstTagColor,
  }) {
    final page = style.page;
    final appBrightness = appTheme.brightness;
    final paper = _paperColor(page, appBrightness);
    final pageBrightness = paper == null
        ? appBrightness
        : ThemeData.estimateBrightnessForColor(paper);
    final seed = switch (page.colorSeed) {
      DiaryPreviewColorSeed.app => null,
      DiaryPreviewColorSeed.mood => moodPalette.seedOf(moodEmoji),
      DiaryPreviewColorSeed.tag =>
        firstTagColor == null ? null : Color(firstTagColor),
      DiaryPreviewColorSeed.custom =>
        page.seedColor == null ? null : Color(page.seedColor!),
    };
    // 心情 / 首个标签是逐篇取色的基调，取不到时才看回退；自定义色没设时
    // 与改版前一样沿用应用主题。
    final neutral =
        seed == null &&
        page.seedFallback == DiaryPreviewSeedFallback.neutral &&
        (page.colorSeed == DiaryPreviewColorSeed.mood ||
            page.colorSeed == DiaryPreviewColorSeed.tag);
    final themed = seed != null || neutral || pageBrightness != appBrightness;
    final theme = themed
        ? SeededThemeCache.of(
            seed ?? appSeed,
            pageBrightness,
            reduceMotion: reduceMotion,
            variant: neutral
                ? DynamicSchemeVariant.neutral
                : seed != null
                ? _variantFor(page.seedIntensity)
                : DynamicSchemeVariant.tonalSpot,
          )
        : appTheme;
    final background =
        paper ??
        (page.tintPaper && seed != null
            ? tintedPaper(theme.colorScheme)
            : theme.colorScheme.surface);

    final layout = _layoutFor(style, screenSize.width, screenSize.height);
    return DiaryPreviewResolvedStyle._(
      style: style,
      theme: theme,
      themed: themed,
      background: background,
      paperFollowsTheme: paper == null,
      bodyColor: _readable(
        page.textLight,
        page.textDark,
        pageBrightness,
        background,
        bodyContrast,
      ),
      titleColor: _readable(
        style.title.colorLight,
        style.title.colorDark,
        pageBrightness,
        background,
        titleContrast,
      ),
      horizontalPadding: layout.horizontalPadding,
      maxContentWidth: layout.maxContentWidth,
      coverHeight: layout.coverHeight,
      coverInColumn: layout.coverInColumn,
      layoutWidth: screenSize.width,
      screenHeight: screenSize.height,
    );
  }

  /// 按内容实际可用的宽度 [available] 重算版式（边距、正文列宽、头图），
  /// 配色不变。与上次换算的宽度相同（手机上通常如此）时返回自身。
  DiaryPreviewResolvedStyle atWidth(double available) {
    if (!available.isFinite || available <= 0 || available == _layoutWidth) {
      return this;
    }
    final layout = _layoutFor(style, available, _screenHeight);
    return DiaryPreviewResolvedStyle._(
      style: style,
      theme: theme,
      themed: themed,
      background: background,
      paperFollowsTheme: paperFollowsTheme,
      bodyColor: bodyColor,
      titleColor: titleColor,
      horizontalPadding: layout.horizontalPadding,
      maxContentWidth: layout.maxContentWidth,
      coverHeight: layout.coverHeight,
      coverInColumn: layout.coverInColumn,
      layoutWidth: available,
      screenHeight: _screenHeight,
    );
  }

  /// 宽度为 [width]、屏高为 [screenHeight] 时的版式。
  ///
  /// 正文列宽：用户开了“限制正文宽度”时取用户的宽度；没开但宽于
  /// [wideReadingThreshold] 时取 [AppContentWidth.reading]；列宽不小于可用
  /// 宽度时不限制（null）。正文列宽包含左右边距，与改版前“限制正文宽度”
  /// 的口径一致。
  static ({
    double horizontalPadding,
    double? maxContentWidth,
    double coverHeight,
    bool coverInColumn,
  })
  _layoutFor(DiaryPreviewStyle style, double width, double screenHeight) {
    final page = style.page;
    final limit = page.limitWidth
        ? page.contentWidth
        : width > wideReadingThreshold
        ? AppContentWidth.reading
        : null;
    final maxContentWidth = limit != null && limit < width ? limit : null;
    final column = maxContentWidth ?? width;
    final roomForPadding = (column - DiaryPreviewStyleLimits.minTextWidth) / 2;
    final horizontalPadding = math.max(
      0.0,
      math.min(page.horizontalPadding, roomForPadding),
    );
    final screenCap =
        screenHeight * DiaryPreviewStyleLimits.coverMaxScreenFraction;
    final coverInColumn = width >= AppBreakpoints.medium;
    // 列内头图与正文左右对齐：宽度为正文列减去两侧边距，高度按宽度换算，
    // 不随用户设定的头图高度（那是为通栏手机头图设计的）。
    final coverHeight = coverInColumn
        ? math.max(
            0.0,
            math.min(
              math.min(
                columnCoverMaxHeight,
                (column - horizontalPadding * 2) * columnCoverAspect,
              ),
              screenCap,
            ),
          )
        : math.min(style.cover.height, screenCap);
    return (
      horizontalPadding: horizontalPadding,
      maxContentWidth: maxContentWidth,
      coverHeight: coverHeight,
      coverInColumn: coverInColumn,
    );
  }

  final DiaryPreviewStyle style;

  /// 页面主题；[themed] 为 false 时就是应用主题本身。
  final ThemeData theme;
  final bool themed;

  /// 页面底色（纸色，或主题 surface；随基调染色时为染过的 surface）。
  final Color background;

  /// 纸张是否“跟随主题”（没有纸色，[background] 取主题 surface 或染过的
  /// surface）。只有这时预览页才让位给“背景与材质”的预览区域背景；选了
  /// 纸色时纸色优先。
  final bool paperFollowsTheme;

  /// 通过对比度检查的自定义正文颜色；null 表示用主题正文色。
  final Color? bodyColor;

  /// 通过对比度检查的自定义标题颜色；null 表示用主题色。
  final Color? titleColor;

  /// 实际左右边距（窄屏上为正文留出至少
  /// [DiaryPreviewStyleLimits.minTextWidth]）。
  final double horizontalPadding;

  /// 正文列最大宽度（含左右边距）；不限制或可用宽度本来就更窄时为 null。
  final double? maxContentWidth;

  /// 头图框高度（最高为屏高的
  /// [DiaryPreviewStyleLimits.coverMaxScreenFraction]）；[coverInColumn] 时
  /// 为列内头图画面本身的高度（不含上边距）。
  final double coverHeight;

  /// 头图放进正文列、作为圆角卡片显示（宽窗口），而不是通栏。
  final bool coverInColumn;

  /// 列内头图的圆角：内嵌模式沿用用户设定的圆角，通栏模式取卡片圆角。
  double get columnCoverRadius =>
      style.cover.mode == DiaryPreviewCoverMode.inset
      ? style.cover.radius
      : AppRadii.card;

  /// 上次换算版式所用的宽度。
  final double _layoutWidth;
  final double _screenHeight;

  static Color? _paperColor(DiaryPreviewPageStyle page, Brightness brightness) {
    final light = brightness == Brightness.light;
    if (page.paper == DiaryPreviewPaper.custom) {
      final custom = page.paperLight;
      if (custom == null) {
        return null;
      }
      if (light) {
        return Color(custom);
      }
      final dark = page.paperDark;
      return dark != null
          ? Color(dark)
          : DiaryCardColors.deriveDark(
              Color(custom),
              DiaryCardColorRole.surface,
            );
    }
    final preset = paperColors[page.paper];
    if (preset == null) {
      return null;
    }
    return Color(light ? preset.$1 : preset.$2);
  }

  static DynamicSchemeVariant _variantFor(
    DiaryPreviewSeedIntensity intensity,
  ) => switch (intensity) {
    DiaryPreviewSeedIntensity.soft => DynamicSchemeVariant.tonalSpot,
    DiaryPreviewSeedIntensity.original => DynamicSchemeVariant.fidelity,
    DiaryPreviewSeedIntensity.vivid => DynamicSchemeVariant.vibrant,
  };

  /// 随基调染色的纸：在 [scheme] 的 surface 上叠一层同色相的浅色，见
  /// [paperTintLight]。
  static Color tintedPaper(ColorScheme scheme) {
    final light = scheme.brightness == Brightness.light;
    final tint = light ? scheme.primaryFixed : scheme.onPrimaryFixedVariant;
    return Color.alphaBlend(
      tint.withValues(alpha: light ? paperTintLight : paperTintDark),
      scheme.surface,
    );
  }

  static Color? _readable(
    int? lightValue,
    int? darkValue,
    Brightness pageBrightness,
    Color background,
    double minContrast,
  ) {
    if (lightValue == null) {
      return null;
    }
    final color = pageBrightness == Brightness.light
        ? Color(lightValue)
        : darkValue != null
        ? Color(darkValue)
        : DiaryCardColors.deriveDark(
            Color(lightValue),
            DiaryCardColorRole.text,
          );
    return DiaryCardColors.contrastOver(color, background) >= minContrast
        ? color
        : null;
  }
}
