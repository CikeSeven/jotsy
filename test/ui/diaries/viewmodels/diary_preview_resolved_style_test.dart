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

  test('the veil tint is the tinted paper color, only when it applies', () {
    final on = moodSeed.copyWith(tintScrim: true);
    final tinted = _resolve(on, mood: '😊');
    expect(
      tinted.scrimTint,
      DiaryPreviewResolvedStyle.tintedPaper(tinted.theme.colorScheme),
    );
    // 遮罩染色不改纸张本身（那是“纸张随基调染色”的事）。
    expect(tinted.background, tinted.theme.colorScheme.surface);
    // 没开、没心情、选了纸色：遮罩保持中性。
    expect(_resolve(moodSeed, mood: '😊').scrimTint, isNull);
    expect(_resolve(on).scrimTint, isNull);
    expect(
      _resolve(
        on.copyWith(paper: DiaryPreviewPaper.warm),
        mood: '😊',
      ).scrimTint,
      isNull,
    );
    // 换宽度重算版式时保留。
    expect(tinted.atWidth(900).scrimTint, tinted.scrimTint);
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

  test('the title divider is a faint copy of the text color on any paper', () {
    for (final brightness in Brightness.values) {
      for (final page in <DiaryPreviewPageStyle>[
        const DiaryPreviewPageStyle(),
        const DiaryPreviewPageStyle(paper: DiaryPreviewPaper.sepia),
        // 墨色纸在浅色应用里换成深色主题，线跟着换成浅色的淡线。
        const DiaryPreviewPageStyle(paper: DiaryPreviewPaper.ink),
        const DiaryPreviewPageStyle(
          paper: DiaryPreviewPaper.custom,
          paperLight: 0xFFCDBFA8,
        ),
        moodSeed.copyWith(tintPaper: true),
      ]) {
        final resolved = _resolve(page, brightness: brightness, mood: '😊');
        final line = resolved.titleDividerColor;
        final ink = resolved.theme.colorScheme.onSurface;
        // 按页面本身的明暗取不透明度（墨色纸在浅色应用里是深色页）。
        final opacity = resolved.theme.brightness == Brightness.light
            ? DiaryPreviewResolvedStyle.titleDividerOpacityLight
            : DiaryPreviewResolvedStyle.titleDividerOpacityDark;
        expect(line, ink.withValues(alpha: opacity));
        // 叠到纸上：看得见，但远比正文淡。
        final onPaper = Color.alphaBlend(line, resolved.background);
        final contrast = DiaryCardColors.contrastOver(
          onPaper,
          resolved.background,
        );
        expect(contrast, greaterThan(1.25), reason: '$brightness $page');
        expect(contrast, lessThan(2.2), reason: '$brightness $page');
      }
    }
  });

  test('the title divider follows a custom text color', () {
    final resolved = _resolve(
      const DiaryPreviewPageStyle(
        paper: DiaryPreviewPaper.sepia,
        textLight: 0xFF4A3420,
      ),
    );
    expect(resolved.bodyColor, const Color(0xFF4A3420));
    expect(
      resolved.titleDividerColor,
      const Color(
        0xFF4A3420,
      ).withValues(alpha: DiaryPreviewResolvedStyle.titleDividerOpacityLight),
    );
  });
}
