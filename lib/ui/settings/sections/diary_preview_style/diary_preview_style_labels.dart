import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/diary_preview_style/diary_preview_presets.dart';
import '../../../diaries/models/diary_preview_style/diary_preview_settings.dart';
import '../../../diaries/models/diary_preview_style/diary_preview_style.dart';
import '../../../widgets/expressive_icon_choice_row.dart';
import '../../widgets/style_editor/style_preset_grid.dart';

// 预览页样式设置的文案与图标映射：枚举 → 本地化标签 / 图标。只做映射，
// 不含状态。

String diaryPreviewPresetName(AppLocalizations l10n, DiaryPreviewPresetId id) =>
    switch (id) {
      DiaryPreviewPresetId.classic => l10n.diaryPreviewStylePresetClassic,
      DiaryPreviewPresetId.paper => l10n.diaryPreviewStylePresetPaper,
      DiaryPreviewPresetId.magazine => l10n.diaryPreviewStylePresetMagazine,
      DiaryPreviewPresetId.minimal => l10n.diaryPreviewStylePresetMinimal,
      DiaryPreviewPresetId.night => l10n.diaryPreviewStylePresetNight,
      DiaryPreviewPresetId.journal => l10n.diaryPreviewStylePresetJournal,
      DiaryPreviewPresetId.mood => l10n.diaryPreviewStylePresetMood,
      DiaryPreviewPresetId.immersive => l10n.diaryPreviewStylePresetImmersive,
    };

String _presetDescription(AppLocalizations l10n, DiaryPreviewPresetId id) =>
    switch (id) {
      DiaryPreviewPresetId.classic => l10n.diaryPreviewStylePresetClassicDesc,
      DiaryPreviewPresetId.paper => l10n.diaryPreviewStylePresetPaperDesc,
      DiaryPreviewPresetId.magazine => l10n.diaryPreviewStylePresetMagazineDesc,
      DiaryPreviewPresetId.minimal => l10n.diaryPreviewStylePresetMinimalDesc,
      DiaryPreviewPresetId.night => l10n.diaryPreviewStylePresetNightDesc,
      DiaryPreviewPresetId.journal => l10n.diaryPreviewStylePresetJournalDesc,
      DiaryPreviewPresetId.mood => l10n.diaryPreviewStylePresetMoodDesc,
      DiaryPreviewPresetId.immersive =>
        l10n.diaryPreviewStylePresetImmersiveDesc,
    };

FaIconData _presetIcon(DiaryPreviewPresetId id) => switch (id) {
  DiaryPreviewPresetId.classic => FontAwesomeIcons.bookOpenReader,
  DiaryPreviewPresetId.paper => FontAwesomeIcons.scroll,
  DiaryPreviewPresetId.magazine => FontAwesomeIcons.newspaper,
  DiaryPreviewPresetId.minimal => FontAwesomeIcons.feather,
  DiaryPreviewPresetId.night => FontAwesomeIcons.moon,
  DiaryPreviewPresetId.journal => FontAwesomeIcons.bookBookmark,
  DiaryPreviewPresetId.mood => FontAwesomeIcons.faceSmile,
  DiaryPreviewPresetId.immersive => FontAwesomeIcons.expand,
};

List<StylePresetOption<DiaryPreviewPresetId>> diaryPreviewPresetOptions(
  AppLocalizations l10n,
) => <StylePresetOption<DiaryPreviewPresetId>>[
  for (final id in DiaryPreviewPresetId.values)
    StylePresetOption<DiaryPreviewPresetId>(
      id: id,
      icon: _presetIcon(id),
      name: diaryPreviewPresetName(l10n, id),
      description: _presetDescription(l10n, id),
    ),
];

/// 当前外观的显示名：内置预设名、我的样式名，或“自定义”。
String diaryPreviewStyleDisplayName(
  AppLocalizations l10n,
  DiaryPreviewSettings settings,
) {
  final preset = DiaryPreviewPresets.match(settings.current);
  if (preset != null) {
    return diaryPreviewPresetName(l10n, preset);
  }
  for (final item in settings.saved) {
    if (item.style == settings.current) {
      return item.name;
    }
  }
  return l10n.styleEditorCustom;
}

List<ExpressiveIconChoice<DiaryPreviewColorSeed>> diaryPreviewSeedChoices(
  AppLocalizations l10n,
) => <ExpressiveIconChoice<DiaryPreviewColorSeed>>[
  ExpressiveIconChoice<DiaryPreviewColorSeed>(
    value: DiaryPreviewColorSeed.app,
    icon: FontAwesomeIcons.palette,
    label: l10n.diaryPreviewStyleSeedApp,
  ),
  ExpressiveIconChoice<DiaryPreviewColorSeed>(
    value: DiaryPreviewColorSeed.mood,
    icon: FontAwesomeIcons.faceSmile,
    label: l10n.diaryPreviewStyleSeedMood,
  ),
  ExpressiveIconChoice<DiaryPreviewColorSeed>(
    value: DiaryPreviewColorSeed.tag,
    icon: FontAwesomeIcons.tag,
    label: l10n.diaryPreviewStyleSeedTag,
  ),
  ExpressiveIconChoice<DiaryPreviewColorSeed>(
    value: DiaryPreviewColorSeed.custom,
    icon: FontAwesomeIcons.eyeDropper,
    label: l10n.diaryPreviewStyleSeedCustom,
  ),
];

