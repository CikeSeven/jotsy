import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/theme.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/diaries/models/diary_mood_palette.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_style.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_card_colors.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_preview_resolved_style.dart';

const Color _appSeed = Color(SettingsService.defaultThemeSeedColorValue);

DiaryPreviewResolvedStyle _resolve(
  DiaryPreviewPageStyle page, {
  Brightness brightness = Brightness.light,
  String? mood,
  int? tagColor,
  DiaryMoodPalette? palette,
}) {
  return DiaryPreviewResolvedStyle.resolve(
    style: DiaryPreviewStyle(page: page),
    appTheme: buildSeededAppTheme(_appSeed, brightness),
    appSeed: _appSeed,
    screenSize: const Size(400, 800),
    reduceMotion: false,
    moodPalette: palette ?? DiaryMoodPalette.defaults,
    moodEmoji: mood,
    firstTagColor: tagColor,
  );
}

double _hueGap(Color a, Color b) {
  final d = (HSVColor.fromColor(a).hue - HSVColor.fromColor(b).hue).abs() % 360;
  return math.min(d, 360 - d);
}

void main() {
  const moodSeed = DiaryPreviewPageStyle(colorSeed: DiaryPreviewColorSeed.mood);
  final moods = SettingsService.defaultMoodOptions;

  test('the default style is the app theme itself', () {
    for (final brightness in Brightness.values) {
      final appTheme = buildSeededAppTheme(_appSeed, brightness);
      final resolved = DiaryPreviewResolvedStyle.resolve(
        style: DiaryPreviewStyle.defaults,
        appTheme: appTheme,
        appSeed: _appSeed,
        screenSize: const Size(400, 800),
        reduceMotion: false,
        moodPalette: DiaryMoodPalette.defaults,
        moodEmoji: '😭',
      );
      expect(resolved.themed, isFalse);
      expect(identical(resolved.theme, appTheme), isTrue);
      expect(resolved.background, appTheme.colorScheme.surface);
    }
  });

  test('every mood gets its own page theme, happy moods included', () {
    final app = _resolve(const DiaryPreviewPageStyle());
    final primaries = <Color>[
      for (final mood in moods)
        _resolve(moodSeed, mood: mood).theme.colorScheme.primary,
    ];
    expect(primaries.toSet(), hasLength(moods.length));
    // 改版前 😐🙂😊😄😀🤩 都与“跟随应用”同色。
    for (final mood in <String>['🙂', '😊', '😄', '🤩']) {
      final resolved = _resolve(moodSeed, mood: mood);
      expect(resolved.themed, isTrue);
      expect(
        _hueGap(
          resolved.theme.colorScheme.primary,
          app.theme.colorScheme.primary,
        ),
        greaterThan(20),
        reason: mood,
      );
    }
  });

  test('custom mood colors change the page theme', () {
    final custom = DiaryMoodPalette(
      moodOptions: moods,
      colors: DiaryMoodColors.defaults.withColor(10, 0xFF2E7D32),
    );
    final before = _resolve(moodSeed, mood: '🤩');
    final after = _resolve(moodSeed, mood: '🤩', palette: custom);
    expect(
      after.theme.colorScheme.primary,
      isNot(before.theme.colorScheme.primary),
    );
    expect(
      _hueGap(after.theme.colorScheme.primary, const Color(0xFF2E7D32)),
      lessThan(20),
    );
  });

  test('vivid is more saturated than soft', () {
    double saturation(DiaryPreviewSeedIntensity intensity) {
      var total = 0.0;
      for (final mood in moods) {
        total += HSVColor.fromColor(
          _resolve(
            moodSeed.copyWith(seedIntensity: intensity),
            mood: mood,
          ).theme.colorScheme.primary,
        ).saturation;
      }
      return total;
    }

    expect(
      saturation(DiaryPreviewSeedIntensity.vivid),
      greaterThan(saturation(DiaryPreviewSeedIntensity.soft)),
    );
  });

  test('paper is tinted only on theme paper with a resolved color', () {
    final tinted = moodSeed.copyWith(tintPaper: true);
    final plain = _resolve(moodSeed, mood: '😊');
    final washed = _resolve(tinted, mood: '😊');
    expect(washed.background, isNot(plain.background));
    expect(washed.background, isNot(washed.theme.colorScheme.surface));
    expect(washed.paperFollowsTheme, isTrue);
    // 没心情：没有基调颜色可染。
    final noMood = _resolve(tinted);
    expect(noMood.background, noMood.theme.colorScheme.surface);
    // 选了纸色时以纸色为准。
    final warm = _resolve(
      tinted.copyWith(paper: DiaryPreviewPaper.warm),
      mood: '😊',
    );
    expect(
      warm.background,
      Color(DiaryPreviewResolvedStyle.paperColors[DiaryPreviewPaper.warm]!.$1),
    );
  });

  test('body text stays readable on every tinted paper', () {
    for (final brightness in Brightness.values) {
      for (final intensity in DiaryPreviewSeedIntensity.values) {
        for (final mood in moods) {
          final resolved = _resolve(
            moodSeed.copyWith(tintPaper: true, seedIntensity: intensity),
            brightness: brightness,
            mood: mood,
          );
          expect(
            DiaryCardColors.contrastOver(
              resolved.theme.colorScheme.onSurface,
              resolved.background,
            ),
            greaterThanOrEqualTo(7),
            reason: '$mood $intensity $brightness',
          );
        }
      }
    }
  });

  test('entries without a color follow the fallback', () {
    final app = _resolve(moodSeed);
    expect(app.themed, isFalse);

    final neutralMood = _resolve(
      moodSeed.copyWith(seedFallback: DiaryPreviewSeedFallback.neutral),
    );
    expect(neutralMood.themed, isTrue);
    expect(
      HSVColor.fromColor(neutralMood.theme.colorScheme.primary).saturation,
      lessThan(0.25),
    );

    const tagSeed = DiaryPreviewPageStyle(
      colorSeed: DiaryPreviewColorSeed.tag,
      seedFallback: DiaryPreviewSeedFallback.neutral,
    );
    expect(_resolve(tagSeed).themed, isTrue);
    // 取到颜色时不受回退影响。
    expect(
      _resolve(tagSeed, tagColor: 0xFFE53935).theme.colorScheme.primary,
      _resolve(
        tagSeed.copyWith(seedFallback: DiaryPreviewSeedFallback.app),
        tagColor: 0xFFE53935,
      ).theme.colorScheme.primary,
    );
    // 自定义基调没设颜色时不看回退，与改版前一样沿用应用主题。
    expect(
      _resolve(
        const DiaryPreviewPageStyle(
          colorSeed: DiaryPreviewColorSeed.custom,
          seedFallback: DiaryPreviewSeedFallback.neutral,
        ),
      ).themed,
      isFalse,
    );
  });
}
