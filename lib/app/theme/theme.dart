import "package:flutter/material.dart";

part 'theme_color_schemes.dart';

/// 应用 Material 主题装配器。
///
/// 职责：
/// - 承载不同亮暗/对比度下的 `ColorScheme` 入口；
/// - 统一输出 `ThemeData`；
/// - 将大体积配色常量拆到独立文件，保持本文件聚焦在“装配逻辑”。
class MaterialTheme {
  final TextTheme textTheme;

  const MaterialTheme(this.textTheme);

  static ColorScheme lightScheme() => MaterialThemeSchemes.lightScheme;
  ThemeData light() => theme(lightScheme());

  static ColorScheme lightMediumContrastScheme() =>
      MaterialThemeSchemes.lightMediumContrastScheme;
  ThemeData lightMediumContrast() => theme(lightMediumContrastScheme());

  static ColorScheme lightHighContrastScheme() =>
      MaterialThemeSchemes.lightHighContrastScheme;
  ThemeData lightHighContrast() => theme(lightHighContrastScheme());

  static ColorScheme darkScheme() => MaterialThemeSchemes.darkScheme;
  ThemeData dark() => theme(darkScheme());

  static ColorScheme darkMediumContrastScheme() =>
      MaterialThemeSchemes.darkMediumContrastScheme;
  ThemeData darkMediumContrast() => theme(darkMediumContrastScheme());

  static ColorScheme darkHighContrastScheme() =>
      MaterialThemeSchemes.darkHighContrastScheme;
  ThemeData darkHighContrast() => theme(darkHighContrastScheme());

  ThemeData theme(ColorScheme colorScheme) => ThemeData(
    useMaterial3: true,
    fontFamily: 'HarmonyOSSansSC',
    brightness: colorScheme.brightness,
    colorScheme: colorScheme,
    textTheme: textTheme.apply(
      fontFamily: 'HarmonyOSSansSC',
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    ),
    scaffoldBackgroundColor: colorScheme.surface,
    canvasColor: colorScheme.surface,
  );

  List<ExtendedColor> get extendedColors => [];
}

class ExtendedColor {
  final Color seed, value;
  final ColorFamily light;
  final ColorFamily lightHighContrast;
  final ColorFamily lightMediumContrast;
  final ColorFamily dark;
  final ColorFamily darkHighContrast;
  final ColorFamily darkMediumContrast;

  const ExtendedColor({
    required this.seed,
    required this.value,
    required this.light,
    required this.lightHighContrast,
    required this.lightMediumContrast,
    required this.dark,
    required this.darkHighContrast,
    required this.darkMediumContrast,
  });
}

class ColorFamily {
  const ColorFamily({
    required this.color,
    required this.onColor,
    required this.colorContainer,
    required this.onColorContainer,
  });

  final Color color;
  final Color onColor;
  final Color colorContainer;
  final Color onColorContainer;
}
