import 'diary_card_style.dart';

/// 内置预设的标识；名称、说明与图标由设置页按 id 解析（模型层不含文案）。
enum DiaryCardPresetId {
  classic,
  compact,
  magazine,
  minimal,
  gallery,
  sticky,
  journal,
  mood,
  glass,
}

/// 内置的卡片样式预设。
///
/// 套用预设即把当前样式整体替换为预设值（之后可继续微调）；[classic] 就是
/// 默认样式。标签显示数量是独立设置，预设不改动它。
abstract final class DiaryCardPresets {
  static const Map<DiaryCardPresetId, DiaryCardStyle> styles =
      <DiaryCardPresetId, DiaryCardStyle>{
        DiaryCardPresetId.classic: DiaryCardStyle.defaults,
        DiaryCardPresetId.compact: _compact,
        DiaryCardPresetId.magazine: _magazine,
        DiaryCardPresetId.minimal: _minimal,
        DiaryCardPresetId.gallery: _gallery,
        DiaryCardPresetId.sticky: _sticky,
        DiaryCardPresetId.journal: _journal,
        DiaryCardPresetId.mood: _mood,
        DiaryCardPresetId.glass: _glass,
      };

  static DiaryCardStyle styleOf(DiaryCardPresetId id) => styles[id]!;

  /// 与 [style] 完全相同的第一个预设；不是任何预设时为 null。
  static DiaryCardPresetId? match(DiaryCardStyle style) {
    for (final entry in styles.entries) {
      if (entry.value == style) {
        return entry.key;
      }
    }
    return null;
  }

  /// 紧凑：小封面、单行摘要、收紧的间距，一屏能看到更多日记。
  static const _compact = DiaryCardStyle(
    surface: DiaryCardSurfaceStyle(cornerRadius: 18),
    typography: DiaryCardTypography(titleScale: 0.9),
    list: DiaryCardModeStyle(
      coverPosition: DiaryCardCoverPosition.start,
      coverSide: 84,
      coverRadius: 12,
      coverHeight: 160,
      coverGap: 12,
      paddingH: 14,
      paddingV: 10,
      cardGap: 6,
      elementGap: 4,
      previewMaxLines: 1,
      metaPosition: DiaryCardMetaPosition.eyebrow,
    ),
    waterfall: DiaryCardModeStyle(
      coverPosition: DiaryCardCoverPosition.top,
      coverHeight: 112,
      coverGap: 10,
      paddingH: 12,
      paddingV: 10,
      cardGap: 6,
      elementGap: 4,
      previewMaxLines: 2,
      metaPosition: DiaryCardMetaPosition.footer,
    ),
  );

  /// 杂志：通栏大图、放大的标题与宽松行距，完整日期。
  static const _magazine = DiaryCardStyle(
    surface: DiaryCardSurfaceStyle(
      cornerRadius: 20,
      shadow: DiaryCardShadowStyle.soft,
    ),
    typography: DiaryCardTypography(
      titleScale: 1.12,
      lineHeight: DiaryCardLineHeight.relaxed,
    ),
    content: DiaryCardContentStyle(tagStyle: DiaryCardTagStyle.plain),
    meta: DiaryCardMetaStyle(dateFormat: DiaryCardDateFormat.full),
    list: DiaryCardModeStyle(
      coverPosition: DiaryCardCoverPosition.top,
      coverHeight: 184,
      coverDivider: false,
      coverGap: 14,
      paddingH: 18,
      paddingV: 16,
      elementGap: 8,
      previewMaxLines: 3,
      metaPosition: DiaryCardMetaPosition.eyebrow,
    ),
    waterfall: DiaryCardModeStyle(
      coverPosition: DiaryCardCoverPosition.top,
      coverHeight: 180,
      coverDivider: false,
      coverGap: 10,
      paddingH: 14,
      paddingV: 14,
      elementGap: 6,
      previewMaxLines: 4,
      metaPosition: DiaryCardMetaPosition.footer,
    ),
  );

  /// 极简：只留文字，去掉封面、描边、阴影与心情天气。
  static const _minimal = DiaryCardStyle(
    surface: DiaryCardSurfaceStyle(
      cornerRadius: 16,
      borderWidth: 0,
      shadow: DiaryCardShadowStyle.none,
    ),
    typography: DiaryCardTypography(titleWeight: DiaryCardTitleWeight.medium),
    content: DiaryCardContentStyle(
      tagStyle: DiaryCardTagStyle.dot,
      pinnedBadge: DiaryCardPinnedBadge.iconOnly,
    ),
    meta: DiaryCardMetaStyle(
      showMood: false,
      showWeather: false,
      footerTime: DiaryCardFooterTime.hidden,
    ),
    list: DiaryCardModeStyle(
      coverPosition: DiaryCardCoverPosition.hidden,
      coverHeight: 160,
      coverGap: 14,
      paddingH: 16,
      paddingV: 16,
      elementGap: 6,
      previewMaxLines: 2,
      metaPosition: DiaryCardMetaPosition.eyebrow,
    ),
    waterfall: DiaryCardModeStyle(
      coverPosition: DiaryCardCoverPosition.hidden,
      coverHeight: 140,
      coverGap: 10,
      paddingH: 14,
      paddingV: 14,
      elementGap: 5,
      previewMaxLines: 4,
      metaPosition: DiaryCardMetaPosition.footer,
    ),
  );

