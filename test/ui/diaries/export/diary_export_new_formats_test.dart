import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/export/diary_export_blocks.dart';
import 'package:node_diary/ui/diaries/export/diary_export_book.dart';
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
/// 写出器的专门写法（标注、折叠列表、表格、上下标、字号、对齐与深层标题）。
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

    test('table text lines bar-join cells and space-join paragraphs', () {
      String lines(ExportBlock block) => block.tableTextLines
          .map((line) => line.map((ExportInline run) => run.text).join())
          .join('\n');
      expect(lines(blocks[5]), '姓名 | 年龄\n小明 | 十 岁');
      expect(blocks[0].tableTextLines, isEmpty);
    });

    test('size scale follows the editor steps and ignores numbers', () {
      double? scale(Object? size) =>
          ExportInline.fromAttributes('x', {'size': size}).sizeScale;
      expect(scale('small'), 0.85);
      expect(scale('large'), 1.25);
      expect(scale('huge'), 1.5);
      expect(scale(null), isNull);
      // 编辑器把数字字号当正文显示，导出同样不写字号。
      expect(scale(18), isNull);
    });
  });

  group('writers render the new blocks', () {
    test('plain text', () {
      final text = ExportPlainText.render(_writerEntry().blocks);
      expect(
        text,
        contains('☔ 记得带伞\n💡 默认\n▸ 更多\n  里面\n  • 子项\n姓名 | 年龄\n小明 | 十 岁\n新块'),
      );
      expect(text, contains('x2H2O'));
      expect(text, contains('a|b | c\nd | e'));
    });

    test('Markdown', () async {
      final markdown = await _markdown(_writerEntry());
      expect(markdown, contains('x<sup>2</sup>H<sub>2</sub>O'));
      // 标注是以图标开头的引用，两个标注各成一段。
      expect(markdown, contains('> ☔ 记得带伞\n\n> 💡 默认\n\n▸ 更多\n\n里面'));
      expect(markdown, contains('| 姓名 | 年龄 |\n| --- | --- |\n| 小明 | 十<br>岁 |'));
      // 没有表头行：先写一行空表头，第一行数据不被当成表头；| 转义。
      expect(
        markdown,
        contains('|  |  |\n| --- | --- |\n| a\\|b | c |\n| d | e |'),
      );
      expect(markdown, contains('##### H五'));
    });

    test('HTML', () async {
      final html = await _html(_writerEntry());
      expect(html, contains('x<sup>2</sup>H<sub>2</sub>O'));
      expect(
        html,
        contains(
          '<div class="callout callout-blue"><span class="callout-icon">☔'
          '</span><div class="callout-body">记得带伞</div></div>',
        ),
      );
      expect(html, contains('class="callout callout-default"'));
      expect(html, contains('class="callout callout-yellow"'));
      // 每个档位的样式都取纸面配色。
      expect(
        html,
        contains(
          '.callout-yellow{background:#FFF4D6;border-left-color:#F2B200}',
        ),
      );
      expect(
        html,
        contains(
          '<details open><summary>更多</summary>\n<p>里面</p>\n'
          '<ul><li class="ls-disc">子项</li></ul>\n</details>\n',
        ),
      );
      expect(
        html,
        contains(
          '<table><thead><tr><th>姓名</th><th>年龄</th></tr></thead>'
          '<tbody><tr><td>小明</td><td>十<br>岁</td></tr></tbody></table>',
        ),
      );
      expect(
        html,
        contains(
          '<table><tbody><tr><td>a|b</td><td>c</td></tr>'
          '<tr><td>d</td><td>e</td></tr></tbody></table>',
        ),
      );
      expect(html, contains('<span style="font-size:1.25em">大</span>'));
      expect(
        html,
        contains('<blockquote><p style="text-align:center">居中引用</p>'),
      );
      expect(
        html,
        contains('<li class="ls-disc" style="text-align:center">居中列表</li>'),
      );
      // 单篇的正文标题从 h2 起：H5 → h6，H6 超出 h6，带上自己的级别。
      expect(html, contains('<h6>H五</h6>'));
      expect(html, contains('<h6 class="h-level-7" aria-level="7">H六</h6>'));
    });

    test('HTML keeps H5 and H6 distinct in a book', () async {
      final entry = _writerEntry();
      final html = await _html(
        entry,
        book: DiaryExportBookLayout.resolve(
          DiaryExportBook(
            title: '书',
            chapters: <DiaryExportBookChapter>[
              DiaryExportBookChapter(diaryIds: <String>[entry.diaryId]),
            ],
          ),
          <DiaryExportEntry>[entry],
          labels: testBookLabels,
          exportedAt: DateTime(2026, 10, 29),
        ),
      );
      // 篇标题为 h2，正文标题顺延两级：H5 → 7、H6 → 8，仍各是一级。
      expect(html, contains('<h6 class="h-level-7" aria-level="7">H五</h6>'));
      expect(html, contains('<h6 class="h-level-8" aria-level="8">H六</h6>'));
      expect(html, contains('h6.h-level-8{'));
    });

    test('HTML without the new blocks writes no block styles', () async {
      final html = await _html(
        DiaryExportEntry.parse(
          diaryId: 'plain',
          title: 'plain',
          createdAt: DateTime(2026, 10, 29),
          updatedAt: DateTime(2026, 10, 29),
          deltaOps: <dynamic>[
            <String, dynamic>{'insert': 'hello\n'},
          ],
        ),
      );
      expect(html, isNot(contains('.callout')));
      expect(html, isNot(contains('<details')));
    });

    test('Word', () async {
      final output = await DiaryDocxWriter.write(
        <DiaryExportEntry>[_writerEntry()],
        options: _options,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        documentTitle: '格式',
        languageTag: 'zh-CN',
        now: DateTime.utc(2026, 10, 29),
      );
      final parts = {for (final f in output.files!) f.path: f};
      final xml = utf8.decode(parts['word/document.xml']!.bytes!);
      final styles = utf8.decode(parts['word/styles.xml']!.bytes!);
      final document = XmlDocument.parse(xml);
      XmlDocument.parse(styles);
      String text(XmlElement element) =>
          element.findAllElements('w:t').map((t) => t.innerText).join();
      final paragraphs = [
        for (final p in document.findAllElements('w:p')) text(p),
      ];
      expect(paragraphs, containsAllInOrder(['☔ 记得带伞', '💡 默认', '▸ 更多', '里面']));

      // 标注：段落底色与左侧色条取纸面配色。
      final callout = document
          .findAllElements('w:p')
          .firstWhere((p) => text(p) == '☔ 记得带伞');
      expect(
        callout.findAllElements('w:shd').first.getAttribute('w:fill'),
        'E8F0FE',
      );
      expect(
        callout.findAllElements('w:left').first.getAttribute('w:color'),
        '4285F4',
      );

      // 表格：两张，第一张首行是重复的表头，格里每段一个 w:p。
      final tables = document.findAllElements('w:tbl').toList();
      expect(tables, hasLength(2));
      expect(tables.first.findAllElements('w:tblHeader'), hasLength(1));
      expect(tables.last.findAllElements('w:tblHeader'), isEmpty);
      expect(
        tables.first.findAllElements('w:tblW').single.getAttribute('w:type'),
        'pct',
      );
      expect(tables.first.findAllElements('w:gridCol'), hasLength(2));
      final cells = tables.first.findAllElements('w:tc').toList();
      expect(cells[3].findAllElements('w:p').map(text), ['十', '岁']);
      expect(cells.first.findAllElements('w:b'), isNotEmpty);
      expect(cells[2].findAllElements('w:b'), isEmpty);

      expect(xml, contains('<w:vertAlign w:val="superscript"/>'));
      expect(xml, contains('<w:vertAlign w:val="subscript"/>'));
      // 正文 16px = 24 半磅，大号 ×1.25。
      expect(xml, contains('<w:sz w:val="30"/><w:szCs w:val="30"/>'));
      final quote = document
          .findAllElements('w:p')
          .firstWhere((p) => text(p) == '居中引用');
      expect(
        quote.findAllElements('w:jc').single.getAttribute('w:val'),
        'center',
      );
      final list = document
          .findAllElements('w:p')
          .firstWhere((p) => text(p).endsWith('居中列表'));
      expect(list.findAllElements('w:jc'), isNotEmpty);
      expect(xml, contains('<w:pStyle w:val="Heading5"/>'));
      expect(xml, contains('<w:pStyle w:val="Heading6"/>'));
      expect(styles, contains('w:styleId="Heading5"'));
      expect(styles, contains('w:styleId="Heading6"'));
    });

    test('PDF draws the new blocks without missing glyphs', () async {
      final body = await DiaryPdfWriter.prepareBody(
        _writerEntry(),
        includeImages: false,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        images: <Uint8List>[],
      );
      expect(
        body!.map((ExportBlock b) => b.kind),
        containsAllInOrder([
          ExportBlockKind.callout,
          ExportBlockKind.toggle,
          ExportBlockKind.table,
        ]),
      );

      final printed = <String>[];
      final fonts = await DiaryPdfFonts.load();
      final output = await runZoned(
        () => DiaryPdfWriter.write(
          <DiaryExportEntry>[_writerEntry()],
          options: _options,
          labels: testExportLabels,
          media: DiaryExportMediaLibrary(),
          fonts: fonts,
          documentTitle: '格式',
        ),
        zoneSpecification: ZoneSpecification(
          print: (_, _, _, String line) => printed.add(line),
        ),
      );
      expect(ascii.decode(output.bytes!.sublist(0, 5)), '%PDF-');
      // 标注图标（emoji）不写进 PDF，折叠列表的三角是矢量图形：内置字体
      // 没有这些字形，写成文字会报缺字并印成方框。
      expect(
        printed.where((String line) => line.contains('Unable to find a font')),
        isEmpty,
      );
    });

    test('PDF lets a long table break between rows', () async {
      final rows = 80;
      final entry = DiaryExportEntry.parse(
        diaryId: 'long-table',
        title: 'table',
        createdAt: DateTime(2026, 10, 29),
        updatedAt: DateTime(2026, 10, 29),
        blockDocument: {
          'document': {
            'type': 'page',
            'children': [
              {
                'type': 'table',
                'children': [
                  for (var row = 0; row < rows; row++)
                    for (var col = 0; col < 2; col++)
                      _cell(row, col, ['第 $row 行']),
                ],
                'data': {'rowsLen': rows, 'colsLen': 2, 'headerRow': true},
              },
            ],
          },
        },
      );
      final output = await DiaryPdfWriter.write(
        <DiaryExportEntry>[entry],
        options: _options,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        fonts: await DiaryPdfFonts.load(),
        documentTitle: 'table',
      );
      final pages = RegExp(
        r'/Type\s*/Page\b',
      ).allMatches(latin1.decode(output.bytes!)).length;
      expect(pages, greaterThan(1));
    });
  });
}

