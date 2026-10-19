import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/export/diary_export_book.dart';
import 'package:node_diary/ui/diaries/export/diary_export_docx.dart';
import 'package:node_diary/ui/diaries/export/diary_export_entry.dart';
import 'package:node_diary/ui/diaries/export/diary_export_format.dart';
import 'package:node_diary/ui/diaries/export/diary_export_html.dart';
import 'package:node_diary/ui/diaries/export/diary_export_markdown.dart';
import 'package:node_diary/ui/diaries/export/diary_export_media.dart';
import 'package:node_diary/ui/diaries/export/diary_export_pdf.dart';
import 'package:node_diary/ui/diaries/export/diary_export_text.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../../../support/export_test_images.dart';
import 'diary_export_test_fixtures.dart';

/// 导出成书：版式解析（空章、未分章、锚点、扉页统计）与各写出器的扉页、
/// 目录与章节标题。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late String coverPath;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('export_book_');
    coverPath = p.join(temp.path, 'private cover.jpg');
    await File(coverPath).writeAsBytes(base64Decode(jpgBase64));
  });
  tearDown(() => temp.delete(recursive: true));

  DiaryExportEntry plain(String id, String title, DateTime createdAt) {
    return DiaryExportEntry.parse(
      diaryId: id,
      title: title,
      createdAt: createdAt,
      updatedAt: createdAt,
      deltaOps: <dynamic>[
        <String, dynamic>{'insert': '$title 的正文\n'},
      ],
    );
  }

  final a = plain('a', '出发', DateTime(2026, 4, 1, 8));
  final b = plain('b', '到达', DateTime(2026, 4, 2, 9));
  final c = plain('c', '回家', DateTime(2026, 5, 2, 20));

  DiaryExportBook book({String? cover}) => DiaryExportBook(
    title: '旅行日记',
    description: ' 走过的路 ',
    coverPath: cover,
    chapters: <DiaryExportBookChapter>[
      DiaryExportBookChapter(title: '春', diaryIds: <String>['a', 'b']),
      // 整章都是未解封的胶囊：导出时连同标题一起去掉。
      DiaryExportBookChapter(title: '空章', diaryIds: <String>['sealed']),
      DiaryExportBookChapter(diaryIds: <String>['c']),
    ],
  );

  DiaryExportBookLayout layout(
    List<DiaryExportEntry> entries, {
    DiaryExportBook? from,
  }) => DiaryExportBookLayout.resolve(
    from ?? book(),
    entries,
    labels: testBookLabels,
    exportedAt: DateTime(2026, 10, 19, 12),
  );

  group('DiaryExportBookLayout', () {
    test('drops empty chapters and names the unassigned group', () {
      final resolved = layout(<DiaryExportEntry>[a, b, c]);
      expect(resolved.title, '旅行日记');
      expect(resolved.description, '走过的路');
      expect(resolved.hasChapterHeadings, isTrue);
      expect(resolved.sections.map((s) => '${s.anchor} ${s.title}'), <String>[
        'chapter-1 春',
        'chapter-2 未分章',
      ]);
      expect(resolved.entries.map(resolved.anchorOf), <String>[
        'entry-1',
        'entry-2',
        'entry-3',
      ]);
      expect(resolved.summaryLine, '2026-4-1 – 2026-5-2 · 3 篇');
      expect(resolved.exportedLine, '导出于 2026-10-19');
      expect(resolved.contentsTitle, '目录');
    });

    test('writes no chapter headings when only unassigned entries remain', () {
      final resolved = layout(<DiaryExportEntry>[c, a]);
      // a 在第一章，c 未分章：仍有带名称的章节。
      expect(resolved.hasChapterHeadings, isTrue);

      final onlyLoose = layout(
        <DiaryExportEntry>[c],
        from: DiaryExportBook(
          title: '散篇',
          chapters: <DiaryExportBookChapter>[
            DiaryExportBookChapter(title: '胶囊章', diaryIds: <String>['x']),
            DiaryExportBookChapter(diaryIds: <String>['c']),
          ],
        ),
      );
      expect(onlyLoose.hasChapterHeadings, isFalse);
      expect(onlyLoose.sections.single.title, isNull);
      expect(onlyLoose.description, isNull);
    });

    test('arranges by the book and appends unknown entries at the end', () {
      final arranged = book().arrange(<DiaryExportEntry>[
        plain('z', '书外', DateTime(2020)),
        c,
        b,
        a,
      ], (DiaryExportEntry e) => e.diaryId);
      expect(arranged.map((e) => e.diaryId), <String>['a', 'b', 'c', 'z']);
      final resolved = layout(arranged);
      expect(resolved.sections.last.entries.map((e) => e.diaryId), <String>[
        'c',
        'z',
      ]);
    });
  });

  test('plain text has a title page, contents and ruled chapter headings', () {
    final resolved = layout(<DiaryExportEntry>[a, b, c]);
    final text = utf8.decode(
      DiaryTextWriter.write(
        resolved.entries,
        options: DiaryExportOptions.defaults,
        labels: testExportLabels,
        book: resolved,
      ).bytes!,
    );
    expect(
      text,
      startsWith(
        '旅行日记\n走过的路\n2026-4-1 – 2026-5-2 · 3 篇\n导出于 2026-10-19\n\n'
        '${DiaryTextWriter.bookRule}\n\n'
        '目录\n\n春\n  2026-4-1  出发\n  2026-4-2  到达\n未分章\n  2026-5-2  回家\n\n'
        '${DiaryTextWriter.bookRule}\n\n'
        '春\n${DiaryTextWriter.chapterRule}\n\n出发\n',
      ),
    );
    expect(
      text,
      contains(
        '${DiaryTextWriter.separator}\n\n到达\n2026年4月2日 09:00\n\n到达 的正文\n\n'
        '${DiaryTextWriter.bookRule}\n\n未分章\n${DiaryTextWriter.chapterRule}\n\n回家',
      ),
    );
  });

  test('Markdown is one book file with anchors, shifted headings and the '
      'cover bundled without device paths', () async {
    final rich = richEntry();
    final resolved = layout(<DiaryExportEntry>[
      rich,
      c,
    ], from: _withIds(book(cover: coverPath), first: rich.diaryId));
    final output = await DiaryMarkdownWriter.write(
      resolved.entries,
      options: DiaryExportOptions.defaults,
      labels: testExportLabels,
      media: DiaryExportMediaLibrary(),
      book: resolved,
      documentStem: '旅行日记',
    );
    expect(output.files!.map((f) => f.path), <String>[
      '旅行日记.md',
      'media/0001.jpg',
    ]);
    expect(output.files![1].file!.path, coverPath);
    final markdown = utf8.decode(output.files!.first.bytes!);
    expect(
      markdown,
      startsWith(
        '# 旅行日记\n\n![](media/0001.jpg)\n\n走过的路\n\n'
        '2026-4-3 – 2026-5-2 · 2 篇\n\n导出于 2026-10-19\n\n## 目录\n\n'
        '- [春](#chapter-1)\n    - [2026-4-3  春日 \\*小记\\*](#entry-1)\n'
        '- [未分章](#chapter-2)\n    - [2026-5-2  回家](#entry-2)\n\n'
        '# <a id="chapter-1"></a>春\n\n'
        '## <a id="entry-1"></a>春日 \\*小记\\*\n\n'
        '2026年4月3日 09:05 · 晴 · 杭州西湖 · 😊 · 精力 4/5\n\n#旅行 #美食\n\n今天',
      ),
    );
    // 正文的二级标题顺延到四级。
    expect(markdown, contains('\n#### 小标题\n'));
    expect(markdown, contains('# <a id="chapter-2"></a>未分章'));
    expect(markdown, isNot(contains('title: ')));
    expect(markdown, isNot(contains(temp.path)));
  });

  test('HTML has a title page, linked contents, chapter sections and '
      'demoted entry headings', () async {
    final rich = richEntry();
    final resolved = layout(<DiaryExportEntry>[
      rich,
      c,
    ], from: _withIds(book(cover: coverPath), first: rich.diaryId));
    final output = await DiaryHtmlWriter.write(
      resolved.entries,
      options: DiaryExportOptions.defaults,
      labels: testExportLabels,
      media: DiaryExportMediaLibrary(),
      documentTitle: '旅行日记',
      languageTag: 'zh',
      book: resolved,
    );
    // 多篇带图：页面 + media/，封面按原文件流式打包。
    expect(output.files!.map((f) => f.path), <String>[
      'index.html',
      'media/0001.jpg',
    ]);
    final html = utf8.decode(output.files!.first.bytes!);
    final order = <String>[
      '<section class="book-title">',
      '<img src="media/0001.jpg"',
      '<h1>旅行日记</h1>',
      '<p class="book-description">走过的路</p>',
      '2026-4-3 – 2026-5-2 · 2 篇',
      '导出于 2026-10-19',
      '<nav class="toc">',
      '<h2>目录</h2>',
      '<a href="#chapter-1">春</a>',
      '<a href="#entry-1">',
      '<a href="#chapter-2">未分章</a>',
      '<a href="#entry-2">',
      '<h1 class="chapter-title" id="chapter-1">春</h1>',
      '<article id="entry-1">',
      '<h2>春日 *小记*</h2>',
      '<h4>小标题</h4>',
      '<h1 class="chapter-title" id="chapter-2">未分章</h1>',
      '<article id="entry-2">',
      '<h2>回家</h2>',
    ];
    var last = -1;
    for (final marker in order) {
      final index = html.indexOf(marker, last + 1);
      expect(index, greaterThan(last), reason: marker);
      last = index;
    }
    expect(html, contains('.chapter{break-before:page}'));
    expect(html, isNot(contains(temp.path)));
  });

  test('a one-entry HTML book inlines the cover as a data URI', () async {
    final resolved = layout(<DiaryExportEntry>[
      c,
    ], from: book(cover: coverPath));
    final output = await DiaryHtmlWriter.write(
      resolved.entries,
      options: DiaryExportOptions.defaults,
      labels: testExportLabels,
      media: DiaryExportMediaLibrary(),
      documentTitle: '旅行日记',
      languageTag: 'zh',
      book: resolved,
    );
    expect(output.isBundle, isFalse);
    final html = utf8.decode(output.bytes!);
    expect(html, contains('<figure class="book-cover"><img src="data:image/'));
    // 只剩未分章：不写章节标题，目录直接列出各篇。
    expect(html, isNot(contains('class="chapter-title"')));
    expect(html, contains('<a href="#entry-1">'));
  });

  test('Word adds a title page, a linked contents list and chapters that '
      'start new pages', () async {
    final resolved = layout(<DiaryExportEntry>[
      a,
      b,
      c,
    ], from: book(cover: coverPath));
    final output = await DiaryDocxWriter.write(
      resolved.entries,
      options: DiaryExportOptions.defaults,
      labels: testExportLabels,
      media: DiaryExportMediaLibrary(),
      documentTitle: '旅行日记',
      languageTag: 'zh-CN',
      now: DateTime.utc(2026, 10, 19),
      book: resolved,
    );
    final files = {for (final f in output.files!) f.path: f};
    // 封面按原文件流式写入，文档里不出现设备路径。
    expect(files['word/media/image1.jpeg']!.file!.path, coverPath);
    final documentXml = utf8.decode(files['word/document.xml']!.bytes!);
    expect(documentXml, isNot(contains(temp.path)));
    final document = XmlDocument.parse(documentXml);
    final styles = XmlDocument.parse(
      utf8.decode(files['word/styles.xml']!.bytes!),
    );

    String? styleOf(XmlElement paragraph) => paragraph
        .findAllElements('w:pStyle')
        .firstOrNull
        ?.getAttribute('w:val');
    String textOf(XmlElement paragraph) =>
        paragraph.findAllElements('w:t').map((e) => e.innerText).join();

    final paragraphs = document.findAllElements('w:p').toList();
    final styled = <String>[
      for (final paragraph in paragraphs)
        if (styleOf(paragraph) case final String style
            when style.startsWith('Book') || style.startsWith('Toc'))
          '$style ${textOf(paragraph)}',
    ];
    expect(styled, <String>[
      'BookTitle 旅行日记',
      'BookDescription 走过的路',
      'BookMeta 2026-4-1 – 2026-5-2 · 3 篇',
      'BookMeta 导出于 2026-10-19',
      'TocHeading 目录',
      'TocChapter 春',
      'TocEntry 2026-4-1出发',
      'TocEntry 2026-4-2到达',
      'TocChapter 未分章',
      'TocEntry 2026-5-2回家',
      'BookChapter 春',
      'BookEntry 出发',
      'BookEntry 到达',
      'BookChapter 未分章',
      'BookEntry 回家',
    ]);
    expect(
      document
          .findAllElements('w:hyperlink')
          .map((e) => e.getAttribute('w:anchor')),
      <String>['chapter_1', 'entry_1', 'entry_2', 'chapter_2', 'entry_3'],
    );
    expect(
      document
          .findAllElements('w:bookmarkStart')
          .map((e) => e.getAttribute('w:name')),
      <String>['chapter_1', 'entry_1', 'entry_2', 'chapter_2', 'entry_3'],
    );
    bool breaks(String style, String text) => paragraphs.any(
      (p) =>
          styleOf(p) == style &&
          textOf(p) == text &&
          p.findAllElements('w:pageBreakBefore').isNotEmpty,
    );
    expect(breaks('TocHeading', '目录'), isTrue);
    expect(breaks('BookChapter', '春'), isTrue);
    // 章节标题后的第一篇与标题同页，第二篇另起一页。
    expect(breaks('BookEntry', '出发'), isFalse);
    expect(breaks('BookEntry', '到达'), isTrue);

    String? outlineLevel(String styleId) => styles
        .findAllElements('w:style')
        .firstWhere((e) => e.getAttribute('w:styleId') == styleId)
        .findAllElements('w:outlineLvl')
        .single
        .getAttribute('w:val');
    expect(outlineLevel('BookChapter'), '0');
    expect(outlineLevel('BookEntry'), '1');
    // 正文标题顺延到章、篇之下。
    expect(outlineLevel('Heading1'), '2');
  });

  test('Word without a book keeps the plain styles', () async {
    final output = await DiaryDocxWriter.write(
      <DiaryExportEntry>[a],
      options: DiaryExportOptions.defaults,
      labels: testExportLabels,
      media: DiaryExportMediaLibrary(),
      documentTitle: '出发',
      languageTag: 'zh-CN',
      now: DateTime.utc(2026, 10, 19),
    );
    final styles = utf8.decode(
      output.files!.firstWhere((f) => f.path == 'word/styles.xml').bytes!,
    );
    expect(styles, isNot(contains('BookChapter')));
    expect(styles, contains('<w:outlineLvl w:val="0"/>'));
  });

  group('PDF book', () {
    late DiaryPdfFonts fonts;
    setUpAll(() async => fonts = await DiaryPdfFonts.load());

    Future<String> pdf(
      DiaryExportBookLayout? resolved,
      List<DiaryExportEntry> entries, {
      DiaryExportOptions options = DiaryExportOptions.defaults,
    }) async {
      final output = await DiaryPdfWriter.write(
        entries,
        options: options,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        fonts: fonts,
        documentTitle: 'Trip',
        book: resolved,
      );
      // 字典部分是 ASCII；正文流已压缩，按 latin1 读不会出错。
      return latin1.decode(output.bytes!);
    }

    final one = plain('a', 'Day one', DateTime(2026, 4, 1));
    final two = plain('b', 'Day two', DateTime(2026, 4, 2));
    final three = plain('c', 'Day three', DateTime(2026, 5, 2));
    DiaryExportBook ascii({String? cover}) => DiaryExportBook(
      title: 'Trip',
      coverPath: cover,
      chapters: <DiaryExportBookChapter>[
        DiaryExportBookChapter(title: 'Spring', diaryIds: <String>['a', 'b']),
        DiaryExportBookChapter(title: 'Autumn', diaryIds: <String>['c']),
      ],
    );

    test('builds a title page, contents and one page per chapter, with '
        'bookmarks and links in book order', () async {
      final resolved = layout(<DiaryExportEntry>[
        one,
        two,
        three,
      ], from: ascii(cover: coverPath));
      final text = await pdf(resolved, resolved.entries);
      expect(text, startsWith('%PDF-'));
      final pages = _pageRefs(text);
      // 扉页 + 目录 + 两章各一页。
      expect(pages, hasLength(4));
      // 书签（大纲）按章、篇的先后。
      final outline = <String>['Spring', 'Day one', 'Day two', 'Autumn'];
      var last = -1;
      for (final title in outline) {
        final match = RegExp(
          '/Title\\s*\\($title\\)',
        ).allMatches(text).where((m) => m.start > last).firstOrNull;
        expect(match, isNotNull, reason: title);
        last = match!.start;
      }
      // 命名目标落在各自的页上：第一章与前两篇在第 3 页，第二章在第 4 页。
      expect(_destinationPage(text, 'chapter-1', pages), 3);
      expect(_destinationPage(text, 'entry-2', pages), 3);
      expect(_destinationPage(text, 'chapter-2', pages), 4);
      expect(_destinationPage(text, 'entry-3', pages), 4);
      // 目录每行都是可点按的链接（2 章 + 3 篇）。
      expect(RegExp(r'/Subtype\s*/Link').allMatches(text), hasLength(5));
    });

    test('without a book the same diaries flow on as before', () async {
      final text = await pdf(null, <DiaryExportEntry>[one, two, three]);
      expect(_pageRefs(text), hasLength(1));
      expect(text, isNot(contains('/Outlines')));
    });

    test('the cover counts toward the image cap', () async {
      final big = Uint8List(DiaryPdfWriter.maxImageBytes ~/ 2 + 1)
        ..setAll(0, base64Decode(pngBase64));
      final bigPath = p.join(temp.path, 'big.png');
      await File(bigPath).writeAsBytes(big);
      final withImage = DiaryExportEntry.parse(
        diaryId: 'a',
        title: 'Day one',
        createdAt: DateTime(2026, 4, 1),
        updatedAt: DateTime(2026, 4, 1),
        deltaOps: <dynamic>[
          <String, dynamic>{
            'insert': <String, dynamic>{'image': bigPath},
          },
          <String, dynamic>{'insert': '\n'},
        ],
      );
      final resolved = layout(<DiaryExportEntry>[
        withImage,
      ], from: ascii(cover: bigPath));
      await expectLater(
        pdf(resolved, resolved.entries),
        throwsA(isA<DiaryExportTooLargeException>()),
      );
    });
  });
}

