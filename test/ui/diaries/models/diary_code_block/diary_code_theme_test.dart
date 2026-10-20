import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_theme.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_card_colors.dart';

double _ratio(Color a, Color b) => DiaryCardColors.contrastRatio(a, b);

void _expectReadable(DiaryCodePalette palette, String label) {
  final bg = palette.background;
  expect(
    palette.tokens.keys.toSet(),
    DiaryCodeTokenRole.values.toSet(),
    reason: label,
  );
  expect(palette.header, isNot(palette.background), reason: label);
  expect(
    _ratio(palette.foreground, bg),
    greaterThanOrEqualTo(4.5),
    reason: '$label foreground',
  );
  expect(
    _ratio(palette.foreground, palette.header),
    greaterThanOrEqualTo(4.5),
    reason: '$label foreground on header',
  );
  expect(
    _ratio(palette.lineNumber, bg),
    greaterThanOrEqualTo(3.0),
    reason: '$label line number',
  );
  expect(
    _ratio(palette.inlineForeground, palette.inlineBackground),
    greaterThanOrEqualTo(4.5),
    reason: '$label inline',
  );
  for (final role in DiaryCodeTokenRole.values) {
    final min = role == DiaryCodeTokenRole.comment ? 3.0 : 4.5;
    expect(
      _ratio(palette.tokens[role]!, bg),
      greaterThanOrEqualTo(min),
      reason: '$label ${role.name}',
    );
  }
  expect(palette.commentItalic, isTrue, reason: label);
  expect(
    palette.tokenStyle(DiaryCodeTokenRole.comment).fontStyle,
    FontStyle.italic,
  );
  expect(palette.tokenStyle(DiaryCodeTokenRole.keyword).fontStyle, isNull);
  expect(
    palette.tokenStyle(DiaryCodeTokenRole.string).color,
    palette.tokens[DiaryCodeTokenRole.string],
  );
}

