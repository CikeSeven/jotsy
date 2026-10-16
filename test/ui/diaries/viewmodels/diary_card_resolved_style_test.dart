import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/expressive_surfaces.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_card_resolved_style.dart';

import '../../../support/expressive_test_theme.dart';

DiaryCardResolvedStyle _resolve(
  DiaryCardStyle style,
  DiaryCardMode mode, {
  Brightness brightness = Brightness.light,
  double width = 360,
  double textScale = 1,
}) {
  return DiaryCardResolvedStyle.resolve(
    style: style,
    mode: mode,
    theme: expressiveTestTheme(brightness),
    screenWidth: width,
    textScale: textScale,
  );
}

void main() {
  group('default style reproduces the pre-customization card', () {
    for (final brightness in Brightness.values) {
      test('list text styles and geometry in $brightness', () {
        final theme = expressiveTestTheme(brightness);
        final resolved = DiaryCardResolvedStyle.resolve(
          style: DiaryCardStyle.defaults,
          mode: DiaryCardMode.list,
          theme: theme,
          screenWidth: 320,
        );
        final text = theme.textTheme;
        expect(
          resolved.eyebrowStyle,
          text.labelMedium?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.15,
          ),
        );
        expect(
          resolved.titleStyle,
          text.titleLarge?.copyWith(
            fontSize: 18.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            height: 1.25,
          ),
        );
        expect(resolved.previewStyle, text.bodyMedium?.copyWith(height: 1.42));
        expect(resolved.footerStyle, text.bodySmall?.copyWith(fontSize: 11.5));
        expect(resolved.sideCoverSize, const Size(116, 116));
        expect(resolved.footerGap, 8);
        expect(resolved.cornerRadius, 24);
        expect(resolved.accentStartInset, 0);
        expect(resolved.accentTopInset, 0);
      });

      test('waterfall text styles and columns in $brightness', () {
        final theme = expressiveTestTheme(brightness);
        final resolved = DiaryCardResolvedStyle.resolve(
          style: DiaryCardStyle.defaults,
          mode: DiaryCardMode.waterfall,
          theme: theme,
          screenWidth: 320,
          textScale: 1.3,
        );
        final text = theme.textTheme;
        expect(
          resolved.eyebrowStyle,
          text.labelSmall?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        );
        expect(
          resolved.titleStyle,
          text.titleMedium?.copyWith(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.15,
            height: 1.3,
          ),
        );
        expect(resolved.previewStyle, text.bodySmall?.copyWith(height: 1.36));
        expect(resolved.footerStyle, text.bodySmall?.copyWith(fontSize: 11));
        expect(resolved.columns, 2);
        expect(resolved.footerGap, 8);
      });

      test('surface and text colors in $brightness', () {
        final resolved = _resolve(
          DiaryCardStyle.defaults,
          DiaryCardMode.list,
          brightness: brightness,
        );
        final scheme = resolved.colorScheme;
        final isLight = brightness == Brightness.light;
        final plain = resolved.appearanceFor(pinned: false, locked: false);
        expect(plain.surface.color, ExpressiveSurfaces.cardColor(scheme));
        expect(plain.surface.gradientColors, isNull);
        expect(plain.surface.radius, 24);
        expect(plain.surface.borderWidth, 0.8);
        expect(
          plain.surface.borderColor,
          ExpressiveSurfaces.cardBorderColor(scheme),
        );
        expect(
          plain.surface.shadows,
          isLight
              ? <BoxShadow>[
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : <BoxShadow>[
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.32),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        );
        expect(plain.titleColor, scheme.onSurface);
        expect(plain.bodyColor, scheme.onSurfaceVariant);
        expect(
          plain.eyebrowColor,
          scheme.onSurfaceVariant.withValues(alpha: 0.82),
        );
        expect(
          plain.previewColor,
          scheme.onSurfaceVariant.withValues(alpha: 0.88),
        );
        expect(
          plain.footerColor,
          scheme.onSurfaceVariant.withValues(alpha: 0.72),
        );
        expect(
          plain.mutedColor,
          scheme.onSurfaceVariant.withValues(alpha: 0.6),
        );
        expect(plain.accentColor, scheme.primary);
        expect(
          plain.chipFill,
          scheme.surfaceContainerHighest.withValues(
            alpha: isLight ? 0.6 : 0.45,
          ),
        );
        expect(
          plain.chipBorder,
          scheme.outlineVariant.withValues(alpha: isLight ? 0.25 : 0.2),
        );
        expect(plain.inverted, isFalse);
        expect(plain.accentBarColor, isNull);

        final pinned = resolved.appearanceFor(pinned: true, locked: false);
        expect(
          pinned.surface.color,
          Color.alphaBlend(
            scheme.primary.withAlpha(14),
            ExpressiveSurfaces.cardColor(scheme),
          ),
        );
        expect(
          pinned.surface.borderColor,
          scheme.primary.withValues(alpha: isLight ? 0.35 : 0.45),
        );
        expect(pinned.eyebrowColor, scheme.primary);
        expect(pinned.surface.shadows, hasLength(isLight ? 3 : 1));
      });
    }
  });

  group('safety clamps', () {
    test('large side covers shrink to leave the text column room', () {
      final style = DiaryCardStyle.defaults.withMode(
        DiaryCardMode.list,
        DiaryCardModeStyle.listDefaults.copyWith(coverSide: 168),
      );
      expect(
        _resolve(style, DiaryCardMode.list, width: 412).sideCoverSize,
        const Size(168, 168),
      );
      final narrow = _resolve(style, DiaryCardMode.list, width: 320);
      expect(narrow.sideCoverSize.width, lessThan(168));
      // 320 - 2×12 - 2×16 - 14 - 120 = 130
      expect(narrow.sideCoverSize.width, 130);
    });

    test('side padding shrinks so narrow columns keep room for text', () {
      final style = DiaryCardStyle.defaults.withMode(
        DiaryCardMode.waterfall,
        DiaryCardModeStyle.waterfallDefaults.copyWith(paddingH: 32),
      );
      expect(_resolve(style, DiaryCardMode.waterfall, width: 600).paddingH, 32);
      // 单列 (320 - 2×12 - 8) / 2 = 144，正文至少 96 → 内边距 (144 - 96) / 2。
      expect(_resolve(style, DiaryCardMode.waterfall, width: 320).paddingH, 24);
      expect(
        _resolve(
          DiaryCardStyle.defaults,
          DiaryCardMode.waterfall,
          width: 320,
        ).paddingH,
        14,
      );
      expect(
        _resolve(
          DiaryCardStyle.defaults,
          DiaryCardMode.list,
          width: 320,
        ).paddingH,
        16,
      );
    });

    test('cover shapes keep their aspect ratio', () {
      Size sizeFor(DiaryCardCoverShape shape) => _resolve(
        DiaryCardStyle.defaults.withMode(
          DiaryCardMode.list,
          DiaryCardModeStyle.listDefaults.copyWith(
            coverSide: 100,
            coverShape: shape,
          ),
        ),
        DiaryCardMode.list,
      ).sideCoverSize;
      expect(sizeFor(DiaryCardCoverShape.landscape), const Size(100, 75));
      expect(sizeFor(DiaryCardCoverShape.portrait), const Size(75, 100));
      expect(sizeFor(DiaryCardCoverShape.circle), const Size(100, 100));
    });

    test('three waterfall columns fall back to two when too narrow', () {
      final style = DiaryCardStyle.defaults.withMode(
        DiaryCardMode.waterfall,
        DiaryCardModeStyle.waterfallDefaults.copyWith(columns: 3),
      );
      expect(_resolve(style, DiaryCardMode.waterfall, width: 412).columns, 3);
      expect(_resolve(style, DiaryCardMode.waterfall, width: 320).columns, 2);
      expect(
        _resolve(
          style,
          DiaryCardMode.waterfall,
          width: 412,
          textScale: 1.3,
        ).columns,
        2,
      );
    });

    test('accent bars reserve their width in the text padding', () {
      const style = DiaryCardStyle(
        surface: DiaryCardSurfaceStyle(
          accentBar: DiaryCardAccentBar.start,
          accentWidth: 6,
        ),
      );
      final resolved = _resolve(style, DiaryCardMode.list);
      expect(resolved.accentStartInset, 6);
      expect(resolved.accentTopInset, 0);
      expect(
        resolved.appearanceFor(pinned: false, locked: false).accentBarColor,
        resolved.colorScheme.primary,
      );
    });
  });

  group('appearance', () {
    const moodStyle = DiaryCardStyle(
      surface: DiaryCardSurfaceStyle(
        background: DiaryCardColorSpec(
          source: DiaryCardColorSource.mood,
          strength: 0.3,
        ),
      ),
    );

    test('mood and tag colors vary per entry but not for locked capsules', () {
      final resolved = _resolve(moodStyle, DiaryCardMode.list);
      final low = resolved.appearanceFor(
        pinned: false,
        locked: false,
        moodEmoji: '😭',
      );
      final high = resolved.appearanceFor(
        pinned: false,
        locked: false,
        moodEmoji: '🤩',
      );
      final none = resolved.appearanceFor(pinned: false, locked: false);
      final locked = resolved.appearanceFor(
        pinned: false,
        locked: true,
        moodEmoji: '😭',
      );
      final themed = ExpressiveSurfaces.cardColor(resolved.colorScheme);
      expect(low.surface.color, isNot(high.surface.color));
      expect(none.surface.color, themed);
      expect(locked.surface.color, themed);

      const tagStyle = DiaryCardStyle(
        surface: DiaryCardSurfaceStyle(
          borderColor: DiaryCardColorSpec(
            source: DiaryCardColorSource.firstTag,
            strength: 1,
          ),
        ),
      );
      final tagged = _resolve(tagStyle, DiaryCardMode.list).appearanceFor(
        pinned: false,
        locked: false,
        tags: const <Tag>[Tag(id: 1, name: 'a', color: 0xFF4CAF50)],
      );
      expect(tagged.surface.borderColor, const Color(0xFF4CAF50));
    });

    test('dark custom backgrounds flip the text to inverse colors', () {
      const style = DiaryCardStyle(
        surface: DiaryCardSurfaceStyle(
          background: DiaryCardColorSpec(
            source: DiaryCardColorSource.custom,
            light: 0xFF1B1B3A,
            strength: 1,
          ),
        ),
      );
      final resolved = _resolve(style, DiaryCardMode.list);
      final appearance = resolved.appearanceFor(pinned: false, locked: false);
      expect(appearance.inverted, isTrue);
      expect(appearance.titleColor, resolved.colorScheme.onInverseSurface);
    });

    test('custom dark-mode colors are used as given or derived', () {
      const given = DiaryCardStyle(
        surface: DiaryCardSurfaceStyle(
          background: DiaryCardColorSpec(
            source: DiaryCardColorSource.custom,
            light: 0xFFFFF4B8,
            dark: 0xFF3A3420,
            strength: 1,
          ),
        ),
      );
      expect(
        _resolve(
          given,
          DiaryCardMode.list,
          brightness: Brightness.dark,
        ).appearanceFor(pinned: false, locked: false).surface.color,
        const Color(0xFF3A3420),
      );
      final derived = _resolve(
        given.copyWith(
          surface: given.surface.copyWith(
            background: given.surface.background.copyWith(clearDark: true),
          ),
        ),
        DiaryCardMode.list,
        brightness: Brightness.dark,
      ).appearanceFor(pinned: false, locked: false);
      expect(
        HSLColor.fromColor(derived.surface.color).lightness,
        lessThan(0.3),
      );
    });

    test('unreadable custom text colors fall back unless allowed', () {
      const faint = DiaryCardColorSpec(
        source: DiaryCardColorSource.custom,
        light: 0xFFFDFDFD,
        strength: 1,
      );
      const style = DiaryCardStyle(
        typography: DiaryCardTypography(titleColor: faint),
      );
      final resolved = _resolve(style, DiaryCardMode.list);
      expect(
        resolved.appearanceFor(pinned: false, locked: false).titleColor,
        resolved.colorScheme.onSurface,
      );
      final allowed = _resolve(
        style.copyWith(
          typography: style.typography.copyWith(ensureContrast: false),
        ),
        DiaryCardMode.list,
      );
      expect(
        allowed.appearanceFor(pinned: false, locked: false).titleColor,
        const Color(0xFFFDFDFD),
      );
    });

    test('gradients and translucency reach the surface spec', () {
      const style = DiaryCardStyle(
        surface: DiaryCardSurfaceStyle(gradient: true, opacity: 0.7),
      );
      final appearance = _resolve(
        style,
        DiaryCardMode.list,
      ).appearanceFor(pinned: false, locked: false);
      expect(appearance.surface.gradientColors, hasLength(2));
      expect(appearance.surface.color.a, closeTo(0.7, 0.01));
      expect(
        appearance.surface.shadows.every(
          (shadow) => shadow.blurStyle == BlurStyle.outer,
        ),
        isTrue,
      );
    });

    test('custom shadows follow elevation and the shadow color', () {
      const style = DiaryCardStyle(
        surface: DiaryCardSurfaceStyle(
          shadow: DiaryCardShadowStyle.custom,
          shadowElevation: 10,
          shadowColor: DiaryCardColorSpec(
            source: DiaryCardColorSource.primary,
            strength: 0.5,
          ),
        ),
      );
      final resolved = _resolve(style, DiaryCardMode.list);
      final shadow = resolved
          .appearanceFor(pinned: false, locked: false)
          .surface
          .shadows
          .single;
      expect(shadow.blurRadius, 15);
      expect(shadow.offset, const Offset(0, 5));
      expect(shadow.color, resolved.colorScheme.primary.withValues(alpha: 0.5));
    });
  });

  test('resolution is reused for identical inputs', () {
    final theme = expressiveTestTheme(Brightness.light);
    DiaryCardResolvedStyle resolve() => DiaryCardResolvedStyle.resolve(
      style: DiaryCardStyle.defaults,
      mode: DiaryCardMode.list,
      theme: theme,
      screenWidth: 360,
    );
    expect(identical(resolve(), resolve()), isTrue);
  });
}