/// 把书的第一章第一篇换成 [first]（富文本夹具的日记 id 是 `d1`）。
DiaryExportBook _withIds(DiaryExportBook book, {required String first}) {
  return DiaryExportBook(
    title: book.title,
    description: book.description,
    coverPath: book.coverPath,
    chapters: <DiaryExportBookChapter>[
      DiaryExportBookChapter(title: '春', diaryIds: <String>[first]),
      for (final chapter in book.chapters.skip(1)) chapter,
    ],
  );
}

/// 页面树里各页的对象号，按页序。
List<String> _pageRefs(String pdf) {
  final kids = RegExp(
    r'/Type\s*/Pages.*?/Kids\s*\[([^\]]*)\]',
    dotAll: true,
  ).firstMatch(pdf);
  expect(kids, isNotNull);
  return RegExp(
    r'(\d+)\s+\d+\s+R',
  ).allMatches(kids!.group(1)!).map((m) => m.group(1)!).toList();
}

/// 命名目标 [name] 所在的页码（从 1 起）。
int _destinationPage(String pdf, String name, List<String> pages) {
  final match = RegExp(
    '\\($name\\)\\s*<<\\s*/D\\s*\\[\\s*(\\d+)\\s+\\d+\\s+R',
  ).firstMatch(pdf);
  expect(match, isNotNull, reason: name);
  return pages.indexOf(match!.group(1)!) + 1;
}
