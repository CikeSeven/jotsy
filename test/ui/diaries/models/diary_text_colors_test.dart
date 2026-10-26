import '../../../support/diary_content_test_helpers.dart';
import 'dart:ui' show Color;

import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/journal_import_style.dart';
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';

void main() {
  group('parseDiaryHexInput', () {
    test('accepts six digits with or without # and 0x prefixes', () {
      for (final input in <String>[
        '3a7bd5',
        '#3A7BD5',
        '0x3A7BD5',
        ' 3A 7B D5 ',
      ]) {
        expect(
          parseDiaryHexInput(input),
          const Color(0xFF3A7BD5),
          reason: input,
        );
      }
    });

    test('expands three digits into an opaque color', () {
      expect(parseDiaryHexInput('#f0a'), const Color(0xFFFF00AA));
    });

    test('rejects other lengths and non-hex characters', () {
      for (final input in <String>[
        '',
        '#',
        '12',
        '1234',
        '12345',
        '1234567',
        'FF3A7BD5',
        'GGGGGG',
        '#12 34Z',
      ]) {
        expect(parseDiaryHexInput(input), isNull, reason: input);
      }
    });
  });

  test('sanitizeDiaryHexInput strips pasted prefixes and uppercases', () {
    expect(sanitizeDiaryHexInput('#3a7bd5'), '3A7BD5');
    expect(sanitizeDiaryHexInput('0x3a7bd5'), '3A7BD5');
    expect(sanitizeDiaryHexInput('12-zz ab'), '12AB');
  });

  test('encodeDiaryColor always writes uppercase #AARRGGBB', () {
    expect(encodeDiaryColor(const Color(0xFF3a7bd5)), '#FF3A7BD5');
    expect(encodeDiaryColor(const Color(0x0000000f)), '#0000000F');
    expect(
      DiaryColorTarget.text.attributeFor(const Color(0xFFE5484D)).value,
      '#FFE5484D',
    );
    expect(DiaryColorTarget.background.attributeFor(null).value, isNull);
    expect(DiaryColorTarget.background.attributeFor(null).key, 'bg_color');
  });

  group('parseDiaryColorValue', () {
    test('reads six-digit values as opaque and eight-digit as ARGB', () {
      expect(parseDiaryColorValue('#3a7bd5'), const Color(0xFF3A7BD5));
      expect(parseDiaryColorValue('#4dff6369'), const Color(0x4DFF6369));
    });

    test('returns null for color names and junk', () {
      for (final value in <String?>[
        null,
        'red',
        'rgb(1,2,3)',
        '#12345',
        '#GGGGGG',
      ]) {
        expect(parseDiaryColorValue(value), isNull, reason: '$value');
      }
    });

    test('an unreadable attribute is a color without a swatch', () {
      final value = DiaryColorValue.parse('red');
      expect(value.isNone, isFalse);
      expect(value.color, isNull);
      expect(value.matches(const Color(0xFFE5484D)), isFalse);
      expect(DiaryColorValue.parse(null).isNone, isTrue);
    });
  });

  group('flattenDiaryColors', () {
    const white = Color(0xFFFFFFFF);

    test('lays the background on the paper and the text on that', () {
      final flat = flattenDiaryColors(
        text: const Color(0x80000000),
        background: const Color(0x4DFF6369),
        paper: white,
      );
      // 混合结果是浮点分量，按写入正文的 ARGB 比较。
      expect(encodeDiaryColor(flat.background!), '#FFFFD0D2');
      expect(encodeDiaryColor(flat.text!), '#FF7F6868');
    });

    test('a fully transparent background is no background', () {
      final flat = flattenDiaryColors(
        text: const Color(0xFFE5484D),
        background: const Color(0x00FF0000),
        paper: white,
      );
      expect(flat.background, isNull);
      expect(encodeDiaryColor(flat.text!), '#FFE5484D');
      final none = flattenDiaryColors(paper: white);
      expect(none.text, isNull);
      expect(none.background, isNull);
    });
  });

  test('the yellow highlight preset is the imported highlight color', () {
    expect(
      encodeDiaryColor(
        DiaryColorPreset.yellow.colorFor(DiaryColorTarget.background),
      ),
      journalHighlightColor,
    );
    expect(
      DiaryColorPreset.match(
        parseDiaryColorValue(journalHighlightColor)!,
        DiaryColorTarget.background,
      ),
      DiaryColorPreset.yellow,
    );
  });

  test('collects distinct non-preset colors in document order', () {
    final document = documentFromLegacyDelta(
      (Delta()
            ..insert('a', <String, dynamic>{'color': '#FF123456'})
            ..insert('b', <String, dynamic>{'color': '#FFE5484D'})
            ..insert('c', <String, dynamic>{'color': '#123456'})
            ..insert('d', <String, dynamic>{'color': 'red'})
            ..insert('e', <String, dynamic>{'color': '#ff00aa00'})
            ..insert('f', <String, dynamic>{'background': '#80ABCDEF'})
            ..insert('\n'))
          .toJson(),
    );
    expect(collectDiaryDocumentColors(document, DiaryColorTarget.text), <Color>[
      const Color(0xFF123456),
      const Color(0xFF00AA00),
    ]);
    expect(
      collectDiaryDocumentColors(document, DiaryColorTarget.background),
      <Color>[const Color(0x80ABCDEF)],
    );
  });

  group('DiaryColorGridLayout', () {
    test('a phone fits the presets in two rows of eight', () {
      final grid = DiaryColorGridLayout.resolve(innerWidth: 320);
      expect(grid.columns, 8);
      expect(grid.presetRows, 2);
      // 预设两行 + 分隔 + 我的颜色一行，与自定义页同高。
      expect(grid.height, 128);
    });

    test('columns are clamped between 6 and 16', () {
      final narrow = DiaryColorGridLayout.resolve(innerWidth: 200);
      expect(narrow.columns, 6);
      expect(narrow.presetRows, 2);
      final wide = DiaryColorGridLayout.resolve(innerWidth: 1000);
      expect(wide.columns, 16);
      expect(wide.presetRows, 1);
      expect(wide.height, 88);
    });
  });
}
