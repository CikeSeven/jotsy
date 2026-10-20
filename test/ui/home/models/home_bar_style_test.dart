import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_behavior.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';

void main() {
  group('HomeBarStyle defaults', () {
    test('match the solid bar before the redesign', () {
      const d = HomeBarStyle.defaults;
      expect(d.material, HomeBarMaterial.solid);
      expect(d.glassTopBars, isTrue);
      expect(d.blurSigma, 20);
      expect(d.tintOpacity, 0.72);
      expect(d.tint, HomeBarTint.neutral);
      expect(d.tintColor, isNull);
      expect(d.tintColorDark, isNull);
      expect(d.border, isTrue);
      expect(d.shadow, isTrue);
      expect(d.barHeight, 64);
      expect(d.cornerRadius, 32);
      expect(d.sideMargin, 16);
      expect(d.bottomGap, 12);
      expect(d.fabPlacement, HomeBarFabPlacement.above);
      expect(d.labelMode, HomeBarLabelMode.always);
      expect(d.iconSize, 20);
      expect(d.indicator, HomeBarIndicator.capsule);
      expect(d.isDefault, isTrue);
      expect(d.toJson(), isEmpty);
    });
  });

  group('HomeBarStyle.fromJson', () {
    test('returns defaults for non-map input', () {
      for (final raw in <Object?>[null, 'x', 3, <Object>[], true]) {
        expect(HomeBarStyle.fromJson(raw), HomeBarStyle.defaults);
      }
    });

    test('decodes each field independently of bad neighbours', () {
      final style = HomeBarStyle.fromJson(<String, Object?>{
        'material': 'glass',
        'glassTopBars': 'yes',
        'blurSigma': 'big',
        'tintOpacity': 0.5,
        'tint': 'rainbow',
        'tintColor': 0xFF336699,
        'tintColorDark': 'nope',
        'border': false,
        'shadow': 0,
        'barHeight': 70,
        'cornerRadius': null,
        'labelMode': 'selected',
        'indicator': 7,
      });
      expect(style.material, HomeBarMaterial.glass);
      expect(style.glassTopBars, isTrue);
      expect(style.blurSigma, 20);
      expect(style.tintOpacity, 0.5);
      expect(style.tint, HomeBarTint.neutral);
      expect(style.tintColor, 0xFF336699);
      expect(style.tintColorDark, isNull);
      expect(style.border, isFalse);
      expect(style.shadow, isTrue);
      expect(style.barHeight, 70);
      expect(style.cornerRadius, 32);
      expect(style.labelMode, HomeBarLabelMode.selected);
      expect(style.indicator, HomeBarIndicator.capsule);
    });

    test('clamps numbers to their limits and rejects NaN', () {
      final high = HomeBarStyle.fromJson(<String, Object?>{
        'blurSigma': 999,
        'tintOpacity': 2,
        'barHeight': 500,
        'cornerRadius': 100,
        'sideMargin': 99,
        'bottomGap': 99,
        'iconSize': 99,
      });
      expect(high.blurSigma, HomeBarStyleLimits.blurSigma.max);
      expect(high.tintOpacity, HomeBarStyleLimits.tintOpacity.max);
      expect(high.barHeight, HomeBarStyleLimits.barHeight.max);
      expect(high.cornerRadius, HomeBarStyleLimits.cornerRadius.max);
      expect(high.sideMargin, HomeBarStyleLimits.sideMargin.max);
      expect(high.bottomGap, HomeBarStyleLimits.bottomGap.max);
      expect(high.iconSize, HomeBarStyleLimits.iconSize.max);

      final low = HomeBarStyle.fromJson(<String, Object?>{
        'blurSigma': -5,
        'tintOpacity': 0,
        'barHeight': 1,
        'iconSize': 1,
      });
      expect(low.blurSigma, 0);
      expect(low.tintOpacity, HomeBarStyleLimits.tintOpacity.min);
      expect(low.barHeight, HomeBarStyleLimits.barHeight.min);
      expect(low.iconSize, HomeBarStyleLimits.iconSize.min);

      final nan = HomeBarStyle.fromJson(<String, Object?>{
        'blurSigma': double.nan,
        'barHeight': double.infinity,
      });
      expect(nan.blurSigma, HomeBarStyle.defaults.blurSigma);
      expect(nan.barHeight, HomeBarStyle.defaults.barHeight);
    });

    test('falls back on unknown enum names', () {
      final style = HomeBarStyle.fromJson(<String, Object?>{
        'material': 'metal',
        'tint': 'neon',
        'labelMode': 'sometimes',
        'indicator': 'glow',
        'fabPlacement': 'left',
      });
      expect(style, HomeBarStyle.defaults);
    });

    test('rejects colors outside the 32-bit range and forces opacity', () {
      expect(
        HomeBarStyle.fromJson(<String, Object?>{'tintColor': -1}).tintColor,
        isNull,
      );
      expect(
        HomeBarStyle.fromJson(<String, Object?>{
          'tintColor': 0x1FFFFFFFF,
        }).tintColor,
        isNull,
      );
      expect(
        HomeBarStyle.fromJson(<String, Object?>{
          'tintColor': 0x80112233,
        }).tintColor,
        0xFF112233,
      );
    });

    test('keeps a custom tint without a color as stored', () {
      final style = HomeBarStyle.fromJson(<String, Object?>{'tint': 'custom'});
      expect(style.tint, HomeBarTint.custom);
      expect(style.tintColor, isNull);
    });
  });

  group('HomeBarStyle.toJson', () {
    test('writes only fields that differ from the defaults', () {
      const style = HomeBarStyle(material: HomeBarMaterial.glass, iconSize: 24);
      expect(style.toJson(), <String, Object>{
        'material': 'glass',
        'iconSize': 24.0,
      });
    });

    test('round-trips every field through JSON text', () {
      const style = HomeBarStyle(
        material: HomeBarMaterial.glass,
        glassTopBars: false,
        blurSigma: 33,
        tintOpacity: 0.4,
        tint: HomeBarTint.custom,
        tintColor: 0xFF224466,
        tintColorDark: 0xFF101820,
        border: false,
        shadow: false,
        barHeight: 72,
        cornerRadius: 12,
        sideMargin: 8,
        bottomGap: 20,
        fabPlacement: HomeBarFabPlacement.inline,
        labelMode: HomeBarLabelMode.never,
        iconSize: 26,
        indicator: HomeBarIndicator.none,
      );
      final decoded = HomeBarStyle.fromJson(
        jsonDecode(jsonEncode(style.toJson())),
      );
      expect(decoded, style);
      expect(decoded.hashCode, style.hashCode);
    });

    test('copyWith can clear a custom color', () {
      const style = HomeBarStyle(tintColor: 0xFF123456);
      expect(style.copyWith().tintColor, 0xFF123456);
      expect(style.copyWith(tintColor: () => null).tintColor, isNull);
    });
  });

  group('HomeBarBehavior', () {
    test('defaults to off and encodes sparsely', () {
      expect(HomeBarBehavior.defaults.hideOnScroll, isFalse);
      expect(HomeBarBehavior.defaults.indicatorFollowsSwipe, isFalse);
      expect(HomeBarBehavior.defaults.toJson(), isEmpty);
      expect(
        const HomeBarBehavior(hideOnScroll: true).toJson(),
        <String, Object>{'hideOnScroll': true},
      );
    });

    test('decodes tolerantly and round-trips', () {
      expect(HomeBarBehavior.fromJson('x'), HomeBarBehavior.defaults);
      final behavior = HomeBarBehavior.fromJson(<String, Object?>{
        'hideOnScroll': 'yes',
        'indicatorFollowsSwipe': true,
      });
      expect(behavior.hideOnScroll, isFalse);
      expect(behavior.indicatorFollowsSwipe, isTrue);
      expect(HomeBarBehavior.fromJson(behavior.toJson()), behavior);
      expect(
        behavior.copyWith(hideOnScroll: true),
        const HomeBarBehavior(hideOnScroll: true, indicatorFollowsSwipe: true),
      );
    });
  });
}
