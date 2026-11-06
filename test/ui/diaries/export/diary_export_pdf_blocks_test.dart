import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_typography.dart';

import 'diary_export_pdf_test_support.dart';

/// PDF 里列表、待办、分隔线与日记链接卡片的画法：按页面流里的位置与绘制
/// 命令验证，与应用里看到的一致。
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
}
