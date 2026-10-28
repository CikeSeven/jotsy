import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/ui/diaries/export/diary_export_docx.dart';
import 'package:node_diary/ui/diaries/export/diary_export_entry.dart';
import 'package:node_diary/ui/diaries/export/diary_export_format.dart';
import 'package:node_diary/ui/diaries/export/diary_export_media.dart';
import 'package:xml/xml.dart';

import 'diary_export_test_fixtures.dart';

/// 验证 Word 实际采用的正文样式及继承边界，而非只检查设置是否传入。
void main() {
  Future<XmlDocument> styles(DiaryTypography typography) async {
    final output = await DiaryDocxWriter.write(
      [richEntry()],
      options: DiaryExportOptions.defaults,
      labels: testExportLabels,
      media: DiaryExportMediaLibrary(),
      documentTitle: 'Typography',
      languageTag: 'zh-CN',
      typography: typography,
    );
    return XmlDocument.parse(
      utf8.decode(
        output.files!.singleWhere((f) => f.path == 'word/styles.xml').bytes!,
      ),
    );
  }

  Future<XmlDocument> body(DiaryTypography typography) async {
    final entry = DiaryExportEntry.parse(
      diaryId: 'indent',
      title: '缩进',
      createdAt: DateTime(2026, 4, 3, 9, 5),
      updatedAt: DateTime(2026, 4, 3, 9, 5),
      tagNames: const <String>[],
      metadata: testMetadata,
      deltaOps: <dynamic>[
        <String, dynamic>{'insert': '第一段正文\n居中的一行'},
        <String, dynamic>{
          'insert': '\n',
          'attributes': <String, dynamic>{'align': 'center'},
        },
        <String, dynamic>{'insert': '列表项'},
        <String, dynamic>{
          'insert': '\n',
          'attributes': <String, dynamic>{'list': 'bullet'},
        },
      ],
    );
    final output = await DiaryDocxWriter.write(
      [entry],
      options: DiaryExportOptions.defaults,
      labels: testExportLabels,
      media: DiaryExportMediaLibrary(),
      documentTitle: 'Indent',
      languageTag: 'zh-CN',
      typography: typography,
    );
    return XmlDocument.parse(
      utf8.decode(
        output.files!.singleWhere((f) => f.path == 'word/document.xml').bytes!,
      ),
    );
  }

  /// 文字为 [text] 的段落的 `w:ind`；没有缩进时为 null。
  XmlElement? indentOf(XmlDocument document, String text) => document
      .findAllElements('w:p')
      .singleWhere((p) => p.innerText.contains(text))
      .getElement('w:pPr')
      ?.getElement('w:ind');

  XmlElement style(XmlDocument document, String id) => document
      .findAllElements('w:style')
      .singleWhere((e) => e.getAttribute('w:styleId') == id);

  test('Word uses the selected body metrics instead of 1.5 lines and 6pt '
      'after every paragraph', () async {
    final document = await styles(
      const DiaryTypography(
        fontSize: 24,
        lineHeight: 2.2,
        letterSpacing: 1.25,
        paragraphSpacing: 12,
      ),
    );
    final normal = style(document, 'Normal');
    final spacing = normal.getElement('w:pPr')!.getElement('w:spacing')!;
    expect(spacing.getAttribute('w:line'), '528');
    expect(spacing.getAttribute('w:lineRule'), 'auto');
    expect(spacing.getAttribute('w:after'), '180');
    final run = normal.getElement('w:rPr')!;
    // 24px = 18pt，字距 1.25px = 0.9375pt；Word 分别按半磅 / twip 取整。
    expect(run.getElement('w:sz')!.getAttribute('w:val'), '36');
    expect(run.getElement('w:szCs')!.getAttribute('w:val'), '36');
    expect(run.getElement('w:spacing')!.getAttribute('w:val'), '19');
    expect(run.childElements.map((e) => e.name.qualified), [
      'w:spacing',
      'w:sz',
      'w:szCs',
    ]);
  });

  test('lists and quotes inherit body metrics without the extra paragraph '
      'gap; headings only follow tracking', () async {
    final document = await styles(
      const DiaryTypography(
        fontSize: 28,
        lineHeight: 3,
        letterSpacing: 2,
        paragraphSpacing: 48,
      ),
    );
    for (final id in ['DiaryList', 'Quote']) {
      final element = style(document, id);
      expect(element.getElement('w:basedOn')!.getAttribute('w:val'), 'Normal');
      final spacing = element.getElement('w:pPr')!.getElement('w:spacing')!;
      expect(spacing.getAttribute('w:after'), '120');
      expect(spacing.getAttribute('w:line'), isNull);
    }
    final heading = style(document, 'Heading1');
    expect(heading.getElement('w:basedOn'), isNull);
    final run = heading.getElement('w:rPr')!;
    expect(run.getElement('w:sz')!.getAttribute('w:val'), '32');
    expect(run.getElement('w:spacing')!.getAttribute('w:val'), '30');
    // 抬头与代码不继承正文参数，否则调大行距 / 字距会破坏各自的版式。
    for (final id in ['Title', 'DiaryMeta', 'CodeBlock']) {
      expect(style(document, id).getElement('w:basedOn'), isNull);
    }
    final code = style(document, 'CodeBlock');
    expect(
      code.getElement('w:rPr')!.getElement('w:sz')!.getAttribute('w:val'),
      '20',
    );
    final spacing = code.getElement('w:pPr')!.getElement('w:spacing')!;
    expect(spacing.getAttribute('w:line'), '276');
    expect(spacing.getAttribute('w:after'), '0');
  });

  test(
    'default typography has the app line height and no paragraph gap',
    () async {
      final normal = style(await styles(const DiaryTypography()), 'Normal');
      final spacing = normal.getElement('w:pPr')!.getElement('w:spacing')!;
      expect(spacing.getAttribute('w:line'), '372');
      expect(spacing.getAttribute('w:after'), '0');
      final run = normal.getElement('w:rPr')!;
      expect(run.getElement('w:sz')!.getAttribute('w:val'), '24');
      expect(run.getElement('w:spacing')!.getAttribute('w:val'), '0');
    },
  );

  test('negative tracking and single spacing remain valid at the lower '
      'bounds', () async {
    final normal = style(
      await styles(
        const DiaryTypography(fontSize: 10, lineHeight: 1, letterSpacing: -1),
      ),
      'Normal',
    );
    final spacing = normal.getElement('w:pPr')!.getElement('w:spacing')!;
    expect(spacing.getAttribute('w:line'), '240');
    expect(spacing.getAttribute('w:after'), '0');
    final run = normal.getElement('w:rPr')!;
    expect(run.getElement('w:sz')!.getAttribute('w:val'), '15');
    expect(run.getElement('w:spacing')!.getAttribute('w:val'), '-15');
  });

  test('body paragraphs indent their first line by whole characters; '
      'centered lines and lists do not', () async {
    final document = await body(
      const DiaryTypography(fontSize: 18, letterSpacing: 2, firstLineIndent: 2),
    );
    // 两个字 = 2 × (18px + 2px) = 40px = 30pt = 600 twip。
    final indent = indentOf(document, '第一段正文')!;
    expect(indent.getAttribute('w:firstLine'), '600');
    expect(indent.getAttribute('w:left'), isNull);
    expect(indentOf(document, '居中的一行'), isNull);
    final list = indentOf(document, '列表项')!;
    expect(list.getAttribute('w:hanging'), '420');
    expect(list.getAttribute('w:firstLine'), isNull);
  });

  test('without an indent body paragraphs carry no w:ind', () async {
    final document = await body(const DiaryTypography());
    expect(indentOf(document, '第一段正文'), isNull);
  });
}