void main() {
  group('DiaryCodeThemes.palette', () {
    const seeds = <Color>[
      Color(0xFF6750A4),
      Color(0xFF00897B),
      Color(0xFFFFC107),
    ];

    for (final id in DiaryCodeThemeId.values) {
      for (final brightness in Brightness.values) {
        test('${id.name} ${brightness.name} meets contrast thresholds', () {
          final seedList = id == DiaryCodeThemeId.app ? seeds : seeds.take(1);
          for (final seed in seedList) {
            final scheme = ColorScheme.fromSeed(
              seedColor: seed,
              brightness: brightness,
            );
            final palette = DiaryCodeThemes.palette(id, brightness, scheme);
            expect(palette.brightness, brightness);
            _expectReadable(palette, '${id.name}/${brightness.name}/$seed');
          }
        });
      }
    }

    test('curated themes keep their official background', () {
      final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4));
      expect(
        DiaryCodeThemes.palette(
          DiaryCodeThemeId.dracula,
          Brightness.dark,
          scheme,
        ).background,
        const Color(0xFF282A36),
      );
      expect(
        DiaryCodeThemes.palette(
          DiaryCodeThemeId.solarized,
          Brightness.light,
          scheme,
        ).background,
        const Color(0xFFFDF6E3),
      );
    });

    test('app theme follows the scheme surfaces', () {
      final light = ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4));
      final palette = DiaryCodeThemes.palette(
        DiaryCodeThemeId.app,
        Brightness.light,
        light,
      );
      expect(palette.background, light.surfaceContainer);
      expect(palette.header, light.surfaceContainerHigh);
      expect(palette.border, light.outlineVariant);
      expect(palette.inlineBackground, light.surfaceContainerHighest);

      final dark = ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
        brightness: Brightness.dark,
      );
      final darkPalette = DiaryCodeThemes.palette(
        DiaryCodeThemeId.app,
        Brightness.dark,
        dark,
      );
      expect(darkPalette.background, dark.surfaceContainerHigh);
      expect(darkPalette.header, dark.surfaceContainerHighest);
    });

    test('app theme with a mismatched scheme still yields a dark palette', () {
      final light = ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4));
      final palette = DiaryCodeThemes.palette(
        DiaryCodeThemeId.app,
        Brightness.dark,
        light,
      );
      expect(palette.background.computeLuminance(), lessThan(0.1));
      _expectReadable(palette, 'app/dark from light scheme');
    });

    test('palettes are cached per theme and brightness', () {
      final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4));
      final first = DiaryCodeThemes.palette(
        DiaryCodeThemeId.nord,
        Brightness.light,
        scheme,
      );
      final second = DiaryCodeThemes.palette(
        DiaryCodeThemeId.nord,
        Brightness.light,
        scheme,
      );
      expect(identical(first, second), isTrue);
      final other = ColorScheme.fromSeed(seedColor: const Color(0xFF00897B));
      expect(
        DiaryCodeThemes.palette(
          DiaryCodeThemeId.app,
          Brightness.light,
          scheme,
        ).tokens[DiaryCodeTokenRole.keyword],
        isNot(
          DiaryCodeThemes.palette(
            DiaryCodeThemeId.app,
            Brightness.light,
            other,
          ).tokens[DiaryCodeTokenRole.keyword],
        ),
      );
    });
  });

  group('ensureContrast', () {
    test('keeps colors that already pass', () {
      const fg = Color(0xFF1F2328);
      expect(ensureContrast(fg, const Color(0xFFFFFFFF), 4.5), fg);
    });

    test('darkens on light backgrounds and keeps the hue', () {
      const fg = Color(0xFF88C0D0);
      const bg = Color(0xFFECEFF4);
      final fixed = ensureContrast(fg, bg, 4.5);
      expect(_ratio(fixed, bg), greaterThanOrEqualTo(4.5));
      expect(fixed.computeLuminance(), lessThan(fg.computeLuminance()));
      expect(
        HSLColor.fromColor(fixed).hue,
        closeTo(HSLColor.fromColor(fg).hue, 2),
      );
    });

    test('lightens on dark backgrounds', () {
      const fg = Color(0xFF5C6370);
      const bg = Color(0xFF282C34);
      final fixed = ensureContrast(fg, bg, 4.5);
      expect(_ratio(fixed, bg), greaterThanOrEqualTo(4.5));
      expect(fixed.computeLuminance(), greaterThan(fg.computeLuminance()));
    });

    test('falls back to the strongest extreme when unreachable', () {
      const bg = Color(0xFF777777);
      final fixed = ensureContrast(const Color(0xFF7A7A7A), bg, 10);
      expect(_ratio(fixed, bg), greaterThan(4));
    });
  });

  group('diaryCodeTokenRoleFor', () {
    test('maps highlight.js class names to roles', () {
      const expected = <String, DiaryCodeTokenRole?>{
        'keyword': DiaryCodeTokenRole.keyword,
        'selector-tag': DiaryCodeTokenRole.keyword,
        'doctag': DiaryCodeTokenRole.keyword,
        'built_in': DiaryCodeTokenRole.type,
        'type': DiaryCodeTokenRole.type,
        'title class_': DiaryCodeTokenRole.type,
        'title.class_': DiaryCodeTokenRole.type,
        'title': DiaryCodeTokenRole.function,
        'title.function': DiaryCodeTokenRole.function,
        'section': DiaryCodeTokenRole.function,
        'string': DiaryCodeTokenRole.string,
        'regexp': DiaryCodeTokenRole.string,
        'char.escape': DiaryCodeTokenRole.string,
        'number': DiaryCodeTokenRole.number,
        'literal': DiaryCodeTokenRole.literal,
        'symbol': DiaryCodeTokenRole.literal,
        'bullet': DiaryCodeTokenRole.literal,
        'link': DiaryCodeTokenRole.literal,
        'comment': DiaryCodeTokenRole.comment,
        'quote': DiaryCodeTokenRole.comment,
        'attr': DiaryCodeTokenRole.variable,
        'params': DiaryCodeTokenRole.variable,
        'template-variable': DiaryCodeTokenRole.variable,
        'meta': DiaryCodeTokenRole.meta,
        'meta-keyword': DiaryCodeTokenRole.meta,
        'meta-string': DiaryCodeTokenRole.meta,
        'meta.prompt': DiaryCodeTokenRole.meta,
        'tag': DiaryCodeTokenRole.tag,
        'name': DiaryCodeTokenRole.tag,
        'selector-class': DiaryCodeTokenRole.tag,
        'addition': DiaryCodeTokenRole.addition,
        'deletion': DiaryCodeTokenRole.deletion,
        'subst': null,
        'emphasis': null,
        'strong': null,
        '': null,
        'javascript': null,
      };
      expected.forEach((className, role) {
        expect(diaryCodeTokenRoleFor(className), role, reason: className);
      });
    });
  });
}
