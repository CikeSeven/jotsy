// 桌面小组件的配色导出：把种子色经应用同一个配色算法
// （`appColorSchemeFromSeed`，含灰色与纯黑的特殊处理）展开成明暗两套色槽，
// 写进快照的 `palettes`。原生侧只认这里列出的色槽名
// （`WidgetPalette.kt` 的 `ROLES`），两端须同步。
//
// “跟随壁纸”的配色由原生直接取系统动态色资源（壁纸一换就跟着变，应用不必
// 运行），这里不导出；Android 12 以下没有动态色，原生退回 `app`。

import 'package:flutter/material.dart';

import '../../../app/theme/app_color_scheme.dart';
import '../../../core/services/home_widgets/home_widget_style.dart';

/// 导出的色槽（名字与 Material 3 `ColorScheme` 的字段一致）。
const List<String> kHomeWidgetPaletteRoles = <String>[
  'primary',
  'onPrimary',
  'primaryContainer',
  'onPrimaryContainer',
  'secondary',
  'onSecondary',
  'secondaryContainer',
  'onSecondaryContainer',
  'tertiary',
  'onTertiary',
  'tertiaryContainer',
  'onTertiaryContainer',
  'error',
  'errorContainer',
  'onErrorContainer',
  'surface',
  'onSurface',
  'onSurfaceVariant',
  'surfaceContainerLowest',
  'surfaceContainerLow',
  'surfaceContainer',
  'surfaceContainerHigh',
  'surfaceContainerHighest',
  'outline',
  'outlineVariant',
];

/// 一套配色的色槽 → ARGB。
Map<String, int> homeWidgetPaletteRolesOf(ColorScheme s) {
  int v(Color color) => color.toARGB32();
  return <String, int>{
    'primary': v(s.primary),
    'onPrimary': v(s.onPrimary),
    'primaryContainer': v(s.primaryContainer),
    'onPrimaryContainer': v(s.onPrimaryContainer),
    'secondary': v(s.secondary),
    'onSecondary': v(s.onSecondary),
    'secondaryContainer': v(s.secondaryContainer),
    'onSecondaryContainer': v(s.onSecondaryContainer),
    'tertiary': v(s.tertiary),
    'onTertiary': v(s.onTertiary),
    'tertiaryContainer': v(s.tertiaryContainer),
    'onTertiaryContainer': v(s.onTertiaryContainer),
    'error': v(s.error),
    'errorContainer': v(s.errorContainer),
    'onErrorContainer': v(s.onErrorContainer),
    'surface': v(s.surface),
    'onSurface': v(s.onSurface),
    'onSurfaceVariant': v(s.onSurfaceVariant),
    'surfaceContainerLowest': v(s.surfaceContainerLowest),
    'surfaceContainerLow': v(s.surfaceContainerLow),
    'surfaceContainer': v(s.surfaceContainer),
    'surfaceContainerHigh': v(s.surfaceContainerHigh),
    'surfaceContainerHighest': v(s.surfaceContainerHighest),
    'outline': v(s.outline),
    'outlineVariant': v(s.outlineVariant),
  };
}

/// 一个种子色的明暗两套配色（快照里 `palettes` 的一项）。
Map<String, Object?> homeWidgetPaletteOf(Color seed) => <String, Object?>{
  'light': homeWidgetPaletteRolesOf(
    appColorSchemeFromSeed(seed, Brightness.light),
  ),
  'dark': homeWidgetPaletteRolesOf(
    appColorSchemeFromSeed(seed, Brightness.dark),
  ),
};

/// 快照要带的全部配色：总带 `app`（“跟随壁纸”在旧系统上的退路，也是没有
/// 配置的实例的默认），再加上各实例自选的种子色，同一种子只导出一次。
Map<String, Object?> homeWidgetPalettesFor(
  Color appSeed,
  Iterable<HomeWidgetStyle> styles,
) {
  final palettes = <String, Object?>{'app': homeWidgetPaletteOf(appSeed)};
  for (final style in styles) {
    final key = style.paletteKey;
    if (palettes.containsKey(key) || !key.startsWith('seed:')) continue;
    palettes[key] = homeWidgetPaletteOf(style.seedColor(appSeed));
  }
  return palettes;
}

/// 小组件工作室的精选色板：都是种子色，经同一个算法展开；最后两项是无彩色
/// （石墨按同明度去色，纯黑为黑白配色），与主题色的处理一致。
const List<int> kHomeWidgetPresetSeeds = <int>[
  0xFF1E6586, // 海盐（应用默认主题色）
  0xFF2E9488, // 湖青
  0xFF7A9A5B, // 抹茶
  0xFFD9A520, // 琥珀
  0xFFE8654A, // 珊瑚
  0xFFD98BA0, // 樱粉
  0xFF6F5BA6, // 暮紫
  0xFFB4553C, // 砖红
  0xFF6B6F76, // 石墨
  kMonochromeThemeSeedValue, // 墨黑
];