  /// 画廊：照片优先。列表为多图拼贴的通栏封面，瀑布流以封面作卡片背景。
  static const _gallery = DiaryCardStyle(
    surface: DiaryCardSurfaceStyle(
      cornerRadius: 22,
      shadow: DiaryCardShadowStyle.floating,
    ),
    content: DiaryCardContentStyle(collage: true),
    list: DiaryCardModeStyle(
      coverPosition: DiaryCardCoverPosition.top,
      coverHeight: 200,
      coverDivider: false,
      coverGap: 14,
      paddingH: 16,
      paddingV: 14,
      elementGap: 6,
      previewMaxLines: 2,
      metaPosition: DiaryCardMetaPosition.cover,
    ),
    waterfall: DiaryCardModeStyle(
      coverPosition: DiaryCardCoverPosition.background,
      coverHeight: 252,
      coverGap: 10,
      scrim: 0.85,
      paddingH: 12,
      paddingV: 12,
      elementGap: 4,
      previewMaxLines: 2,
      metaPosition: DiaryCardMetaPosition.cover,
    ),
  );

  /// 便签：暖黄纸面、顶部色条与小圆角，封面像夹在纸上的照片。
  static const _sticky = DiaryCardStyle(
    surface: DiaryCardSurfaceStyle(
      cornerRadius: 6,
      background: DiaryCardColorSpec(
        source: DiaryCardColorSource.custom,
        light: 0xFFFFF4B8,
        strength: 1,
      ),
      borderWidth: 0,
      accentBar: DiaryCardAccentBar.top,
      accentWidth: 6,
      accentColor: DiaryCardColorSpec(
        source: DiaryCardColorSource.custom,
        light: 0xFFF2B33D,
        strength: 1,
      ),
      shadow: DiaryCardShadowStyle.floating,
    ),
    content: DiaryCardContentStyle(tagStyle: DiaryCardTagStyle.plain),
    list: DiaryCardModeStyle(
      coverPosition: DiaryCardCoverPosition.end,
      coverSide: 88,
      coverShape: DiaryCardCoverShape.portrait,
      coverRadius: 4,
      coverHeight: 160,
      coverGap: 14,
      paddingH: 16,
      paddingV: 16,
      elementGap: 6,
      previewMaxLines: 3,
      metaPosition: DiaryCardMetaPosition.eyebrow,
    ),
    waterfall: DiaryCardModeStyle(
      coverPosition: DiaryCardCoverPosition.top,
      coverRadius: 4,
      coverHeight: 120,
      coverInset: true,
      coverGap: 10,
      paddingH: 12,
      paddingV: 14,
      elementGap: 5,
      previewMaxLines: 4,
      metaPosition: DiaryCardMetaPosition.footer,
    ),
  );

  /// 手账：起始边主色条，没有封面时用大号日期块占位。
  static const _journal = DiaryCardStyle(
    surface: DiaryCardSurfaceStyle(
      cornerRadius: 18,
      accentBar: DiaryCardAccentBar.start,
    ),
    content: DiaryCardContentStyle(
      coverFallback: DiaryCardCoverFallback.dateBlock,
    ),
    meta: DiaryCardMetaStyle(showTime: true),
    list: DiaryCardModeStyle(
      coverPosition: DiaryCardCoverPosition.start,
      coverSide: 96,
      coverRadius: 14,
      coverHeight: 160,
      coverGap: 14,
      paddingH: 16,
      paddingV: 14,
      elementGap: 6,
      previewMaxLines: 2,
      metaPosition: DiaryCardMetaPosition.eyebrow,
    ),
  );

  /// 心情色：卡片底色、描边随当天心情变化，没有封面时显示心情块。
  static const _mood = DiaryCardStyle(
    surface: DiaryCardSurfaceStyle(
      background: DiaryCardColorSpec(
        source: DiaryCardColorSource.mood,
        strength: 0.16,
      ),
      borderWidth: 1.2,
      borderColor: DiaryCardColorSpec(
        source: DiaryCardColorSource.mood,
        strength: 0.6,
      ),
    ),
    content: DiaryCardContentStyle(
      coverFallback: DiaryCardCoverFallback.moodTile,
    ),
    meta: DiaryCardMetaStyle(indicatorStyle: DiaryCardIndicatorStyle.plain),
  );

  /// 玻璃：中性的主题卡片底色降到 55% 不透明并模糊页面背景图，白色细描边
  /// 勾出边缘、柔和外投影托起卡片。底色取主题来源（不写死颜色），暗色主题
  /// 下自然是深色玻璃；描边的自定义白色在暗色主题经 `deriveDark` 推导为
  /// 浅灰。没有背景图的页面上它就是一张半透明卡片。
  static const _glass = DiaryCardStyle(
    surface: DiaryCardSurfaceStyle(
      opacity: 0.55,
      material: DiaryCardMaterial.glass,
      blurSigma: 18,
      borderWidth: 0.8,
      borderColor: DiaryCardColorSpec(
        source: DiaryCardColorSource.custom,
        light: 0xFFFFFFFF,
        strength: 0.5,
      ),
      shadow: DiaryCardShadowStyle.soft,
    ),
  );
}
