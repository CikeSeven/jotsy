import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/export/diary_export_entry.dart';
import 'package:node_diary/ui/diaries/export/diary_export_format.dart';
import 'package:node_diary/ui/diaries/export/diary_export_media.dart';
import 'package:node_diary/ui/diaries/export/diary_export_pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'diary_export_test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<DiaryPdfFonts> asciiFonts() async => DiaryPdfFonts(
    pw.Font.helvetica(),
    pw.Font.helveticaBold(),
    bundled: (await DiaryPdfFonts.load()).regular,
  );

  Future<Uint8List> export(List<dynamic> ops, {DiaryPdfFonts? fonts}) async {
    final output = await DiaryPdfWriter.write(
      <DiaryExportEntry>[
        DiaryExportEntry.parse(
          diaryId: 'heading',
          title: 'Heading formats',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          deltaOps: ops,
        ),
      ],
      options: DiaryExportOptions.defaults.copyWith(
        includeMedia: false,
        includeMeta: false,
      ),
      labels: testExportLabels,
      media: DiaryExportMediaLibrary(),
      fonts: fonts ?? await DiaryPdfFonts.load(),
      documentTitle: 'Heading formats',
    );
    return Uint8List.fromList(output.bytes!);
  }

  for (var level = 1; level <= 6; level++) {
    test(
      'PDF keeps text color and translucent background in H$level',
      () async {
        final bytes = await export(<dynamic>[
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
        final commands = _pageCommands(bytes);
        expect(commands, contains('0 0 1 rg'));
        expect(commands, contains('1 0.49804 0.49804 rg'));
      },
    );
  }

  test('PDF keeps mixed heading runs separate and does not style the next '
      'paragraph', () async {
    final bytes = await export(
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
      fonts: await asciiFonts(),
    );
    final commands = _pageCommands(bytes);
    final pdf = latin1.decode(bytes);
    final plain = _textRun(commands, 'Plain');
    final styled = _textRun(commands, 'Styled');
    final link = _textRun(commands, 'Link');
    final body = _textRun(commands, 'Body');
    expect(plain.size, closeTo(16.8, 0.001));
    expect(styled.size, plain.size);
    expect(link.size, plain.size);
    expect(body.size, 12);
    expect(styled.font, isNot(plain.font));
    expect(body.font, plain.font);
    expect(_fontName(pdf, styled.font), 'Helvetica-Bold');
    expect(_fontName(pdf, plain.font), 'Helvetica');
    expect(commands, contains('0 0 1 rg'));
    expect(commands, contains('0 0.50196 0 rg'));
    // 两条样式装饰线 + 链接的下划线；未格式化片段和下一段不多画线。
    expect(RegExp(r'\bl\s*S\b').allMatches(commands), hasLength(3));
    expect(pdf, contains('https://example.com/heading'));
  });

  test('PDF exports empty and consecutive headings without dropping body '
      'text', () async {
    final bytes = await export(<dynamic>[
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
    ], fonts: await asciiFonts());
    final commands = _pageCommands(bytes);
    expect(_textRun(commands, 'First').size, 12);
    expect(_textRun(commands, 'Second').size, closeTo(15.6, 0.001));
    expect(_textRun(commands, 'Body').size, 12);
  });

  test('PDF preserves different formats on repeated heading text', () async {
    final bytes = await export(<dynamic>[
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
    ], fonts: await asciiFonts());
    final commands = _pageCommands(bytes);
    expect(RegExp(r'\(Repeated\)').allMatches(commands), hasLength(2));
    expect(commands, contains('1 0 0 rg'));
    expect(commands, contains('0 0 1 rg'));
  });
}

({String font, double size}) _textRun(String commands, String text) {
  final run = RegExp(
    r'BT\s*/(\w+)\s+([\d.]+)\s+Tf\b(?:(?!\bET\b).)*?'
    '\\(${RegExp.escape(text)}\\)',
    dotAll: true,
  ).firstMatch(commands);
  expect(run, isNotNull, reason: 'Missing PDF text run: $text\n$commands');
  return (font: run!.group(1)!, size: double.parse(run.group(2)!));
}

String _fontName(String pdf, String resource) {
  final reference = RegExp('/$resource (\\d+) 0 R').firstMatch(pdf)!;
  final object = RegExp(
    '${reference.group(1)} 0 obj\\s*<<(.*?)>>',
    dotAll: true,
  ).firstMatch(pdf)!;
  return RegExp(
    r'/BaseFont\s*/([^\s/>]+)',
  ).firstMatch(object.group(1)!)!.group(1)!;
}

/// PDF 的字体与页面流都会压缩；按字节长度解压，只保留含文字绘制的页面
/// 流，避免把嵌入字体的二进制内容误当成颜色、字号或文字命令。
String _pageCommands(Uint8List bytes) {
  final source = latin1.decode(bytes);
  final streams = RegExp(
    r'<<(.*?)>>\s*stream\r?\n',
    dotAll: true,
  ).allMatches(source);
  return streams
      .map((match) {
        final dictionary = match.group(1)!;
        final length = RegExp(r'/Length\s+(\d+)').firstMatch(dictionary);
        if (length == null || !dictionary.contains('/FlateDecode')) {
          return '';
        }
        final end = match.end + int.parse(length.group(1)!);
        final stream = latin1.decode(
          zlib.decode(bytes.sublist(match.end, end)),
        );
        return stream.contains('BT') ? stream : '';
      })
      .join('\n');
}
