import 'dart:ui' show Color;

import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/quill_delta.dart';
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
    expect(
      DiaryColorTarget.background.attributeFor(null).key,
      quill.Attribute.background.key,
    );
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

  group('resolveDiaryHexInputColor', () {
    test('keeps the current alpha when the RGB is unchanged', () {
      expect(
        resolveDiaryHexInputColor(
          const Color(0xFFFFC107),
          const Color(0x66FFC107),
        ),
        const Color(0x66FFC107),
      );
    });

    test('uses an opaque color when the RGB changes', () {
      expect(
        resolveDiaryHexInputColor(
          const Color(0xFF3A7BD5),
          const Color(0x66FFC107),
        ),
        const Color(0xFF3A7BD5),
      );
      expect(
        resolveDiaryHexInputColor(const Color(0xFF3A7BD5), null),
        const Color(0xFF3A7BD5),
      );
    });
  });

  test('collects distinct non-preset colors in document order', () {
    final document = quill.Document.fromDelta(
      Delta()
        ..insert('a', <String, dynamic>{'color': '#FF123456'})
        ..insert('b', <String, dynamic>{'color': '#FFE5484D'})
        ..insert('c', <String, dynamic>{'color': '#123456'})
        ..insert('d', <String, dynamic>{'color': 'red'})
        ..insert('e', <String, dynamic>{'color': '#ff00aa00'})
        ..insert('f', <String, dynamic>{'background': '#80ABCDEF'})
        ..insert('\n'),
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
      final grid = DiaryColorGridLayout.resolve(
        innerWidth: 320,
        usedColorCount: 0,
      );
      expect(grid.columns, 8);
      expect(grid.rows, 2);
      expect(grid.customCount, 0);
    });

    test('custom colors fill at most two rows', () {
      final grid = DiaryColorGridLayout.resolve(
        innerWidth: 320,
        usedColorCount: 9,
      );
      expect(grid.customCount, 4);
      expect(grid.rows, 2);
    });

    test('columns are clamped between 6 and 16', () {
      expect(
        DiaryColorGridLayout.resolve(
          innerWidth: 200,
          usedColorCount: 3,
        ).columns,
        6,
      );
      final wide = DiaryColorGridLayout.resolve(
        innerWidth: 1000,
        usedColorCount: 0,
      );
      expect(wide.columns, 16);
      expect(wide.rows, 1);
    });
  });
}
