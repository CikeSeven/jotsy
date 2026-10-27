import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/expressive_surfaces.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/settings_service.dart';
import '../../widgets/mood_band_palette.dart';
import '../models/diary_card_style/diary_card_style.dart';
import 'diary_card_appearance.dart';

/// 某一布局模式下、已落到具体数值的卡片样式。
///
/// 输入：[DiaryCardStyle]、布局模式、主题、列表可用宽度（[screenWidth]）、
/// 系统字号、心情配置、瀑布流最少列数（[minColumns]）与卡片所在的页面颜色
/// （[pageBackground]）；输出：间距、封面尺寸、
/// 有效列数、不含颜色的基础文字样式，以及按卡片类别缓存的颜色
/// （[appearanceFor]）。无副作用。
///
/// 为什么集中解析：列表每帧可能构建十几张卡片，若每张卡都从样式重新推导
/// 字号、夹紧封面并计算对比度，开销会落在滚动帧里。这里每次 section build
/// 只解析一次（并按参数复用最近几次的结果），卡片只做查表。
///
/// 安全夹紧：侧边封面在窄屏上缩小以给文字列留出至少 [minTextColumnWidth]；
/// 瀑布流列数大于 2 时，单列放不下 [minWaterfallColumnWidth]（随大字号放宽）
/// 就自动减列。默认样式在 320dp 及以上不会触发任何夹紧。
class DiaryCardResolvedStyle {
  DiaryCardResolvedStyle._({
    required this.style,
    required this.mode,
    required this.theme,
    required this.screenWidth,
    required this.textScale,
    required this.moodOptions,
    required this.minColumns,
    required this.pageBackground,
  }) : modeStyle = style.mode(mode) {
    final m = modeStyle;
    final textTheme = theme.textTheme;
    final typography = style.typography;
    final metaScale = typography.metaScale;
    final titleWeight = switch (typography.titleWeight) {
      DiaryCardTitleWeight.regular => FontWeight.w400,
      DiaryCardTitleWeight.medium => FontWeight.w500,
      DiaryCardTitleWeight.bold => FontWeight.w700,
    };
    final lineHeightDelta = switch (typography.lineHeight) {
      DiaryCardLineHeight.compact => -0.12,
      DiaryCardLineHeight.standard => 0.0,
      DiaryCardLineHeight.relaxed => 0.16,
    };
    if (compact) {
      eyebrowStyle = textTheme.labelSmall?.copyWith(
        fontSize: 12 * metaScale,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      );
      titleStyle = textTheme.titleMedium?.copyWith(
        fontSize: 16.5 * typography.titleScale,
        fontWeight: titleWeight,
        letterSpacing: -0.15,
        height: 1.3,
      );
      previewStyle = textTheme.bodySmall?.copyWith(
        fontSize: _scaledOrNull(
          textTheme.bodySmall?.fontSize,
          12,
          typography.previewScale,
        ),
        height: 1.36 + lineHeightDelta,
      );
      footerStyle = textTheme.bodySmall?.copyWith(fontSize: 11 * metaScale);
    } else {
      eyebrowStyle = textTheme.labelMedium?.copyWith(
        fontSize: 13 * metaScale,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      );
      titleStyle = textTheme.titleLarge?.copyWith(
        fontSize: 18.5 * typography.titleScale,
        fontWeight: titleWeight,
        letterSpacing: -0.2,
        height: 1.25,
      );
      previewStyle = textTheme.bodyMedium?.copyWith(
        fontSize: _scaledOrNull(
          textTheme.bodyMedium?.fontSize,
          14,
          typography.previewScale,
        ),
        height: 1.42 + lineHeightDelta,
      );
      footerStyle = textTheme.bodySmall?.copyWith(fontSize: 11.5 * metaScale);
    }

    accentStartInset = style.surface.accentBar == DiaryCardAccentBar.start
        ? style.surface.accentWidth
        : 0;
    accentTopInset = style.surface.accentBar == DiaryCardAccentBar.top
        ? style.surface.accentWidth
        : 0;

    // 宽窗口里瀑布流按宽度加列（[minColumns]，见日记页的中等窗口布局）；
    // 加出的列宽本就宽裕，下面的减列不会再把它减回去。
    var effectiveColumns = math.max(m.columns, minColumns);
    final minColumn = minWaterfallColumnWidth * math.min(textScale, 1.3);
    while (effectiveColumns > 2 &&
        (screenWidth - 2 * m.sideMargin - (effectiveColumns - 1) * m.cardGap) /
                effectiveColumns <
            minColumn) {
      effectiveColumns -= 1;
    }
    columns = effectiveColumns;

    // 内边距不能把正文挤得比最小正文宽度还窄（最大内边距 + 色条 + 窄列的
    // 组合），否则眉线连日期与徽章都放不下。默认样式在 320dp 及以上不会
    // 触发这条夹紧。
    final cardWidth = compact
        ? (screenWidth - 2 * m.sideMargin - (columns - 1) * m.cardGap) / columns
        : screenWidth - 2 * m.sideMargin;
    final minContent = compact ? minWaterfallContentWidth : minListContentWidth;
    paddingH = math.min(
      m.paddingH,
      math.max(
        DiaryCardStyleLimits.paddingH.min,
        (cardWidth - accentStartInset - minContent) / 2,
      ),
    );

    // 侧边封面：给文字列至少留 minTextColumnWidth，窄屏上封面让位。
    final availableForCover =
        screenWidth -
        2 * m.sideMargin -
        2 * paddingH -
        m.coverGap -
        accentStartInset -
        minTextColumnWidth;
    final side = math.min(
      m.coverSide,
      math.max(DiaryCardStyleLimits.coverSide.min, availableForCover),
    );
    sideCoverSize = switch (m.coverShape) {
      DiaryCardCoverShape.square ||
      DiaryCardCoverShape.circle => Size(side, side),
      DiaryCardCoverShape.landscape => Size(side, side * 0.75),
      DiaryCardCoverShape.portrait => Size(side * 0.75, side),
    };
  }

