import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diary_templates/viewmodels/diary_template_accent.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_cover_parts.dart';
import 'package:node_diary/ui/widgets/color_palette_families.dart';

final ColorScheme _light = ColorScheme.fromSeed(
  seedColor: const Color(0xFF1E6586),
);
final ColorScheme _dark = ColorScheme.fromSeed(
  seedColor: const Color(0xFF1E6586),
  brightness: Brightness.dark,
);

List<Color> get _grays =>
    kColorPaletteFamilies.firstWhere((f) => f.label == '灰').colors;

bool _isNeutral(Color color) {
  final v = color.toARGB32();
  final r = (v >> 16) & 0xFF;
  final g = (v >> 8) & 0xFF;
  final b = v & 0xFF;
  return r == g && g == b;
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('灰色系每一格都换算成中性灰，不再带上主题的青蓝色', () {
    for (final scheme in [_light, _dark]) {
      for (final gray in _grays) {
        final accent = diaryTemplateAccentColors(gray.toARGB32(), scheme);
        expect(_isNeutral(accent.container), isTrue, reason: '$gray');
        expect(accent.container, isNot(scheme.primaryContainer));
      }
    }
  });

  test('浅色主题下选了最深的灰色，日记本就是这种深灰', () {
    const darkest = Color(0xFF616161);
    final accent = notebookAccentColors(darkest.toARGB32(), _light);
    expect(accent.container.toARGB32(), darkest.toARGB32());
  });

  test('越深的灰色换算出的容器色越深，明暗主题都保持次序', () {
    for (final scheme in [_light, _dark]) {
      final luminances = [
        for (final gray in _grays)
          diaryTemplateAccentColors(
            gray.toARGB32(),
            scheme,
          ).container.computeLuminance(),
      ];
      for (var i = 1; i < luminances.length; i++) {
        expect(luminances[i], lessThanOrEqualTo(luminances[i - 1]));
      }
      expect(luminances.last, lessThan(luminances.first));
    }
  });

  test('灰色容器色上的前景在明暗主题下都满足 4.5:1', () {
    for (final scheme in [_light, _dark]) {
      for (final gray in _grays) {
        final accent = diaryTemplateAccentColors(gray.toARGB32(), scheme);
        expect(
          _contrast(accent.container, accent.onContainer),
          greaterThanOrEqualTo(4.5),
          reason: '$gray ${scheme.brightness}',
        );
      }
    }
  });

  test('暗色主题下最浅的灰色也压暗，不在暗色页面上刺眼', () {
    final accent = diaryTemplateAccentColors(0xFFFAFAFA, _dark);
    expect(accent.container.computeLuminance(), lessThan(0.12));
  });

  test('棕色系最浅一格同样按中性灰处理，不被染成黄色', () {
    final accent = diaryTemplateAccentColors(0xFFEFEBE9, _light);
    expect(_isNeutral(accent.container), isTrue);
  });

  test('彩色种子仍经 ColorScheme.fromSeed 换算', () {
    for (final seed in [0xFFE53935, 0xFFD7CCC8, 0xFFE8F5E9]) {
      for (final scheme in [_light, _dark]) {
        final derived = ColorScheme.fromSeed(
          seedColor: Color(seed),
          brightness: scheme.brightness,
        );
        final accent = diaryTemplateAccentColors(seed, scheme);
        expect(accent.container, derived.primaryContainer);
        expect(accent.onContainer, derived.onPrimaryContainer);
      }
    }
  });

  test('没有颜色时跟随主题色', () {
    final accent = notebookAccentColors(null, _light);
    expect(accent.container, _light.primaryContainer);
    expect(accent.onContainer, _light.onPrimaryContainer);
  });
}
