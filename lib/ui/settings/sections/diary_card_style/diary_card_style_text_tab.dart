import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/diary_card_style/diary_card_style.dart';
import '../../../diaries/viewmodels/diary_card_colors.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../controllers/diary_card_style_editor_controller.dart';
import '../../widgets/diary_card_color_tile.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import 'diary_card_style_labels.dart';
import '../../widgets/style_editor/style_editor_common.dart';

/// “字体”标签页：标题/摘要/辅助文字的字号缩放、标题字重、摘要行距，以及
/// 标题与正文颜色和“自动保证可读”。两种布局共用。
class DiaryCardStyleTextTab extends StatelessWidget {
  const DiaryCardStyleTextTab({super.key, required this.controller});

  final DiaryCardStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = controller.style;
    final typography = style.typography;
    String percent(double value) => diaryCardPercentLabel(l10n, value);

    DiaryCardStyle withTypography(DiaryCardTypography next) =>
        style.copyWith(typography: next);

    Widget scale({
      required String title,
      required double value,
      required DiaryCardRange range,
      required DiaryCardTypography Function(double) apply,
    }) {
      return SettingsSliderTile(
        title: title,
        value: value,
        min: range.min,
        max: range.max,
        divisions: range.divisions,
        valueLabel: percent,
        onChanged: (double v) => controller.preview(withTypography(apply(v))),
        onChangeEnd: (double v) => controller.commit(withTypography(apply(v))),
      );
    }

    return StyleEditorTabList(
      children: <Widget>[
        SettingsCardGroup(
          title: l10n.diaryCardStyleSharedGroup,
          children: <Widget>[
            scale(
              title: l10n.diaryCardStyleTitleSize,
              value: typography.titleScale,
              range: DiaryCardStyleLimits.titleScale,
              apply: (v) => typography.copyWith(titleScale: v),
            ),
            SettingsChoiceTile(
              title: l10n.diaryCardStyleTitleWeight,
              child: ExpressiveButtonGroup<DiaryCardTitleWeight>(
                minSegmentWidth: 80,
                segments: <ButtonSegment<DiaryCardTitleWeight>>[
                  ButtonSegment<DiaryCardTitleWeight>(
                    value: DiaryCardTitleWeight.regular,
                    label: Text(l10n.diaryCardStyleWeightRegular),
                  ),
                  ButtonSegment<DiaryCardTitleWeight>(
                    value: DiaryCardTitleWeight.medium,
                    label: Text(l10n.diaryCardStyleWeightMedium),
                  ),
                  ButtonSegment<DiaryCardTitleWeight>(
                    value: DiaryCardTitleWeight.bold,
                    label: Text(l10n.diaryCardStyleWeightBold),
                  ),
                ],
                selected: <DiaryCardTitleWeight>{typography.titleWeight},
                onSelectionChanged: (Set<DiaryCardTitleWeight> v) =>
                    controller.commit(
                      withTypography(
                        typography.copyWith(titleWeight: v.single),
                      ),
                    ),
              ),
            ),
            scale(
              title: l10n.diaryCardStylePreviewSize,
              value: typography.previewScale,
              range: DiaryCardStyleLimits.previewScale,
              apply: (v) => typography.copyWith(previewScale: v),
            ),
            SettingsChoiceTile(
              title: l10n.diaryCardStyleLineHeight,
              child: ExpressiveButtonGroup<DiaryCardLineHeight>(
                minSegmentWidth: 80,
                segments: <ButtonSegment<DiaryCardLineHeight>>[
                  ButtonSegment<DiaryCardLineHeight>(
                    value: DiaryCardLineHeight.compact,
                    label: Text(l10n.diaryCardStyleLineCompact),
                  ),
                  ButtonSegment<DiaryCardLineHeight>(
                    value: DiaryCardLineHeight.standard,
                    label: Text(l10n.diaryCardStyleLineStandard),
                  ),
                  ButtonSegment<DiaryCardLineHeight>(
                    value: DiaryCardLineHeight.relaxed,
                    label: Text(l10n.diaryCardStyleLineRelaxed),
                  ),
                ],
                selected: <DiaryCardLineHeight>{typography.lineHeight},
                onSelectionChanged: (Set<DiaryCardLineHeight> v) =>
                    controller.commit(
                      withTypography(typography.copyWith(lineHeight: v.single)),
                    ),
              ),
            ),
            scale(
              title: l10n.diaryCardStyleMetaSize,
              value: typography.metaScale,
              range: DiaryCardStyleLimits.metaScale,
              apply: (v) => typography.copyWith(metaScale: v),
            ),
          ],
        ),
        SettingsCardGroup(
          children: <Widget>[
            DiaryCardColorTile(
              title: l10n.diaryCardStyleTitleColor,
              spec: typography.titleColor,
              role: DiaryCardColorRole.text,
              // 文字颜色不使用浓度。
              showStrength: false,
              onPreview: (spec) => controller.preview(
                withTypography(typography.copyWith(titleColor: spec)),
              ),
              onCommit: (spec) => controller.commit(
                withTypography(typography.copyWith(titleColor: spec)),
              ),
            ),
            DiaryCardColorTile(
              title: l10n.diaryCardStyleBodyColor,
              spec: typography.bodyColor,
              role: DiaryCardColorRole.text,
              // 文字颜色不使用浓度。
              showStrength: false,
              onPreview: (spec) => controller.preview(
                withTypography(typography.copyWith(bodyColor: spec)),
              ),
              onCommit: (spec) => controller.commit(
                withTypography(typography.copyWith(bodyColor: spec)),
              ),
            ),
            SettingsSwitchTile(
              title: l10n.diaryCardStyleEnsureContrast,
              subtitle: l10n.diaryCardStyleEnsureContrastSubtitle,
              value: typography.ensureContrast,
              onChanged: (bool v) => controller.commit(
                withTypography(typography.copyWith(ensureContrast: v)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
