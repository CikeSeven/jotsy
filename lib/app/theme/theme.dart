import "package:flutter/material.dart";

import 'expressive_controls.dart';
import 'expressive_surfaces.dart';

part 'theme_color_schemes.dart';

/// 由种子色装配应用的亮/暗主题：tonalSpot 动态配色 + Material 2021 字阶。
///
/// 应用外壳与设置页里的明暗预览共用同一装配，预览看到的就是切换主题后的
/// 真实效果。
ThemeData buildSeededAppTheme(Color seedColor, Brightness brightness) {
  return MaterialTheme(
    brightness == Brightness.light
        ? Typography.material2021().black
        : Typography.material2021().white,
  ).theme(
    ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    ),
  );
}

/// 应用 Material 3 Expressive 主题装配器。
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

  ThemeData theme(ColorScheme colorScheme) {
    // 页面画布统一取种子色派生的 surface：纯白卡片在其上清爽浮起，换主题色时
    // 底色随之带上同一色调，不再与固定冷灰蓝底色产生色差。
    final scaffoldBg = ExpressiveSurfaces.pageBackground(colorScheme);
    final baseTheme = ThemeData(
      useMaterial3: true,
      fontFamily: 'HarmonyOSSansSC',
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBg,
      canvasColor: scaffoldBg,
      // 显式取标准密度：Flutter 在桌面平台的默认是 compact，会把按钮、列表行、
      // 输入框等整体压矮 4–8dp，DESIGN.md 的 dp 规格就不再成立。Android/iOS
      // 的默认本来就是 standard，移动端不受影响。
      visualDensity: VisualDensity.standard,
    );
    final resolvedTextTheme = baseTheme.textTheme
        .merge(textTheme)
        .apply(
          fontFamily: 'HarmonyOSSansSC',
          bodyColor: colorScheme.onSurface,
          displayColor: colorScheme.onSurface,
        );
    // Expressive 是 M3 的扩展而非 Material 4；继续启用 useMaterial3，
    // 用集中式组件主题补齐形状、强调字重与表面，第三方 Material 控件也会继承。
    final emphasizedTextTheme = resolvedTextTheme.copyWith(
      headlineLarge: resolvedTextTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: resolvedTextTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: resolvedTextTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      titleLarge: resolvedTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleMedium: resolvedTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      labelLarge: resolvedTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
    return ExpressiveSurfaces.apply(
      ExpressiveControls.apply(
        baseTheme.copyWith(textTheme: emphasizedTextTheme),
      ),
    );
  }

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
