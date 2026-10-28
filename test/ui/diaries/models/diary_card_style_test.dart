import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style_presets.dart';

/// 每个字段都偏离默认值的样式，用来验证完整往返。
const _everyField = DiaryCardStyle(
  surface: DiaryCardSurfaceStyle(
    cornerRadius: 10,
    background: DiaryCardColorSpec(
      source: DiaryCardColorSource.custom,
      light: 0xFF123456,
      dark: 0xFF654321,
      strength: 0.5,
    ),
    opacity: 0.8,
    gradient: true,
    gradientEnd: DiaryCardColorSpec(
      source: DiaryCardColorSource.secondary,
      strength: 0.3,
    ),
    gradientDirection: DiaryCardGradientDirection.horizontal,
    pinnedTint: false,
    borderWidth: 2,
    borderColor: DiaryCardColorSpec(source: DiaryCardColorSource.firstTag),
    accentBar: DiaryCardAccentBar.start,
    accentWidth: 6,
    accentColor: DiaryCardColorSpec(source: DiaryCardColorSource.mood),
    shadow: DiaryCardShadowStyle.custom,
    shadowElevation: 12,
    shadowColor: DiaryCardColorSpec(
      source: DiaryCardColorSource.primary,
      strength: 0.4,
    ),
    material: DiaryCardMaterial.glass,
    blurSigma: 24,
  ),
  typography: DiaryCardTypography(
    titleScale: 1.2,
    titleWeight: DiaryCardTitleWeight.regular,
    previewScale: 0.9,
    lineHeight: DiaryCardLineHeight.compact,
    metaScale: 1.1,
    textAlign: DiaryCardTextAlign.center,
    titleColor: DiaryCardColorSpec(
      source: DiaryCardColorSource.custom,
      light: 0xFF000080,
      strength: 1,
    ),
    bodyColor: DiaryCardColorSpec(
      source: DiaryCardColorSource.tertiary,
      strength: 1,
    ),
    ensureContrast: false,
  ),
  content: DiaryCardContentStyle(
    blocks: <DiaryCardBlock>[
      DiaryCardBlock.title,
      DiaryCardBlock.preview,
      DiaryCardBlock.eyebrow,
      DiaryCardBlock.footer,
      DiaryCardBlock.tags,
    ],
    showTitle: false,
    showUntitled: false,
    showPreview: false,
    tagStyle: DiaryCardTagStyle.dot,
    pinnedBadge: DiaryCardPinnedBadge.hidden,
    coverFallback: DiaryCardCoverFallback.moodTile,
    collage: true,
  ),
  meta: DiaryCardMetaStyle(
    showDate: false,
    dateFormat: DiaryCardDateFormat.numeric,
    showWeekday: false,
    showTime: true,
    dateSource: DiaryCardDateSource.updated,
    footerTime: DiaryCardFooterTime.created,
    showMood: false,
    showWeather: false,
    indicatorStyle: DiaryCardIndicatorStyle.plain,
    showLocation: true,
    showEnergy: true,
    showWordCount: true,
    showMedia: true,
  ),
  list: DiaryCardModeStyle(
    coverPosition: DiaryCardCoverPosition.end,
    coverSide: 90,
    coverShape: DiaryCardCoverShape.circle,
    coverRadius: 4,
    coverHeight: 200,
    coverInset: true,
    coverDivider: false,
    coverGap: 20,
    scrim: 0.6,
    paddingH: 20,
    paddingV: 18,
    cardGap: 12,
    sideMargin: 4,
    elementGap: 9,
    titleMaxLines: 3,
    previewMaxLines: 5,
    metaPosition: DiaryCardMetaPosition.cover,
    columns: 3,
  ),
  waterfall: DiaryCardModeStyle(
    coverPosition: DiaryCardCoverPosition.background,
    coverHeight: 240,
    coverGap: 8,
    paddingH: 10,
    paddingV: 8,
    elementGap: 3,
    titleMaxLines: 1,
    previewMaxLines: 6,
    metaPosition: DiaryCardMetaPosition.eyebrow,
    columns: 3,
  ),
);

