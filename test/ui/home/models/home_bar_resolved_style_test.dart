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
    test('the defaults keep the reviewed proportions', () {
      final labeled = _resolve(glass, _light);
      // 图标框 24 + 间距 3 + 文字 13.2 + 上下各 4，取整为 48；栏高再加两道
      // 6 的缝。
      expect(labeled.itemWidth, 72);
      expect(labeled.itemHeight, 48);
      expect(labeled.itemInset, 6);
      expect(labeled.barHeight, 60);
      expect(labeled.iconSize, 22);
      expect(labeled.iconBox, 24);
      expect(labeled.labelSize, 11);
      expect(labeled.labelGap, 3);

      final selected = _resolve(
        glass.copyWith(labelMode: HomeBarLabelMode.selected),
        _light,
      );
      expect(selected.barHeight, labeled.barHeight);
      expect(selected.itemWidth, labeled.itemWidth);

      // 只有图标：文字的字号与间距不算进格高，上下各留 9。
      final iconsOnly = _resolve(
        glass.copyWith(
          labelMode: HomeBarLabelMode.never,
          itemLabelSize: 14,
          itemLabelGap: 8,
        ),
        _light,
      );
      expect(iconsOnly.itemHeight, 42);
      expect(iconsOnly.barHeight, 54);
    });

    test('the bar grows with its content and its inset', () {
      final resolved = _resolve(
        glass.copyWith(
          itemIconSize: 26,
          itemLabelSize: 14,
          itemLabelGap: 8,
          itemInset: 10,
        ),
        _light,
      );
      // 28 + 8 + 16.8 + 8 = 60.8 → 61；栏高 61 + 20。
      expect(resolved.itemHeight, 61);
      expect(resolved.barHeight, 81);
    });

    test('presets resolve to their documented sizes', () {
      final compact = _resolve(HomeBarPreset.compact.style, _dark);
      expect(compact.itemWidth, 60);
      expect(compact.itemHeight, 42);
      expect(compact.barHeight, 52);

      final roomy = _resolve(HomeBarPreset.roomy.style, _light);
      expect(roomy.itemHeight, 52);
      expect(roomy.barHeight, 66);

      final focus = _resolve(HomeBarPreset.focus.style, _light);
      expect(focus.itemHeight, 48);
      expect(focus.barHeight, 56);
    });

    test('a full roundness is a capsule with a concentric indicator', () {
      for (final preset in HomeBarPreset.values) {
        final resolved = _resolve(preset.style, _light);
        expect(resolved.bottomGap, HomeBarMetrics.bottomGap);
        if (preset.style.roundness == 1) {
          expect(resolved.cornerRadius, resolved.barHeight / 2);
          expect(resolved.indicatorRadius, resolved.itemHeight / 2);
        }
      }
    });

    test('a lower roundness keeps the indicator concentric', () {
      final rounded = _resolve(HomeBarPreset.rounded.style, _light);
      expect(rounded.cornerRadius, closeTo(13.5, 1e-9));
      expect(rounded.indicatorRadius, closeTo(7.5, 1e-9));

      // 圆角比缝还小时指示器为直角，不出现负数。
      final square = _resolve(glass.copyWith(roundness: 0.1), _light);
      expect(square.cornerRadius, closeTo(3, 1e-9));
      expect(square.indicatorRadius, 0);
    });

    test('constructed out-of-range values are clamped when rendering', () {
      final resolved = _resolve(
        const HomeBarStyle(
          roundness: 3,
          itemWidth: 400,
          itemInset: -2,
          itemIconSize: 100,
        ),
        _light,
      );
      expect(resolved.roundness, HomeBarStyleLimits.roundness.max);
      expect(resolved.itemWidth, HomeBarStyleLimits.itemWidth.max);
      expect(resolved.itemInset, HomeBarStyleLimits.itemInset.min);
      expect(resolved.iconSize, HomeBarStyleLimits.itemIconSize.max);
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
