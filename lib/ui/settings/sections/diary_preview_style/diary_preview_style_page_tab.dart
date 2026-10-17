import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/diary_preview_style/diary_preview_style.dart';
import '../../../diaries/viewmodels/diary_card_colors.dart';
import '../../../diaries/viewmodels/diary_preview_resolved_style.dart';
import '../../../widgets/color_swatch_button.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../../widgets/expressive_icon_choice_row.dart';
import '../../controllers/diary_preview_style_editor_controller.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import '../../widgets/style_editor/style_custom_color_tile.dart';
import '../../widgets/style_editor/style_editor_common.dart';
import '../diary_card_style/diary_card_style_labels.dart';
import 'diary_preview_style_labels.dart';

/// “页面”标签页：配色基调、纸张与正文颜色，边距与正文宽度，顶栏，阅读
/// 辅助（进度线、回到顶部）。
class DiaryPreviewStylePageTab extends StatelessWidget {
  const DiaryPreviewStylePageTab({super.key, required this.controller});

  final DiaryPreviewStyleEditorController controller;

  /// 自定义颜色初次打开时的初始值：取当前主题主色。
  static int _initialColor(BuildContext context) =>
      Theme.of(context).colorScheme.primary.toARGB32();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final page = controller.style.page;
    final scheme = Theme.of(context).colorScheme;
    final light = scheme.brightness == Brightness.light;

    void commit(DiaryPreviewPageStyle next) =>
        controller.commitWith((style) => style.copyWith(page: next));
    void preview(DiaryPreviewPageStyle next) =>
        controller.previewWith((style) => style.copyWith(page: next));

    Color paperSwatch(DiaryPreviewPaper paper) {
      final preset = DiaryPreviewResolvedStyle.paperColors[paper];
      if (preset != null) {
        return Color(light ? preset.$1 : preset.$2);
      }
      return scheme.surface;
    }