  /// 解析（或复用最近一次相同参数的结果）。
  factory DiaryCardResolvedStyle.resolve({
    required DiaryCardStyle style,
    required DiaryCardMode mode,
    required ThemeData theme,
    required double screenWidth,
    double textScale = 1,
    List<String> moodOptions = SettingsService.defaultMoodOptions,
    int minColumns = 0,
    Color? pageBackground,
  }) {
    final page =
        pageBackground ?? ExpressiveSurfaces.pageBackground(theme.colorScheme);
    for (final candidate in _recent) {
      if (candidate.mode == mode &&
          candidate.pageBackground == page &&
          identical(candidate.theme, theme) &&
          candidate.screenWidth == screenWidth &&
          candidate.textScale == textScale &&
          candidate.minColumns == minColumns &&
          candidate.style == style &&
          listEquals(candidate.moodOptions, moodOptions)) {
        return candidate;
      }
    }
    final resolved = DiaryCardResolvedStyle._(
      style: style,
      mode: mode,
      theme: theme,
      screenWidth: screenWidth,
      textScale: textScale,
      moodOptions: moodOptions,
      minColumns: minColumns,
      pageBackground: page,
    );
    _recent.insert(0, resolved);
    if (_recent.length > _maxRecent) {
      _recent.removeLast();
    }
    return resolved;
  }

  /// 日记列表、搜索、归档、日历与设置页预览可能交替使用不同样式。
  static const int _maxRecent = 6;
  static final List<DiaryCardResolvedStyle> _recent =
      <DiaryCardResolvedStyle>[];

  /// 侧边封面旁文字列的最小宽度。
  static const double minTextColumnWidth = 120;

  /// 瀑布流单列的最小宽度（系统字号 1.0 时）。
  static const double minWaterfallColumnWidth = 104;

  /// 卡片正文（内边距以内）的最小宽度，超出时收窄左右内边距。
  static const double minWaterfallContentWidth = 96;
  static const double minListContentWidth = 160;

  final DiaryCardStyle style;
  final DiaryCardMode mode;
  final ThemeData theme;

  /// 列表实际可用的宽度（含卡片左右边距）。沿用“屏宽”的名字：手机上它就是
  /// 屏宽；宽窗口里是日记页内容列或双栏左栏的宽度。
  final double screenWidth;
  final double textScale;
  final List<String> moodOptions;

  /// 瀑布流至少的列数（按可用宽度加列时给出）；0 表示只用样式里的列数。
  final int minColumns;

  /// 卡片实际叠在的页面颜色，半透明 / 玻璃卡片的文字对比度按它计算（见
  /// [DiaryCardAppearanceResolver.pageBackground]）。缺省为主题页面底色。
  final Color pageBackground;
  final DiaryCardModeStyle modeStyle;

  bool get compact => mode == DiaryCardMode.waterfall;
  ColorScheme get colorScheme => theme.colorScheme;

  late final TextStyle? eyebrowStyle;
  late final TextStyle? titleStyle;
  late final TextStyle? previewStyle;
  late final TextStyle? footerStyle;

  /// 起始边 / 顶边强调条占去的宽度，正文内边距在对应一侧让出这段距离。
  late final double accentStartInset;
  late final double accentTopInset;