void main() {
  group('DiaryCardStyle defaults', () {
    test('match the pre-customization card exactly', () {
      const style = DiaryCardStyle.defaults;
      expect(style.surface.cornerRadius, 24);
      expect(style.surface.background.source, DiaryCardColorSource.theme);
      expect(style.surface.opacity, 1);
      expect(style.surface.gradient, isFalse);
      expect(style.surface.pinnedTint, isTrue);
      expect(style.surface.borderWidth, 0.8);
      expect(style.surface.borderColor.source, DiaryCardColorSource.theme);
      expect(style.surface.accentBar, DiaryCardAccentBar.none);
      expect(style.surface.shadow, DiaryCardShadowStyle.themed);
      expect(style.surface.material, DiaryCardMaterial.solid);
      expect(style.typography.titleScale, 1);
      expect(style.typography.titleWeight, DiaryCardTitleWeight.bold);
      expect(style.typography.previewScale, 1);
      expect(style.typography.lineHeight, DiaryCardLineHeight.standard);
      expect(style.typography.metaScale, 1);
      expect(style.typography.textAlign, DiaryCardTextAlign.start);
      expect(style.typography.titleColor.isThemed, isTrue);
      expect(style.typography.bodyColor.isThemed, isTrue);
      expect(style.content.blocks, DiaryCardBlock.values);
      expect(style.content.showTitle, isTrue);
      expect(style.content.showUntitled, isTrue);
      expect(style.content.showPreview, isTrue);
      expect(style.content.tagStyle, DiaryCardTagStyle.chip);
      expect(style.content.pinnedBadge, DiaryCardPinnedBadge.standard);
      expect(style.content.coverFallback, DiaryCardCoverFallback.none);
      expect(style.content.collage, isFalse);
      expect(style.meta.showDate, isTrue);
      expect(style.meta.dateFormat, DiaryCardDateFormat.eyebrow);
      expect(style.meta.showWeekday, isTrue);
      expect(style.meta.showTime, isFalse);
      expect(style.meta.dateSource, DiaryCardDateSource.created);
      expect(style.meta.footerTime, DiaryCardFooterTime.relativeUpdated);
      expect(style.meta.showMood, isTrue);
      expect(style.meta.showWeather, isTrue);
      expect(style.meta.indicatorStyle, DiaryCardIndicatorStyle.stamp);
      expect(style.meta.hasFooterExtras, isFalse);
      // 留言数默认开，但只在开启留言功能且有留言时出现。
      expect(style.meta.showComments, isTrue);

      final list = style.list;
      expect(list.coverPosition, DiaryCardCoverPosition.start);
      expect(list.coverSide, 116);
      expect(list.coverShape, DiaryCardCoverShape.square);
      expect(list.coverRadius, 16);
      expect(list.coverGap, 14);
      expect(list.paddingH, 16);
      expect(list.paddingV, 14);
      expect(list.cardGap, 8);
      expect(list.sideMargin, 12);
      expect(list.elementGap, 6);
      expect(list.titleMaxLines, 2);
      expect(list.previewMaxLines, 2);
      expect(list.metaPosition, DiaryCardMetaPosition.eyebrow);

      final waterfall = style.waterfall;
      expect(waterfall.coverPosition, DiaryCardCoverPosition.top);
      expect(waterfall.coverHeight, 140);
      expect(waterfall.coverInset, isFalse);
      expect(waterfall.coverDivider, isTrue);
      expect(waterfall.paddingH, 14);
      expect(waterfall.paddingV, 12);
      expect(waterfall.cardGap, 8);
      expect(waterfall.sideMargin, 12);
      expect(waterfall.elementGap, 5);
      expect(waterfall.titleMaxLines, 2);
      expect(waterfall.previewMaxLines, 3);
      expect(waterfall.metaPosition, DiaryCardMetaPosition.footer);
      expect(waterfall.columns, 2);
    });

    test('encode sparsely as an empty object', () {
      expect(DiaryCardStyle.defaults.toJson(), isEmpty);
      expect(DiaryCardStyle.defaults.encode(), '{}');
      expect(DiaryCardStyle.defaults.isDefault, isTrue);
    });
  });

  group('DiaryCardStyle decoding', () {
    test('falls back to defaults for missing or corrupt input', () {
      for (final raw in <String?>[null, '', '  ', '{not json', '[1, 2]', '7']) {
        expect(DiaryCardStyle.decode(raw), DiaryCardStyle.defaults);
      }
    });

    test('round-trips every field', () {
      final decoded = DiaryCardStyle.decode(_everyField.encode());
      expect(decoded, _everyField);
      expect(decoded.surface.background.light, 0xFF123456);
      expect(decoded.surface.background.dark, 0xFF654321);
    });

    test('encodes only fields that differ from their defaults', () {
      const style = DiaryCardStyle(
        surface: DiaryCardSurfaceStyle(cornerRadius: 12),
        waterfall: DiaryCardModeStyle(
          coverPosition: DiaryCardCoverPosition.top,
          coverHeight: 140,
          coverGap: 10,
          paddingH: 14,
          paddingV: 12,
          elementGap: 5,
          previewMaxLines: 3,
          metaPosition: DiaryCardMetaPosition.footer,
          columns: 3,
        ),
      );
      expect(style.toJson(), <String, Object>{
        'surface': <String, Object>{'cornerRadius': 12.0},
        'waterfall': <String, Object>{'columns': 3},
      });
    });

    test('a single bad field falls back alone', () {
      final json = jsonDecode(_everyField.encode()) as Map<String, dynamic>;
      (json['surface'] as Map<String, dynamic>)['cornerRadius'] = 'round';
      (json['meta'] as Map<String, dynamic>)['dateFormat'] = 'lunar';
      (json['list'] as Map<String, dynamic>)['coverShape'] = 42;
      final decoded = DiaryCardStyle.fromJson(json);
      expect(decoded.surface.cornerRadius, 24);
      expect(decoded.meta.dateFormat, DiaryCardDateFormat.eyebrow);
      expect(decoded.list.coverShape, DiaryCardCoverShape.square);
      // 同一对象里的其他字段不受影响。
      expect(decoded.surface.borderWidth, 2);
      expect(decoded.meta.showTime, isTrue);
      expect(decoded.list.coverSide, 90);
    });

    test('a corrupt sub-object resets only that group', () {
      final json = jsonDecode(_everyField.encode()) as Map<String, dynamic>;
      json['typography'] = 'large';
      final decoded = DiaryCardStyle.fromJson(json);
      expect(decoded.typography, const DiaryCardTypography());
      expect(decoded.surface, _everyField.surface);
    });

    test('clamps out-of-range numbers and rejects non-finite ones', () {
      final decoded = DiaryCardStyle.fromJson(<String, Object>{
        'surface': <String, Object>{
          'cornerRadius': 400,
          'borderWidth': -3,
          'background': <String, Object>{'strength': 9},
        },
        'list': <String, Object>{
          'coverSide': 1,
          'titleMaxLines': 99,
          'previewMaxLines': 2.6,
        },
      });
      expect(
        decoded.surface.cornerRadius,
        DiaryCardStyleLimits.cornerRadius.max,
      );
      expect(decoded.surface.borderWidth, DiaryCardStyleLimits.borderWidth.min);
      expect(decoded.surface.background.strength, 1);
      expect(decoded.list.coverSide, DiaryCardStyleLimits.coverSide.min);
      expect(decoded.list.titleMaxLines, 4);
      expect(decoded.list.previewMaxLines, 3);

      // jsonDecode 不会产出 NaN，但手工构造的 Map（如测试或迁移代码）可能。
      final nan = DiaryCardStyle.fromJson(<String, Object>{
        'surface': <String, Object>{'cornerRadius': double.nan},
      });
      expect(nan.surface.cornerRadius, 24);
    });

    test('waterfall ignores side cover positions', () {
      final decoded = DiaryCardStyle.fromJson(<String, Object>{
        'waterfall': <String, Object>{'coverPosition': 'start'},
        'list': <String, Object>{'coverPosition': 'background'},
      });
      expect(decoded.waterfall.coverPosition, DiaryCardCoverPosition.top);
      expect(decoded.list.coverPosition, DiaryCardCoverPosition.background);
    });

    test('normalizes the block order', () {
      final decoded = DiaryCardStyle.fromJson(<String, Object>{
        'content': <String, Object>{
          'blocks': <Object>['preview', 'preview', 'bogus', 3, 'title'],
        },
      });
      expect(decoded.content.blocks, <DiaryCardBlock>[
        DiaryCardBlock.preview,
        DiaryCardBlock.title,
        DiaryCardBlock.eyebrow,
        DiaryCardBlock.tags,
        DiaryCardBlock.footer,
      ]);
    });

    test('parses custom colors leniently and forces them opaque', () {
      DiaryCardColorSpec decode(Object? light) => DiaryCardStyle.fromJson(
        <String, Object>{
          'surface': <String, Object>{
            'background': <String, Object?>{'source': 'custom', 'light': light},
          },
        },
      ).surface.background;

      expect(decode('#12AB34').light, 0xFF12AB34);
      expect(decode('12ab34').light, 0xFF12AB34);
      expect(decode('#8012AB34').light, 0xFF12AB34);
      expect(decode(0x0012AB34).light, 0xFF12AB34);
      expect(decode('#12AB3').light, isNull);
      expect(decode('teal').light, isNull);
      // 自定义来源却没有颜色时按主题色处理。
      expect(decode('teal').isThemed, isTrue);
    });

    test('ignores a newer field it does not know and keeps the rest', () {
      final decoded = DiaryCardStyle.fromJson(<String, Object>{
        'surface': <String, Object>{'cornerRadius': 8, 'sparkle': true},
        'future': <String, Object>{'x': 1},
      });
      expect(decoded.surface.cornerRadius, 8);
    });
  });

  group('DiaryCardStyle helpers', () {
    test('mode and withMode address the right layout', () {
      final updated = DiaryCardStyle.defaults.withMode(
        DiaryCardMode.waterfall,
        DiaryCardStyle.defaults.waterfall.copyWith(columns: 3),
      );
      expect(updated.mode(DiaryCardMode.waterfall).columns, 3);
      expect(updated.mode(DiaryCardMode.list), DiaryCardModeStyle.listDefaults);
    });

    test('copyWith on blocks keeps every block exactly once', () {
      final content = const DiaryCardContentStyle().copyWith(
        blocks: <DiaryCardBlock>[DiaryCardBlock.footer, DiaryCardBlock.footer],
      );
      expect(content.blocks.first, DiaryCardBlock.footer);
      expect(content.blocks.toSet(), DiaryCardBlock.values.toSet());
      expect(content.blocks, hasLength(DiaryCardBlock.values.length));
    });
  });

  group('DiaryCardPresets', () {
    test('classic is the default style and every preset round-trips', () {
      expect(
        DiaryCardPresets.styleOf(DiaryCardPresetId.classic),
        DiaryCardStyle.defaults,
      );
      for (final id in DiaryCardPresetId.values) {
        final style = DiaryCardPresets.styleOf(id);
        expect(DiaryCardStyle.decode(style.encode()), style, reason: id.name);
        expect(DiaryCardPresets.match(style), id, reason: id.name);
      }
    });

    test('presets are distinct and a tweaked preset matches none', () {
      final styles = DiaryCardPresets.styles.values.toSet();
      expect(styles, hasLength(DiaryCardPresetId.values.length));
      final tweaked = DiaryCardPresets.styleOf(
        DiaryCardPresetId.magazine,
      ).copyWith(surface: const DiaryCardSurfaceStyle(cornerRadius: 3));
      expect(DiaryCardPresets.match(tweaked), isNull);
    });
  });
}