    return StyleEditorTabList(
      children: <Widget>[
        SettingsCardGroup(
          title: l10n.diaryPreviewStyleColorGroup,
          footer: l10n.diaryPreviewStylePaperHint,
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.diaryPreviewStyleColorSeed,
              subtitle: l10n.diaryPreviewStyleSeedHint,
              child: ExpressiveIconChoiceRow<DiaryPreviewColorSeed>(
                choices: diaryPreviewSeedChoices(l10n),
                selected: page.colorSeed,
                onSelected: (DiaryPreviewColorSeed seed) => commit(
                  page.copyWith(
                    colorSeed: seed,
                    seedColor:
                        seed == DiaryPreviewColorSeed.custom &&
                            page.seedColor == null
                        ? () => _initialColor(context)
                        : null,
                  ),
                ),
              ),
            ),
            if (page.colorSeed == DiaryPreviewColorSeed.custom)
              StyleCustomColorTile(
                title: l10n.diaryPreviewStyleSeedColor,
                light: page.seedColor ?? _initialColor(context),
                dark: null,
                role: DiaryCardColorRole.accent,
                onChanged: (color) =>
                    commit(page.copyWith(seedColor: () => color.light)),
              ),
            SettingsChoiceTile(
              title: l10n.diaryPreviewStylePaper,
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: <Widget>[
                  for (final paper in DiaryPreviewPaper.values)
                    if (paper == DiaryPreviewPaper.custom)
                      Tooltip(
                        message: diaryPreviewPaperLabel(l10n, paper),
                        child: IconButton.outlined(
                          isSelected: page.paper == paper,
                          // 第一次选自定义时从暖白纸起调（浅色值）。
                          onPressed: () => commit(
                            page.copyWith(
                              paper: paper,
                              paperLight: page.paperLight == null
                                  ? () => DiaryPreviewResolvedStyle
                                        .paperColors[DiaryPreviewPaper.warm]!
                                        .$1
                                  : null,
                            ),
                          ),
                          icon: const FaIcon(
                            FontAwesomeIcons.eyeDropper,
                            size: 16,
                          ),
                        ),
                      )
                    else
                      ColorSwatchButton(
                        color: paperSwatch(paper),
                        selected: page.paper == paper,
                        semanticLabel: diaryPreviewPaperLabel(l10n, paper),
                        onTap: () => commit(page.copyWith(paper: paper)),
                      ),
                ],
              ),
            ),
            if (page.paper == DiaryPreviewPaper.custom &&
                page.paperLight != null)
              StyleCustomColorTile(
                title: l10n.diaryPreviewStylePaperColor,
                light: page.paperLight!,
                dark: page.paperDark,
                role: DiaryCardColorRole.surface,
                onChanged: (color) => commit(
                  page.copyWith(
                    paperLight: () => color.light,
                    paperDark: () => color.dark,
                  ),
                ),
              ),
            SettingsSwitchTile(
              title: l10n.diaryPreviewStyleTextColor,
              subtitle: l10n.diaryPreviewStyleTextColorHint,
              value: page.textLight != null,
              onChanged: (bool on) => commit(
                page.copyWith(
                  textLight: () => on ? scheme.onSurface.toARGB32() : null,
                  textDark: () => null,
                ),
              ),
            ),
            if (page.textLight != null)
              StyleCustomColorTile(
                title: l10n.diaryPreviewStyleTextColor,
                light: page.textLight!,
                dark: page.textDark,
                role: DiaryCardColorRole.text,
                onChanged: (color) => commit(
                  page.copyWith(
                    textLight: () => color.light,
                    textDark: () => color.dark,
                  ),
                ),
              ),
          ],
        ),
        SettingsCardGroup(
          title: l10n.diaryPreviewStyleLayoutGroup,
          children: <Widget>[
            SettingsSliderTile(
              title: l10n.diaryPreviewStylePadding,
              value: page.horizontalPadding,
              min: DiaryPreviewStyleLimits.horizontalPadding.min,
              max: DiaryPreviewStyleLimits.horizontalPadding.max,
              divisions: DiaryPreviewStyleLimits.horizontalPadding.divisions,
              valueLabel: (double v) => diaryCardDpLabel(l10n, v),
              onChanged: (double v) =>
                  preview(page.copyWith(horizontalPadding: v)),
              onChangeEnd: (double v) =>
                  commit(page.copyWith(horizontalPadding: v)),
            ),
            SettingsSwitchTile(
              title: l10n.diaryPreviewStyleLimitWidth,
              subtitle: l10n.diaryPreviewStyleLimitWidthSubtitle,
              value: page.limitWidth,
              onChanged: (bool v) => commit(page.copyWith(limitWidth: v)),
            ),
            if (page.limitWidth)
              SettingsSliderTile(
                title: l10n.diaryPreviewStyleContentWidth,
                value: page.contentWidth,
                min: DiaryPreviewStyleLimits.contentWidth.min,
                max: DiaryPreviewStyleLimits.contentWidth.max,
                divisions: DiaryPreviewStyleLimits.contentWidth.divisions,
                valueLabel: (double v) => diaryCardDpLabel(l10n, v),
                onChanged: (double v) =>
                    preview(page.copyWith(contentWidth: v)),
                onChangeEnd: (double v) =>
                    commit(page.copyWith(contentWidth: v)),
              ),
          ],
        ),
        SettingsCardGroup(
          title: l10n.diaryPreviewStyleTopBarGroup,
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.diaryPreviewStyleTopBarGroup,
              child: ExpressiveButtonGroup<DiaryPreviewTopBarMode>(
                segments: <ButtonSegment<DiaryPreviewTopBarMode>>[
                  ButtonSegment<DiaryPreviewTopBarMode>(
                    value: DiaryPreviewTopBarMode.floating,
                    label: Text(l10n.diaryPreviewStyleTopBarFloating),
                  ),
                  ButtonSegment<DiaryPreviewTopBarMode>(
                    value: DiaryPreviewTopBarMode.pinned,
                    label: Text(l10n.diaryPreviewStyleTopBarPinned),
                  ),
                ],
                selected: <DiaryPreviewTopBarMode>{page.topBar},
                onSelectionChanged: (Set<DiaryPreviewTopBarMode> v) =>
                    commit(page.copyWith(topBar: v.single)),
              ),
            ),
            SettingsChoiceTile(
              title: l10n.diaryPreviewStyleTopBarTitle,
              child: ExpressiveButtonGroup<DiaryPreviewTopBarTitle>(
                minSegmentWidth: 64,
                segments: <ButtonSegment<DiaryPreviewTopBarTitle>>[
                  ButtonSegment<DiaryPreviewTopBarTitle>(
                    value: DiaryPreviewTopBarTitle.label,
                    label: Text(l10n.autoT0120),
                  ),
                  ButtonSegment<DiaryPreviewTopBarTitle>(
                    value: DiaryPreviewTopBarTitle.date,
                    label: Text(l10n.diaryPreviewStyleTopBarTitleDate),
                  ),
                  ButtonSegment<DiaryPreviewTopBarTitle>(
                    value: DiaryPreviewTopBarTitle.position,
                    label: Text(l10n.diaryPreviewStyleTopBarTitlePosition),
                  ),
                  ButtonSegment<DiaryPreviewTopBarTitle>(
                    value: DiaryPreviewTopBarTitle.none,
                    label: Text(l10n.diaryPreviewStyleTopBarTitleNone),
                  ),
                ],
                selected: <DiaryPreviewTopBarTitle>{page.topBarTitle},
                onSelectionChanged: (Set<DiaryPreviewTopBarTitle> v) =>
                    commit(page.copyWith(topBarTitle: v.single)),
              ),
            ),
            SettingsSwitchTile(
              title: l10n.diaryPreviewStyleShowTypographyButton,
              value: page.showTypographyButton,
              onChanged: (bool v) =>
                  commit(page.copyWith(showTypographyButton: v)),
            ),
            SettingsSwitchTile(
              title: l10n.diaryPreviewStyleShowEditButton,
              value: page.showEditButton,
              onChanged: (bool v) => commit(page.copyWith(showEditButton: v)),
            ),
            SettingsSwitchTile(
              title: l10n.diaryPreviewStyleShowShareButton,
              value: page.showShareButton,
              onChanged: (bool v) => commit(page.copyWith(showShareButton: v)),
            ),
          ],
        ),
        SettingsCardGroup(
          title: l10n.diaryPreviewStyleReadingGroup,
          children: <Widget>[
            SettingsSwitchTile(
              title: l10n.diaryPreviewStyleProgress,
              subtitle: l10n.diaryPreviewStyleProgressSubtitle,
              value: page.progress == DiaryPreviewProgress.line,
              onChanged: (bool v) => commit(
                page.copyWith(
                  progress: v
                      ? DiaryPreviewProgress.line
                      : DiaryPreviewProgress.none,
                ),
              ),
            ),
            SettingsSwitchTile(
              title: l10n.diaryPreviewStyleBackToTop,
              subtitle: l10n.diaryPreviewStyleBackToTopSubtitle,
              value: page.backToTop,
              onChanged: (bool v) => commit(page.copyWith(backToTop: v)),
            ),
          ],
        ),
      ],
    );
  }
}
