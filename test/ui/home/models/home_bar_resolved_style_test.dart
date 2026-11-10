import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_metrics.dart';
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
    test('the defaults are translucent, saturated glass', () {
      final resolved = _resolve(glass, _light);
      expect(resolved.translucent, isTrue);
      expect(resolved.topBarHairline, isFalse);
      expect(resolved.blurSigma, closeTo(15, 0.01));
      expect(resolved.saturation, HomeBarMetrics.saturation);
      expect(resolved.saturation, greaterThan(1));
      expect(resolved.fill, resolved.tint);
    });

    test('the blur follows the opacity between its two ends', () {
      double sigma(double opacity) =>
          _resolve(HomeBarStyle(tintOpacity: opacity), _light).blurSigma;
      final range = HomeBarStyleLimits.tintOpacity;
      expect(sigma(range.min), HomeBarMetrics.minBlurSigma);
      expect(sigma(range.max), HomeBarMetrics.maxBlurSigma);
      // 越通透模糊越轻：通透 < 玻璃 < 磨砂。
      final clear = _resolve(HomeBarPreset.clear.style, _light).blurSigma;
      final frosted = _resolve(HomeBarPreset.frosted.style, _light).blurSigma;
      expect(clear, lessThan(sigma(glass.tintOpacity)));
      expect(frosted, greaterThan(sigma(glass.tintOpacity)));
      // 直接构造的越界值同样夹到两端。
      expect(sigma(0), HomeBarMetrics.minBlurSigma);
      expect(sigma(1), HomeBarMetrics.maxBlurSigma);
    });

    test('the top bar hairline follows its own switch', () {
      expect(
        _resolve(glass.copyWith(topBarHairline: true), _light).topBarHairline,
        isTrue,
      );
      expect(
        _resolve(glass, _light).hairlineColor,
        _light.outlineVariant.withValues(alpha: 0.35),
      );
    });

    test('high contrast keeps the glass layout but turns translucency off', () {
      final normal = _resolve(glass, _light);
      final contrast = _resolve(glass, _light, highContrast: true);
      expect(contrast.translucent, isFalse);
      expect(contrast.fill, contrast.solidFill);
      expect(contrast.fill.a, 1);
      // 布局不变：同样的栏高、项宽与顶栏结构。
      expect(contrast.barHeight, normal.barHeight);
      expect(contrast.itemWidth, normal.itemWidth);
    });
  });

  group('geometry', () {
    test('follows the label mode and nothing else', () {
      final labeled = _resolve(glass, _light);
      expect(labeled.barHeight, HomeBarMetrics.labeledBarHeight);
      expect(labeled.itemWidth, HomeBarMetrics.labeledItemWidth);

      final selected = _resolve(
        glass.copyWith(labelMode: HomeBarLabelMode.selected),
        _light,
      );
      expect(selected.barHeight, labeled.barHeight);
      expect(selected.itemWidth, labeled.itemWidth);

      final compact = _resolve(HomeBarPreset.compact.style, _dark);
      expect(compact.barHeight, HomeBarMetrics.compactBarHeight);
      expect(compact.itemWidth, HomeBarMetrics.compactItemWidth);
    });

    test('the pill is always a capsule', () {
      for (final preset in HomeBarPreset.values) {
        final resolved = _resolve(preset.style, _light);
        expect(resolved.cornerRadius, resolved.barHeight / 2);
        expect(resolved.bottomGap, HomeBarMetrics.bottomGap);
      }
    });
  });

  group('tint', () {
    test('neutral uses the lowest / high surface containers', () {
      expect(
        _opaque(_resolve(glass, _light).tint),
        _light.surfaceContainerLowest,
      );
      expect(_opaque(_resolve(glass, _dark).tint), _dark.surfaceContainerHigh);
      expect(_resolve(glass, _light).tinted, isFalse);
    });

    test('theme leans toward the primary container', () {
      final style = HomeBarPreset.tinted.style;
      expect(
        _opaque(_resolve(style, _light).tint),
        Color.lerp(
          _light.surfaceContainerLowest,
          _light.primaryContainer,
          0.35,
        ),
      );
      expect(
        _opaque(_resolve(style, _dark).tint),
        Color.lerp(_dark.surfaceContainerHigh, _dark.primaryContainer, 0.30),
      );
      expect(_resolve(style, _light).tinted, isTrue);
    });

    test('the opacity is the alpha of the tint, clamped to its range', () {
      expect(_resolve(glass, _light).tint.a, closeTo(0.5, 0.005));
      expect(
        _resolve(HomeBarPreset.clear.style, _light).tint.a,
        closeTo(0.2, 0.005),
      );
      // 直接构造（而非解码）的越界值在渲染层再夹一次。
      expect(
        _resolve(const HomeBarStyle(tintOpacity: 0.01), _light).tint.a,
        closeTo(HomeBarStyleLimits.tintOpacity.min, 0.005),
      );
    });

    test('the solid fill is the tint flattened onto the surface', () {
      final resolved = _resolve(HomeBarPreset.clear.style, _dark);
      expect(resolved.solidFill.a, 1);
      expect(
        resolved.solidFill,
        Color.alphaBlend(resolved.tint, _dark.surface),
      );
    });
  });

  group('colors', () {
    test('the foreground uses the theme colors', () {
      final resolved = _resolve(glass, _light);
      expect(resolved.selectedForeground, _light.primary);
      expect(resolved.unselectedForeground, _light.onSurfaceVariant);
    });

    test('the indicator and outline are tuned per brightness', () {
      final light = _resolve(glass, _light);
      final dark = _resolve(glass, _dark);
      expect(light.indicatorColor, _light.primary.withValues(alpha: 0.12));
      expect(dark.indicatorColor, _dark.primary.withValues(alpha: 0.20));
      // 描边是边缘的反光：亮色用最亮的表面色，暗色用 onSurface，都是
      // 半透明的高光而不是灰色轮廓。
      expect(_opaque(light.borderColor), _light.surfaceContainerLowest);
      expect(light.borderColor.a, closeTo(0.8, 0.005));
      expect(_opaque(dark.borderColor), _dark.onSurface);
      expect(dark.borderColor.a, closeTo(0.16, 0.005));
      expect(dark.shadowColor.a, greaterThan(light.shadowColor.a));
    });
  });

  test('equal inputs resolve to equal values', () {
    final a = _resolve(HomeBarPreset.tinted.style, _dark);
    final b = _resolve(HomeBarPreset.tinted.style, _dark);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(_resolve(HomeBarPreset.glass.style, _dark)));
    expect(a, isNot(_resolve(HomeBarPreset.tinted.style, _light)));
  });
}
