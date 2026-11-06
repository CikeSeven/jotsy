import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 主题色“黑白”的种子：纯黑。
///
/// 色板里没有纯黑，只有主题色选择器末尾的“黑白”色系（`kMonochromeThemeFamily`）
/// 写入这个值；按值识别，不另加设置键，随备份与同步原样带过去。
const int kMonochromeThemeSeedValue = 0xFF000000;

/// 种子色是否没有色相：三个通道相差不超过 8/255。
///
/// 色板的灰色系全部为 0、棕色系最浅一格为 6，其余色系最淡的一格也有 13。
/// 这类颜色不能直接交给 `ColorScheme.fromSeed`：默认的 tonalSpot 只取种子色的
/// 色相、把主色彩度固定拉到 36，灰色按 CAM16 算出的色相约 209°，会被染成
/// 青蓝色，看起来就像默认主题色；棕色系最浅一格落在约 111°，被染成黄绿色。
bool isAchromaticColor(Color color) {
  final channels = <double>[color.r, color.g, color.b];
  return channels.reduce(math.max) - channels.reduce(math.min) <= 8 / 255;
}

/// 由种子色得到一种明暗下的完整配色。应用主题与各处按种子色另建的主题
/// （预览页、设置页的明暗预览等，都经 `buildSeededAppTheme`）只经这里。
///
/// - 纯黑（[kMonochromeThemeSeedValue]）为黑白配色：Material 的 monochrome
///   方案，浅色下主色纯黑、深色下主色纯白，其余全是灰阶；不看 [variant]。
/// - 其他无彩色种子（[isAchromaticColor]）照常按 [variant] 生成，再把除错误色
///   以外的每个色槽换成同明度（HCT tone）的中性灰：各色槽的深浅层次与彩色
///   主题完全一致，只是没有色相，不会被染成青蓝色。
/// - 其余种子原样走 `ColorScheme.fromSeed`。
ColorScheme appColorSchemeFromSeed(
  Color seed,
  Brightness brightness, {
  DynamicSchemeVariant variant = DynamicSchemeVariant.tonalSpot,
}) {
  if (seed.toARGB32() == kMonochromeThemeSeedValue) {
    return ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
    );
  }
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    dynamicSchemeVariant: variant,
  );
  return isAchromaticColor(seed) ? _withoutHue(scheme) : scheme;
}

/// 除错误色（删除、校验失败仍须一眼认出是红色）以外的色槽全部去掉色相。
ColorScheme _withoutHue(ColorScheme s) {
  return s.copyWith(
    primary: _neutral(s.primary),
    onPrimary: _neutral(s.onPrimary),
    primaryContainer: _neutral(s.primaryContainer),
    onPrimaryContainer: _neutral(s.onPrimaryContainer),
    primaryFixed: _neutral(s.primaryFixed),
    primaryFixedDim: _neutral(s.primaryFixedDim),
    onPrimaryFixed: _neutral(s.onPrimaryFixed),
    onPrimaryFixedVariant: _neutral(s.onPrimaryFixedVariant),
    secondary: _neutral(s.secondary),
    onSecondary: _neutral(s.onSecondary),
    secondaryContainer: _neutral(s.secondaryContainer),
    onSecondaryContainer: _neutral(s.onSecondaryContainer),
    secondaryFixed: _neutral(s.secondaryFixed),
    secondaryFixedDim: _neutral(s.secondaryFixedDim),
    onSecondaryFixed: _neutral(s.onSecondaryFixed),
    onSecondaryFixedVariant: _neutral(s.onSecondaryFixedVariant),
    tertiary: _neutral(s.tertiary),
    onTertiary: _neutral(s.onTertiary),
    tertiaryContainer: _neutral(s.tertiaryContainer),
    onTertiaryContainer: _neutral(s.onTertiaryContainer),
    tertiaryFixed: _neutral(s.tertiaryFixed),
    tertiaryFixedDim: _neutral(s.tertiaryFixedDim),
    onTertiaryFixed: _neutral(s.onTertiaryFixed),
    onTertiaryFixedVariant: _neutral(s.onTertiaryFixedVariant),
    surface: _neutral(s.surface),
    onSurface: _neutral(s.onSurface),
    surfaceDim: _neutral(s.surfaceDim),
    surfaceBright: _neutral(s.surfaceBright),
    surfaceContainerLowest: _neutral(s.surfaceContainerLowest),
    surfaceContainerLow: _neutral(s.surfaceContainerLow),
    surfaceContainer: _neutral(s.surfaceContainer),
    surfaceContainerHigh: _neutral(s.surfaceContainerHigh),
    surfaceContainerHighest: _neutral(s.surfaceContainerHighest),
    onSurfaceVariant: _neutral(s.onSurfaceVariant),
    outline: _neutral(s.outline),
    outlineVariant: _neutral(s.outlineVariant),
    inverseSurface: _neutral(s.inverseSurface),
    onInverseSurface: _neutral(s.onInverseSurface),
    inversePrimary: _neutral(s.inversePrimary),
    surfaceTint: _neutral(s.surfaceTint),
  );
}

/// 同一相对亮度 Y 的中性灰。HCT 的 tone 就是 L*，只由 Y 决定，所以换成灰色
/// 后明度不变，色槽之间的对比度也就与原配色一致。
Color _neutral(Color color) {
  final y = color.computeLuminance();
  final srgb = y <= 0.0031308
      ? 12.92 * y
      : 1.055 * math.pow(y, 1 / 2.4) - 0.055;
  final v = (srgb * 255).round().clamp(0, 255);
  return Color.fromARGB((color.a * 255).round(), v, v, v);
}
