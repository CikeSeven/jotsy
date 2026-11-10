import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../home/models/home_bar_style/home_bar_style.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../controllers/home_bar_style_editor_controller.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import '../../widgets/style_editor/style_editor_common.dart';

/// “外观”标签页：导航栏全部的外观选项。
///
/// 栏的尺寸、圆角、图标与指示器是一组校对好的固定比例（见
/// `HomeBarMetrics`），这里只有不破坏比例的五项，分两组：
/// - 玻璃：色调、通透程度（模糊强度随它变化）、顶栏分隔线——顶栏恒为
///   玻璃，没有开关；
/// - 布局：文字怎么显示、新建按钮放哪。
class HomeBarStyleAppearanceTab extends StatelessWidget {
  const HomeBarStyleAppearanceTab({super.key, required this.controller});

  final HomeBarStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = controller.style;
    final highContrast = MediaQuery.highContrastOf(context);
    void commit(HomeBarStyle Function(HomeBarStyle s) update) =>
        controller.commitWith(update);

    return StyleEditorTabList(
      children: <Widget>[
        SettingsCardGroup(
          title: l10n.homeBarStyleGlassGroup,
          footer: highContrast ? l10n.homeBarStyleHighContrastNote : null,
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.homeBarStyleTint,
              child: ExpressiveButtonGroup<HomeBarTint>(
                minSegmentWidth: 96,
                segments: <ButtonSegment<HomeBarTint>>[
                  ButtonSegment<HomeBarTint>(
                    value: HomeBarTint.neutral,
                    label: Text(l10n.homeBarStyleTintNeutral),
                  ),
                  ButtonSegment<HomeBarTint>(
                    value: HomeBarTint.theme,
                    label: Text(l10n.homeBarStyleTintTheme),
                  ),
                ],
                selected: <HomeBarTint>{style.tint},
                onSelectionChanged: (Set<HomeBarTint> v) =>
                    commit((s) => s.copyWith(tint: v.single)),
              ),
            ),
            SettingsSliderTile(
              title: l10n.homeBarStyleOpacity,
              value: style.tintOpacity,
              min: HomeBarStyleLimits.tintOpacity.min,
              max: HomeBarStyleLimits.tintOpacity.max,
              divisions: HomeBarStyleLimits.tintOpacity.divisions,
              valueLabel: (double v) =>
                  l10n.diaryCardStyleValuePercent('${(v * 100).round()}'),
              // 拖动中只改草稿（预览即时重绘、不写盘），松手才写入；规整到
              // 百分位，消除 0.65000001 这类浮点尾数，样式才能与预设按 `==`
              // 相等。
              onChanged: (double v) => controller.previewWith(
                (s) => s.copyWith(tintOpacity: _percent(v)),
              ),
              onChangeEnd: (double v) =>
                  commit((s) => s.copyWith(tintOpacity: _percent(v))),
            ),
            SettingsSwitchTile(
              title: l10n.homeBarStyleTopBarHairline,
              subtitle: l10n.homeBarStyleTopBarHairlineSubtitle,
              value: style.topBarHairline,
              onChanged: (bool v) =>
                  commit((s) => s.copyWith(topBarHairline: v)),
            ),
          ],
        ),
        SettingsCardGroup(
          title: l10n.homeBarStyleLayoutGroup,
          footer: l10n.homeBarStyleFabFooter,
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.homeBarStyleLabels,
              child: ExpressiveButtonGroup<HomeBarLabelMode>(
                minSegmentWidth: 88,
                segments: <ButtonSegment<HomeBarLabelMode>>[
                  ButtonSegment<HomeBarLabelMode>(
                    value: HomeBarLabelMode.always,
                    label: Text(l10n.homeBarStyleLabelsAlways),
                  ),
                  ButtonSegment<HomeBarLabelMode>(
                    value: HomeBarLabelMode.selected,
                    label: Text(l10n.homeBarStyleLabelsSelected),
                  ),
                  ButtonSegment<HomeBarLabelMode>(
                    value: HomeBarLabelMode.never,
                    label: Text(l10n.homeBarStyleLabelsNever),
                  ),
                ],
                selected: <HomeBarLabelMode>{style.labelMode},
                onSelectionChanged: (Set<HomeBarLabelMode> v) =>
                    commit((s) => s.copyWith(labelMode: v.single)),
              ),
            ),
            SettingsChoiceTile(
              title: l10n.homeBarStyleFabGroup,
              child: ExpressiveButtonGroup<HomeBarFabPlacement>(
                minSegmentWidth: 96,
                segments: <ButtonSegment<HomeBarFabPlacement>>[
                  ButtonSegment<HomeBarFabPlacement>(
                    value: HomeBarFabPlacement.above,
                    label: Text(l10n.homeBarStyleFabAbove),
                  ),
                  ButtonSegment<HomeBarFabPlacement>(
                    value: HomeBarFabPlacement.inline,
                    label: Text(l10n.homeBarStyleFabInline),
                  ),
                ],
                selected: <HomeBarFabPlacement>{style.fabPlacement},
                onSelectionChanged: (Set<HomeBarFabPlacement> v) =>
                    commit((s) => s.copyWith(fabPlacement: v.single)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static double _percent(double value) => (value * 100).round() / 100;
}
