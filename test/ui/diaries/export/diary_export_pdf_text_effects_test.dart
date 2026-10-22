import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/export/diary_export_pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'diary_export_pdf_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PDF draws italic and stronger bold without losing underline in '
      'headings or following paragraphs', () async {
    final bytes = await exportPdfOps(<dynamic>[
      for (final header in <int?>[1, 2, 3, 4, 5, 6, null]) ...<dynamic>[
        <String, dynamic>{
          'insert': 'Underlined',
          'attributes': <String, dynamic>{'underline': true},
        },
        <String, dynamic>{
          'insert': 'Italic',
          'attributes': <String, dynamic>{'italic': true},
        },
        <String, dynamic>{
          'insert': 'Bold',
          'attributes': <String, dynamic>{'bold': true},
        },
        <String, dynamic>{
          'insert': 'Combined',
          'attributes': <String, dynamic>{
            'bold': true,
            'italic': true,
            'underline': true,
            'strike': true,
            'color': '#FF0000FF',
          },
        },
        <String, dynamic>{
          'insert': '\n',
          if (header != null) 'attributes': <String, dynamic>{'header': header},
        },
      ],
      <String, dynamic>{'insert': 'Unstyled\n'},
    ], fonts: await pdfAsciiFonts());
    final commands = pdfPageCommands(bytes);
    for (final text in <String>['Underlined', 'Italic', 'Bold', 'Combined']) {
      expect(
        RegExp('\\(${RegExp.escape(text)}\\)').allMatches(commands),
        hasLength(7),
      );
    }
    // 斜体必须真的倾斜；仅把 fontStyle 设为 italic、却映射到常规字体无效。
    expect(
      RegExp(r'1 0 0\.21256 1 [\d.\-]+ 0 cm').allMatches(commands),
      hasLength(14),
    );
    expect(RegExp(r'\b2 Tr\b').allMatches(commands), hasLength(14));
    // 六级标题与正文各一条下划线，以及组合片段的下划线与删除线。
    expect(RegExp(r'\bl\s*S\b').allMatches(commands), hasLength(21));
    final plain = pdfTextRun(commands, 'Unstyled');
    expect(plain.size, 12);
    expect(pdfFontName(latin1.decode(bytes), plain.font), 'Helvetica');
  });

  test('PDF retains heading inline sizes and colors on adjacent styled '
      'body fragments', () async {
    final bytes = await exportPdfOps(<dynamic>[
      for (final size in <Object>['small', 'large', 'huge', 24])
        <String, dynamic>{
          'insert': 'Size$size',
          'attributes': <String, dynamic>{'size': size},
        },
      <String, dynamic>{
        'insert': '\n',
        'attributes': <String, dynamic>{'header': 1},
      },
      <String, dynamic>{
        'insert': 'Red',
        'attributes': <String, dynamic>{'color': '#FFFF0000'},
      },
      <String, dynamic>{
        'insert': 'Blue',
        'attributes': <String, dynamic>{'color': '#FF0000FF'},
      },
      <String, dynamic>{'insert': '\n'},
    ], fonts: await pdfAsciiFonts());
    final commands = pdfPageCommands(bytes);
    expect(pdfTextRun(commands, 'Sizesmall').size, closeTo(10.2, 0.001));
    expect(pdfTextRun(commands, 'Sizelarge').size, 15);
    expect(pdfTextRun(commands, 'Sizehuge').size, 18);
    expect(pdfTextRun(commands, 'Size24').size, 24);
    expect(pdfTextRun(commands, 'Red').size, 12);
    expect(pdfTextRun(commands, 'Blue').size, 12);
    expect(commands, contains('1 0 0 rg'));
    expect(commands, contains('0 0 1 rg'));
  });

  test(
    'PDF applies italic, bold and underline to Chinese heading glyphs',
    () async {
      final bytes = await exportPdfOps(<dynamic>[
        <String, dynamic>{
          'insert': '中文格式标题',
          'attributes': <String, dynamic>{
            'bold': true,
            'italic': true,
            'underline': true,
          },
        },
        <String, dynamic>{
          'insert': '\n',
          'attributes': <String, dynamic>{'header': 1},
        },
        <String, dynamic>{'insert': '普通正文\n'},
      ]);
      final commands = pdfPageCommands(bytes);
      expect(commands, contains('1 0 0.21256 1'));
      expect(commands, contains('2 Tr'));
      expect(RegExp(r'\bl\s*S\b').allMatches(commands), hasLength(1));
    },
  );

  test(
    'PDF retains effects with one font weight and Chinese fallback',
    () async {
      final regular = pw.Font.helvetica();
      final bytes = await exportPdfOps(
        <dynamic>[
          <String, dynamic>{
            'insert': 'Mixed中文',
            'attributes': <String, dynamic>{
              'bold': true,
              'italic': true,
              'underline': true,
            },
          },
          <String, dynamic>{
            'insert': '\n',
            'attributes': <String, dynamic>{'header': 2},
          },
          <String, dynamic>{'insert': 'Plain\n'},
        ],
        fonts: DiaryPdfFonts(
          regular,
          regular,
          bundled: (await DiaryPdfFonts.load()).regular,
        ),
      );
      final commands = pdfPageCommands(bytes);
      // 西文与每个缺字回落的中文都补粗、倾斜；末尾普通文字不带效果。
      expect(RegExp(r'1 0 0\.21256 1').allMatches(commands), hasLength(3));
      expect(RegExp(r'\b2 Tr\b').allMatches(commands), hasLength(3));
      expect(
        pdfTextRun(commands, 'Plain').font,
        isNot(pdfTextRun(commands, 'Mixed').font),
      );
    },
  );

  test(
    'PDF keeps long heading wraps and styled paragraphs across pages',
    () async {
      final bytes = await exportPdfOps(<dynamic>[
        <String, dynamic>{
          'insert': List<String>.filled(60, 'Wrapped').join(' '),
          'attributes': <String, dynamic>{
            'italic': true,
            'bold': true,
            'underline': true,
          },
        },
        <String, dynamic>{
          'insert': '\n',
          'attributes': <String, dynamic>{'header': 2, 'align': 'center'},
        },
        for (var i = 0; i < 100; i++) ...<dynamic>[
          <String, dynamic>{
            'insert': 'Line$i with italic and underline',
            'attributes': <String, dynamic>{'italic': true, 'underline': true},
          },
          <String, dynamic>{'insert': '\n'},
        ],
        <String, dynamic>{'insert': 'LastPlain\n'},
      ], fonts: await pdfAsciiFonts());
      final commands = pdfPageCommands(bytes);
      expect(
        RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length,
        greaterThan(1),
      );
      expect(RegExp(r'\(Wrapped\)').allMatches(commands), hasLength(60));
      expect(RegExp(r'\(Line\d+\)').allMatches(commands), hasLength(100));
      expect(pdfTextRun(commands, 'LastPlain').size, 12);
      expect(
        RegExp(r'\bl\s*S\b').allMatches(commands).length,
        greaterThan(100),
      );
    },
  );
}