/// 配色基调下方的说明：随所选基调换成这一种的取色方式。
String diaryPreviewSeedHint(
  AppLocalizations l10n,
  DiaryPreviewColorSeed seed,
) => switch (seed) {
  DiaryPreviewColorSeed.app => l10n.diaryPreviewStyleSeedAppHint,
  DiaryPreviewColorSeed.mood => l10n.diaryPreviewStyleSeedMoodHint,
  DiaryPreviewColorSeed.tag => l10n.diaryPreviewStyleSeedTagHint,
  DiaryPreviewColorSeed.custom => l10n.diaryPreviewStyleSeedCustomHint,
};

String diaryPreviewSeedIntensityLabel(
  AppLocalizations l10n,
  DiaryPreviewSeedIntensity intensity,
) => switch (intensity) {
  DiaryPreviewSeedIntensity.soft => l10n.diaryPreviewStyleSeedIntensitySoft,
  DiaryPreviewSeedIntensity.original =>
    l10n.diaryPreviewStyleSeedIntensityOriginal,
  DiaryPreviewSeedIntensity.vivid => l10n.diaryPreviewStyleSeedIntensityVivid,
};

String diaryPreviewSeedFallbackLabel(
  AppLocalizations l10n,
  DiaryPreviewSeedFallback fallback,
) => switch (fallback) {
  DiaryPreviewSeedFallback.app => l10n.diaryPreviewStyleSeedFallbackApp,
  DiaryPreviewSeedFallback.neutral => l10n.diaryPreviewStyleSeedFallbackNeutral,
};

String diaryPreviewPaperLabel(AppLocalizations l10n, DiaryPreviewPaper paper) =>
    switch (paper) {
      DiaryPreviewPaper.theme => l10n.diaryPreviewStylePaperTheme,
      DiaryPreviewPaper.warm => l10n.diaryPreviewStylePaperWarm,
      DiaryPreviewPaper.sepia => l10n.diaryPreviewStylePaperSepia,
      DiaryPreviewPaper.mint => l10n.diaryPreviewStylePaperMint,
      DiaryPreviewPaper.gray => l10n.diaryPreviewStylePaperGray,
      DiaryPreviewPaper.ink => l10n.diaryPreviewStylePaperInk,
      DiaryPreviewPaper.custom => l10n.diaryPreviewStylePaperCustom,
    };

List<ExpressiveIconChoice<DiaryPreviewCoverMode>> diaryPreviewCoverModeChoices(
  AppLocalizations l10n,
) => <ExpressiveIconChoice<DiaryPreviewCoverMode>>[
  ExpressiveIconChoice<DiaryPreviewCoverMode>(
    value: DiaryPreviewCoverMode.banner,
    icon: FontAwesomeIcons.panorama,
    label: l10n.diaryPreviewStyleCoverBanner,
  ),
  ExpressiveIconChoice<DiaryPreviewCoverMode>(
    value: DiaryPreviewCoverMode.inset,
    icon: FontAwesomeIcons.image,
    label: l10n.diaryPreviewStyleCoverInset,
  ),
  ExpressiveIconChoice<DiaryPreviewCoverMode>(
    value: DiaryPreviewCoverMode.hidden,
    icon: FontAwesomeIcons.eyeSlash,
    label: l10n.diaryPreviewStyleCoverHidden,
  ),
];

List<ExpressiveIconChoice<DiaryPreviewMetaLayout>>
diaryPreviewMetaLayoutChoices(AppLocalizations l10n) =>
    <ExpressiveIconChoice<DiaryPreviewMetaLayout>>[
      ExpressiveIconChoice<DiaryPreviewMetaLayout>(
        value: DiaryPreviewMetaLayout.stacked,
        icon: FontAwesomeIcons.barsStaggered,
        label: l10n.diaryPreviewStyleMetaStacked,
      ),
      ExpressiveIconChoice<DiaryPreviewMetaLayout>(
        value: DiaryPreviewMetaLayout.inline,
        icon: FontAwesomeIcons.gripLines,
        label: l10n.diaryPreviewStyleMetaInline,
      ),
      ExpressiveIconChoice<DiaryPreviewMetaLayout>(
        value: DiaryPreviewMetaLayout.card,
        icon: FontAwesomeIcons.idCard,
        label: l10n.diaryPreviewStyleMetaCard,
      ),
    ];
