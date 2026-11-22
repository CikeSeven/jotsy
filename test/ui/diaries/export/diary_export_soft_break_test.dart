import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/export/diary_export_blocks.dart';
import 'package:node_diary/ui/diaries/export/diary_export_docx.dart';
import 'package:node_diary/ui/diaries/export/diary_export_entry.dart';
import 'package:node_diary/ui/diaries/export/diary_export_epub.dart';
import 'package:node_diary/ui/diaries/export/diary_export_format.dart';
import 'package:node_diary/ui/diaries/export/diary_export_html.dart';
import 'package:node_diary/ui/diaries/export/diary_export_markdown.dart';
import 'package:node_diary/ui/diaries/export/diary_export_media.dart';
import 'package:node_diary/ui/diaries/export/diary_export_plain_text.dart';

import 'diary_export_pdf_test_support.dart';
import 'diary_export_test_fixtures.dart';

/// 块内的软换行（桌面 Shift + Enter、导入的笔记）留在同一块里导出（#341）：
/// 一个编号项里换了行，导出后仍是一项、只有一个序号，下一项的序号接着排。
/// 以前每行拆成一块，网页 / EPUB 每行一个 `<li>`（序号 1、2、3……），PDF、
/// Word 与纯文本每行都重复这一项的序号。

/// 块文档里带一段文字的块（[text] 里的 `\n` 是块内的软换行）。
Map<String, Object?> _block(String type, String text) => <String, Object?>{
  'type': type,
  'data': <String, Object?>{
    'delta': <Object?>[
      <String, Object?>{'insert': text},
    ],
  },
};

/// 与 #341 的截图同一结构：第一项里有两个软换行，后面接第二项。
final List<Map<String, Object?>> _numbered = <Map<String, Object?>>[
  _block('numbered_list', 'Alpha\nBeta\nGamma'),
  _block('numbered_list', 'Delta'),
];

DiaryExportEntry _entry(List<Map<String, Object?>> children) =>
    pdfEntryOf(children);

final DiaryExportOptions _options = DiaryExportOptions.defaults.copyWith(
  includeMeta: false,
  includeMedia: false,
);

Future<String> _html(List<Map<String, Object?>> children) async {
  final output = await DiaryHtmlWriter.write(
    <DiaryExportEntry>[_entry(children)],
    options: _options,
    labels: testExportLabels,
    media: DiaryExportMediaLibrary(),
    documentTitle: 'Soft breaks',
    languageTag: 'en',
  );
  return utf8.decode(output.bytes!);
}

Future<String> _epubChapter(List<Map<String, Object?>> children) async {
  final output = await DiaryEpubWriter.write(
    <DiaryExportEntry>[_entry(children)],
    options: _options,
    labels: testExportLabels,
    media: DiaryExportMediaLibrary(),
    documentTitle: 'Soft breaks',
    languageTag: 'en',
    now: DateTime(2026, 11, 23),
  );
  final chapter = output.files!.firstWhere(
    (DiaryExportBundleFile file) => file.path == 'OEBPS/text/0001.xhtml',
  );
  return utf8.decode(chapter.bytes!);
}

Future<String> _docx(List<Map<String, Object?>> children) async {
  final output = await DiaryDocxWriter.write(
    <DiaryExportEntry>[_entry(children)],
    options: _options,
    labels: testExportLabels,
    media: DiaryExportMediaLibrary(),
    documentTitle: 'Soft breaks',
    languageTag: 'en',
    now: DateTime.utc(2026, 11, 23),
  );
  return utf8.decode(
    output.files!
        .firstWhere(
          (DiaryExportBundleFile file) => file.path == 'word/document.xml',
        )
        .bytes!,
  );
}

Future<String> _markdown(List<Map<String, Object?>> children) async {
  final output = await DiaryMarkdownWriter.write(
    <DiaryExportEntry>[_entry(children)],
    options: _options,
    labels: testExportLabels,
    media: DiaryExportMediaLibrary(),
  );
  // 去掉 YAML front matter，只看正文。
  return utf8.decode(output.bytes!).split('---\n').last.trim();
}

