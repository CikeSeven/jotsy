import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/diaries/models/diary_mood_palette.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_card_colors.dart';

/// 两个色相（度）在色环上的距离。
double _hueGap(double a, double b) {
  final d = (a - b).abs() % 360;
  return math.min(d, 360 - d);
}

void main() {
  group('DiaryMoodColors', () {
    test('missing, broken or non-object settings fall back to defaults', () {
      for (final raw in <String?>[null, '', '  ', 'not json', '[1, 2]', '3']) {
        expect(DiaryMoodColors.decode(raw), DiaryMoodColors.defaults);
      }
      expect(DiaryMoodColors.defaults.isDefault, isTrue);
      expect(DiaryMoodColors.defaults.encode(), isNull);
    });

    test('only the broken slots reset, the rest are kept', () {
      final colors = DiaryMoodColors.decode(
        jsonEncode(<String, Object?>{
          '1': '#123456',
          '2': 'teal',
          '0': '#FFFFFF',
          '11': '#FFFFFF',
          'x': '#FFFFFF',
          '10': 0x80ABCDEF,
        }),
      );
      expect(colors.colorOf(1), 0xFF123456);
      expect(colors.colorOf(2), kDiaryMoodDefaultColors[1]);
      // 不透明：透明度被丢掉。
      expect(colors.colorOf(10), 0xFFABCDEF);
      for (var slot = 3; slot <= 9; slot += 1) {
        expect(colors.colorOf(slot), kDiaryMoodDefaultColors[slot - 1]);
      }
    });

    test('encoding is sparse and round trips', () {
      final colors = DiaryMoodColors.defaults
          .withColor(3, 0xFF00FF00)
          .withColor(7, 0x22FF0000);
      final raw = colors.encode();
      expect(jsonDecode(raw!), <String, Object>{
        '3': '#00FF00',
        '7': '#FF0000',
      });
      expect(DiaryMoodColors.decode(raw), colors);
      expect(colors.isDefault, isFalse);
      // 改回内置色后整份等于默认，删除设置键。
      expect(
        colors
            .withColor(3, kDiaryMoodDefaultColors[2])
            .withColor(7, kDiaryMoodDefaultColors[6])
            .encode(),
        isNull,
      );
    });
  });

  group('DiaryMoodPalette', () {
    test('default emojis stay recognized after the user renames slots', () {
      final options = List<String>.of(SettingsService.defaultMoodOptions);
      options[0] = '🌧';
      final palette = DiaryMoodPalette(
        moodOptions: options,
        colors: DiaryMoodColors.defaults.withColor(1, 0xFF000080),
      );
      expect(palette.slotOf('🌧'), 1);
      // 换符号之前写的日记仍按默认符号对上同一格。
      expect(palette.slotOf(SettingsService.defaultMoodOptions[0]), 1);
      expect(palette.slotOf(' 🤩 '), 10);
      expect(palette.slotOf(null), isNull);
      expect(palette.slotOf(''), isNull);
      expect(palette.slotOf('🦄'), isNull);
      expect(palette.seedOf('🌧'), const Color(0xFF000080));
      expect(palette.seedOf('🦄'), isNull);
      expect(palette.accentOf('🦄', Brightness.light), isNull);
    });

    test('palettes compare by emojis and colors', () {
      expect(
        DiaryMoodPalette(moodOptions: SettingsService.defaultMoodOptions),
        DiaryMoodPalette.defaults,
      );
      expect(
        DiaryMoodPalette(
          moodOptions: SettingsService.defaultMoodOptions,
          colors: DiaryMoodColors.defaults.withColor(5, 0xFF000000),
        ),
        isNot(DiaryMoodPalette.defaults),
      );
    });

    test('the ten default moods give ten clearly different page themes', () {
      // 预览页的整页主题由 tonalSpot 生成，它只取种子色的色相：相邻两档
      // 生成的主色色相必须拉得开，否则就会像改版前那样几档长得一样。
      final hues = <double>[
        for (final seed in kDiaryMoodDefaultColors)
          HSVColor.fromColor(
            ColorScheme.fromSeed(seedColor: Color(seed)).primary,
          ).hue,
      ];
      for (var i = 0; i < hues.length; i += 1) {
        for (var j = i + 1; j < hues.length; j += 1) {
          expect(
            _hueGap(hues[i], hues[j]),
            greaterThanOrEqualTo(12),
            reason: 'mood ${i + 1} vs ${j + 1}',
          );
        }
      }
    });

    test('accents stay readable on both light and dark surfaces', () {
      final palette = DiaryMoodPalette.defaults;
      for (final brightness in Brightness.values) {
        final surface = ColorScheme.fromSeed(
          seedColor: const Color(SettingsService.defaultThemeSeedColorValue),
          brightness: brightness,
        ).surface;
        for (var slot = 1; slot <= 10; slot += 1) {
          final accent = palette.accentForSlot(slot, brightness);
          expect(
            DiaryCardColors.contrastOver(accent, surface),
            greaterThanOrEqualTo(3),
            reason: 'slot $slot in $brightness',
          );
          // 同一实例里记着换算结果。
          expect(
            identical(palette.accentForSlot(slot, brightness), accent),
            isTrue,
          );
        }
      }
    });

    test('a grayish custom color keeps its low saturation', () {
      // fidelity 保留原色的浓淡：用户挑的灰色不会被补成鲜艳的颜色。
      final gray = HSVColor.fromColor(
        DiaryMoodPalette.accentFor(const Color(0xFF7A7F85), Brightness.light),
      );
      final vivid = HSVColor.fromColor(
        DiaryMoodPalette.accentFor(const Color(0xFFE8654A), Brightness.light),
      );
      expect(gray.saturation, lessThan(vivid.saturation));
      expect(gray.saturation, lessThan(0.3));
    });
  });
}
