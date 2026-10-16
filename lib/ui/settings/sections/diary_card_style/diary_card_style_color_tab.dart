import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/diary_card_style/diary_card_style.dart';
import '../../../diaries/viewmodels/diary_card_colors.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../controllers/diary_card_style_editor_controller.dart';
import '../../widgets/diary_card_color_tile.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import 'diary_card_style_common.dart';
import 'diary_card_style_labels.dart';

/// “色彩”标签页：卡片底色（来源与浓度）、两色渐变与卡片不透明度。两种
/// 布局共用；文字颜色在“字体”页，描边、色条与阴影在“质感”页。
class DiaryCardStyleColorTab extends StatelessWidget {
  const DiaryCardStyleColorTab({super.key, required this.controller});

  final DiaryCardStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = controller.style;
    final surface = style.surface;

    DiaryCardStyle withSurface(DiaryCardSurfaceStyle next) =>
        style.copyWith(surface: next);

    return DiaryCardStyleTabList(
      children: <Widget>[
        SettingsCardGroup(
          title: l10n.diaryCardStyleSharedGroup,
          children: <Widget>[
            DiaryCardColorTile(
              title: l10n.diaryCardStyleBackground,
              spec: surface.background,
              role: DiaryCardColorRole.surface,
              onPreview: (spec) => controller.preview(
                withSurface(surface.copyWith(background: spec)),
              ),
              onCommit: (spec) => controller.commit(
                withSurface(surface.copyWith(background: spec)),
              ),
            ),
            SettingsSliderTile(
              title: l10n.diaryCardStyleOpacity,
              value: surface.opacity,
              min: DiaryCardStyleLimits.opacity.min,
              max: DiaryCardStyleLimits.opacity.max,
              divisions: DiaryCardStyleLimits.opacity.divisions,
              valueLabel: (double v) => diaryCardPercentLabel(l10n, v),
              onChanged: (double v) =>
                  controller.preview(withSurface(surface.copyWith(opacity: v))),
              onChangeEnd: (double v) =>
                  controller.commit(withSurface(surface.copyWith(opacity: v))),
            ),
          ],
        ),
        SettingsCardGroup(
          children: <Widget>[
            SettingsSwitchTile(
              title: l10n.diaryCardStyleGradient,
              subtitle: l10n.diaryCardStyleGradientSubtitle,
              value: surface.gradient,
              onChanged: (bool v) =>
                  controller.commit(withSurface(surface.copyWith(gradient: v))),
            ),
            if (surface.gradient) ...<Widget>[
              DiaryCardColorTile(
                title: l10n.diaryCardStyleGradientEnd,
                spec: surface.gradientEnd,
                role: DiaryCardColorRole.surface,
                onPreview: (spec) => controller.preview(
                  withSurface(surface.copyWith(gradientEnd: spec)),
                ),
                onCommit: (spec) => controller.commit(
                  withSurface(surface.copyWith(gradientEnd: spec)),
                ),
              ),
              SettingsChoiceTile(
                title: l10n.diaryCardStyleGradientDirection,
                child: ExpressiveButtonGroup<DiaryCardGradientDirection>(
                  minSegmentWidth: 80,
                  segments: <ButtonSegment<DiaryCardGradientDirection>>[
                    ButtonSegment<DiaryCardGradientDirection>(
                      value: DiaryCardGradientDirection.vertical,
                      label: Text(l10n.diaryCardStyleDirectionVertical),
                    ),
                    ButtonSegment<DiaryCardGradientDirection>(
                      value: DiaryCardGradientDirection.horizontal,
                      label: Text(l10n.diaryCardStyleDirectionHorizontal),
                    ),
                    ButtonSegment<DiaryCardGradientDirection>(
                      value: DiaryCardGradientDirection.diagonal,
                      label: Text(l10n.diaryCardStyleDirectionDiagonal),
                    ),
                  ],
                  selected: <DiaryCardGradientDirection>{
                    surface.gradientDirection,
                  },
                  onSelectionChanged: (Set<DiaryCardGradientDirection> v) =>
                      controller.commit(
                        withSurface(
                          surface.copyWith(gradientDirection: v.single),
                        ),
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
