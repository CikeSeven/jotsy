// 小组件外观的样式库：内置的几套精选外观、“我的样式”与样式码。
//
// 外观（`HomeWidgetStyle`）与种类无关，所以预设与“我的样式”在所有种类之间共用；
// 内容选项按种类不同，不进样式库。“我的样式”存在小组件设置的 `saved` 字段里
// （与小组件设置同一个本机键，不随备份导出），这里复用样式库的 `SavedStyles` 做
// 增删改与编解码，样式码复用 `StyleCodeFormat`（前缀 `jotsy-widget:v1:`，贴到别的
// 样式编辑页里会被当作无效码）。

import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/services/home_widgets/home_widget_settings.dart';
import '../../../core/services/home_widgets/home_widget_style.dart';
import '../../../l10n/app_localizations.dart';
import '../../diaries/models/style_library/saved_style.dart';
import '../../diaries/models/style_library/style_code.dart';

/// 小组件外观的样式码。
final StyleCodeFormat<HomeWidgetStyle> homeWidgetStyleCode =
    StyleCodeFormat<HomeWidgetStyle>(
      scheme: 'jotsy-widget',
      version: 1,
      fromJson: HomeWidgetStyle.fromJson,
      toJson: (HomeWidgetStyle style) => style.toJson(),
    );

/// 设置里的“我的样式”。
List<SavedStyle<HomeWidgetStyle>> homeWidgetSavedStyles(
  HomeWidgetSettings settings,
) => SavedStyles.decode(settings.savedStyles, HomeWidgetStyle.fromJson);

/// 换上新的“我的样式”列表。
HomeWidgetSettings homeWidgetSettingsWithSaved(
  HomeWidgetSettings settings,
  List<SavedStyle<HomeWidgetStyle>> saved,
) => settings.withSavedStyles(
  SavedStyles.encode(saved, (HomeWidgetStyle style) => style.toJson()),
);

/// 内置的几套外观。枚举名不持久化（套用后存的是外观本身），可以随版本调整。
enum HomeWidgetStylePreset {
  /// 经典：跟随主题色的实色卡片，与应用的日记卡片同一层级（即默认外观）。
  classic(HomeWidgetStyle.defaults, FontAwesomeIcons.solidSquare),

  /// 随壁纸：系统动态取色的色调底。
  wallpaper(
    HomeWidgetStyle(
      palette: HomeWidgetPalette.wallpaper,
      background: HomeWidgetBackground.tonal,
    ),
    FontAwesomeIcons.palette,
  ),

  /// 浓郁：主题色铺底、内容反白。
  vivid(
    HomeWidgetStyle(background: HomeWidgetBackground.vivid),
    FontAwesomeIcons.fillDrip,
  ),

  /// 通透：半透明底、更大的圆角与宽松的间距，透出壁纸。
  glass(
    HomeWidgetStyle(
      opacity: 0.62,
      cornerRadius: 28,
      density: HomeWidgetDensity.roomy,
    ),
    FontAwesomeIcons.droplet,
  ),

  /// 极简：没有底色，只有内容。
  clear(
    HomeWidgetStyle(background: HomeWidgetBackground.clear),
    FontAwesomeIcons.circleHalfStroke,
  ),

  /// 暖阳：暖橙色调的色调底。
  sunrise(
    HomeWidgetStyle(
      palette: HomeWidgetPalette.seed,
      seed: 0xFFE8913A,
      background: HomeWidgetBackground.tonal,
    ),
    FontAwesomeIcons.solidSun,
  ),

  /// 森林：沉静的绿色铺底。
  forest(
    HomeWidgetStyle(
      palette: HomeWidgetPalette.seed,
      seed: 0xFF4F7A5A,
      background: HomeWidgetBackground.vivid,
    ),
    FontAwesomeIcons.tree,
  ),

  /// 夜读：固定深色、靛蓝强调，夜里不刺眼。
  night(
    HomeWidgetStyle(
      palette: HomeWidgetPalette.seed,
      seed: 0xFF5C6BC0,
      brightness: HomeWidgetBrightness.dark,
    ),
    FontAwesomeIcons.solidMoon,
  );

  const HomeWidgetStylePreset(this.style, this.icon);

  final HomeWidgetStyle style;
  final FaIconData icon;

  /// 与 [style] 完全相同的预设；不是任何预设时为 null。
  static HomeWidgetStylePreset? matching(HomeWidgetStyle style) {
    for (final preset in values) {
      if (preset.style == style) return preset;
    }
    return null;
  }

  String name(AppLocalizations l10n) => switch (this) {
    classic => l10n.homeWidgetPresetClassic,
    wallpaper => l10n.homeWidgetPresetWallpaper,
    vivid => l10n.homeWidgetPresetVivid,
    glass => l10n.homeWidgetPresetGlass,
    clear => l10n.homeWidgetPresetClear,
    sunrise => l10n.homeWidgetPresetSunrise,
    forest => l10n.homeWidgetPresetForest,
    night => l10n.homeWidgetPresetNight,
  };

  String description(AppLocalizations l10n) => switch (this) {
    classic => l10n.homeWidgetPresetClassicDescription,
    wallpaper => l10n.homeWidgetPresetWallpaperDescription,
    vivid => l10n.homeWidgetPresetVividDescription,
    glass => l10n.homeWidgetPresetGlassDescription,
    clear => l10n.homeWidgetPresetClearDescription,
    sunrise => l10n.homeWidgetPresetSunriseDescription,
    forest => l10n.homeWidgetPresetForestDescription,
    night => l10n.homeWidgetPresetNightDescription,
  };
}