/// 页面流里文字恰为 [word] 的各个片段在页面上的位置，按绘制先后。每个组件
/// 都在自己平移过的坐标系里画字（`q` / `Q` 之间的 `1 0 0 1 x y cm`），`Td`
/// 只是相对它的位置，所以一路累加平移。PDF 原点在左下，越往下 y 越小。
List<({double x, double y})> _pdfPositions(String commands, String word) {
  final found = <({double x, double y})>[];
  final saved = <({double x, double y})>[];
  var origin = (x: 0.0, y: 0.0);
  final token = RegExp(
    r'\bq\b|\bQ\b|1 0 0 1 ([-\d.]+) ([-\d.]+) cm'
    r'|([-\d.]+) ([-\d.]+) Td \[\((.*?)\)\]TJ',
  );
  for (final match in token.allMatches(commands)) {
    switch (match.group(0)) {
      case 'q':
        saved.add(origin);
      case 'Q':
        origin = saved.removeLast();
      case _ when match.group(1) != null:
        origin = (
          x: origin.x + double.parse(match.group(1)!),
          y: origin.y + double.parse(match.group(2)!),
        );
      case _ when match.group(5) == word:
        found.add((
          x: origin.x + double.parse(match.group(3)!),
          y: origin.y + double.parse(match.group(4)!),
        ));
    }
  }
  return found;
}

