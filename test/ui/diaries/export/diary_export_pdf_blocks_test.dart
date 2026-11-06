import 'dart:typed_data';

import 'package:flutter/widgets.dart' show TextDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/ui/diaries/export/diary_export_pdf.dart';
import 'package:node_diary/ui/diaries/export/diary_export_pdf_body.dart';
import 'package:node_diary/ui/diaries/export/diary_export_pdf_text_effects.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'diary_export_pdf_test_support.dart';

/// PDF 里列表、待办、分隔线、日记链接卡片与表格格子的画法：按页面流里的
/// 位置与绘制命令验证，与应用里看到的一致。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A4 宽 21cm、左右各 2cm 页边距后的版心宽度（pt）。
  const contentWidth = 17 / 2.54 * 72;

  test('list items keep wrapped lines under their text instead of under the '
      'marker', () async {
    final filler = List<String>.filled(80, 'xx').join(' ');
    for (final type in <String>['bulleted_list', 'numbered_list']) {
      final commands = await exportPdfBlocks(<Map<String, Object?>>[
        pdfTextBlock(type, 'Item $filler'),
      ]);
      // 标记在单独的一列里，文字列的第一个词与折行后的各行同一起点。
      expect(pdfXsOf(commands, 'Item'), <double>[0], reason: type);
      expect(pdfXsOf(commands, 'xx'), contains(0), reason: type);
    }
  });

  test('todo items draw a box instead of bracket text, and done items turn '
      'gray with a line through them', () async {
    final done = await exportPdfBlocks(<Map<String, Object?>>[
      pdfTextBlock('todo_list', 'Done', data: {'checked': true}),
    ]);
    final open = await exportPdfBlocks(<Map<String, Object?>>[
      pdfTextBlock('todo_list', 'Open'),
    ]);
    for (final commands in <String>[done, open]) {
      expect(commands, isNot(contains('[x]')));
      expect(commands, isNot(contains('([)')));
    }
    expect(pdfXsOf(done, 'Done'), <double>[0]);
    expect(pdfXsOf(open, 'Open'), <double>[0]);
    // 已完成：方框里画白色的勾，文字转灰并划线（未完成的都没有）。
    const white = '1 1 1 RG';
    const gray = '0.45882 0.45882 0.45882 rg';
    final strike = RegExp(r'\bl\s*S\b');
    expect(done, contains(white));
    expect(open, isNot(contains(white)));
    expect(gray.allMatches(done).length, gray.allMatches(open).length + 1);
    // 勾与删除线各一条折线 / 直线。
    expect(strike.allMatches(done), hasLength(2));
    expect(strike.allMatches(open), isEmpty);
  });

  test('dividers draw a rule across the whole line', () async {
    final commands = await exportPdfBlocks(<Map<String, Object?>>[
      pdfTextBlock('paragraph', 'Above'),
      <String, Object?>{'type': 'divider', 'data': <String, Object?>{}},
    ]);
    final rule = RegExp(r'([\d.]+) 0 m 0 0 l S').firstMatch(commands);
    expect(rule, isNotNull);
    expect(double.parse(rule!.group(1)!), closeTo(contentWidth, 0.01));
  });

  test('diary link card titles are not indented as body paragraphs', () async {
    final commands = await exportPdfBlocks(<Map<String, Object?>>[
      pdfTextBlock('paragraph', 'Body'),
      <String, Object?>{
        'type': 'link_card',
        'data': <String, Object?>{
          'target': 'jotsy://diary/abc',
          'title': 'Linked',
        },
      },
    ], typography: const DiaryTypography(firstLineIndent: 2));
    expect(pdfXsOf(commands, 'Body'), <double>[24]);
    expect(pdfXsOf(commands, 'Linked'), <double>[0]);
  });

  test('a table cell with a bold word and a long Chinese run keeps the '
      'Chinese on the first line instead of pushing it below', () async {
    // 用内置中文字体直接排一张 1×1 的表格（页面上只有它）：标准字体缺
    // 中文，缺字回落会把中文另拆成片段，掩盖这个问题。
    final fonts = await DiaryPdfFonts.load();
    final theme = pw.ThemeData.withFont(
      base: fonts.regular,
      bold: fonts.bold,
      fontFallback: <pw.Font>[fonts.bundled],
    );
    final blocks = pdfEntryOf(<Map<String, Object?>>[
      <String, Object?>{
        'type': 'table',
        'data': <String, Object?>{'rowsLen': 1, 'colsLen': 1},
        'children': <Object?>[
          <String, Object?>{
            'type': 'table/cell',
            'data': <String, Object?>{'rowPosition': 0, 'colPosition': 0},
            'children': <Object?>[
              <String, Object?>{
                'type': 'paragraph',
                'data': <String, Object?>{
                  'delta': <Object?>[
                    <String, Object?>{
                      'insert': '粗',
                      'attributes': <String, Object?>{'bold': true},
                    },
                    <String, Object?>{'insert': '今天天气很好，我们一起去公园散步。' * 6},
                  ],
                },
              },
            ],
          },
        ],
      },
    ]).blocks;
    final document = pw.Document()
      ..addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: theme,
          build: (_) => buildDiaryPdfBody(
            blocks,
            theme: theme,
            codeFont: fonts.bundled,
            effects: DiaryPdfTextEffects(
              regular: fonts.regular,
              bold: fonts.bold,
              bundled: fonts.bundled,
            ),
            images: const <Uint8List>[],
            textDirection: TextDirection.ltr,
          ),
        ),
      );
    final commands = pdfPageCommands(await document.save());
    // 按基线分组的各行文字片段；PDF 的纵坐标向上，第一行最高。
    final lines = <double, List<double>>{};
    for (final run in RegExp(
      r'([-\d.]+) ([-\d.]+) Td \[',
    ).allMatches(commands)) {
      lines
          .putIfAbsent(double.parse(run.group(2)!), () => <double>[])
          .add(double.parse(run.group(1)!));
    }
    final baselines = lines.keys.toList()..sort();
    expect(baselines.length, greaterThan(1));
    // 第一行除了粗体的“粗”，还接着排了中文。
    expect(lines[baselines.last]!.length, greaterThan(1));
  });
}
