import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/diary_card_style/diary_card_style.dart';
import '../../../diaries/models/diary_card_style/diary_card_style_presets.dart';
import '../../../diaries/models/diary_card_style/diary_card_style_settings.dart';
import '../../../widgets/expressive_icon_choice_row.dart';

// 卡片样式设置页的文案与图标映射：枚举 → 本地化标签 / 图标 / 数值格式。
// 只做映射，不含状态。

String diaryCardPresetName(AppLocalizations l10n, DiaryCardPresetId id) =>
    switch (id) {
      DiaryCardPresetId.classic => l10n.diaryCardStylePresetClassic,
      DiaryCardPresetId.compact => l10n.diaryCardStylePresetCompact,
      DiaryCardPresetId.magazine => l10n.diaryCardStylePresetMagazine,
      DiaryCardPresetId.minimal => l10n.diaryCardStylePresetMinimal,
      DiaryCardPresetId.gallery => l10n.diaryCardStylePresetGallery,
      DiaryCardPresetId.sticky => l10n.diaryCardStylePresetSticky,
      DiaryCardPresetId.journal => l10n.diaryCardStylePresetJournal,
      DiaryCardPresetId.mood => l10n.diaryCardStylePresetMood,
    };

String diaryCardPresetDescription(
  AppLocalizations l10n,
  DiaryCardPresetId id,
) => switch (id) {
  DiaryCardPresetId.classic => l10n.diaryCardStylePresetClassicDesc,
  DiaryCardPresetId.compact => l10n.diaryCardStylePresetCompactDesc,
  DiaryCardPresetId.magazine => l10n.diaryCardStylePresetMagazineDesc,
  DiaryCardPresetId.minimal => l10n.diaryCardStylePresetMinimalDesc,
  DiaryCardPresetId.gallery => l10n.diaryCardStylePresetGalleryDesc,
  DiaryCardPresetId.sticky => l10n.diaryCardStylePresetStickyDesc,
  DiaryCardPresetId.journal => l10n.diaryCardStylePresetJournalDesc,
  DiaryCardPresetId.mood => l10n.diaryCardStylePresetMoodDesc,
};

FaIconData diaryCardPresetIcon(DiaryCardPresetId id) => switch (id) {
  DiaryCardPresetId.classic => FontAwesomeIcons.solidNewspaper,
  DiaryCardPresetId.compact => FontAwesomeIcons.barsStaggered,
  DiaryCardPresetId.magazine => FontAwesomeIcons.bookOpen,
  DiaryCardPresetId.minimal => FontAwesomeIcons.feather,
  DiaryCardPresetId.gallery => FontAwesomeIcons.images,
  DiaryCardPresetId.sticky => FontAwesomeIcons.noteSticky,
  DiaryCardPresetId.journal => FontAwesomeIcons.bookBookmark,
  DiaryCardPresetId.mood => FontAwesomeIcons.faceSmile,
};

/// 当前样式的显示名：内置预设名、我的样式名，或“自定义”。
String diaryCardStyleDisplayName(
  AppLocalizations l10n,
  DiaryCardStyleSettings settings,
) {
  final preset = DiaryCardPresets.match(settings.current);
  if (preset != null) {
    return diaryCardPresetName(l10n, preset);
  }
  for (final item in settings.saved) {
    if (item.style == settings.current) {
      return item.name;
    }
  }
  return l10n.styleEditorCustom;
}

List<ExpressiveIconChoice<DiaryCardCoverPosition>>
diaryCardCoverPositionChoices(AppLocalizations l10n, DiaryCardMode mode) {
  return <ExpressiveIconChoice<DiaryCardCoverPosition>>[
    for (final position in DiaryCardModeStyle.coverPositionsFor(mode))
      ExpressiveIconChoice<DiaryCardCoverPosition>(
        value: position,
        icon: switch (position) {
          DiaryCardCoverPosition.start => FontAwesomeIcons.tableColumns,
          DiaryCardCoverPosition.end => FontAwesomeIcons.tableColumns,
          DiaryCardCoverPosition.top => FontAwesomeIcons.panorama,
          DiaryCardCoverPosition.background => FontAwesomeIcons.image,
          DiaryCardCoverPosition.hidden => FontAwesomeIcons.eyeSlash,
        },
        label: switch (position) {
          DiaryCardCoverPosition.start => l10n.diaryCardStyleCoverStart,
          DiaryCardCoverPosition.end => l10n.diaryCardStyleCoverEnd,
          DiaryCardCoverPosition.top => l10n.diaryCardStyleCoverTop,
          DiaryCardCoverPosition.background =>
            l10n.diaryCardStyleCoverBackground,
          DiaryCardCoverPosition.hidden => l10n.diaryCardStyleCoverHidden,
        },
      ),
  ];
}

