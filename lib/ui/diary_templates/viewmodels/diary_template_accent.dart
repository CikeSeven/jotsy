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
/// 模板跟随主题色。换算较贵，按（种子, 明暗）缓存。
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
  final derived = ColorScheme.fromSeed(
    seedColor: Color(seed),
    brightness: scheme.brightness,
  );
  return _cache[key] = DiaryTemplateAccentColors(
    derived.primaryContainer,
    derived.onPrimaryContainer,
  );
}

final Map<(int, Brightness), DiaryTemplateAccentColors> _cache =
    <(int, Brightness), DiaryTemplateAccentColors>{};
