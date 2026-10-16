import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/diary_card_style/diary_card_style.dart';
import '../../../diaries/viewmodels/diary_card_colors.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../../widgets/expressive_icon_choice_row.dart';
import '../../controllers/diary_card_style_editor_controller.dart';
import '../../widgets/diary_card_color_tile.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import 'diary_card_style_common.dart';
import 'diary_card_style_labels.dart';

/// “质感”标签页：描边、强调色条与阴影。两种布局共用；只在对应样式开启时
/// 列出它的细项（色条宽度与颜色、自定义阴影高度与颜色）。
class DiaryCardStyleTextureTab extends StatelessWidget {
  const DiaryCardStyleTextureTab({super.key, required this.controller});

  final DiaryCardStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = controller.style;
    final surface = style.surface;
    String dp(double value) => diaryCardDpLabel(l10n, value);

    DiaryCardStyle withSurface(DiaryCardSurfaceStyle next) =>
        style.copyWith(surface: next);

    Widget slider({
      required String title,
      required double value,
      required DiaryCardRange range,
      required DiaryCardSurfaceStyle Function(double) apply,
    }) {
      return SettingsSliderTile(
        title: title,
        value: value,
        min: range.min,
        max: range.max,
        divisions: range.divisions,
        valueLabel: dp,
        onChanged: (double v) => controller.preview(withSurface(apply(v))),
        onChangeEnd: (double v) => controller.commit(withSurface(apply(v))),
      );
    }

    final shadowColored =
        surface.shadow != DiaryCardShadowStyle.themed &&
        surface.shadow != DiaryCardShadowStyle.none;
    return DiaryCardStyleTabList(
      children: <Widget>[
        SettingsCardGroup(
          title: l10n.diaryCardStyleSharedGroup,
          children: <Widget>[
            slider(
              title: l10n.diaryCardStyleBorderWidth,
              value: surface.borderWidth,
              range: DiaryCardStyleLimits.borderWidth,
              apply: (v) => surface.copyWith(borderWidth: v),
            ),
            if (surface.borderWidth > 0)
              DiaryCardColorTile(
                title: l10n.diaryCardStyleBorderColor,
                spec: surface.borderColor,
                role: DiaryCardColorRole.accent,
                onPreview: (spec) => controller.preview(
                  withSurface(surface.copyWith(borderColor: spec)),
                ),
                onCommit: (spec) => controller.commit(
                  withSurface(surface.copyWith(borderColor: spec)),
                ),
              ),
          ],
        ),
        SettingsCardGroup(
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.diaryCardStyleAccentBar,
              child: ExpressiveButtonGroup<DiaryCardAccentBar>(
                minSegmentWidth: 80,
                segments: <ButtonSegment<DiaryCardAccentBar>>[
                  ButtonSegment<DiaryCardAccentBar>(
                    value: DiaryCardAccentBar.none,
                    label: Text(l10n.diaryCardStyleAccentNone),
                  ),
                  ButtonSegment<DiaryCardAccentBar>(
                    value: DiaryCardAccentBar.start,
                    label: Text(l10n.diaryCardStyleAccentStart),
                  ),
                  ButtonSegment<DiaryCardAccentBar>(
                    value: DiaryCardAccentBar.top,
                    label: Text(l10n.diaryCardStyleAccentTop),
                  ),
                ],
                selected: <DiaryCardAccentBar>{surface.accentBar},
                onSelectionChanged: (Set<DiaryCardAccentBar> v) => controller
                    .commit(withSurface(surface.copyWith(accentBar: v.single))),
              ),
            ),
            if (surface.accentBar != DiaryCardAccentBar.none) ...<Widget>[
              slider(
                title: l10n.diaryCardStyleAccentWidth,
                value: surface.accentWidth,
                range: DiaryCardStyleLimits.accentWidth,
                apply: (v) => surface.copyWith(accentWidth: v),
              ),
              DiaryCardColorTile(
                title: l10n.diaryCardStyleAccentColor,
                spec: surface.accentColor,
                role: DiaryCardColorRole.accent,
                strengthAppliesToTheme: true,
                onPreview: (spec) => controller.preview(
                  withSurface(surface.copyWith(accentColor: spec)),
                ),
                onCommit: (spec) => controller.commit(
                  withSurface(surface.copyWith(accentColor: spec)),
                ),
              ),
            ],
          ],
        ),
        SettingsCardGroup(
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.diaryCardStyleShadow,
              child: ExpressiveIconChoiceRow<DiaryCardShadowStyle>(
                choices: diaryCardShadowChoices(l10n),
                selected: surface.shadow,
                onSelected: (DiaryCardShadowStyle v) =>
                    controller.commit(withSurface(surface.copyWith(shadow: v))),
              ),
            ),
            if (surface.shadow == DiaryCardShadowStyle.custom)
              slider(
                title: l10n.diaryCardStyleShadowElevation,
                value: surface.shadowElevation,
                range: DiaryCardStyleLimits.shadowElevation,
                apply: (v) => surface.copyWith(shadowElevation: v),
              ),
            if (shadowColored)
              DiaryCardColorTile(
                title: l10n.diaryCardStyleShadowColor,
                spec: surface.shadowColor,
                role: DiaryCardColorRole.accent,
                strengthAppliesToTheme: true,
                onPreview: (spec) => controller.preview(
                  withSurface(surface.copyWith(shadowColor: spec)),
                ),
                onCommit: (spec) => controller.commit(
                  withSurface(surface.copyWith(shadowColor: spec)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
