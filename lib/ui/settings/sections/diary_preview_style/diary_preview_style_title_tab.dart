import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/diary_preview_style/diary_preview_style.dart';
import '../../../diaries/viewmodels/diary_card_colors.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../controllers/diary_preview_style_editor_controller.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import '../../widgets/style_editor/style_custom_color_tile.dart';
import '../../widgets/style_editor/style_editor_common.dart';
import '../diary_card_style/diary_card_style_labels.dart';

/// “标题”标签页：显隐、“无标题”占位、大小、字重、对齐与颜色。标题字体
/// 跟随正文字体设置，这里不另设。
class DiaryPreviewStyleTitleTab extends StatelessWidget {
  const DiaryPreviewStyleTitleTab({super.key, required this.controller});

  final DiaryPreviewStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = controller.style.title;
    final scheme = Theme.of(context).colorScheme;

    void commit(DiaryPreviewTitleStyle next) =>
        controller.commitWith((style) => style.copyWith(title: next));
    void preview(DiaryPreviewTitleStyle next) =>
        controller.previewWith((style) => style.copyWith(title: next));

    return StyleEditorTabList(
      children: <Widget>[
        SettingsCardGroup(
          children: <Widget>[
            SettingsSwitchTile(
              title: l10n.diaryPreviewStyleTitleVisible,
              value: title.visible,
              onChanged: (bool v) => commit(title.copyWith(visible: v)),
            ),
            if (title.visible) ...<Widget>[
              SettingsSwitchTile(
                title: l10n.diaryPreviewStyleTitleUntitled,
                subtitle: l10n.diaryPreviewStyleTitleUntitledSubtitle,
                value: title.showUntitled,
                onChanged: (bool v) => commit(title.copyWith(showUntitled: v)),
              ),
              SettingsSliderTile(
                title: l10n.diaryPreviewStyleTitleScale,
                value: title.scale,
                min: DiaryPreviewStyleLimits.titleScale.min,
                max: DiaryPreviewStyleLimits.titleScale.max,
                divisions: DiaryPreviewStyleLimits.titleScale.divisions,
                valueLabel: (double v) => diaryCardPercentLabel(l10n, v),
                onChanged: (double v) => preview(title.copyWith(scale: v)),
                onChangeEnd: (double v) => commit(title.copyWith(scale: v)),
              ),
              SettingsChoiceTile(
                title: l10n.diaryPreviewStyleTitleWeight,
                child: ExpressiveButtonGroup<DiaryPreviewTitleWeight>(
                  minSegmentWidth: 64,
                  segments: <ButtonSegment<DiaryPreviewTitleWeight>>[
                    for (final (weight, label)
                        in <(DiaryPreviewTitleWeight, String)>[
                          (
                            DiaryPreviewTitleWeight.regular,
                            l10n.diaryPreviewStyleWeightRegular,
                          ),
                          (
                            DiaryPreviewTitleWeight.medium,
                            l10n.diaryPreviewStyleWeightMedium,
                          ),
                          (
                            DiaryPreviewTitleWeight.bold,
                            l10n.diaryPreviewStyleWeightBold,
                          ),
                          (
                            DiaryPreviewTitleWeight.heavy,
                            l10n.diaryPreviewStyleWeightHeavy,
                          ),
                        ])
                      ButtonSegment<DiaryPreviewTitleWeight>(
                        value: weight,
                        label: Text(label),
                      ),
                  ],
                  selected: <DiaryPreviewTitleWeight>{title.weight},
                  onSelectionChanged: (Set<DiaryPreviewTitleWeight> v) =>
                      commit(title.copyWith(weight: v.single)),
                ),
              ),
              SettingsChoiceTile(
                title: l10n.diaryPreviewStyleTitleAlign,
                child: ExpressiveButtonGroup<DiaryPreviewAlign>(
                  segments: <ButtonSegment<DiaryPreviewAlign>>[
                    ButtonSegment<DiaryPreviewAlign>(
                      value: DiaryPreviewAlign.start,
                      label: Text(l10n.diaryPreviewStyleAlignStart),
                    ),
                    ButtonSegment<DiaryPreviewAlign>(
                      value: DiaryPreviewAlign.center,
                      label: Text(l10n.diaryPreviewStyleAlignCenter),
                    ),
                  ],
                  selected: <DiaryPreviewAlign>{title.align},
                  onSelectionChanged: (Set<DiaryPreviewAlign> v) =>
                      commit(title.copyWith(align: v.single)),
                ),
              ),
              SettingsSwitchTile(
                title: l10n.diaryPreviewStyleTitleColor,
                subtitle: l10n.diaryPreviewStyleTextColorHint,
                value: title.colorLight != null,
                onChanged: (bool on) => commit(
                  title.copyWith(
                    colorLight: () => on ? scheme.primary.toARGB32() : null,
                    colorDark: () => null,
                  ),
                ),
              ),
              if (title.colorLight != null)
                StyleCustomColorTile(
                  title: l10n.diaryPreviewStyleTitleColor,
                  light: title.colorLight!,
                  dark: title.colorDark,
                  role: DiaryCardColorRole.text,
                  onChanged: (color) => commit(
                    title.copyWith(
                      colorLight: () => color.light,
                      colorDark: () => color.dark,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ],
    );
  }
}
