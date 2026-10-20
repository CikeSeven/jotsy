import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_presets.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style_code.dart';

const _border = HomeBarLineStyle.borderDefaults;
const _top = HomeBarLineStyle.topBarDefaults;

void main() {
  group('HomeBarLineStyle', () {
    test('the two lines have their own defaults', () {
      expect(_border.color, HomeBarLineColor.theme);
      expect(_border.opacity, 0.6);
      expect(_border.width, 1.0);
      expect(_top.color, HomeBarLineColor.theme);
      expect(_top.opacity, 0.35);
      expect(_top.width, 0.6);
      expect(HomeBarStyle.defaults.borderLine, _border);
      expect(HomeBarStyle.defaults.topBarLine, _top);
    });

    test('returns the fallback for non-map input', () {
      for (final raw in <Object?>[null, 'x', 3, <Object>[], true]) {
        expect(HomeBarLineStyle.fromJson(raw, fallback: _top), _top);
      }
    });

    test('decodes each field independently and clamps numbers', () {
      final line = HomeBarLineStyle.fromJson(<String, Object?>{
        'color': 'custom',
        'customColor': '#336699',
        'customColorDark': 'nope',
        'opacity': 7,
        'width': 'thick',
      }, fallback: _border);
      expect(line.color, HomeBarLineColor.custom);
      expect(line.customColor, 0xFF336699);
      expect(line.customColorDark, isNull);
      expect(line.opacity, HomeBarStyleLimits.lineOpacity.max);
      expect(line.width, _border.width);

      final low = HomeBarLineStyle.fromJson(<String, Object?>{
        'opacity': 0,
        'width': 0.1,
      }, fallback: _border);
      expect(low.opacity, HomeBarStyleLimits.lineOpacity.min);
      expect(low.width, HomeBarStyleLimits.lineWidth.min);

      final high = HomeBarLineStyle.fromJson(<String, Object?>{
        'width': 9,
        'opacity': double.nan,
      }, fallback: _top);
      expect(high.width, HomeBarStyleLimits.lineWidth.max);
      expect(high.opacity, _top.opacity);
    });

    test('unknown color names fall back to the default source', () {
      final line = HomeBarLineStyle.fromJson(<String, Object?>{
        'color': 'rainbow',
      }, fallback: _border);
      expect(line, _border);
      expect(
        HomeBarLineStyle.fromJson(<String, Object?>{
          'color': 3,
        }, fallback: _top).color,
        HomeBarLineColor.theme,
      );
    });

    test('custom colors are forced opaque', () {
      final line = HomeBarLineStyle.fromJson(<String, Object?>{
        'customColor': 0x80112233,
        'customColorDark': '#40445566',
      }, fallback: _border);
      expect(line.customColor, 0xFF112233);
      expect(line.customColorDark, 0xFF445566);
    });

    test('encodes sparsely relative to its own defaults', () {
      expect(_border.toJson(_border), isEmpty);
      expect(_top.toJson(_top), isEmpty);
      // 底栏描边的默认值放到顶栏分隔线上就是“改过”的。
      expect(_border.toJson(_top), <String, Object>{
        'opacity': 0.6,
        'width': 1.0,
      });
      final line = _border.copyWith(
        color: HomeBarLineColor.custom,
        customColor: () => 0xFF0A0B0C,
        width: 2.5,
      );
      expect(line.toJson(_border), <String, Object>{
        'color': 'custom',
        'customColor': '#0A0B0C',
        'width': 2.5,
      });
      expect(
        HomeBarLineStyle.fromJson(line.toJson(_border), fallback: _border),
        line,
      );
    });

    test('copyWith keeps or clears custom colors and compares by value', () {
      const line = HomeBarLineStyle(
        color: HomeBarLineColor.custom,
        customColor: 0xFF123456,
        customColorDark: 0xFF010203,
        opacity: 0.5,
        width: 2,
      );
      expect(line.copyWith(), line);
      expect(line.copyWith().hashCode, line.hashCode);
      expect(line.copyWith(customColor: () => null).customColor, isNull);
      expect(
        line.copyWith(customColorDark: () => null).customColor,
        0xFF123456,
      );
      expect(line.copyWith(opacity: 0.55), isNot(line));
    });
  });

  group('HomeBarStyle with lines', () {
    const style = HomeBarStyle(
      material: HomeBarMaterial.glass,
      topBarHairline: true,
      borderLine: HomeBarLineStyle(
        color: HomeBarLineColor.custom,
        customColor: 0xFF224466,
        customColorDark: 0xFF8899AA,
        opacity: 0.8,
        width: 2.2,
      ),
      topBarLine: HomeBarLineStyle(
        color: HomeBarLineColor.primary,
        opacity: 0.35,
        width: 1.5,
      ),
    );

    test('writes nested line objects only when changed', () {
      expect(const HomeBarStyle(border: false).toJson(), <String, Object>{
        'border': false,
      });
      expect(style.toJson(), <String, Object>{
        'material': 'glass',
        'borderLine': <String, Object>{
          'color': 'custom',
          'customColor': '#224466',
          'customColorDark': '#8899AA',
          'opacity': 0.8,
          'width': 2.2,
        },
        'topBarHairline': true,
        'topBarLine': <String, Object>{'color': 'primary', 'width': 1.5},
      });
    });

    test('round-trips both lines through JSON text', () {
      final decoded = HomeBarStyle.fromJson(
        jsonDecode(jsonEncode(style.toJson())),
      );
      expect(decoded, style);
      expect(decoded.hashCode, style.hashCode);
      expect(decoded, isNot(style.copyWith(topBarLine: _top)));
    });

    test('a bad line object only resets that line', () {
      final decoded = HomeBarStyle.fromJson(<String, Object?>{
        'material': 'glass',
        'borderLine': 'oops',
        'topBarLine': <String, Object?>{'width': 2},
      });
      expect(decoded.material, HomeBarMaterial.glass);
      expect(decoded.borderLine, _border);
      expect(decoded.topBarLine, _top.copyWith(width: 2));
    });

    test('round-trips both lines through a style code', () {
      final code = HomeBarStyleCode.encode(style, name: 'Lines');
      final result = HomeBarStyleCode.decode(code);
      expect(result.status, StyleCodeStatus.ok);
      expect(result.style, style);
    });
  });

  group('presets', () {
    test('clear shows a highlight rim; the others keep the default lines', () {
      final clear = HomeBarPreset.clear.style;
      expect(clear.borderLine.color, HomeBarLineColor.highlight);
      expect(clear.borderLine.opacity, 0.7);
      expect(clear.borderLine.width, 1.0);
      expect(clear.topBarLine, _top);
      for (final preset in HomeBarPreset.values) {
        expect(HomeBarPreset.matching(preset.style), preset);
        if (preset != HomeBarPreset.clear) {
          expect(preset.style.borderLine, _border, reason: preset.name);
          expect(preset.style.topBarLine, _top, reason: preset.name);
        }
      }
      // 改动一条线就不再是这个预设。
      expect(
        HomeBarPreset.matching(
          clear.copyWith(borderLine: clear.borderLine.copyWith(width: 1.1)),
        ),
        isNull,
      );
    });
  });
}
