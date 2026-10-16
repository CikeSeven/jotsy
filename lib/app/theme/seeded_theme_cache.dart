import 'dart:collection';

import 'package:flutter/material.dart';

import 'expressive_controls.dart';
import 'theme.dart';

/// 按（种子色、明暗、减少动画）缓存的应用主题。
///
/// `ColorScheme.fromSeed` 要做 HCT 色调板计算，ThemeData 组装也不便宜；设置页
/// 的明暗预览、预览页按心情 / 标签 / 纸张重新着色都会反复用到同几套主题，
/// 这里固定容量 LRU 复用同一实例（下游按主题实例做的缓存也因此能命中）。
/// 装配方式与应用外壳一致：[buildSeededAppTheme]，减少动画时再经
/// [ExpressiveControls.withoutMotion]。
abstract final class SeededThemeCache {
  static const int _maxEntries = 16;
  static final LinkedHashMap<(int, Brightness, bool), ThemeData> _cache =
      LinkedHashMap<(int, Brightness, bool), ThemeData>();

  static ThemeData of(
    Color seed,
    Brightness brightness, {
    required bool reduceMotion,
  }) {
    final key = (seed.toARGB32(), brightness, reduceMotion);
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      return cached;
    }
    var theme = buildSeededAppTheme(seed, brightness);
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
