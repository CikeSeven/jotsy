import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'diary_export_pdf_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (var level = 1; level <= 6; level++) {
    test(
      'PDF keeps text color and translucent background in H$level',
      () async {
        final bytes = await exportPdfOps(<dynamic>[
          <String, dynamic>{
            'insert': '彩色标题',
            'attributes': <String, dynamic>{
              'color': '#FF0000FF',
              'background': '#80FF0000',
              'bold': true,
              'underline': true,
              'strike': true,
            },
          },
          <String, dynamic>{
            'insert': '\n',
            'attributes': <String, dynamic>{'header': level},
          },
          <String, dynamic>{'insert': '普通正文\n'},
        ]);

        // 核对实际 PDF 绘制流：仅检查预处理后的 Delta 无法发现插件随后
        // 又用标题默认样式覆盖行内样式的回归。半透明红底已叠到白纸上。
        final commands = pdfPageCommands(bytes);
        expect(commands, contains('0 0 1 rg'));
        expect(commands, contains('1 0.49804 0.49804 rg'));
      },
    );
  }

  test('PDF keeps mixed heading runs separate and does not style the next '
      'paragraph', () async {
    final bytes = await exportPdfOps(
      <dynamic>[
        <String, dynamic>{'insert': 'Plain '},
        <String, dynamic>{
          'insert': 'Styled',
          'attributes': <String, dynamic>{
            'color': '#FF0000FF',
            'background': '#80FF0000',
            'bold': true,
            'underline': true,
            'strike': true,
          },
        },
        <String, dynamic>{
          'insert': ' Link',
          'attributes': <String, dynamic>{
            'link': 'https://example.com/heading',
            'color': '#FF008000',
          },
        },
        <String, dynamic>{
          'insert': '\n',
          'attributes': <String, dynamic>{'header': 2, 'align': 'center'},
        },
        <String, dynamic>{'insert': 'Body\n'},
      ],
      // PDF 的标准字体让正文直接用 ASCII 写入，便于把每个片段的字重与
      // 字号对应到实际的字体资源；上面的六级测试另覆盖内置中文字体。
      fonts: await pdfAsciiFonts(),
    );
    final commands = pdfPageCommands(bytes);
    final pdf = latin1.decode(bytes);
    final plain = pdfTextRun(commands, 'Plain');
    final styled = pdfTextRun(commands, 'Styled');
    final link = pdfTextRun(commands, 'Link');
    final body = pdfTextRun(commands, 'Body');
    expect(plain.size, closeTo(16.8, 0.001));
    expect(styled.size, plain.size);
    expect(link.size, plain.size);
    expect(body.size, 12);
    expect(styled.font, isNot(plain.font));
    expect(body.font, plain.font);
    expect(pdfFontName(pdf, styled.font), 'Helvetica-Bold');
    expect(pdfFontName(pdf, plain.font), 'Helvetica');
    expect(commands, contains('0 0 1 rg'));
    expect(commands, contains('0 0.50196 0 rg'));
    // 两条样式装饰线 + 链接的下划线；未格式化片段和下一段不多画线。
    expect(RegExp(r'\bl\s*S\b').allMatches(commands), hasLength(3));
    expect(pdf, contains('https://example.com/heading'));
  });

  test('PDF exports empty and consecutive headings without dropping body '
      'text', () async {
    final bytes = await exportPdfOps(<dynamic>[
      <String, dynamic>{
        'insert': '\n',
        'attributes': <String, dynamic>{'header': 1},
      },
      <String, dynamic>{'insert': 'First\nSecond'},
      <String, dynamic>{
        'insert': '\n',
        'attributes': <String, dynamic>{'header': 3, 'indent': 1},
      },
      <String, dynamic>{'insert': 'Body\n'},
    ], fonts: await pdfAsciiFonts());
    final commands = pdfPageCommands(bytes);
    expect(pdfTextRun(commands, 'First').size, 12);
    expect(pdfTextRun(commands, 'Second').size, closeTo(15.6, 0.001));
    expect(pdfTextRun(commands, 'Body').size, 12);
  });

  test('PDF preserves different formats on repeated heading text', () async {
    final bytes = await exportPdfOps(<dynamic>[
      for (final color in <String>['#FFFF0000', '#FF0000FF']) ...<dynamic>[
        <String, dynamic>{
          'insert': 'Repeated',
          'attributes': <String, dynamic>{'color': color},
        },
        <String, dynamic>{
          'insert': '\n',
          'attributes': <String, dynamic>{'header': 1},
        },
      ],
    ], fonts: await pdfAsciiFonts());
    final commands = pdfPageCommands(bytes);
    expect(RegExp(r'\(Repeated\)').allMatches(commands), hasLength(2));
    expect(commands, contains('1 0 0 rg'));
    expect(commands, contains('0 0 1 rg'));
  });
}