/// 写出器测试用的正文：解析器测试那一份，再加上标题、对齐、字号与没有
/// 表头的表格。
DiaryExportEntry _writerEntry() {
  final children = [
    ...((_document['document']! as Map)['children'] as List),
    _plain('callout', '黄色', data: {'tone': 'yellow'}),
    _text('paragraph', [
      {'insert': '正文'},
      {
        'insert': '大',
        'attributes': {'size': 'large'},
      },
    ]),
    _plain('quote', '居中引用', data: {'align': 'center'}),
    _plain('bulleted_list', '居中列表', data: {'align': 'center'}),
    _plain('heading', 'H五', data: {'level': 5}),
    _plain('heading', 'H六', data: {'level': 6}),
    {
      'type': 'table',
      'children': [
        _cell(0, 0, ['a|b']),
        _cell(0, 1, ['c']),
        _cell(1, 0, ['d']),
        _cell(1, 1, ['e']),
      ],
      'data': {'rowsLen': 2, 'colsLen': 2},
    },
  ];
  // 折叠列表多一个列表子项：网页里收进同一个 <details>。
  final toggle = children.indexWhere(
    (node) => (node as Map)['type'] == 'toggle_list',
  );
  children[toggle] = _text(
    'toggle_list',
    [
      {'insert': '更多'},
    ],
    data: {'collapsed': true},
    children: [_plain('paragraph', '里面'), _plain('bulleted_list', '子项')],
  );
  return DiaryExportEntry.parse(
    diaryId: 'writers',
    title: '格式',
    createdAt: DateTime(2026, 10, 29, 9),
    updatedAt: DateTime(2026, 10, 29, 9),
    blockDocument: {
      'document': {'type': 'page', 'children': children},
    },
  );
}

Future<String> _markdown(DiaryExportEntry entry) async {
  final output = await DiaryMarkdownWriter.write(
    <DiaryExportEntry>[entry],
    options: _options,
    labels: testExportLabels,
    media: DiaryExportMediaLibrary(),
  );
  return utf8.decode(output.bytes!);
}

Future<String> _html(
  DiaryExportEntry entry, {
  DiaryExportBookLayout? book,
}) async {
  final output = await DiaryHtmlWriter.write(
    <DiaryExportEntry>[entry],
    options: _options,
    labels: testExportLabels,
    media: DiaryExportMediaLibrary(),
    documentTitle: '格式',
    languageTag: 'zh',
    book: book,
  );
  return utf8.decode(output.bytes!);
}
