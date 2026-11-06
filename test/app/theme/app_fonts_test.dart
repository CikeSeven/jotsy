import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/app_fonts.dart';
import 'package:node_diary/app/theme/seeded_theme_cache.dart';
import 'package:node_diary/app/theme/theme.dart';

const Color _seed = Color(0xff1e6586);

/// 字阶里每个样式的字族名。
List<String?> _families(TextTheme text) => <TextStyle?>[
  text.displayLarge,
  text.headlineSmall,
  text.titleLarge,
  text.titleMedium,
  text.bodyLarge,
  text.bodyMedium,
  text.bodySmall,
  text.labelLarge,
  text.labelSmall,
].map((style) => style?.fontFamily).toList();

void main() {
  group('buildSeededAppTheme fonts', () {
    for (final brightness in Brightness.values) {
      test(
        'the default theme keeps the bundled font in ${brightness.name}',
        () {
          final theme = buildSeededAppTheme(_seed, brightness);

          expect(
            _families(theme.textTheme),
            everyElement(kAppBundledFontFamily),
          );
          expect(AppFonts.of(theme), const AppFonts());
        },
      );

      test('a diary-only font leaves the interface text theme untouched in '
          '${brightness.name}', () {
        final plain = buildSeededAppTheme(_seed, brightness);
        final theme = buildSeededAppTheme(
          _seed,
          brightness,
          fonts: const AppFonts(diary: 'sans-serif'),
        );

        expect(theme.textTheme, plain.textTheme);
        expect(theme.primaryTextTheme, plain.primaryTextTheme);
        expect(AppFonts.of(theme).diary, 'sans-serif');
      });

      test('the whole-app font replaces every text style in '
          '${brightness.name}', () {
        const fonts = AppFonts(interface: 'sans-serif', diary: 'sans-serif');
        final plain = buildSeededAppTheme(_seed, brightness);
        final theme = buildSeededAppTheme(_seed, brightness, fonts: fonts);

        expect(_families(theme.textTheme), everyElement('sans-serif'));
        expect(_families(theme.primaryTextTheme), everyElement('sans-serif'));
        // 只换字族：字号、字重与行高不变。
        expect(
          theme.textTheme.titleLarge,
          plain.textTheme.titleLarge?.copyWith(fontFamily: 'sans-serif'),
        );
        expect(AppFonts.of(theme), fonts);
      });
    }

    test('a theme without the extension reads as the bundled fonts', () {
      expect(AppFonts.of(ThemeData()), const AppFonts());
    });
  });

  group('SeededThemeCache fonts', () {
    test('reuses one instance per font choice', () {
      const fonts = AppFonts(interface: 'JotsyDiaryFont_a');
      final plain = SeededThemeCache.of(
        _seed,
        Brightness.dark,
        reduceMotion: false,
      );
      final themed = SeededThemeCache.of(
        _seed,
        Brightness.dark,
        reduceMotion: false,
        fonts: fonts,
      );

      expect(identical(plain, themed), isFalse);
      expect(
        identical(
          themed,
          SeededThemeCache.of(
            _seed,
            Brightness.dark,
            reduceMotion: false,
            fonts: const AppFonts(interface: 'JotsyDiaryFont_a'),
          ),
        ),
        isTrue,
      );
      expect(themed.textTheme.bodyMedium?.fontFamily, 'JotsyDiaryFont_a');
      expect(plain.textTheme.bodyMedium?.fontFamily, kAppBundledFontFamily);
    });
  });

  test('theme transitions switch fonts half way instead of blending', () {
    const from = AppFonts();
    const to = AppFonts(interface: 'sans-serif', diary: 'sans-serif');

    expect(from.lerp(to, 0.4), from);
    expect(from.lerp(to, 0.5), to);
    expect(from.lerp(null, 0.8), from);
  });
}
