import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/export/diary_export_blocks.dart';
import 'package:node_diary/ui/diaries/export/diary_export_docx.dart';
import 'package:node_diary/ui/diaries/export/diary_export_entry.dart';
import 'package:node_diary/ui/diaries/export/diary_export_format.dart';
import 'package:node_diary/ui/diaries/export/diary_export_html.dart';
import 'package:node_diary/ui/diaries/export/diary_export_markdown.dart';
import 'package:node_diary/ui/diaries/export/diary_export_media.dart';
import 'package:node_diary/ui/diaries/export/diary_export_pdf.dart';
import 'package:node_diary/ui/diaries/export/diary_export_plain_text.dart';
import 'package:xml/xml.dart';

import 'diary_export_test_fixtures.dart';

/// 标注、折叠列表、表格、上下标与认不出的块在导出模型里的样子，以及各
/// 写出器在补上专门写法之前的退化写法（内容不丢）。
Map<String, Object?> _text(
  String type,
  List<Map<String, Object?>> delta, {
  Map<String, Object?> data = const {},
  List<Map<String, Object?>> children = const [],
}) => {
  'type': type,
  if (children.isNotEmpty) 'children': children,
  'data': {...data, 'delta': delta},
};

Map<String, Object?> _plain(
  String type,
  String text, {
  Map<String, Object?> data = const {},
}) => _text(type, [
  {'insert': text},
], data: data);

Map<String, Object?> _cell(int row, int col, List<String> paragraphs) => {
  'type': 'table/cell',
  'children': [for (final text in paragraphs) _plain('paragraph', text)],
  'data': {'rowPosition': row, 'colPosition': col},
};

final Map<String, Object?> _document = {
  'document': {
    'type': 'page',
    'children': [
      _text('paragraph', [
        {'insert': 'x'},
        {
          'insert': '2',
          'attributes': {'script': 'super'},
        },
        {'insert': 'H'},
        {
          'insert': '2',
          'attributes': {'script': 'sub'},
        },
        {
          'insert': 'O',
          'attributes': {'script': 'weird'},
        },
      ]),
      _plain('callout', '记得带伞', data: {'icon': '☔', 'tone': 'blue'}),
      _plain('callout', '默认', data: {'tone': 'orange'}),
      _text(
        'toggle_list',
        [
          {'insert': '更多'},
        ],
        data: {'collapsed': true},
        children: [_plain('paragraph', '里面')],
      ),
      {
        'type': 'table',
        'children': [
          _cell(0, 0, ['姓名']),
          _cell(0, 1, ['年龄']),
          _cell(1, 0, ['小明']),
          _cell(1, 1, ['十', '岁']),
        ],
        'data': {'rowsLen': 2, 'colsLen': 2, 'headerRow': true},
      },
      _plain('future_block', '新块'),
      {
        'type': 'quill_embed',
        'data': {
          'value': {
            'file': {'path': '/private/a.pdf', 'name': 'a.pdf'},
            'extra': 1,
          },
        },
      },
      _plain('paragraph', 'end'),
    ],
  },
};

DiaryExportEntry _entry() => DiaryExportEntry.parse(
  diaryId: 'formats',
  title: '格式',
  createdAt: DateTime(2026, 10, 29, 9),
  updatedAt: DateTime(2026, 10, 29, 9),
  blockDocument: _document,
);