({double x, double y}) _at(String commands, String word) =>
    _pdfPositions(commands, word).single;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parser', () {
    test('keeps soft-broken lines in one numbered item', () {
      final blocks = _entry(_numbered).blocks;
      expect(blocks.map((ExportBlock b) => b.listMarker), <String>['1.', '2.']);
      expect(blocks.first.inlines.map((ExportInline r) => r.text), <String>[
        'Alpha',
        '\n',
        'Beta',
        '\n',
        'Gamma',
      ]);
      expect(blocks.first.inlines.where((r) => r.isLineBreak), hasLength(2));
      expect(blocks.first.plainText, 'Alpha\nBeta\nGamma');
    });

    test('still splits code blocks into one block per line', () {
      final blocks = _entry(<Map<String, Object?>>[
        _block('code', 'let a\nlet b'),
      ]).blocks;
      expect(blocks.map((ExportBlock b) => b.plainText), <String>[
        'let a',
        'let b',
      ]);
    });

    test('splitLines keeps empty lines between consecutive breaks', () {
      final lines = ExportBlock.splitLines(
        _entry(<Map<String, Object?>>[
          _block('paragraph', 'A\n\nB'),
        ]).blocks.single.inlines,
      );
      expect(
        lines.map((List<ExportInline> l) => l.map((r) => r.text).join()),
        <String>['A', '', 'B'],
      );
    });
  });

  test('html writes one li per item with <br> inside', () async {
    final html = await _html(_numbered);
    expect(
      html,
      contains(
        '<li class="ls-decimal">Alpha<br>Beta<br>Gamma</li>'
        '<li class="ls-decimal">Delta</li>',
      ),
    );
    expect('<li'.allMatches(html), hasLength(2));
  });

  test('epub writes one li per item with <br/> inside', () async {
    final xhtml = await _epubChapter(_numbered);
    expect(
      xhtml,
      contains(
        '<li class="ls-decimal">Alpha<br/>Beta<br/>Gamma</li>'
        '<li class="ls-decimal">Delta</li>',
      ),
    );
    expect(xhtml, isNot(contains('<br>')));
  });

  test('html keeps a soft-broken paragraph in one <p>', () async {
    final html = await _html(<Map<String, Object?>>[
      _block('paragraph', 'Roses\nViolets'),
    ]);
    expect(html, contains('>Roses<br>Violets</p>'));
  });

  test(
    'word writes the marker once and breaks lines in the paragraph',
    () async {
      final document = await _docx(_numbered);
      expect('>1.'.allMatches(document), hasLength(1));
      expect('>2.'.allMatches(document), hasLength(1));
      expect(
        RegExp(
          r'Alpha</w:t></w:r><w:r><w:br/></w:r>.*?Beta</w:t></w:r>'
          r'<w:r><w:br/></w:r>.*?Gamma',
        ).hasMatch(document),
        isTrue,
      );
    },
  );

  test('markdown writes hard breaks aligned under the item', () async {
    expect(
      await _markdown(_numbered),
      '1. Alpha  \n'
      '   Beta  \n'
      '   Gamma\n'
      '2. Delta',
    );
  });

  test('markdown escapes a continuation line that looks like a list', () async {
    expect(
      await _markdown(<Map<String, Object?>>[
        _block('quote', 'Note\n- not a list'),
      ]),
      '> Note  \n'
      '> \\- not a list',
    );
  });

  test('plain text aligns continuation lines under the text', () {
    expect(
      ExportPlainText.render(
        _entry(<Map<String, Object?>>[
          ..._numbered,
          _block('quote', 'Said\nonce'),
          _block('todo_list', 'Buy\nmilk'),
        ]).blocks,
      ),
      '1. Alpha\n'
      '   Beta\n'
      '   Gamma\n'
      '2. Delta\n'
      '> Said\n'
      '> once\n'
      '☐ Buy\n'
      '  milk',
    );
  });

  group('pdf', () {
    test('draws the number once and aligns continuation lines', () async {
      final commands = await exportPdfBlocks(_numbered);
      expect(_pdfPositions(commands, '1.'), hasLength(1));
      expect(_pdfPositions(commands, '2.'), hasLength(1));
      final alpha = _at(commands, 'Alpha');
      final beta = _at(commands, 'Beta');
      final gamma = _at(commands, 'Gamma');
      final delta = _at(commands, 'Delta');
      expect(beta.x, closeTo(alpha.x, 0.01));
      expect(gamma.x, closeTo(alpha.x, 0.01));
      expect(delta.x, closeTo(alpha.x, 0.01));
      // 续行紧接着上一行往下排，与块内折行同样的行距；到下一项才多出列表项
      // 之间的段距（段后 2.5 + 段前 3.5）。
      final line = alpha.y - beta.y;
      expect(beta.y - gamma.y, closeTo(line, 0.01));
      expect(gamma.y - delta.y, closeTo(line + 6, 0.01));
    });

    test('keeps a soft-broken paragraph as one block', () async {
      final commands = await exportPdfBlocks(<Map<String, Object?>>[
        _block('paragraph', 'Roses\nViolets'),
        _block('paragraph', 'Tulips'),
      ]);
      final roses = _at(commands, 'Roses');
      final violets = _at(commands, 'Violets');
      final tulips = _at(commands, 'Tulips');
      expect(violets.x, closeTo(roses.x, 0.01));
      // 段内换行没有段距，到下一段才有。
      final line = roses.y - violets.y;
      expect(violets.y - tulips.y, closeTo(line + 6, 0.01));
    });

    test('draws the callout icon only on its first line', () async {
      final commands = await exportPdfBlocks(<Map<String, Object?>>[
        _block('callout', 'Tip\nMore'),
      ]);
      final tip = _at(commands, 'Tip');
      final more = _at(commands, 'More');
      expect(more.x, closeTo(tip.x, 0.01));
      expect(tip.y, greaterThan(more.y));
      // emoji 图标画成图片：只画一次（续行只占位）。
      expect(RegExp(r'/I\w* Do\b').allMatches(commands), hasLength(1));
    });

    test('pages through list items and callouts taller than a page', () async {
      // 拆成一行一个组件，pdf 库才能在行间分页；整块一个 Row 会因放不下
      // 一页而让整份导出失败。
      final lines = List<String>.generate(160, (int i) => 'Line $i').join('\n');
      final commands = await exportPdfBlocks(<Map<String, Object?>>[
        _block('numbered_list', lines),
        _block('callout', lines),
        _block('toggle_list', lines),
      ]);
      expect(_pdfPositions(commands, '159'), hasLength(3));
      expect(_pdfPositions(commands, '1.'), hasLength(1));
    });
  });
}
