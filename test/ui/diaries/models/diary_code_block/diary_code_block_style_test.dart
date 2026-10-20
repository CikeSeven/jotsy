import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';

void main() {
  group('DiaryCodeBlockStyle', () {
    test('defaults match the documented spec', () {
      const style = DiaryCodeBlockStyle.defaults;
      expect(style.theme, DiaryCodeThemeId.app);
      expect(style.brightness, DiaryCodeBrightness.system);
      expect(style.lineNumbers, isTrue);
      expect(style.header, isTrue);
      expect(style.autoDetect, isTrue);
      expect(style.border, isFalse);
      expect(style.fontId, kDiaryCodeFontMono);
      expect(style.fontScale, 0.9);
      expect(style.lineHeight, 1.5);
      expect(style.radius, 12);
      expect(style.isDefault, isTrue);
      expect(style.usesImportedFont, isFalse);
    });

    test('encodes to null when equal to the defaults', () {
      expect(DiaryCodeBlockStyle.defaults.encode(), isNull);
      expect(DiaryCodeBlockStyle.decode(null), DiaryCodeBlockStyle.defaults);
      expect(DiaryCodeBlockStyle.decode('  '), DiaryCodeBlockStyle.defaults);
    });

    test('round-trips every field through encode and decode', () {
      final style = DiaryCodeBlockStyle.defaults.copyWith(
        theme: DiaryCodeThemeId.tokyoNight,
        brightness: DiaryCodeBrightness.dark,
        lineNumbers: false,
        header: false,
        autoDetect: false,
        border: true,
        fontId: kDiaryCodeFontBody,
        fontScale: 1.1,
        lineHeight: 1.8,
        radius: 4,
      );
      final raw = style.encode();
      expect(raw, isNotNull);
      expect(jsonDecode(raw!)['theme'], 'tokyo_night');
      expect(DiaryCodeBlockStyle.decode(raw), style);
      expect(DiaryCodeBlockStyle.decode(raw).isDefault, isFalse);
    });

    test('wrong field types fall back per field', () {
      final style = DiaryCodeBlockStyle.decode(
        jsonEncode(<String, Object?>{
          'theme': 7,
          'brightness': 'dim',
          'lineNumbers': 'false',
          'header': 0,
          'autoDetect': null,
          'border': true,
          'fontId': 12,
          'fontScale': '1.2',
          'lineHeight': <int>[],
          'radius': 'wide',
        }),
      );
      expect(
        style,
        DiaryCodeBlockStyle.defaults.copyWith(border: true, fontScale: 1.2),
      );
    });

    test('clamps out-of-range numbers and snaps them to the step', () {
      final style = DiaryCodeBlockStyle.fromJson(<String, Object?>{
        'fontScale': 9,
        'lineHeight': 1.23,
        'radius': -5,
      });
      expect(style.fontScale, DiaryCodeBlockStyle.maxFontScale);
      expect(style.lineHeight, 1.25);
      expect(style.radius, DiaryCodeBlockStyle.minRadius);

      final snapped = DiaryCodeBlockStyle.defaults.copyWith(
        fontScale: 0.71,
        radius: 7,
        lineHeight: double.nan,
      );
      expect(snapped.fontScale, 0.7);
      expect(snapped.radius, 8);
      expect(snapped.lineHeight, DiaryCodeBlockStyle.defaultLineHeight);
    });

    test('unknown theme ids fall back to the app theme', () {
      expect(
        DiaryCodeThemeId.fromStorageId('solarized-ish'),
        DiaryCodeThemeId.app,
      );
      expect(DiaryCodeThemeId.fromStorageId(null), DiaryCodeThemeId.app);
      expect(
        DiaryCodeThemeId.fromStorageId('rose_pine'),
        DiaryCodeThemeId.rosePine,
      );
      expect(
        DiaryCodeBlockStyle.decode('{"theme":"monokai","border":true}').theme,
        DiaryCodeThemeId.app,
      );
      expect(DiaryCodeThemeId.app.displayName, isNull);
      expect(DiaryCodeThemeId.rosePine.displayName, 'Rosé Pine');
    });

    test('keeps an imported font id and blanks fall back to mono', () {
      const fontId = 'font_1729400000000';
      final style = DiaryCodeBlockStyle.decode('{"fontId":"$fontId"}');
      expect(style.fontId, fontId);
      expect(style.usesImportedFont, isTrue);
      expect(DiaryCodeBlockStyle.decode(style.encode()), style);

      expect(
        DiaryCodeBlockStyle.defaults.copyWith(fontId: '   ').fontId,
        kDiaryCodeFontMono,
      );
    });

    test('broken json falls back to the defaults', () {
      for (final raw in ['{not json', '[1,2]', '"text"', '42']) {
        expect(
          DiaryCodeBlockStyle.decode(raw),
          DiaryCodeBlockStyle.defaults,
          reason: raw,
        );
      }
    });
  });
}
