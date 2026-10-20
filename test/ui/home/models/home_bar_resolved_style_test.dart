import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_card_colors.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_presets.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_resolved_style.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';

final _light = ColorScheme.fromSeed(seedColor: Colors.teal);
final _dark = ColorScheme.fromSeed(
  seedColor: Colors.teal,
  brightness: Brightness.dark,
);

HomeBarResolvedStyle _resolve(
  HomeBarStyle style,
  ColorScheme scheme, {
  bool highContrast = false,
}) => HomeBarResolvedStyle.resolve(style, scheme, highContrast: highContrast);

Color _opaque(Color color) => color.withValues(alpha: 1);

void main() {
  final glass = HomeBarPreset.glass.style;

  group('material', () {
    test('solid defaults never use glass', () {
      final resolved = _resolve(HomeBarStyle.defaults, _light);
      expect(resolved.isGlass, isFalse);
      expect(resolved.glassTopBars, isFalse);
      expect(resolved.border, isFalse);
      expect(resolved.shadow, isFalse);
    });

    test('glass applies, including top bars unless turned off', () {
      final resolved = _resolve(glass, _light);
      expect(resolved.isGlass, isTrue);
      expect(resolved.glassTopBars, isTrue);
      expect(resolved.border, isTrue);
      expect(resolved.shadow, isTrue);
      expect(
        _resolve(glass.copyWith(glassTopBars: false), _light).glassTopBars,
        isFalse,
      );
    });

    test('the top bar hairline needs glass top bars and its own switch', () {
      expect(_resolve(glass, _light).topBarHairline, isFalse);
      final on = glass.copyWith(topBarHairline: true);
      expect(_resolve(on, _light).topBarHairline, isTrue);
      // 底栏描边不再牵动顶栏分隔线。
      expect(
        _resolve(on.copyWith(border: false), _light).topBarHairline,
        isTrue,
      );
      expect(
        _resolve(glass.copyWith(border: true), _light).topBarHairline,
        isFalse,
      );
      expect(
        _resolve(on.copyWith(glassTopBars: false), _light).topBarHairline,
        isFalse,
      );
      expect(
        _resolve(
          HomeBarStyle.defaults.copyWith(topBarHairline: true),
          _light,
        ).topBarHairline,
        isFalse,
      );
      expect(_resolve(on, _light), isNot(_resolve(glass, _light)));
    });

    test('high contrast keeps the glass layout but turns translucency off', () {
      final resolved = _resolve(
        glass.copyWith(fabPlacement: HomeBarFabPlacement.inline),
        _light,
        highContrast: true,
      );
      expect(resolved.isGlass, isTrue);
      expect(resolved.translucent, isFalse);
      expect(resolved.glassTopBars, isTrue);
      expect(resolved.fabPlacement, HomeBarFabPlacement.inline);
      expect(resolved.fill, resolved.solidFill);
      expect(resolved.fill.a, 1);
      final normal = _resolve(glass, _light);
      expect(normal.translucent, isTrue);
      expect(normal.fill, normal.tint);
    });
  });

  group('geometry', () {
    test('corner radius clamps to half the bar height', () {
      final resolved = _resolve(
        glass.copyWith(barHeight: 56, cornerRadius: 40),
        _light,
      );
      expect(resolved.cornerRadius, 28);
      expect(
        _resolve(glass.copyWith(cornerRadius: 10), _light).cornerRadius,
        10,
      );
    });

    test('out-of-range constructed values are clamped again', () {
      final resolved = _resolve(
        const HomeBarStyle(
          material: HomeBarMaterial.glass,
          blurSigma: 99,
          tintOpacity: 0.1,
          iconSize: 3,
          labelGap: 30,
          blockPadding: -2,
        ),
        _light,
      );
      expect(resolved.blurSigma, HomeBarStyleLimits.blurSigma.max);
      expect(resolved.tintOpacity, HomeBarStyleLimits.tintOpacity.min);
      expect(resolved.iconSize, HomeBarStyleLimits.iconSize.min);
      expect(resolved.labelGap, HomeBarStyleLimits.labelGap.max);
      expect(resolved.blockPadding, 0);
    });

    test('spacing passes through and takes part in equality', () {
      final a = _resolve(glass.copyWith(labelGap: 5, blockPadding: 9), _light);
      expect(a.labelGap, 5);
      expect(a.blockPadding, 9);
      final b = _resolve(glass.copyWith(labelGap: 5, blockPadding: 9), _light);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == _resolve(glass.copyWith(labelGap: 6), _light), isFalse);
      expect(a == _resolve(glass.copyWith(blockPadding: 8), _light), isFalse);
    });
  });

  group('tint', () {
    test('neutral uses the lowest / high surface containers', () {
      final light = _resolve(glass, _light);
      expect(_opaque(light.tint), _light.surfaceContainerLowest);
      expect(light.tint.a, closeTo(0.72, 0.01));
      expect(light.solidFill, Color.alphaBlend(light.tint, _light.surface));
      expect(_opaque(_resolve(glass, _dark).tint), _dark.surfaceContainerHigh);
    });

    test('theme leans toward the primary container', () {
      final themed = glass.copyWith(tint: HomeBarTint.theme);
      expect(
        _opaque(_resolve(themed, _light).tint),
        Color.lerp(
          _light.surfaceContainerLowest,
          _light.primaryContainer,
          0.35,
        ),
      );
      expect(
        _opaque(_resolve(themed, _dark).tint),
        Color.lerp(_dark.surfaceContainerHigh, _dark.primaryContainer, 0.30),
      );
    });

    test('custom uses the color, then the dark value or a derived one', () {
      final custom = glass.copyWith(
        tint: HomeBarTint.custom,
        tintColor: () => 0xFFE0C080,
      );
      expect(_opaque(_resolve(custom, _light).tint), const Color(0xFFE0C080));
      expect(
        _opaque(_resolve(custom, _dark).tint),
        DiaryCardColors.deriveDark(
          const Color(0xFFE0C080),
          DiaryCardColorRole.surface,
        ),
      );
      expect(
        _opaque(
          _resolve(
            custom.copyWith(tintColorDark: () => 0xFF202830),
            _dark,
          ).tint,
        ),
        const Color(0xFF202830),
      );
    });

    test('custom without a color reads as neutral', () {
      final resolved = _resolve(
        glass.copyWith(tint: HomeBarTint.custom),
        _light,
      );
      expect(resolved, _resolve(glass, _light));
    });
  });

  group('foreground', () {
    test('uses the theme colors on readable tints', () {
      final resolved = _resolve(glass, _light);
      expect(resolved.selectedForeground, _light.primary);
      expect(resolved.unselectedForeground, _light.onSurfaceVariant);
    });

    test('falls back to a contrasting color on a very dark custom tint', () {
      final resolved = _resolve(
        glass.copyWith(
          tint: HomeBarTint.custom,
          tintColor: () => 0xFF101010,
          tintOpacity: 0.95,
        ),
        _light,
      );
      expect(resolved.selectedForeground, _light.surface);
      expect(resolved.unselectedForeground, _light.surface);
      expect(
        DiaryCardColors.contrastRatio(
          resolved.selectedForeground,
          resolved.solidFill,
        ),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  test('equal inputs resolve to equal values', () {
    expect(_resolve(glass, _dark), _resolve(glass, _dark));
    expect(_resolve(glass, _dark).hashCode, _resolve(glass, _dark).hashCode);
    expect(_resolve(glass, _dark), isNot(_resolve(glass, _light)));
  });
}
