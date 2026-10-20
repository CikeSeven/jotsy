import 'package:flutter/material.dart';

import '../../../../app/theme/seeded_theme_cache.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../diaries/viewmodels/diary_card_colors.dart';
import '../../../home/models/home_bar_style/home_bar_style.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../controllers/home_bar_style_editor_controller.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import '../../widgets/settings_reveal.dart';
import '../../widgets/style_editor/style_color_dialog.dart';
import '../../widgets/style_editor/style_custom_color_tile.dart';
import '../../widgets/style_editor/style_editor_common.dart';
import 'home_bar_style_common.dart';
import 'home_bar_style_labels.dart';

/// “材质”标签页：实色 / 玻璃，以及只在玻璃下出现的玻璃参数。
///
/// 玻璃参数是材质的从属项，与材质选择器合成分组里的同一项：分组按位置
/// 复用子项并在子项之间插分割线，若把它们作为单独的项增删，分割线会多出
/// 一条，后面的行也会接手前一行的状态补播动画。从属行一律缩进一级。
class HomeBarStyleMaterialTab extends StatelessWidget {
  const HomeBarStyleMaterialTab({super.key, required this.controller});

  final HomeBarStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = controller.style;
    final isGlass = style.material == HomeBarMaterial.glass;
    final highContrast = MediaQuery.highContrastOf(context);
    final footer = isGlass
        ? <String>[
            l10n.homeBarStyleGlassFooter,
            if (highContrast) l10n.homeBarStyleHighContrastNote,
          ].join('\n')
        : null;

    return StyleEditorTabList(
      children: <Widget>[
        SettingsCardGroup(
          title: l10n.homeBarStyleTabMaterial,
          footer: footer,
          children: <Widget>[
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ExpressiveButtonGroup<HomeBarMaterial>(
                    minSegmentWidth: 96,
                    segments: <ButtonSegment<HomeBarMaterial>>[
                      for (final material in HomeBarMaterial.values)
                        ButtonSegment<HomeBarMaterial>(
                          value: material,
                          label: Text(homeBarMaterialLabel(l10n, material)),
                        ),
                    ],
                    selected: <HomeBarMaterial>{style.material},
                    // 经 withMaterial 换材质：图标与文字间距随之联动（玻璃栏
                    // 更矮，默认间距会让文字贴住色块下沿），只替换默认值。
                    onSelectionChanged: (Set<HomeBarMaterial> v) =>
                        controller.commitWith((s) => s.withMaterial(v.single)),
                  ),
                ),
                SettingsReveal(
                  visible: isGlass,
                  child: _GlassOptions(controller: controller),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// 玻璃参数（顶栏、模糊、不透明度、色调、描边、阴影），每行前一条缩进的
/// 分割线，与上方的材质选择器隔开。
class _GlassOptions extends StatelessWidget {
  const _GlassOptions({required this.controller});

  final HomeBarStyleEditorController controller;

  /// 第一次切到自定义色调时的起始颜色：当前中性底色（浅色主题下的值，
  /// 去掉透明度），用户从“看起来没变”的颜色开始调，而不是一块突兀的色。
  int _neutralLightBase(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.brightness == Brightness.light
        ? theme.colorScheme
        : SeededThemeCache.of(
            Color(controller.settingsService.themeSeedColorValue),
            Brightness.light,
            reduceMotion: MediaQuery.disableAnimationsOf(context),
          ).colorScheme;
    return 0xFF000000 | (scheme.surfaceContainerLowest.toARGB32() & 0xFFFFFF);
  }

  void _setTint(BuildContext context, HomeBarTint tint) {
    final style = controller.style;
    final seed = tint == HomeBarTint.custom && style.tintColor == null
        ? _neutralLightBase(context)
        : null;
    controller.commitWith(
      (s) =>
          s.copyWith(tint: tint, tintColor: seed == null ? null : () => seed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = controller.style;
    final isCustom = style.tint == HomeBarTint.custom;
    void commit(HomeBarStyle Function(HomeBarStyle s) update) =>
        controller.commitWith(update);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        settingsNestedDivider,
        SettingsSwitchTile(
          nested: true,
          title: l10n.homeBarStyleGlassTopBars,
          subtitle: l10n.homeBarStyleGlassTopBarsSubtitle,
          value: style.glassTopBars,
          onChanged: (bool v) => commit((s) => s.copyWith(glassTopBars: v)),
        ),
        settingsNestedDivider,
        homeBarSlider(
          nested: true,
          controller: controller,
          title: l10n.homeBarStyleBlur,
          range: HomeBarStyleLimits.blurSigma,
          value: style.blurSigma,
          valueLabel: (double v) => '${v.round()}',
          apply: (s, v) => s.copyWith(blurSigma: v),
        ),
        settingsNestedDivider,
        homeBarSlider(
          nested: true,
          controller: controller,
          title: l10n.homeBarStyleOpacity,
          range: HomeBarStyleLimits.tintOpacity,
          value: style.tintOpacity,
          valueLabel: (double v) =>
              l10n.diaryCardStyleValuePercent('${(v * 100).round()}'),
          snap: (double v) => (v * 100).round() / 100,
          apply: (s, v) => s.copyWith(tintOpacity: v),
        ),
        settingsNestedDivider,
        SettingsChoiceTile(
          nested: true,
          title: l10n.homeBarStyleTint,
          child: ExpressiveButtonGroup<HomeBarTint>(
            minSegmentWidth: 72,
            segments: <ButtonSegment<HomeBarTint>>[
              ButtonSegment<HomeBarTint>(
                value: HomeBarTint.neutral,
                label: Text(l10n.homeBarStyleTintNeutral),
              ),
              ButtonSegment<HomeBarTint>(
                value: HomeBarTint.theme,
                label: Text(l10n.homeBarStyleTintTheme),
              ),
              ButtonSegment<HomeBarTint>(
                value: HomeBarTint.custom,
                label: Text(l10n.styleEditorCustom),
              ),
            ],
            selected: <HomeBarTint>{style.tint},
            onSelectionChanged: (Set<HomeBarTint> v) =>
                _setTint(context, v.single),
          ),
        ),
        // 自定义颜色紧跟在色调下方，与色调合在同一个位置固定的槽里，
        // 下面的描边、阴影不会因它的出现而错位复用。
        SettingsReveal(
          visible: isCustom,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              settingsNestedDivider,
              StyleCustomColorTile(
                nested: true,
                title: l10n.homeBarStyleTintColor,
                light: style.tintColor ?? _neutralLightBase(context),
                dark: style.tintColorDark,
                role: DiaryCardColorRole.surface,
                onChanged: (StyleCustomColor color) => commit(
                  (s) => s.copyWith(
                    tintColor: () => color.light,
                    tintColorDark: () => color.dark,
                  ),
                ),
              ),
            ],
          ),
        ),
        settingsNestedDivider,
        SettingsSwitchTile(
          nested: true,
          title: l10n.homeBarStyleBorder,
          subtitle: l10n.homeBarStyleBorderSubtitle,
          value: style.border,
          onChanged: (bool v) => commit((s) => s.copyWith(border: v)),
        ),
        settingsNestedDivider,
        SettingsSwitchTile(
          nested: true,
          title: l10n.homeBarStyleShadow,
          subtitle: l10n.homeBarStyleShadowSubtitle,
          value: style.shadow,
          onChanged: (bool v) => commit((s) => s.copyWith(shadow: v)),
        ),
      ],
    );
  }
}
