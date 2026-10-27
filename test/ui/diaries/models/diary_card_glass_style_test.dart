import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style_code.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style_presets.dart';

/// 卡片玻璃材质（material / blurSigma）与放宽的不透明度下限：默认不变、
/// 往返、逐字段容错、稀疏编码与 v1 样式码的新旧兼容。
void main() {
  group('glass material fields', () {
    test('defaults stay solid and encode to nothing', () {
      const surface = DiaryCardSurfaceStyle();
      expect(surface.material, DiaryCardMaterial.solid);
      expect(surface.isGlass, isFalse);
      expect(surface.blurSigma, 16);
      expect(DiaryCardStyle.defaults.toJson(), isEmpty);
    });

    test('round-trip by name and encode sparsely', () {
      const style = DiaryCardStyle(
        surface: DiaryCardSurfaceStyle(
          material: DiaryCardMaterial.glass,
          blurSigma: 30,
        ),
      );
      expect(style.toJson(), <String, Object>{
        'surface': <String, Object>{'material': 'glass', 'blurSigma': 30.0},
      });
      expect(DiaryCardStyle.decode(style.encode()), style);

      // 只改模糊（仍是实色）时只写模糊一项。
      const blurOnly = DiaryCardStyle(
        surface: DiaryCardSurfaceStyle(blurSigma: 4),
      );
      expect(blurOnly.toJson(), <String, Object>{
        'surface': <String, Object>{'blurSigma': 4.0},
      });
    });

    test('bad values fall back alone and the blur is clamped', () {
      final unknown = DiaryCardStyle.fromJson(<String, Object>{
        'surface': <String, Object>{
          'material': 'crystal',
          'blurSigma': 'soft',
          'cornerRadius': 10,
        },
      });
      expect(unknown.surface.material, DiaryCardMaterial.solid);
      expect(unknown.surface.blurSigma, 16);
      expect(unknown.surface.cornerRadius, 10);

      final clamped = DiaryCardStyle.fromJson(<String, Object>{
        'surface': <String, Object>{
          'material': 'glass',
          'blurSigma': 400,
          'opacity': -1,
        },
      });
      expect(clamped.surface.isGlass, isTrue);
      expect(clamped.surface.blurSigma, DiaryCardStyleLimits.blurSigma.max);
      expect(clamped.surface.opacity, 0);
    });

    test('copyWith, equality and hash cover the new fields', () {
      const base = DiaryCardSurfaceStyle();
      final glass = base.copyWith(
        material: DiaryCardMaterial.glass,
        blurSigma: 12,
      );
      expect(glass, isNot(base));
      expect(glass.copyWith(), glass);
      expect(glass.copyWith().hashCode, glass.hashCode);
      expect(glass.copyWith(blurSigma: 13), isNot(glass));
      expect(
        glass.copyWith(material: DiaryCardMaterial.solid, blurSigma: 16),
        base,
      );
    });
  });

  group('opacity range', () {
    test('accepts values below the old 50% floor', () {
      expect(DiaryCardStyleLimits.opacity.min, 0);
      expect(DiaryCardStyleLimits.opacity.max, 1);
      final decoded = DiaryCardStyle.fromJson(<String, Object>{
        'surface': <String, Object>{'opacity': 0.2},
      });
      expect(decoded.surface.opacity, 0.2);
      // 旧范围内的已有数据原样读出。
      final old = DiaryCardStyle.fromJson(<String, Object>{
        'surface': <String, Object>{'opacity': 0.5},
      });
      expect(old.surface.opacity, 0.5);
    });
  });

  group('style code v1 compatibility', () {
    test('glass codes stay on v1 and round-trip', () {
      final glass = DiaryCardPresets.styleOf(DiaryCardPresetId.glass);
      final code = DiaryCardStyleCode.encode(glass);
      expect(code, startsWith('jotsy-card:v1:'));
      final decoded = DiaryCardStyleCode.decode(code);
      expect(decoded.status, StyleCodeStatus.ok);
      expect(decoded.style, glass);
    });

    test('codes from before the glass fields import as solid', () {
      // 手写一份加入玻璃字段之前的 v1 样式码（没有 material / blurSigma）。
      final payload = base64Url
          .encode(
            utf8.encode(
              jsonEncode(<String, Object>{
                'v': 1,
                's': <String, Object>{
                  'surface': <String, Object>{
                    'cornerRadius': 12.0,
                    'opacity': 0.8,
                  },
                },
              }),
            ),
          )
          .replaceAll('=', '');
      final decoded = DiaryCardStyleCode.decode('jotsy-card:v1:$payload');
      expect(decoded.status, StyleCodeStatus.ok);
      final style = decoded.style!;
      expect(style.surface.cornerRadius, 12);
      expect(style.surface.opacity, 0.8);
      expect(style.surface.material, DiaryCardMaterial.solid);
      expect(style.surface.blurSigma, 16);
    });
  });

  group('glass preset', () {
    test('is a translucent glass card on the themed surface', () {
      final style = DiaryCardPresets.styleOf(DiaryCardPresetId.glass);
      final surface = style.surface;
      expect(surface.isGlass, isTrue);
      expect(surface.opacity, 0.55);
      expect(surface.blurSigma, 18);
      expect(surface.background.isThemed, isTrue);
      expect(surface.borderWidth, greaterThan(0));
      expect(surface.borderColor.source, DiaryCardColorSource.custom);
      expect(surface.shadow, DiaryCardShadowStyle.soft);
      expect(DiaryCardPresets.match(style), DiaryCardPresetId.glass);
      // 内容与布局沿用默认。
      expect(style.list, DiaryCardStyle.defaults.list);
      expect(style.waterfall, DiaryCardStyle.defaults.waterfall);
    });
  });
}
