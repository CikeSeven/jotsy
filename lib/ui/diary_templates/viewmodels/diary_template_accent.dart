import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 模板强调色在当前主题下的一对颜色：图标底色与图标色。
@immutable
class DiaryTemplateAccentColors {
  const DiaryTemplateAccentColors(this.container, this.onContainer);

  final Color container;
  final Color onContainer;
}

/// 把模板的强调色种子换算成当前明暗主题下的容器色。
///
/// 不直接涂种子色：同一个橙色在暗色主题里会刺眼、文字也难辨认。经
/// `ColorScheme.fromSeed` 换算出的 primaryContainer / onPrimaryContainer 在
/// 明暗两种主题下都满足对比度，且与应用其余部分的色调一致。没有强调色的
/// 模板跟随主题色。灰色这类无彩色种子另走 [_neutralAccentColors]。换算较贵，
/// 按（种子, 明暗）缓存。
DiaryTemplateAccentColors diaryTemplateAccentColors(
  int? seed,
  ColorScheme scheme,
) {
  if (seed == null) {
    return DiaryTemplateAccentColors(
      scheme.primaryContainer,
      scheme.onPrimaryContainer,
    );
  }
  final key = (seed, scheme.brightness);
  final cached = _cache[key];
  if (cached != null) return cached;
  if (_cache.length >= 64) _cache.clear();
  final color = Color(seed);
  if (_isAchromatic(color)) {
    return _cache[key] = _neutralAccentColors(color, scheme.brightness);
  }
  final derived = ColorScheme.fromSeed(
    seedColor: color,
    brightness: scheme.brightness,
  );
  return _cache[key] = DiaryTemplateAccentColors(
    derived.primaryContainer,
    derived.onPrimaryContainer,
  );
}

final Map<(int, Brightness), DiaryTemplateAccentColors> _cache =
    <(int, Brightness), DiaryTemplateAccentColors>{};

/// 三个通道相差不超过 8/255 即视为没有色相：色板的灰色系全部为 0、棕色系
/// 最浅一格为 6，其余色系最淡的一格也有 13。
///
/// 这类颜色不能交给 `ColorScheme.fromSeed`：默认的 tonalSpot 把主色彩度固定
/// 拉到 36，灰色按 CAM16 算出的色相约 209°，会被染成青蓝色，看起来就像
/// “跟随主题”；棕色系最浅一格则落在约 111°，被染成黄色。
bool _isAchromatic(Color color) {
  final channels = <double>[color.r, color.g, color.b];
  return channels.reduce(math.max) - channels.reduce(math.min) <= 8 / 255;
}

/// 浅色主题下灰色的取值范围（明度 25–90）：范围内直接取种子的灰度，选了
/// 深灰就是深灰；上限与彩色种子换算出的浅色容器色同一明度，再白就和页面
/// 融在一起了。
const Color _lightInk = Color(0xFF3B3B3B);
const Color _lightPaper = Color(0xFFE2E2E2);

/// 暗色主题下按同一位置压到明度 15–40：深浅次序不变，最浅的也只比彩色
/// 容器色（明度 30）亮一点，不会在暗色页面上刺眼。
const Color _darkInk = Color(0xFF262626);
const Color _darkPaper = Color(0xFF5E5E5E);

/// 容器色上的前景：暗色主题的容器都不亮于明度 40，一律用明度 90 的浅灰
/// （与 fromSeed 的暗色 onPrimaryContainer 同明度）；浅色主题在明度 10 的
/// 墨色与白色之间取对比度更高的一个（中灰只有白色能到 4.5:1）。
const Color _inkOn = Color(0xFF1B1B1B);
const Color _paperOnLight = Color(0xFFFFFFFF);
const Color _paperOnDark = Color(0xFFE2E2E2);

DiaryTemplateAccentColors _neutralAccentColors(
  Color seed,
  Brightness brightness,
) {
  // sRGB 灰度值本身就接近感知明度，按它在浅色范围里的位置取色。
  final gray = (seed.r + seed.g + seed.b) / 3;
  final t = ((gray - _lightInk.r) / (_lightPaper.r - _lightInk.r)).clamp(
    0.0,
    1.0,
  );
  if (brightness == Brightness.dark) {
    return DiaryTemplateAccentColors(
      Color.lerp(_darkInk, _darkPaper, t)!,
      _paperOnDark,
    );
  }
  final container = Color.lerp(_lightInk, _lightPaper, t)!;
  final onContainer =
      _contrast(container, _paperOnLight) >= _contrast(container, _inkOn)
      ? _paperOnLight
      : _inkOn;
  return DiaryTemplateAccentColors(container, onContainer);
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
