import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_typography.dart';

void main() {
  group('DiaryTypography parsing', () {
    test('missing or corrupt raw settings fall back to the defaults', () {
      expect(DiaryTypography.fromRaw(null), const DiaryTypography());
      expect(DiaryTypography.fromRaw('  '), const DiaryTypography());
      expect(DiaryTypography.fromRaw('{not json'), const DiaryTypography());
      expect(DiaryTypography.fromRaw('[1, 2]'), const DiaryTypography());
    });

    test('round-trips every field through the raw json', () {
      final typography = const DiaryTypography().copyWith(
        fontId: 'fabc',
        fontSize: 21,
        lineHeight: 2.15,
        letterSpacing: 1.25,
        paragraphSpacing: 14,
      );

      expect(DiaryTypography.fromRaw(typography.toRaw()), typography);
    });

    test('keeps valid fields when other fields have the wrong type', () {
      final typography = DiaryTypography.fromRaw(
        '{"fontId":"system","fontSize":"20","lineHeight":true,'
        '"letterSpacing":null,"paragraphSpacing":12}',
      );

      expect(typography.fontId, DiaryTypography.systemFontId);
      expect(typography.fontSize, 20);
      expect(typography.lineHeight, DiaryTypography.defaultLineHeight);
      expect(typography.letterSpacing, DiaryTypography.defaultLetterSpacing);
      expect(typography.paragraphSpacing, 12);
    });

    test('clamps out-of-range values and snaps them to the slider step', () {
      final typography = DiaryTypography.fromRaw(
        '{"fontSize":99,"lineHeight":0.2,"letterSpacing":1.3,'
        '"paragraphSpacing":-5,"fontId":""}',
      );

      expect(typography.fontSize, DiaryTypography.maxFontSize);
      expect(typography.lineHeight, DiaryTypography.minLineHeight);
      expect(typography.letterSpacing, 1.25);
      expect(typography.paragraphSpacing, DiaryTypography.minParagraphSpacing);
      expect(typography.fontId, DiaryTypography.bundledFontId);
    });

    test('snapping removes floating point drift from repeated steps', () {
      var lineHeight = DiaryTypography.minLineHeight;
      for (var index = 0; index < 31; index += 1) {
        lineHeight += DiaryTypography.lineHeightStep;
      }

      expect(DiaryTypography.normalizeLineHeight(lineHeight), 2.55);
      expect(DiaryTypography.normalizeLineHeight(double.nan), 1.55);
    });
  });

  group('DiaryTypography legacy presets', () {
    test('maps the old three-level presets onto continuous values', () {
      final typography = DiaryTypography.fromLegacyPresets(
        fontSizePreset: 'large',
        lineHeightPreset: 'compact',
      );

      expect(typography.fontSize, 18);
      expect(typography.lineHeight, 1.35);
      expect(typography.fontId, DiaryTypography.bundledFontId);
    });

    test('unknown or missing presets keep the default values', () {
      expect(
        DiaryTypography.fromLegacyPresets(fontSizePreset: 'huge'),
        const DiaryTypography(),
      );
    });
  });

  test('resetting metrics keeps the chosen font', () {
    final typography = const DiaryTypography().copyWith(
      fontId: 'fabc',
      fontSize: 24,
    );

    expect(typography.hasDefaultMetrics, isFalse);
    expect(typography.withDefaultMetrics().fontId, 'fabc');
    expect(typography.withDefaultMetrics().hasDefaultMetrics, isTrue);
    expect(typography.usesImportedFont, isTrue);
    expect(const DiaryTypography().usesImportedFont, isFalse);
  });
}
