import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/ui/diaries/export/diary_export_entry.dart';
import 'package:node_diary/ui/diaries/export/diary_export_format.dart';
import 'package:node_diary/ui/diaries/export/diary_export_html.dart';
import 'package:node_diary/ui/diaries/export/diary_export_media.dart';

import 'diary_export_pdf_test_support.dart';
import 'diary_export_test_fixtures.dart';

/// 网页导出的首行缩进与嵌套缩进：与应用、PDF 与 Word 同一口径。
void main() {
  Future<String> page(
    List<Map<String, Object?>> children, {
    DiaryTypography typography = const DiaryTypography(),
  }) async {
    final output = await DiaryHtmlWriter.write(
      <DiaryExportEntry>[pdfEntryOf(children)],
      options: DiaryExportOptions.defaults.copyWith(includeMeta: false),
      labels: testExportLabels,
      media: DiaryExportMediaLibrary(),
      documentTitle: 'Indent',
      languageTag: 'zh-CN',
      typography: typography,
    );
    return utf8.decode(output.bytes!);
  }

  test('body paragraphs indent their first line like the app; centered '
      'lines, lists and link card titles do not', () async {
    final children = <Map<String, Object?>>[
      pdfTextBlock('paragraph', 'Body'),
      pdfTextBlock('paragraph', 'Marked', data: {'firstLineIndent': true}),
      pdfTextBlock('paragraph', 'Justified', data: {'align': 'justify'}),
      pdfTextBlock('paragraph', 'Centered', data: {'align': 'center'}),
      pdfTextBlock('bulleted_list', 'Item'),
      <String, Object?>{
        'type': 'link_card',
        'data': <String, Object?>{'target': 'jotsy://diary/a', 'title': 'Card'},
      },
    ];
    final plain = await page(children);
    expect(plain, contains('<p>Body</p>'));
    // 工具栏缩进至少两字，不受全局设置为 0 影响。
    expect(plain, contains('<p style="text-indent:2em">Marked</p>'));

    final one = await page(
      children,
      typography: const DiaryTypography(firstLineIndent: 1),
    );
    expect(one, contains('<p style="text-indent:1em">Body</p>'));
    expect(one, contains('<p style="text-indent:2em">Marked</p>'));
    expect(
      one,
      contains('<p style="text-align:justify;text-indent:1em">Justified</p>'),
    );
    expect(one, contains('<p style="text-align:center">Centered</p>'));
    expect(one, contains('<p>Card</p>'));
    expect(one, contains('>Item</li>'));
    expect(one, isNot(contains(RegExp(r'<li[^>]*text-indent'))));
  });

  test('nested blocks keep their depth as a left margin, measured from the '
      'enclosing toggle list', () async {
    final html = await page(<Map<String, Object?>>[
      pdfTextBlock(
        'paragraph',
        'Parent',
        children: <Map<String, Object?>>[
          pdfTextBlock('paragraph', 'Child'),
          pdfTextBlock('quote', 'Quoted'),
          pdfTextBlock('bulleted_list', 'Listed'),
        ],
      ),
      pdfTextBlock(
        'toggle_list',
        'Toggle',
        children: <Map<String, Object?>>[
          pdfTextBlock(
            'paragraph',
            'Inside',
            children: <Map<String, Object?>>[
              pdfTextBlock('paragraph', 'Deeper'),
            ],
          ),
        ],
      ),
    ]);
    expect(html, contains('<p>Parent</p>'));
    expect(html, contains('<p style="margin-left:1.5em">Child</p>'));
    expect(html, contains('<blockquote style="margin-left:1.5em"><p>Quoted'));
    expect(html, contains('<ul style="margin-left:1.5em"><li'));
    // 折叠列表的子块由 details 的内边距缩进，更深的一层再加外边距。
    expect(html, contains('<p>Inside</p>'));
    expect(html, contains('<p style="margin-left:1.5em">Deeper</p>'));
    expect(html, contains('details{margin:4px 0;padding-left:1.4em}'));
  });
}
