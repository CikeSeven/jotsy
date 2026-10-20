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

HomeBarResolvedStyle _resolve(HomeBarStyle style, ColorScheme scheme) =>
    HomeBarResolvedStyle.resolve(style, scheme);

HomeBarStyle _withBorder(HomeBarLineStyle line) =>
    HomeBarPreset.glass.style.copyWith(borderLine: line);

void main() {
  group('line colors', () {
    test('defaults resolve to the outline variant at each line opacity', () {
      final glass = HomeBarPreset.glass.style;
      for (final scheme in <ColorScheme>[_light, _dark]) {
        final resolved = _resolve(glass, scheme);
        expect(
          resolved.borderColor,
          scheme.outlineVariant.withValues(alpha: 0.6),
        );
        expect(resolved.borderWidth, 1.0);
        expect(
          resolved.hairlineColor,
          scheme.outlineVariant.withValues(alpha: 0.35),
        );
        expect(resolved.hairlineWidth, 0.6);
      }
    });

    test('each color source per brightness', () {
      Color border(HomeBarLineColor color, ColorScheme scheme) => _resolve(
        _withBorder(
          HomeBarLineStyle.borderDefaults.copyWith(color: color, opacity: 1),
        ),
        scheme,
      ).borderColor;

      expect(border(HomeBarLineColor.theme, _light), _light.outlineVariant);
      expect(border(HomeBarLineColor.theme, _dark), _dark.outlineVariant);
      expect(
        border(HomeBarLineColor.highlight, _light),
        _light.surfaceContainerLowest,
      );
      expect(border(HomeBarLineColor.highlight, _dark), _dark.onSurface);
      expect(border(HomeBarLineColor.primary, _light), _light.primary);
      expect(border(HomeBarLineColor.primary, _dark), _dark.primary);
      // 自定义却没选颜色：按跟随主题解读。
      expect(border(HomeBarLineColor.custom, _light), _light.outlineVariant);
      expect(border(HomeBarLineColor.custom, _dark), _dark.outlineVariant);
    });

    test('custom colors: light as is, dark explicit or derived as accent', () {
      const custom = HomeBarLineStyle(
        color: HomeBarLineColor.custom,
        customColor: 0xFF1E88E5,
        opacity: 1,
        width: 1,
      );
      expect(
        _resolve(_withBorder(custom), _light).borderColor,
        const Color(0xFF1E88E5),
      );
      expect(
        _resolve(_withBorder(custom), _dark).borderColor,
        DiaryCardColors.deriveDark(
          const Color(0xFF1E88E5),
          DiaryCardColorRole.accent,
        ),
      );
      expect(
        _resolve(
          _withBorder(custom.copyWith(customColorDark: () => 0xFF90CAF9)),
          _dark,
        ).borderColor,
        const Color(0xFF90CAF9),
      );
    });

    test('opacity is applied and both values are clamped', () {
      final half = _resolve(
        _withBorder(
          HomeBarLineStyle.borderDefaults.copyWith(
            color: HomeBarLineColor.primary,
            opacity: 0.5,
          ),
        ),
        _light,
      );
      expect(half.borderColor, _light.primary.withValues(alpha: 0.5));

      final wild = _resolve(
        HomeBarPreset.glass.style.copyWith(
          borderLine: const HomeBarLineStyle(opacity: 0, width: 9),
          topBarLine: const HomeBarLineStyle(opacity: 4, width: 0),
        ),
        _light,
      );
      expect(wild.borderColor.a, closeTo(0.10, 0.002));
      expect(wild.borderWidth, HomeBarStyleLimits.lineWidth.max);
      expect(wild.hairlineColor.a, 1);
      expect(wild.hairlineWidth, HomeBarStyleLimits.lineWidth.min);
    });

    test('line changes alter the resolved style', () {
      final glass = HomeBarPreset.glass.style;
      final base = _resolve(glass, _light);
      final wider = _resolve(
        glass.copyWith(
          topBarLine: HomeBarLineStyle.topBarDefaults.copyWith(width: 1.2),
        ),
        _light,
      );
      expect(wider, isNot(base));
      expect(wider.hashCode, isNot(base.hashCode));
      expect(_resolve(glass, _light), base);
    });

    test('lines are drawn only while their switches are on', () {
      final glass = HomeBarPreset.glass.style;
      expect(_resolve(glass, _light).border, isTrue);
      expect(_resolve(glass.copyWith(border: false), _light).border, isFalse);
      expect(_resolve(glass, _light).topBarHairline, isFalse);
      expect(
        _resolve(glass.copyWith(topBarHairline: true), _light).topBarHairline,
        isTrue,
      );
      // 实色栏没有这两条线，改了线条样式也一样。
      final solid = _resolve(
        HomeBarStyle.defaults.copyWith(
          topBarHairline: true,
          borderLine: HomeBarLineStyle.borderDefaults.copyWith(width: 3),
        ),
        _light,
      );
      expect(solid.border, isFalse);
      expect(solid.topBarHairline, isFalse);
    });

    test('the clear preset resolves to a highlight rim', () {
      final clear = _resolve(HomeBarPreset.clear.style, _light);
      expect(
        clear.borderColor,
        _light.surfaceContainerLowest.withValues(alpha: 0.7),
      );
      expect(
        _resolve(HomeBarPreset.clear.style, _dark).borderColor,
        _dark.onSurface.withValues(alpha: 0.7),
      );
    });
  });
}
