import 'dart:collection';

import 'package:flutter/material.dart';

import 'app_fonts.dart';
import 'expressive_controls.dart';
import 'theme.dart';

typedef _ThemeKey = (int, Brightness, DynamicSchemeVariant, bool, AppFonts);

/// 按（种子色、明暗、配色方案、减少动画、字体）缓存的应用主题。
///
/// `ColorScheme.fromSeed` 要做 HCT 色调板计算，ThemeData 组装也不便宜；设置页
/// 的明暗预览、预览页按心情 / 标签 / 纸张重新着色都会反复用到同几套主题，
/// 这里固定容量 LRU 复用同一实例（下游按主题实例做的缓存也因此能命中）。
/// 容量按“左右翻阅十种心情各一套主题”再留出余量取定，翻页时不来回重建。
/// 装配方式与应用外壳一致：[buildSeededAppTheme]，减少动画时再经
/// [ExpressiveControls.withoutMotion]。
///
/// 要渲染组件的调用方传 `fonts: AppFonts.of(appTheme)`，另建的主题才与应用
/// 外壳同一字体；只取 `colorScheme` 的可以不传。
abstract final class SeededThemeCache {
  static const int _maxEntries = 24;
  static final LinkedHashMap<_ThemeKey, ThemeData> _cache =
      LinkedHashMap<_ThemeKey, ThemeData>();

  static ThemeData of(
    Color seed,
    Brightness brightness, {
    required bool reduceMotion,
    DynamicSchemeVariant variant = DynamicSchemeVariant.tonalSpot,
    AppFonts fonts = const AppFonts(),
  }) {
    final key = (seed.toARGB32(), brightness, variant, reduceMotion, fonts);
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      return cached;
    }
    var theme = buildSeededAppTheme(
      seed,
      brightness,
      variant: variant,
      fonts: fonts,
    );
    if (reduceMotion) {
      theme = ExpressiveControls.withoutMotion(theme);
    }
    _cache[key] = theme;
    if (_cache.length > _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    return theme;
  }
}
