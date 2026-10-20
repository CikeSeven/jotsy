import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../home/models/home_bar_style/home_bar_presets.dart';
import '../../../home/models/home_bar_style/home_bar_settings.dart';
import '../../../home/models/home_bar_style/home_bar_style.dart';
import '../../widgets/style_editor/style_preset_grid.dart';

// 导航栏样式设置的文案与图标映射：枚举 → 本地化标签 / 图标。只做映射，
// 不含状态。

String homeBarPresetName(AppLocalizations l10n, HomeBarPreset preset) =>
    switch (preset) {
      HomeBarPreset.classic => l10n.homeBarStylePresetClassic,
      HomeBarPreset.glass => l10n.homeBarStylePresetGlass,
      HomeBarPreset.clear => l10n.homeBarStylePresetClear,
      HomeBarPreset.frosted => l10n.homeBarStylePresetFrosted,
      HomeBarPreset.tinted => l10n.homeBarStylePresetTinted,
      HomeBarPreset.compact => l10n.homeBarStylePresetCompact,
    };

/// 描边颜色来源的标签；自定义沿用样式编辑页通用的“自定义”。
String homeBarLineColorLabel(AppLocalizations l10n, HomeBarLineColor color) =>
    switch (color) {
      HomeBarLineColor.theme => l10n.homeBarStyleLineColorTheme,
      HomeBarLineColor.highlight => l10n.homeBarStyleLineColorHighlight,
      HomeBarLineColor.primary => l10n.homeBarStyleLineColorPrimary,
      HomeBarLineColor.custom => l10n.styleEditorCustom,
    };

String _presetDescription(AppLocalizations l10n, HomeBarPreset preset) =>
    switch (preset) {
      HomeBarPreset.classic => l10n.homeBarStylePresetClassicDesc,
      HomeBarPreset.glass => l10n.homeBarStylePresetGlassDesc,
      HomeBarPreset.clear => l10n.homeBarStylePresetClearDesc,
      HomeBarPreset.frosted => l10n.homeBarStylePresetFrostedDesc,
      HomeBarPreset.tinted => l10n.homeBarStylePresetTintedDesc,
      HomeBarPreset.compact => l10n.homeBarStylePresetCompactDesc,
    };

FaIconData _presetIcon(HomeBarPreset preset) => switch (preset) {
  HomeBarPreset.classic => FontAwesomeIcons.tableColumns,
  HomeBarPreset.glass => FontAwesomeIcons.droplet,
  HomeBarPreset.clear => FontAwesomeIcons.eye,
  HomeBarPreset.frosted => FontAwesomeIcons.snowflake,
  HomeBarPreset.tinted => FontAwesomeIcons.palette,
  HomeBarPreset.compact => FontAwesomeIcons.compress,
};

List<StylePresetOption<HomeBarPreset>> homeBarPresetOptions(
  AppLocalizations l10n,
) => <StylePresetOption<HomeBarPreset>>[
  for (final preset in HomeBarPreset.values)
    StylePresetOption<HomeBarPreset>(
      id: preset,
      icon: _presetIcon(preset),
      name: homeBarPresetName(l10n, preset),
      description: _presetDescription(l10n, preset),
    ),
];

String homeBarMaterialLabel(AppLocalizations l10n, HomeBarMaterial material) =>
    switch (material) {
      HomeBarMaterial.solid => l10n.homeBarStyleMaterialSolid,
      HomeBarMaterial.glass => l10n.homeBarStyleMaterialGlass,
    };

/// 当前外观的显示名：内置预设名、我的样式名，或“材质（自定义）”。
///
/// 与预览页样式不同，这里不只写“自定义”：导航栏最关键的区别是实色还是
/// 玻璃，入口副标题直接说出材质，用户不必点进去也知道现在是哪种。
String homeBarStyleDisplayName(
  AppLocalizations l10n,
  HomeBarSettings settings,
) {
  final preset = HomeBarPreset.matching(settings.current);
  if (preset != null) {
    return homeBarPresetName(l10n, preset);
  }
  for (final item in settings.saved) {
    if (item.style == settings.current) {
      return item.name;
    }
  }
  return l10n.homeBarStyleCustomName(
    homeBarMaterialLabel(l10n, settings.current.material),
  );
}
