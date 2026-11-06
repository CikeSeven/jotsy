import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/app_color_scheme.dart';
import 'package:node_diary/app/theme/theme.dart';
import 'package:node_diary/ui/widgets/color_palette_families.dart';

List<Color> get _grays =>
    kColorPaletteFamilies.firstWhere((f) => f.label == '灰').colors;

bool _isNeutral(Color color) {
  final v = color.toARGB32();
  final r = (v >> 16) & 0xFF;
  final g = (v >> 8) & 0xFF;
  final b = v & 0xFF;
  return r == g && g == b;
}

/// 除错误色以外、会被换成灰阶的色槽。
List<Color> _accentAndSurfaceRoles(ColorScheme s) => <Color>[
  s.primary,
  s.onPrimary,
  s.primaryContainer,
  s.onPrimaryContainer,
  s.primaryFixed,
  s.primaryFixedDim,
  s.onPrimaryFixed,
  s.onPrimaryFixedVariant,
  s.secondary,
  s.onSecondary,
  s.secondaryContainer,
  s.onSecondaryContainer,
  s.tertiary,
  s.onTertiary,
  s.tertiaryContainer,
  s.onTertiaryContainer,
  s.surface,
  s.onSurface,
  s.surfaceDim,
  s.surfaceBright,
  s.surfaceContainerLowest,
  s.surfaceContainerLow,
  s.surfaceContainer,
  s.surfaceContainerHigh,
  s.surfaceContainerHighest,
  s.onSurfaceVariant,
  s.outline,
  s.outlineVariant,
  s.inverseSurface,
  s.onInverseSurface,
  s.inversePrimary,
  s.surfaceTint,
];

void main() {
  group('gray seeds', () {
    for (final brightness in Brightness.values) {
      test('every gray shade builds a hue-free scheme in $brightness', () {
        for (final gray in _grays) {
          final scheme = appColorSchemeFromSeed(gray, brightness);
          for (final role in _accentAndSurfaceRoles(scheme)) {
            expect(
              _isNeutral(role),
              isTrue,
              reason: '${_colorHex(gray)} → ${_colorHex(role)}',
            );
          }
        }
      });
    }

    test('gray keeps the tonal layout and only drops the hue', () {
      // 改前灰色被 tonalSpot 染成青蓝（主色 #006874），看着就是默认主题色。
      for (final brightness in Brightness.values) {
        final tinted = ColorScheme.fromSeed(
          seedColor: _grays.last,
          brightness: brightness,
        );
        final gray = appColorSchemeFromSeed(_grays.last, brightness);
        expect(gray.primary, isNot(tinted.primary));
        for (final (a, b) in <(Color, Color)>[
          (gray.primary, tinted.primary),
          (gray.primaryContainer, tinted.primaryContainer),
          (gray.surface, tinted.surface),
          (gray.onSurface, tinted.onSurface),
          (gray.outline, tinted.outline),
        ]) {
          expect(
            a.computeLuminance(),
            moreOrLessEquals(b.computeLuminance(), epsilon: 0.005),
          );
        }
      }
    });

    test('error colors stay red on a gray theme', () {
      for (final brightness in Brightness.values) {
        final scheme = appColorSchemeFromSeed(_grays.first, brightness);
        expect(_isNeutral(scheme.error), isFalse);
        expect(scheme.error.r, greaterThan(scheme.error.b));
      }
    });

    test('lightest brown is achromatic too instead of turning olive', () {
      final brown = kColorPaletteFamilies
          .firstWhere((f) => f.label == '棕')
          .colors
          .first;
      expect(isAchromaticColor(brown), isTrue);
      expect(
        _isNeutral(appColorSchemeFromSeed(brown, Brightness.light).primary),
        isTrue,
      );
    });

    test('other variants on a gray seed stay hue-free as well', () {
      for (final variant in <DynamicSchemeVariant>[
        DynamicSchemeVariant.fidelity,
        DynamicSchemeVariant.vibrant,
        DynamicSchemeVariant.neutral,
      ]) {
        final scheme = appColorSchemeFromSeed(
          _grays[4],
          Brightness.light,
          variant: variant,
        );
        expect(_isNeutral(scheme.primary), isTrue, reason: '$variant');
        expect(_isNeutral(scheme.surface), isTrue, reason: '$variant');
      }
    });
  });

  group('black and white', () {
    const seed = Color(kMonochromeThemeSeedValue);

    test('primary is black in light and white in dark', () {
      final light = appColorSchemeFromSeed(seed, Brightness.light);
      final dark = appColorSchemeFromSeed(seed, Brightness.dark);
      expect(light.primary.toARGB32(), 0xFF000000);
      expect(dark.primary.toARGB32(), 0xFFFFFFFF);
      for (final role in [
        ..._accentAndSurfaceRoles(light),
        ..._accentAndSurfaceRoles(dark),
      ]) {
        expect(_isNeutral(role), isTrue, reason: _colorHex(role));
      }
    });

    test('ignores the requested variant', () {
      final scheme = appColorSchemeFromSeed(
        seed,
        Brightness.light,
        variant: DynamicSchemeVariant.vibrant,
      );
      expect(scheme.primary.toARGB32(), 0xFF000000);
    });

    test('is offered only by the theme color families', () {
      expect(kThemeColorPaletteFamilies.last, same(kMonochromeThemeFamily));
      expect(
        kColorPaletteFamilies.expand((f) => f.colors).map((c) => c.toARGB32()),
        isNot(contains(kMonochromeThemeSeedValue)),
      );
      final selection = resolveColorPaletteSelection(
        initialColor: kMonochromeThemeSeedValue,
        fallbackFamilyIndex: 6,
        fallbackColorIndex: 5,
        families: kThemeColorPaletteFamilies,
      );
      expect(selection.familyIndex, kThemeColorPaletteFamilies.length - 1);
      expect(selection.colorIndex, 0);
    });
  });

  test('chromatic seeds are unchanged', () {
    for (final seed in <Color>[
      const Color(0xFF1E6586),
      kColorPaletteFamilies.first.colors.last,
      kColorPaletteFamilies[4].colors[5],
    ]) {
      for (final brightness in Brightness.values) {
        expect(
          appColorSchemeFromSeed(seed, brightness),
          ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
        );
      }
    }
  });

  test('app theme is assembled from the same scheme', () {
    final theme = buildSeededAppTheme(_grays[3], Brightness.dark);
    expect(
      theme.colorScheme.primary,
      appColorSchemeFromSeed(_grays[3], Brightness.dark).primary,
    );
    expect(_isNeutral(theme.colorScheme.primary), isTrue);
  });
}

String _colorHex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