  /// 列表侧边封面的实际尺寸（已按屏宽夹紧并套用形状比例）。
  late final Size sideCoverSize;

  /// 瀑布流实际列数。
  late final int columns;

  /// 实际的左右内边距（已按最小正文宽度夹紧）；上下内边距即样式值。
  late final double paddingH;
  double get paddingV => modeStyle.paddingV;

  double get cornerRadius => style.surface.cornerRadius;
  double get metaScale => style.typography.metaScale;
  bool get centered => style.typography.textAlign == DiaryCardTextAlign.center;
  TextAlign get textAlign => centered ? TextAlign.center : TextAlign.start;

  /// 底栏前的间距比普通区块间距多一点（默认两种模式都是 8）。
  double get footerGap => modeStyle.elementGap + (compact ? 3 : 2);

  /// 心情天气实际所在的位置：放在封面上但这张卡没有封面时回到该模式默认处。
  DiaryCardMetaPosition metaPositionFor({required bool hasCover}) {
    final position = modeStyle.metaPosition;
    if (position == DiaryCardMetaPosition.cover && !hasCover) {
      return compact
          ? DiaryCardMetaPosition.footer
          : DiaryCardMetaPosition.eyebrow;
    }
    return position;
  }

  late final bool _usesMoodColor = _usesSource(DiaryCardColorSource.mood);
  late final bool _usesTagColor = _usesSource(DiaryCardColorSource.firstTag);
  late final Map<String, int> _moodWeights = SettingsService.buildMoodWeightMap(
    moodOptions,
  );
  late final DiaryCardAppearanceResolver _resolver =
      DiaryCardAppearanceResolver(
        style,
        colorScheme,
        pageBackground: pageBackground,
      );
  final LinkedHashMap<Object, DiaryCardAppearance> _appearances =
      LinkedHashMap<Object, DiaryCardAppearance>();

  /// 某张卡片的颜色。按（置顶、胶囊、心情段、首个标签色）缓存：只有样式
  /// 真正用到心情色/标签色时，这两项才参与区分，默认样式只有两种外观。
  DiaryCardAppearance appearanceFor({
    required bool pinned,
    required bool locked,
    String? moodEmoji,
    List<Tag> tags = const <Tag>[],
  }) {
    final moodBand = _usesMoodColor && !locked ? _moodBand(moodEmoji) : null;
    final tagColor = _usesTagColor && !locked && tags.isNotEmpty
        ? tags.first.color
        : null;
    final key = (pinned, locked, moodBand, tagColor);
    final cached = _appearances[key];
    if (cached != null) {
      return cached;
    }
    final appearance = _resolver.resolve(
      DiaryCardAppearanceContext(
        pinned: pinned,
        locked: locked,
        moodColor: moodBand == null ? null : moodColorFor(moodEmoji),
        tagColor: tagColor == null ? null : Color(tagColor),
      ),
    );
    _appearances[key] = appearance;
    if (_appearances.length > 64) {
      _appearances.remove(_appearances.keys.first);
    }
    return appearance;
  }

  /// 心情对应的分段颜色（不透明）；没有心情或不在心情配置里时为 null。
  Color? moodColorFor(String? moodEmoji) {
    final band = _moodBand(moodEmoji);
    return band == null
        ? null
        : MoodBandPalette.color(colorScheme, band).withValues(alpha: 1);
  }

  int? _moodBand(String? moodEmoji) {
    final mood = moodEmoji?.trim();
    if (mood == null || mood.isEmpty) {
      return null;
    }
    final weight = _moodWeights[mood];
    return weight == null ? null : MoodBandPalette.bandForWeight(weight);
  }

  bool _usesSource(DiaryCardColorSource source) {
    final surface = style.surface;
    final typography = style.typography;
    return surface.background.source == source ||
        (surface.gradient && surface.gradientEnd.source == source) ||
        surface.borderColor.source == source ||
        (surface.accentBar != DiaryCardAccentBar.none &&
            surface.accentColor.source == source) ||
        (surface.shadow != DiaryCardShadowStyle.themed &&
            surface.shadow != DiaryCardShadowStyle.none &&
            surface.shadowColor.source == source) ||
        typography.titleColor.source == source ||
        typography.bodyColor.source == source;
  }

  static double? _scaledOrNull(double? base, double fallback, double scale) {
    // 缩放为 1 时不改写字号，文字样式与改版前完全相同。
    if (scale == 1) {
      return null;
    }
    return (base ?? fallback) * scale;
  }

  @visibleForTesting
  static void debugClearCache() => _recent.clear();
}
