import 'package:flutter/material.dart';

import '../../../app/theme/app_color_scheme.dart';
import '../../../core/services/home_widgets/home_widget_style.dart';
import '../../../l10n/app_localizations.dart';
import '../../diaries/viewmodels/diary_card_colors.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../settings/widgets/settings_option_tiles.dart';
import '../../settings/widgets/style_editor/style_color_dialog.dart';
import '../../settings/widgets/style_editor/style_custom_color_tile.dart';
import '../../widgets/color_swatch_button.dart';
import '../../widgets/expressive_button_group.dart';
import '../controllers/home_widget_studio_controller.dart';
import '../viewmodels/home_widget_palette.dart';

/// 工作室「样式」标签页：配色、明暗、底色与不透明度、圆角、文字大小、间距
/// 与强调色。所有小组件种类共用。
///
/// 滑杆拖动期间只改预览（`commit: false`），松手才写回设置；按钮类选项点了
/// 就写（控制器自己防抖）。
class HomeWidgetStyleTab extends StatelessWidget {
  const HomeWidgetStyleTab({super.key, required this.controller});

  final HomeWidgetStudioController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = controller.style;
    void update(HomeWidgetStyle next, {bool commit = true}) =>
        controller.updateStyle(next, commit: commit);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: <Widget>[
        SettingsCardGroup(
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.homeWidgetStylePalette,
              subtitle: style.palette == HomeWidgetPalette.wallpaper
                  ? l10n.homeWidgetPaletteWallpaperHint
                  : null,
              child: ExpressiveButtonGroup<HomeWidgetPalette>(
                minSegmentWidth: 96,
                segments: <ButtonSegment<HomeWidgetPalette>>[
                  ButtonSegment(
                    value: HomeWidgetPalette.app,
                    label: Text(l10n.homeWidgetPaletteApp),
                  ),
                  ButtonSegment(
                    value: HomeWidgetPalette.wallpaper,
                    label: Text(l10n.homeWidgetPaletteWallpaper),
                  ),
                  ButtonSegment(
                    value: HomeWidgetPalette.seed,
                    label: Text(l10n.homeWidgetPaletteCustom),
                  ),
                ],
                selected: <HomeWidgetPalette>{style.palette},
                onSelectionChanged: (Set<HomeWidgetPalette> value) => update(
                  style.copyWith(
                    palette: value.first,
                    // 第一次选自选颜色时先给精选色板的第一项，预览立刻有变化。
                    seed: value.first == HomeWidgetPalette.seed
                        ? style.seed ?? kHomeWidgetPresetSeeds[1]
                        : null,
                  ),
                ),
              ),
            ),
            if (style.palette == HomeWidgetPalette.seed) ...<Widget>[
              _SeedSwatches(
                selected: style.seed,
                onSelected: (int seed) => update(style.copyWith(seed: seed)),
              ),
              StyleCustomColorTile(
                title: l10n.homeWidgetPaletteCustom,
                light: style.seed ?? kHomeWidgetPresetSeeds.first,
                dark: null,
                role: DiaryCardColorRole.accent,
                showDarkVariant: false,
                onChanged: (StyleCustomColor color) =>
                    update(style.copyWith(seed: color.light)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        SettingsCardGroup(
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.homeWidgetStyleBrightness,
              child: ExpressiveButtonGroup<HomeWidgetBrightness>(
                minSegmentWidth: 88,
                segments: <ButtonSegment<HomeWidgetBrightness>>[
                  ButtonSegment(
                    value: HomeWidgetBrightness.system,
                    label: Text(l10n.homeWidgetBrightnessSystem),
                  ),
                  ButtonSegment(
                    value: HomeWidgetBrightness.light,
                    label: Text(l10n.homeWidgetBrightnessLight),
                  ),
                  ButtonSegment(
                    value: HomeWidgetBrightness.dark,
                    label: Text(l10n.homeWidgetBrightnessDark),
                  ),
                ],
                selected: <HomeWidgetBrightness>{style.brightness},
                onSelectionChanged: (Set<HomeWidgetBrightness> value) =>
                    update(style.copyWith(brightness: value.first)),
              ),
            ),
            SettingsChoiceTile(
              title: l10n.homeWidgetStyleBackground,
              child: ExpressiveButtonGroup<HomeWidgetBackground>(
                minSegmentWidth: 72,
                segments: <ButtonSegment<HomeWidgetBackground>>[
                  ButtonSegment(
                    value: HomeWidgetBackground.surface,
                    label: Text(l10n.homeWidgetBackgroundSurface),
                  ),
                  ButtonSegment(
                    value: HomeWidgetBackground.tonal,
                    label: Text(l10n.homeWidgetBackgroundTonal),
                  ),
                  ButtonSegment(
                    value: HomeWidgetBackground.vivid,
                    label: Text(l10n.homeWidgetBackgroundVivid),
                  ),
                  ButtonSegment(
                    value: HomeWidgetBackground.clear,
                    label: Text(l10n.homeWidgetBackgroundClear),
                  ),
                ],
                selected: <HomeWidgetBackground>{style.background},
                onSelectionChanged: (Set<HomeWidgetBackground> value) =>
                    update(style.copyWith(background: value.first)),
              ),
            ),
            if (style.background != HomeWidgetBackground.clear)
              SettingsSliderTile(
                title: l10n.homeWidgetStyleOpacity,
                value: style.opacity,
                min: HomeWidgetStyle.minOpacity,
                max: 1,
                divisions: 16,
                valueLabel: (double value) => '${(value * 100).round()}%',
                onChanged: (double value) =>
                    update(style.copyWith(opacity: value), commit: false),
                onChangeEnd: (_) => controller.commit(),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsCardGroup(
          children: <Widget>[
            SettingsSwitchTile(
              title: l10n.homeWidgetCornersSystem,
              value: style.cornerRadius == null,
              onChanged: (bool value) =>
                  update(style.copyWith(cornerRadius: () => value ? null : 20)),
            ),
            if (style.cornerRadius != null)
              SettingsSliderTile(
                title: l10n.homeWidgetStyleCorners,
                nested: true,
                value: style.cornerRadius!,
                min: 0,
                max: HomeWidgetStyle.maxCornerRadius,
                divisions: 16,
                valueLabel: (double value) => '${value.round()} dp',
                onChanged: (double value) => update(
                  style.copyWith(cornerRadius: () => value),
                  commit: false,
                ),
                onChangeEnd: (_) => controller.commit(),
              ),
            SettingsSliderTile(
              title: l10n.homeWidgetStyleTextSize,
              value: style.textScale,
              min: HomeWidgetStyle.minTextScale,
              max: HomeWidgetStyle.maxTextScale,
              divisions: 8,
              valueLabel: (double value) => '${(value * 100).round()}%',
              onChanged: (double value) =>
                  update(style.copyWith(textScale: value), commit: false),
              onChangeEnd: (_) => controller.commit(),
            ),
            SettingsChoiceTile(
              title: l10n.homeWidgetStyleDensity,
              child: ExpressiveButtonGroup<HomeWidgetDensity>(
                minSegmentWidth: 80,
                segments: <ButtonSegment<HomeWidgetDensity>>[
                  ButtonSegment(
                    value: HomeWidgetDensity.compact,
                    label: Text(l10n.homeWidgetDensityCompact),
                  ),
                  ButtonSegment(
                    value: HomeWidgetDensity.standard,
                    label: Text(l10n.homeWidgetDensityStandard),
                  ),
                  ButtonSegment(
                    value: HomeWidgetDensity.roomy,
                    label: Text(l10n.homeWidgetDensityRoomy),
                  ),
                ],
                selected: <HomeWidgetDensity>{style.density},
                onSelectionChanged: (Set<HomeWidgetDensity> value) =>
                    update(style.copyWith(density: value.first)),
              ),
            ),
            SettingsChoiceTile(
              title: l10n.homeWidgetStyleAccent,
              child: ExpressiveButtonGroup<HomeWidgetAccent>(
                minSegmentWidth: 88,
                segments: <ButtonSegment<HomeWidgetAccent>>[
                  ButtonSegment(
                    value: HomeWidgetAccent.primary,
                    label: Text(l10n.homeWidgetAccentPrimary),
                  ),
                  ButtonSegment(
                    value: HomeWidgetAccent.secondary,
                    label: Text(l10n.homeWidgetAccentSecondary),
                  ),
                  ButtonSegment(
                    value: HomeWidgetAccent.tertiary,
                    label: Text(l10n.homeWidgetAccentTertiary),
                  ),
                ],
                selected: <HomeWidgetAccent>{style.accent},
                onSelectionChanged: (Set<HomeWidgetAccent> value) =>
                    update(style.copyWith(accent: value.first)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 自选颜色的精选色板：一排色块，色块画的是该种子在当前明暗下的主色——
/// 用户看到的就是小组件上的强调色。HEX / 调色板在下一行的
/// [StyleCustomColorTile]。
class _SeedSwatches extends StatelessWidget {
  const _SeedSwatches({required this.selected, required this.onSelected});

  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: <Widget>[
          for (final seed in kHomeWidgetPresetSeeds)
            ColorSwatchButton(
              color: appColorSchemeFromSeed(Color(seed), brightness).primary,
              selected: seed == selected,
              semanticLabel: _hex(seed),
              onTap: () => onSelected(seed),
            ),
        ],
      ),
    );
  }
}

String _hex(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
