import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_material_colors.dart';
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';

/// Material 色板数据：色系顺序、各色系的格子、反查与色系页排布。
void main() {
  group('palette', () {
    test('has the 19 families of the old Material picker, in order', () {
      expect(DiaryMaterialFamily.values.map((f) => f.name), <String>[
        'red',
        'pink',
        'purple',
        'deepPurple',
        'indigo',
        'blue',
        'lightBlue',
        'cyan',
        'teal',
        'green',
        'lightGreen',
        'lime',
        'yellow',
        'amber',
        'orange',
        'deepOrange',
        'brown',
        'grey',
        'blueGrey',
      ]);
      expect(DiaryMaterialFamily.red.color, Colors.red.shade500);
    });

    test('a hue family has ten tones light to dark, then four accents', () {
      final shades = DiaryMaterialFamily.blue.shades;
      expect(shades.map((s) => s.tone), <String>[
        '50',
        '100',
        '200',
        '300',
        '400',
        '500',
        '600',
        '700',
        '800',
        '900',
        'A100',
        'A200',
        'A400',
        'A700',
      ]);
      expect(shades[2].color, Colors.blue.shade200);
      expect(shades[2].kind, DiaryMaterialShadeKind.tone);
      expect(shades[11].color, Colors.blueAccent.shade200);
      expect(shades[11].kind, DiaryMaterialShadeKind.accent);
    });

    test('brown and blue gray have no accents', () {
      for (final family in <DiaryMaterialFamily>[
        DiaryMaterialFamily.brown,
        DiaryMaterialFamily.blueGrey,
      ]) {
        expect(family.shades, hasLength(10), reason: family.name);
        expect(
          family.shades.map((s) => s.kind).toSet(),
          <DiaryMaterialShadeKind>{DiaryMaterialShadeKind.tone},
        );
      }
    });

    test('gray runs from white through 350 and 850 to black', () {
      final shades = DiaryMaterialFamily.grey.shades;
      expect(shades, hasLength(kDiaryMaterialMaxShades));
      expect(shades.first.kind, DiaryMaterialShadeKind.white);
      expect(shades.first.color.toARGB32(), 0xFFFFFFFF);
      expect(shades.last.kind, DiaryMaterialShadeKind.black);
      expect(shades.last.color.toARGB32(), 0xFF000000);
      expect(shades[5].tone, '350');
      expect(shades[5].color, Colors.grey[350]);
      expect(shades[11].tone, '850');
    });

    test('every color is opaque and belongs to exactly one family', () {
      final seen = <int>{};
      for (final family in DiaryMaterialFamily.values) {
        expect(
          family.shades.length,
          lessThanOrEqualTo(kDiaryMaterialMaxShades),
        );
        for (final shade in family.shades) {
          expect(shade.color.a, 1, reason: '${family.name} ${shade.tone}');
          expect(seen.add(shade.color.toARGB32()), isTrue);
          expect(DiaryMaterialFamily.of(shade.color), family);
        }
      }
    });

    test('a color outside the palette or no color has no family', () {
      expect(DiaryMaterialFamily.of(null), isNull);
      expect(DiaryMaterialFamily.of(const Color(0xFF123456)), isNull);
      // 同一色阶的半透明版本不算（按 ARGB 比较）。
      expect(DiaryMaterialFamily.of(Colors.red.withAlpha(0x4D)), isNull);
      expect(
        DiaryMaterialFamily.of(parseDiaryColorValue('#ffd32f2f')),
        DiaryMaterialFamily.red,
      );
    });
  });

  group('layout', () {
    test('phones get two rows of seven, as tall as the swatches page', () {
      for (final inner in <double>[280, 320, 371]) {
        final grid = DiaryColorGridLayout.resolve(innerWidth: inner);
        expect(grid.materialColumns, 7, reason: '$inner');
        expect(grid.materialRows, 2);
        expect(grid.materialHeight, 128);
        expect(grid.materialHeight, grid.height);
      }
    });

    test('a 14-column panel lines the shades up in one row', () {
      final grid = DiaryColorGridLayout.resolve(innerWidth: 1176);
      expect(grid.materialColumns, kDiaryMaterialMaxShades);
      expect(grid.materialRows, 1);
      expect(grid.materialHeight, 88);
      expect(grid.materialHeight, grid.height);
    });
  });
}