List<ExpressiveIconChoice<DiaryCardCoverShape>> diaryCardCoverShapeChoices(
  AppLocalizations l10n,
) => <ExpressiveIconChoice<DiaryCardCoverShape>>[
  ExpressiveIconChoice<DiaryCardCoverShape>(
    value: DiaryCardCoverShape.square,
    icon: FontAwesomeIcons.square,
    label: l10n.diaryCardStyleShapeSquare,
  ),
  ExpressiveIconChoice<DiaryCardCoverShape>(
    value: DiaryCardCoverShape.landscape,
    icon: FontAwesomeIcons.rectangleList,
    label: l10n.diaryCardStyleShapeLandscape,
  ),
  ExpressiveIconChoice<DiaryCardCoverShape>(
    value: DiaryCardCoverShape.portrait,
    icon: FontAwesomeIcons.mobileScreen,
    label: l10n.diaryCardStyleShapePortrait,
  ),
  ExpressiveIconChoice<DiaryCardCoverShape>(
    value: DiaryCardCoverShape.circle,
    icon: FontAwesomeIcons.circle,
    label: l10n.diaryCardStyleShapeCircle,
  ),
];

List<ExpressiveIconChoice<DiaryCardShadowStyle>> diaryCardShadowChoices(
  AppLocalizations l10n,
) => <ExpressiveIconChoice<DiaryCardShadowStyle>>[
  ExpressiveIconChoice<DiaryCardShadowStyle>(
    value: DiaryCardShadowStyle.themed,
    icon: FontAwesomeIcons.wandMagicSparkles,
    label: l10n.diaryCardStyleShadowThemed,
  ),
  ExpressiveIconChoice<DiaryCardShadowStyle>(
    value: DiaryCardShadowStyle.none,
    icon: FontAwesomeIcons.ban,
    label: l10n.diaryCardStyleShadowNone,
  ),
  ExpressiveIconChoice<DiaryCardShadowStyle>(
    value: DiaryCardShadowStyle.soft,
    icon: FontAwesomeIcons.cloud,
    label: l10n.diaryCardStyleShadowSoft,
  ),
  ExpressiveIconChoice<DiaryCardShadowStyle>(
    value: DiaryCardShadowStyle.floating,
    icon: FontAwesomeIcons.layerGroup,
    label: l10n.diaryCardStyleShadowFloating,
  ),
  ExpressiveIconChoice<DiaryCardShadowStyle>(
    value: DiaryCardShadowStyle.custom,
    icon: FontAwesomeIcons.sliders,
    label: l10n.diaryCardStyleShadowCustom,
  ),
];

String diaryCardBlockLabel(AppLocalizations l10n, DiaryCardBlock block) =>
    switch (block) {
      DiaryCardBlock.eyebrow => l10n.diaryCardStyleBlockEyebrow,
      DiaryCardBlock.title => l10n.diaryCardStyleBlockTitle,
      DiaryCardBlock.tags => l10n.diaryCardStyleBlockTags,
      DiaryCardBlock.preview => l10n.diaryCardStyleBlockPreview,
      DiaryCardBlock.footer => l10n.diaryCardStyleBlockFooter,
    };

FaIconData diaryCardBlockIcon(DiaryCardBlock block) => switch (block) {
  DiaryCardBlock.eyebrow => FontAwesomeIcons.calendarDay,
  DiaryCardBlock.title => FontAwesomeIcons.heading,
  DiaryCardBlock.tags => FontAwesomeIcons.tags,
  DiaryCardBlock.preview => FontAwesomeIcons.alignLeft,
  DiaryCardBlock.footer => FontAwesomeIcons.clock,
};

String diaryCardColorSourceLabel(
  AppLocalizations l10n,
  DiaryCardColorSource source,
) => switch (source) {
  DiaryCardColorSource.theme => l10n.diaryCardStyleSourceTheme,
  DiaryCardColorSource.primary => l10n.diaryCardStyleSourcePrimary,
  DiaryCardColorSource.secondary => l10n.diaryCardStyleSourceSecondary,
  DiaryCardColorSource.tertiary => l10n.diaryCardStyleSourceTertiary,
  DiaryCardColorSource.mood => l10n.diaryCardStyleSourceMood,
  DiaryCardColorSource.firstTag => l10n.diaryCardStyleSourceTag,
  DiaryCardColorSource.custom => l10n.diaryCardStyleSourceCustom,
};

/// 数值标签：dp、百分比与倍率统一一位小数以内、去掉多余的 `.0`。
String diaryCardDpLabel(AppLocalizations l10n, double value) =>
    l10n.diaryCardStyleValueDp(_trim(value));

String diaryCardPercentLabel(AppLocalizations l10n, double fraction) =>
    l10n.diaryCardStyleValuePercent(
      NumberFormat.decimalPattern(
        l10n.localeName,
      ).format((fraction * 100).round()),
    );

String _trim(double value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.round().toString()
      : rounded.toStringAsFixed(1);
}
