import 'package:flutter/material.dart';

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
import 'home_bar_style_outline_group.dart';

/// “材质”标签页：玻璃参数（顶栏、模糊、不透明度、色调、阴影）与描边。
///
/// 底栏只有悬浮玻璃一种形态，这里没有材质选择器；两个分组常驻。
class HomeBarStyleMaterialTab extends StatelessWidget {
  const HomeBarStyleMaterialTab({super.key, required this.controller});

  final HomeBarStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final highContrast = MediaQuery.highContrastOf(context);
    final footer = <String>[
      l10n.homeBarStyleGlassFooter,
      if (highContrast) l10n.homeBarStyleHighContrastNote,
    ].join('\n');

    return StyleEditorTabList(
      children: <Widget>[
        // 两个分组合成列表里的同一项：列表是懒构建的，拆成两项时描边分组要
        // 滚到才进树，展开自定义色调把它顶出屏幕时还会连同状态一起卸载。
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SettingsCardGroup(
              title: l10n.homeBarStyleTabMaterial,
              footer: footer,
              children: <Widget>[_GlassOptions(controller: controller)],
            ),
            const SizedBox(height: 16),
            HomeBarStyleOutlineGroup(controller: controller),
          ],
        ),
      ],
    );
  }
}

/// 玻璃参数（顶栏、模糊、不透明度、色调、阴影），合成分组里的同一项：
/// 自定义色调的颜色行会展开收起，作为单独的项增删时分组的分割线会多出
/// 一条。描边与分隔线在单独的“描边”分组里（[HomeBarStyleOutlineGroup]）。
class _GlassOptions extends StatelessWidget {
  const _GlassOptions({required this.controller});

  final HomeBarStyleEditorController controller;

  /// 第一次切到自定义色调时的起始颜色：当前中性底色（浅色主题下的值，
  /// 去掉透明度），用户从“看起来没变”的颜色开始调，而不是一块突兀的色。
  int _neutralLightBase(BuildContext context) => homeBarOpaqueArgb(
    homeBarLightScheme(context, controller).surfaceContainerLowest,
  );

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
        // 下面的阴影不会因它的出现而错位复用。
        SettingsReveal(
          visible: isCustom,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              settingsDeepNestedDivider,
              StyleCustomColorTile(
                nested: true,
                deep: true,
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
          title: l10n.homeBarStyleShadow,
          subtitle: l10n.homeBarStyleShadowSubtitle,
          value: style.shadow,
          onChanged: (bool v) => commit((s) => s.copyWith(shadow: v)),
        ),
      ],
    );
  }
}