final DiaryExportOptions _options = DiaryExportOptions.defaults.copyWith(
  includeMeta: false,
  includeMedia: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('native parser', () {
    final blocks = ExportBlockParser.parseDocument(_document);

    test(
      'emits callout, toggle and table kinds, and table cells only once',
      () {
        expect(blocks.map((ExportBlock b) => (b.kind, b.indent)), [
          (ExportBlockKind.paragraph, 0),
          (ExportBlockKind.callout, 0),
          (ExportBlockKind.callout, 0),
          (ExportBlockKind.toggle, 0),
          // 折叠列表的子块照常以更深的缩进跟在后面。
          (ExportBlockKind.paragraph, 1),
          (ExportBlockKind.table, 0),
          // 认不出的块带文字：按段落导出。
          (ExportBlockKind.paragraph, 0),
          // 原样保留的历史嵌入按 Quill 嵌入认读。
          (ExportBlockKind.media, 0),
          (ExportBlockKind.paragraph, 0),
        ]);
        expect(blocks[6].plainText, '新块');
        expect(blocks[7].mediaName, 'a.pdf');
      },
    );

    test('callouts carry their icon and tone with defaults', () {
      expect((blocks[1].calloutIcon, blocks[1].calloutTone), ('☔', 'blue'));
      expect(blocks[1].plainText, '记得带伞');
      // 没有图标用缺省图标，认不出的档位按 default。
      expect((blocks[2].calloutIcon, blocks[2].calloutTone), ('💡', 'default'));
      expect(blocks[0].calloutIcon, isNull);
    });

    test('tables carry rows of cells and the header flag', () {
      final table = blocks[5];
      expect(table.tableHeaderRow, isTrue);
      expect(table.inlines, isEmpty);
      List<String> texts(List<ExportInline> cell) => [
        for (final run in cell) run.text,
      ];
      expect(
        [
          for (final row in table.tableRows)
            [for (final cell in row) texts(cell)],
        ],
        [
          [
            ['姓名'],
            ['年龄'],
          ],
          [
            ['小明'],
            // 一格里的两段之间是一个换行片段。
            ['十', '\n', '岁'],
          ],
        ],
      );
      expect(table.tableRows[1][1][1].isLineBreak, isTrue);
      expect(table.plainText, '姓名 | 年龄\n小明 | 十 岁');
      expect(blocks.first.tableRows, isEmpty);
    });

    test('inlines carry superscript and subscript', () {
      expect(blocks.first.inlines.map((ExportInline run) => run.script), [
        null,
        ExportScript.superscript,
        null,
        ExportScript.subscript,
        null,
      ]);
    });

    test('fallback lines prefix callouts and toggles and bar-join table '
        'rows', () {
      String lines(ExportBlock block) => block.fallbackLines
          .map((line) => line.map((ExportInline run) => run.text).join())
          .join('\n');
      expect(lines(blocks[1]), '☔ 记得带伞');
      expect(lines(blocks[3]), '▸ 更多');
      expect(lines(blocks[5]), '姓名 | 年龄\n小明 | 十 岁');
      expect(lines(blocks[0]), 'x2H2O');
    });
  });

  group('writers keep the new blocks as paragraphs', () {
    test('plain text', () {
      final text = ExportPlainText.render(_entry().blocks);
      expect(
        text,
        contains('☔ 记得带伞\n💡 默认\n▸ 更多\n  里面\n姓名 | 年龄\n小明 | 十 岁\n新块'),
      );
    });

    test('Markdown', () async {
      final output = await DiaryMarkdownWriter.write(
        <DiaryExportEntry>[_entry()],
        options: _options,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
      );
      final markdown = utf8.decode(output.bytes!);
      expect(markdown, contains('☔ 记得带伞\n\n💡 默认\n\n▸ 更多'));
      expect(markdown, contains('姓名 | 年龄\n\n小明 | 十 岁\n\n新块'));
    });

    test('HTML', () async {
      final output = await DiaryHtmlWriter.write(
        <DiaryExportEntry>[_entry()],
        options: _options,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        documentTitle: '格式',
        languageTag: 'zh',
      );
      final html = utf8.decode(output.bytes!);
      expect(html, contains('<p>☔ 记得带伞</p>'));
      expect(html, contains('<p>姓名 | 年龄</p>\n<p>小明 | 十 岁</p>'));
    });

    test('Word', () async {
      final output = await DiaryDocxWriter.write(
        <DiaryExportEntry>[_entry()],
        options: _options,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        documentTitle: '格式',
        languageTag: 'zh-CN',
        now: DateTime.utc(2026, 10, 29),
      );
      final parts = {for (final f in output.files!) f.path: f};
      final document = XmlDocument.parse(
        utf8.decode(parts['word/document.xml']!.bytes!),
      );
      final paragraphs = [
        for (final p in document.findAllElements('w:p'))
          p.findAllElements('w:t').map((t) => t.innerText).join(),
      ];
      expect(
        paragraphs,
        containsAllInOrder(['☔ 记得带伞', '▸ 更多', '姓名 | 年龄', '小明 | 十 岁']),
      );
    });

    test(
      'PDF prepares them as paragraphs and exports without throwing',
      () async {
        final body = await DiaryPdfWriter.prepareBody(
          _entry(),
          includeImages: false,
          labels: testExportLabels,
          media: DiaryExportMediaLibrary(),
          images: <Uint8List>[],
        );
        expect(
          body!.where((ExportBlock b) => b.kind != ExportBlockKind.paragraph),
          isEmpty,
        );
        expect(
          body.map((ExportBlock b) => b.plainText),
          containsAllInOrder(['☔ 记得带伞', '▸ 更多', '里面', '姓名 | 年龄', '小明 | 十 岁']),
        );

        final output = await DiaryPdfWriter.write(
          <DiaryExportEntry>[_entry()],
          options: _options,
          labels: testExportLabels,
          media: DiaryExportMediaLibrary(),
          fonts: await DiaryPdfFonts.load(),
          documentTitle: '格式',
        );
        expect(ascii.decode(output.bytes!.sublist(0, 5)), '%PDF-');
      },
    );
  });
}
