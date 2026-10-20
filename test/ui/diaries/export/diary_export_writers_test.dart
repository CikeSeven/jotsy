import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/export/diary_export_blocks.dart';
import 'package:node_diary/ui/diaries/export/diary_export_docx.dart';
import 'package:node_diary/ui/diaries/export/diary_export_entry.dart';
import 'package:node_diary/ui/diaries/export/diary_export_format.dart';
import 'package:node_diary/ui/diaries/export/diary_export_html.dart';
import 'package:node_diary/ui/diaries/export/diary_export_markdown.dart';
import 'package:node_diary/ui/diaries/export/diary_export_media.dart';
import 'package:node_diary/ui/diaries/export/diary_export_naming.dart';
import 'package:node_diary/ui/diaries/export/diary_export_pdf.dart';
import 'package:node_diary/ui/diaries/export/diary_export_plain_text.dart';
import 'package:node_diary/ui/diaries/export/diary_export_text.dart';
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../../../support/export_test_images.dart';
import 'diary_export_test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late String imagePath;
  late String attachmentPath;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('export_writers_');
    imagePath = p.join(temp.path, 'photo 1.jpg');
    await File(imagePath).writeAsBytes(base64Decode(jpgBase64));
    attachmentPath = p.join(temp.path, 'report.pdf');
    await File(attachmentPath).writeAsBytes(<int>[1, 2, 3]);
  });
  tearDown(() => temp.delete(recursive: true));

  group('ExportBlockParser', () {
    test('keeps structure, ordinals across nested bullets and embeds', () {
      final blocks = richEntry(image: '/x.jpg').blocks;
      final kinds = blocks.map((ExportBlock b) => b.kind).toList();
      expect(kinds, <ExportBlockKind>[
        ExportBlockKind.paragraph,
        ExportBlockKind.paragraph,
        ExportBlockKind.heading,
        ExportBlockKind.ordered,
        ExportBlockKind.bullet,
        ExportBlockKind.ordered,
        ExportBlockKind.checked,
        ExportBlockKind.quote,
        ExportBlockKind.code,
        ExportBlockKind.image,
        ExportBlockKind.media,
        ExportBlockKind.media,
        ExportBlockKind.paragraph,
      ]);
      // 有序列表中间夹着更深一级的无序子项，编号接着数。
      expect(blocks[5].ordinal, 2);
      expect(blocks[2].level, 2);
      expect(blocks[10].mediaKind, ExportMediaKind.audio);
      expect(blocks[10].mediaDuration, const Duration(seconds: 75));
      expect(blocks[11].mediaName, '报告.pdf');
    });

    test('restarts numbering when a separate list begins', () {
      final blocks = ExportBlockParser.parse(<dynamic>[
        <String, dynamic>{'insert': 'a'},
        <String, dynamic>{
          'insert': '\n',
          'attributes': <String, dynamic>{'list': 'ordered'},
        },
        <String, dynamic>{'insert': 'b'},
        <String, dynamic>{
          'insert': '\n',
          'attributes': <String, dynamic>{'list': 'bullet'},
        },
        <String, dynamic>{'insert': 'c'},
        <String, dynamic>{
          'insert': '\n',
          'attributes': <String, dynamic>{'list': 'ordered'},
        },
      ]);
      expect(blocks.map((ExportBlock b) => b.ordinal), <int>[1, 0, 1]);
    });
  });

  group('dividers', () {
    DiaryExportEntry dividerEntry() => DiaryExportEntry.parse(
      diaryId: 'hr',
      title: '分隔',
      createdAt: DateTime(2026, 4, 3),
      updatedAt: DateTime(2026, 4, 3),
      deltaOps: <dynamic>[
        <String, dynamic>{'insert': '上\n'},
        <String, dynamic>{
          'insert': <String, dynamic>{'divider': 'hr'},
        },
        <String, dynamic>{'insert': '\n下\n'},
      ],
    );

    test('become a block of their own', () {
      expect(
        dividerEntry().blocks.map((block) => block.kind),
        <ExportBlockKind>[
          ExportBlockKind.paragraph,
          ExportBlockKind.divider,
          ExportBlockKind.paragraph,
        ],
      );
      expect(ExportPlainText.render(dividerEntry().blocks), '上\n———\n下');
    });

    test('are written as each format\'s own rule', () async {
      final options = DiaryExportOptions.defaults.copyWith(
        includeMeta: false,
        includeMedia: false,
      );
      final markdown = await DiaryMarkdownWriter.write(
        <DiaryExportEntry>[dividerEntry()],
        options: options,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
      );
      expect(utf8.decode(markdown.bytes!), contains('上\n\n---\n\n下'));

      final html = await DiaryHtmlWriter.write(
        <DiaryExportEntry>[dividerEntry()],
        options: options,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        documentTitle: '分隔',
        languageTag: 'zh',
      );
      expect(utf8.decode(html.bytes!), contains('<p>上</p>\n<hr>\n<p>下</p>'));

      final docx = await DiaryDocxWriter.write(
        <DiaryExportEntry>[dividerEntry()],
        options: options,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        documentTitle: '分隔',
        languageTag: 'zh-CN',
        now: DateTime.utc(2026, 10, 16),
      );
      final parts = {for (final f in docx.files!) f.path: f};
      final document = XmlDocument.parse(
        utf8.decode(parts['word/document.xml']!.bytes!),
      );
      expect(
        document
            .findAllElements('w:pStyle')
            .map((e) => e.getAttribute('w:val')),
        contains('Divider'),
      );
      expect(
        utf8.decode(parts['word/styles.xml']!.bytes!),
        contains('w:styleId="Divider"'),
      );

      final pdfBody = await DiaryPdfWriter.prepareBody(
        dividerEntry(),
        includeImages: false,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        images: <Uint8List>[],
      );
      expect(
        pdfBody!.toJson(),
        contains(equals(<String, dynamic>{'insert': '———'})),
      );
    });
  });

  group('code block languages', () {
    Map<String, dynamic> codeLine(String text, Object value) =>
        <String, dynamic>{
          'insert': '$text\n',
          'attributes': <String, dynamic>{'code-block': value},
        };

    DiaryExportEntry codeEntry(List<dynamic> ops) => DiaryExportEntry.parse(
      diaryId: 'code',
      title: '代码',
      createdAt: DateTime(2026, 4, 3),
      updatedAt: DateTime(2026, 4, 3),
      deltaOps: <dynamic>[
        <String, dynamic>{'insert': '前\n'},
        ...ops,
      ],
    );

    final options = DiaryExportOptions.defaults.copyWith(
      includeMeta: false,
      includeMedia: false,
    );

    Future<String> markdownOf(List<dynamic> ops) async {
      final output = await DiaryMarkdownWriter.write(
        <DiaryExportEntry>[codeEntry(ops)],
        options: options,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
      );
      return utf8.decode(output.bytes!);
    }

    Future<String> htmlOf(List<dynamic> ops) async {
      final output = await DiaryHtmlWriter.write(
        <DiaryExportEntry>[codeEntry(ops)],
        options: options,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        documentTitle: '代码',
        languageTag: 'zh',
      );
      return utf8.decode(output.bytes!);
    }

    test('blocks carry the explicit language, plain, or null for auto', () {
      final blocks = codeEntry(<dynamic>[
        codeLine('a', 'python'),
        codeLine('b', 'plain'),
        codeLine('c', true),
        codeLine('d', 'weird'),
      ]).blocks;
      expect(blocks.skip(1).map((ExportBlock b) => b.kind).toSet(), {
        ExportBlockKind.code,
      });
      expect(blocks.map((ExportBlock b) => b.codeLanguage), <String?>[
        null,
        'python',
        'plain',
        null,
        null,
      ]);
    });

    test('markdown fences carry the language, text for plain, '
        'nothing for auto', () async {
      final markdown = await markdownOf(<dynamic>[
        codeLine('x = 1', 'python'),
        codeLine('y = 2', 'python'),
        codeLine('raw', 'plain'),
        codeLine('auto', true),
      ]);
      expect(
        markdown,
        contains(
          '```python\nx = 1\ny = 2\n```\n\n'
          '```text\nraw\n```\n\n'
          '```\nauto\n```',
        ),
      );
    });

    test(
      'a language change splits adjacent code lines into two fences',
      () async {
        final markdown = await markdownOf(<dynamic>[
          codeLine('let a', 'javascript'),
          codeLine('fn b', 'rust'),
        ]);
        expect(
          markdown,
          contains('```javascript\nlet a\n```\n\n```rust\nfn b\n```'),
        );
      },
    );

    test('code containing backticks gets a longer fence', () async {
      final markdown = await markdownOf(<dynamic>[
        codeLine('```', 'markdown'),
        codeLine('a ```` b', 'markdown'),
      ]);
      expect(markdown, contains('`````markdown\n```\na ```` b\n`````'));
    });

    test(
      'html marks code with language classes and splits on change',
      () async {
        final html = await htmlOf(<dynamic>[
          codeLine('x = 1', 'python'),
          codeLine('raw', 'plain'),
          codeLine('auto', true),
        ]);
        expect(
          html,
          contains(
            '<pre><code class="language-python">x = 1</code></pre>\n'
            '<pre><code class="language-plaintext">raw</code></pre>\n'
            '<pre><code>auto</code></pre>',
          ),
        );
      },
    );

    test('pdf body rewrites language values to true so the renderer '
        'does not crash', () async {
      final entry = codeEntry(<dynamic>[
        codeLine('x = 1', 'python'),
        codeLine('raw', 'plain'),
        codeLine('auto', true),
        <String, dynamic>{
          'insert': 'off\n',
          'attributes': <String, dynamic>{'code-block': false},
        },
      ]);
      final original = jsonEncode(entry.deltaOps);
      final body = await DiaryPdfWriter.prepareBody(
        entry,
        includeImages: false,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        images: <Uint8List>[],
      );
      final values = body!
          .toJson()
          .map((dynamic op) => (op as Map)['attributes'])
          .whereType<Map>()
          .map((Map attrs) => attrs['code-block'])
          .toList();
      expect(values, <Object?>[true, true, true, false]);
      // 不改动调用方的正文。
      expect(jsonEncode(entry.deltaOps), original);

      final fonts = await DiaryPdfFonts.load();
      final output = await DiaryPdfWriter.write(
        <DiaryExportEntry>[entry],
        options: DiaryExportOptions.defaults,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        fonts: fonts,
        documentTitle: 'Jotsy',
      );
      expect(ascii.decode(output.bytes!.sublist(0, 5)), '%PDF-');
    });

    test('docx and plain text still treat language blocks as code', () async {
      final entry = codeEntry(<dynamic>[codeLine('x = 1', 'python')]);
      expect(ExportPlainText.render(entry.blocks), contains('x = 1'));
      final docx = await DiaryDocxWriter.write(
        <DiaryExportEntry>[entry],
        options: options,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        documentTitle: '代码',
        languageTag: 'zh-CN',
        now: DateTime.utc(2026, 10, 16),
      );
      final parts = {for (final f in docx.files!) f.path: f};
      final document = utf8.decode(parts['word/document.xml']!.bytes!);
      expect(document, contains('w:val="CodeBlock"'));
      expect(document, contains('x = 1'));
    });
  });

  group('ExportImageInfo', () {
    test('reads pixel sizes from common headers', () {
      ExportImageInfo? info(String data) =>
          ExportImageInfo.read(base64Decode(data));
      expect(info(pngBase64)?.width, 3);
      expect(info(pngBase64)?.height, 2);
      expect(info(jpgBase64)?.width, 4);
      expect(info(gifBase64)?.height, 7);
      expect(info(bmpBase64)?.height, 9);
      expect(info(webpBase64)?.width, 6);
      expect(info(webpBase64)?.height, 4);
      expect(ExportImageInfo.read(Uint8List.fromList(<int>[1, 2, 3])), isNull);
    });

    test('swaps width and height for EXIF-rotated JPEGs', () {
      final info = ExportImageInfo.read(base64Decode(jpgRotatedBase64))!;
      expect((info.width, info.height), (2, 4));
    });
  });

  group('DiaryExportNaming', () {
    test('names files by date and a sanitized title, keeping them unique', () {
      final entry = richEntry(title: 'a/b: c?');
      expect(DiaryExportNaming.entryStem(entry), '2026-04-03 0905 a_b_ c_');
      final taken = <String>{};
      expect(DiaryExportNaming.unique(taken, 'x.md'), 'x.md');
      expect(DiaryExportNaming.unique(taken, 'X.md'), 'X (2).md');
      expect(
        DiaryExportNaming.exportStem(<DiaryExportEntry>[
          richEntry(),
          DiaryExportEntry.parse(
            diaryId: 'd2',
            title: '',
            createdAt: DateTime(2026, 5, 1),
            updatedAt: DateTime(2026, 5, 1),
            deltaOps: const <dynamic>[],
          ),
        ]),
        'Jotsy 2026-04-03~2026-05-01',
      );
    });
  });

  group('DiaryMarkdownWriter', () {
    test(
      'writes front matter and bundles media under media/ with relative links',
      () async {
        final output = await DiaryMarkdownWriter.write(
          <DiaryExportEntry>[
            richEntry(image: imagePath, attachmentPath: attachmentPath),
          ],
          options: DiaryExportOptions.defaults,
          labels: testExportLabels,
          media: DiaryExportMediaLibrary(),
        );

        expect(output.isBundle, isTrue);
        final files = output.files!;
        expect(files.map((f) => f.path), <String>[
          '2026-04-03 0905 春日 _小记_.md',
          'media/0001.jpg',
          'media/0002_report.pdf',
        ]);
        final markdown = utf8.decode(files.first.bytes!);
        expect(markdown, startsWith('---\ntitle: "春日 *小记*"\n'));
        expect(markdown, contains('created: 2026-04-03T09:05:00\n'));
        expect(markdown, contains('tags: ["旅行", "美食"]\n'));
        expect(markdown, contains('energy: 4\n'));
        expect(markdown, contains('location: "杭州西湖"\n'));
        expect(
          markdown,
          contains('今天**很开心**，去了[西湖](https://example.com/a%20b) \\<3 & 1+1'),
        );
        expect(markdown, contains('\\# 不是标题'));
        expect(markdown, contains('## 小标题'));
        expect(markdown, contains('1. 第一\n    - 子项\n2. 第二\n- [x] 买花'));
        expect(markdown, contains('> 一句话'));
        expect(markdown, contains('```\nprint(1)\n```'));
        expect(markdown, contains('![](media/0001.jpg)'));
        expect(markdown, contains('[\\[附件 报告.pdf\\]](media/0002_report.pdf)'));
        // 本地录音文件不存在：写成名称，不留指向设备私有路径的链接。
        expect(markdown, contains('\\[录音 晨间录音 · 1:15\\]'));
        expect(markdown, isNot(contains('/private/')));
        expect(markdown, isNot(contains('# 春日')));
      },
    );

    test('a single diary without media is one plain .md file', () async {
      final output = await DiaryMarkdownWriter.write(
        <DiaryExportEntry>[richEntry()],
        options: DiaryExportOptions.defaults.copyWith(
          includeMedia: false,
          includeMeta: false,
        ),
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
      );
      expect(output.isBundle, isFalse);
      final markdown = utf8.decode(output.bytes!);
      expect(markdown, isNot(contains('tags:')));
      expect(markdown, isNot(contains('mood:')));
    });
  });

  group('DiaryHtmlWriter', () {
    test(
      'escapes text, nests lists, inlines images and drops unsafe links',
      () async {
        final entry = DiaryExportEntry.parse(
          diaryId: 'd',
          title: '<b>标题</b>',
          createdAt: DateTime(2026, 4, 3),
          updatedAt: DateTime(2026, 4, 3),
          deltaOps: <dynamic>[
            <String, dynamic>{
              'insert': '点我',
              'attributes': <String, dynamic>{'link': 'javascript:alert(1)'},
            },
            <String, dynamic>{'insert': '\n'},
          ],
        );
        final output = await DiaryHtmlWriter.write(
          <DiaryExportEntry>[richEntry(image: imagePath), entry],
          options: DiaryExportOptions.defaults,
          labels: testExportLabels,
          media: DiaryExportMediaLibrary(),
          documentTitle: '我的日记',
          languageTag: 'zh',
        );
        final html = utf8.decode(output.files!.first.bytes!);
        expect(html, startsWith('<!DOCTYPE html>'));
        expect(html, contains('<title>我的日记</title>'));
        expect(html, contains('&lt;b&gt;标题&lt;/b&gt;'));
        expect(html, contains('<strong>很开心</strong>'));
        expect(html, contains(' &lt;3 &amp; 1+1'));
        expect(
          html,
          contains('<ol><li>第一<ul><li>子项</li></ul></li><li>第二</li></ol>'),
        );
        expect(html, contains('<input type="checkbox" disabled checked'));
        expect(html, contains('<li>#旅行</li>'));
        expect(html, contains('[录音 晨间录音 · 1:15]'));
        expect(html, isNot(contains('javascript:')));
        expect(html, contains('<p>点我</p>'));
      },
    );
  });

  group('DiaryDocxWriter', () {
    test(
      'builds a Word package with styles, images, links and page breaks',
      () async {
        final output = await DiaryDocxWriter.write(
          <DiaryExportEntry>[
            richEntry(image: imagePath),
            richEntry(title: '第二篇'),
          ],
          options: DiaryExportOptions.defaults,
          labels: testExportLabels,
          media: DiaryExportMediaLibrary(),
          documentTitle: 'Jotsy',
          languageTag: 'zh-CN',
          now: DateTime.utc(2026, 10, 16),
        );
        // Word 是 zip 容器：写出器交出包内文件，由控制器流式打包。
        expect(output.containerExtension, 'docx');
        final files = {for (final f in output.files!) f.path: f};
        expect(output.files!.first.path, '[Content_Types].xml');
        String part(String name) => utf8.decode(files[name]!.bytes!);
        // 本地图片按原文件流式写入，不读进内存。
        expect(files['word/media/image1.jpeg']!.file!.path, imagePath);
        final document = XmlDocument.parse(part('word/document.xml'));
        final rels = XmlDocument.parse(part('word/_rels/document.xml.rels'));
        XmlDocument.parse(part('word/styles.xml'));
        XmlDocument.parse(part('[Content_Types].xml'));
        XmlDocument.parse(part('docProps/core.xml'));

        final text = document
            .findAllElements('w:t')
            .map((e) => e.innerText)
            .join();
        expect(text, contains('很开心'));
        expect(text, contains('[录音 晨间录音 · 1:15]'));
        expect(document.findAllElements('w:pageBreakBefore'), hasLength(1));
        expect(document.findAllElements('w:drawing'), hasLength(1));
        final targets = rels
            .findAllElements('Relationship')
            .map((e) => e.getAttribute('Target'))
            .toList();
        expect(targets, contains('media/image1.jpeg'));
        expect(targets, contains('https://example.com/a b'));
        // 4×2 像素按版心等比，不放大：96 DPI 下原尺寸。
        final extent = document.findAllElements('wp:extent').single;
        expect(extent.getAttribute('cx'), '${4 * 9525}');
        expect(extent.getAttribute('cy'), '${2 * 9525}');
      },
    );
  });

  group('text colors', () {
    Map<String, dynamic> styled(String text, Map<String, dynamic> attrs) =>
        <String, dynamic>{'insert': text, 'attributes': attrs};
    final red = encodeDiaryColor(
      DiaryColorPreset.red.colorFor(DiaryColorTarget.text),
    );
    final redHighlight = encodeDiaryColor(
      DiaryColorPreset.red.colorFor(DiaryColorTarget.background),
    );
    final entry = DiaryExportEntry.parse(
      diaryId: 'colors',
      title: '颜色',
      createdAt: DateTime(2026, 4, 3),
      updatedAt: DateTime(2026, 4, 3),
      deltaOps: <dynamic>[
        // 红字 + 浅红背景（预设背景只有 30% 不透明度）。
        styled('红', <String, dynamic>{
          'color': red,
          'background': redHighlight,
        }),
        styled('下', <String, dynamic>{'color': '#FF112233', 'underline': true}),
        styled('码', <String, dynamic>{'code': true, 'background': '#FFFFF59D'}),
        styled('链', <String, dynamic>{
          'link': 'https://example.com',
          'color': '#FF112233',
        }),
        styled('透明', <String, dynamic>{'background': '#00FF0000'}),
        styled('颜色名', <String, dynamic>{'color': 'red'}),
        <String, dynamic>{'insert': '\n'},
      ],
    );
    final options = DiaryExportOptions.defaults.copyWith(
      includeMeta: false,
      includeMedia: false,
    );

    test('the parser keeps readable colors with their opacity', () {
      final runs = entry.blocks.single.inlines;
      expect(runs[0].color, const Color(0xFFE5484D));
      expect(runs[0].background, const Color(0x4DFF6369));
      expect(runs[1].color, const Color(0xFF112233));
      expect(runs[1].background, isNull);
      // 完全透明的背景等于没有背景；读不懂的写法略过。
      expect(runs[4].background, isNull);
      expect(runs[5].color, isNull);
    });

    test(
      'Word writes run colors and shading flattened onto white paper',
      () async {
        final output = await DiaryDocxWriter.write(
          <DiaryExportEntry>[entry],
          options: options,
          labels: testExportLabels,
          media: DiaryExportMediaLibrary(),
          documentTitle: '颜色',
          languageTag: 'zh-CN',
          now: DateTime.utc(2026, 10, 20),
        );
        final xml = utf8.decode(
          output.files!.firstWhere((f) => f.path == 'word/document.xml').bytes!,
        );
        // Word 对 rPr 子元素的顺序很严格：先能解析，再逐个核对。
        XmlDocument.parse(xml);
        String shd(String fill) =>
            '<w:shd w:val="clear" w:color="auto" w:fill="$fill"/>';
        expect(
          xml,
          contains(
            '<w:rPr><w:color w:val="E5484D"/>${shd('FFD0D2')}</w:rPr>'
            '<w:t xml:space="preserve">红</w:t>',
          ),
        );
        expect(
          xml,
          contains(
            '<w:rPr><w:color w:val="112233"/><w:u w:val="single"/></w:rPr>'
            '<w:t xml:space="preserve">下</w:t>',
          ),
        );
        // 直接格式覆盖字符样式：行内代码的浅灰底、链接色让位于用户颜色。
        expect(
          xml,
          contains(
            '<w:rPr><w:rStyle w:val="InlineCode"/>${shd('FFF59D')}</w:rPr>'
            '<w:t xml:space="preserve">码</w:t>',
          ),
        );
        expect(
          xml,
          contains(
            '<w:rPr><w:rStyle w:val="Hyperlink"/><w:color w:val="112233"/>'
            '</w:rPr><w:t xml:space="preserve">链</w:t>',
          ),
        );
        expect(xml, contains('<w:r><w:t xml:space="preserve">透明</w:t></w:r>'));
        expect(xml, contains('<w:r><w:t xml:space="preserve">颜色名</w:t></w:r>'));
      },
    );

    test(
      'HTML writes colors inline, keeping translucency like the app',
      () async {
        final output = await DiaryHtmlWriter.write(
          <DiaryExportEntry>[entry],
          options: options,
          labels: testExportLabels,
          media: DiaryExportMediaLibrary(),
          documentTitle: '颜色',
          languageTag: 'zh',
        );
        final html = utf8.decode(output.bytes!);
        expect(
          html,
          contains(
            '<p><span style="color:#E5484D;'
            'background-color:rgba(255,99,105,0.302)">红</span>'
            // 颜色在下划线外层，线与文字同色。
            '<span style="color:#112233"><u>下</u></span>'
            // 行内代码的颜色写在 <code> 上，盖过它自带的底色。
            '<code style="background-color:#FFF59D">码</code>'
            // 颜色在链接里层，盖过链接色。
            '<a href="https://example.com">'
            '<span style="color:#112233">链</span></a>'
            '透明颜色名</p>',
          ),
        );
      },
    );
  });

  group('plain text and CSV', () {
    test('TXT lists header, meta and body with media placeholders', () {
      final output = DiaryTextWriter.write(
        <DiaryExportEntry>[richEntry(image: '/x.jpg'), richEntry(title: '')],
        options: DiaryExportOptions.defaults,
        labels: testExportLabels,
      );
      final text = utf8.decode(output.bytes!);
      expect(
        text,
        startsWith(
          '春日 *小记*\n2026年4月3日 09:05\n晴 · 杭州西湖 · 😊 · 精力 4/5\n#旅行 #美食\n\n今天很开心',
        ),
      );
      expect(text, contains('1. 第一\n  • 子项\n2. 第二\n☑ 买花'));
      expect(text, contains('[图片]'));
      expect(text, contains(DiaryTextWriter.separator));
      expect(text, contains('\n无标题\n'));
    });

    test('CSV has a BOM, quotes multi-line cells and defuses formulas', () {
      final formula = DiaryExportEntry.parse(
        diaryId: 'f',
        title: '=HYPERLINK("x")',
        createdAt: DateTime(2026, 1, 2, 3, 4),
        updatedAt: DateTime(2026, 1, 2, 3, 4),
        deltaOps: <dynamic>[
          <String, dynamic>{'insert': '第一行\n第二行, 有逗号\n'},
        ],
      );
      final output = DiaryCsvWriter.write(<DiaryExportEntry>[
        formula,
      ], labels: testExportLabels);
      // utf8.decode 会吞掉开头的 BOM，直接核对字节。
      expect(output.bytes!.take(3), <int>[0xEF, 0xBB, 0xBF]);
      final csv = utf8.decode(output.bytes!);
      expect(csv, startsWith('日期,时间,标题,正文,心情,精力,天气,地点,标签,字数,最后编辑\r\n'));
      expect(csv, contains('2026-01-02,03:04,"\'=HYPERLINK(""x"")"'));
      expect(csv, contains('"第一行\n第二行, 有逗号"'));
    });

    test('CSV word count follows TextStats across paragraphs', () {
      final entry = DiaryExportEntry.parse(
        diaryId: 'w',
        title: 'Mixed',
        createdAt: DateTime(2026, 1, 2, 3, 4),
        updatedAt: DateTime(2026, 1, 2, 3, 4),
        deltaOps: <dynamic>[
          <String, dynamic>{'insert': 'hello world\n第二段\n'},
        ],
      );
      // 两段之间不能被拼成一个词：2 个英文词 + 3 个汉字。
      expect(entry.wordCount, 5);
      final csv = utf8.decode(
        DiaryCsvWriter.write(<DiaryExportEntry>[
          entry,
        ], labels: testExportLabels).bytes!,
      );
      expect(csv, contains(',5,'));
    });
  });

  group('DiaryPdfWriter', () {
    test(
      'renders several diaries, skipping missing images instead of failing',
      () async {
        final fonts = await DiaryPdfFonts.load();
        final output = await DiaryPdfWriter.write(
          <DiaryExportEntry>[
            richEntry(image: imagePath, cover: p.join(temp.path, 'gone.jpg')),
            richEntry(image: p.join(temp.path, 'missing.png')),
            DiaryExportEntry.parse(
              diaryId: 'empty',
              title: '只有标题',
              createdAt: DateTime(2026, 4, 5),
              updatedAt: DateTime(2026, 4, 5),
              deltaOps: <dynamic>[
                <String, dynamic>{'insert': '\n'},
              ],
            ),
          ],
          options: DiaryExportOptions.defaults,
          labels: testExportLabels,
          media: DiaryExportMediaLibrary(),
          fonts: fonts,
          documentTitle: 'Jotsy',
        );
        final bytes = output.bytes!;
        expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
        expect(bytes.length, greaterThan(1000));
      },
    );
  });

  group('DiaryPdfWriter.prepareBody', () {
    test('turns attachments into readable names, keeps remote links and never '
        'leaks private paths or mutates the diary', () async {
      final entry = DiaryExportEntry.parse(
        diaryId: 'p',
        title: '',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        deltaOps: <dynamic>[
          <String, dynamic>{
            'insert': '正文',
            'attributes': <String, dynamic>{'bold': true},
          },
          <String, dynamic>{'insert': '\n'},
          <String, dynamic>{
            'insert': <String, dynamic>{
              'video': '/private/diary_videos/trip.mp4',
            },
          },
          <String, dynamic>{'insert': '\n'},
          <String, dynamic>{
            'insert': <String, dynamic>{
              'file': <String, dynamic>{
                'url': 'https://example.invalid/report.pdf',
                'name': '报告.pdf',
              },
            },
          },
          <String, dynamic>{'insert': '\n'},
          <String, dynamic>{
            'insert': <String, dynamic>{'image': '/private/missing.jpg'},
          },
          <String, dynamic>{'insert': '\n'},
        ],
      );
      final original = jsonEncode(entry.deltaOps);
      final images = <Uint8List>[];
      final body = await DiaryPdfWriter.prepareBody(
        entry,
        includeImages: true,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        images: images,
      );
      final ops = body!.toJson();
      expect(ops.first, <String, dynamic>{
        'insert': '正文',
        'attributes': <String, dynamic>{'bold': true},
      });
      // contains 给 Map 时按引用比较，套 equals 才是逐项比较。
      expect(
        ops,
        contains(equals(<String, dynamic>{'insert': '[视频 trip.mp4]'})),
      );
      expect(
        ops,
        contains(
          equals(<String, dynamic>{
            'insert': '[附件 报告.pdf]',
            'attributes': <String, dynamic>{
              'link': 'https://example.invalid/report.pdf',
            },
          }),
        ),
      );
      expect(jsonEncode(ops), isNot(contains('/private')));
      // 找不到的图片直接去掉，不交给插件（它会因读文件失败而中断导出）。
      expect(images, isEmpty);
      expect(jsonEncode(entry.deltaOps), original);
    });

    test('routes images through virtual URLs and skips empty bodies', () async {
      final images = <Uint8List>[];
      final body = await DiaryPdfWriter.prepareBody(
        richEntry(image: imagePath),
        includeImages: true,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        images: images,
      );
      expect(images, hasLength(1));
      expect(
        jsonEncode(body!.toJson()),
        contains('https://jotsy.export/0.png'),
      );

      final empty = await DiaryPdfWriter.prepareBody(
        DiaryExportEntry.parse(
          diaryId: 'e',
          title: 't',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          deltaOps: <dynamic>[
            <String, dynamic>{'insert': '  \n'},
          ],
        ),
        includeImages: true,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        images: <Uint8List>[],
      );
      expect(empty, isNull);
    });

    test('flattens translucent text backgrounds onto the white page so they '
        'stay as light as in the app', () async {
      Map<String, dynamic> styled(String text, Map<String, dynamic> attrs) =>
          <String, dynamic>{'insert': text, 'attributes': attrs};
      final entry = DiaryExportEntry.parse(
        diaryId: 'c',
        title: '',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        deltaOps: <dynamic>[
          // 红字 + 浅红背景（预设背景只有 30% 不透明度）。
          styled('红', <String, dynamic>{
            'color': encodeDiaryColor(
              DiaryColorPreset.red.colorFor(DiaryColorTarget.text),
            ),
            'background': encodeDiaryColor(
              DiaryColorPreset.red.colorFor(DiaryColorTarget.background),
            ),
          }),
          // 半透明文字叠在压平后的背景上。
          styled('灰', <String, dynamic>{
            'color': '#80000000',
            'background': '#4DFF6369',
          }),
          styled('透明', <String, dynamic>{
            'bold': true,
            'background': '#00FF0000',
          }),
          styled('六位', <String, dynamic>{'background': '#ffd0d2'}),
          styled('颜色名', <String, dynamic>{'color': 'red'}),
          <String, dynamic>{'insert': '\n'},
        ],
      );
      final original = jsonEncode(entry.deltaOps);
      final body = await DiaryPdfWriter.prepareBody(
        entry,
        includeImages: false,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        images: <Uint8List>[],
      );
      final attrs = <Object?>[
        for (final op in body!.toJson()) (op as Map)['attributes'],
      ];
      expect(attrs, <Object?>[
        <String, dynamic>{'color': '#FFE5484D', 'background': '#FFFFD0D2'},
        <String, dynamic>{'color': '#FF7F6868', 'background': '#FFFFD0D2'},
        // 完全透明的背景等于没有背景。
        <String, dynamic>{'bold': true},
        <String, dynamic>{'background': '#FFFFD0D2'},
        // 读不懂的写法原样交给插件。
        <String, dynamic>{'color': 'red'},
        null,
      ]);
      // 不改动调用方的正文。
      expect(jsonEncode(entry.deltaOps), original);
    });
  });

  test('a single diary is one page with images inlined', () async {
    final output = await DiaryHtmlWriter.write(
      <DiaryExportEntry>[richEntry(image: imagePath)],
      options: DiaryExportOptions.defaults,
      labels: testExportLabels,
      media: DiaryExportMediaLibrary(),
      documentTitle: 'Jotsy',
      languageTag: 'zh',
    );
    expect(output.isBundle, isFalse);
    expect(
      utf8.decode(output.bytes!),
      contains('src="data:image/jpeg;base64,'),
    );
  });

  test('several diaries with images become index.html plus media/', () async {
    final output = await DiaryHtmlWriter.write(
      <DiaryExportEntry>[richEntry(image: imagePath), richEntry(title: '二')],
      options: DiaryExportOptions.defaults,
      labels: testExportLabels,
      media: DiaryExportMediaLibrary(),
      documentTitle: 'Jotsy',
      languageTag: 'zh',
    );
    expect(output.isBundle, isTrue);
    expect(output.files!.map((f) => f.path), <String>[
      'index.html',
      'media/0001.jpg',
    ]);
    expect(output.files![1].file!.path, imagePath);
    final html = utf8.decode(output.files!.first.bytes!);
    expect(html, contains('<img src="media/0001.jpg"'));
    expect(html, isNot(contains('base64,')));
  });

  test('PDF stops with a clear error once images exceed the cap', () async {
    final big = Uint8List(DiaryPdfWriter.maxImageBytes ~/ 2 + 1)
      ..setAll(0, base64Decode(pngBase64));
    final bigPath = p.join(temp.path, 'big.png');
    await File(bigPath).writeAsBytes(big);
    final entries = <DiaryExportEntry>[
      richEntry(image: bigPath),
      richEntry(image: bigPath, cover: imagePath),
      richEntry(image: bigPath),
    ];
    final images = <Uint8List>[];
    final media = DiaryExportMediaLibrary();
    Future<void> prepare(DiaryExportEntry entry) => DiaryPdfWriter.prepareBody(
      entry,
      includeImages: true,
      labels: testExportLabels,
      media: media,
      images: images,
    );
    await prepare(entries[0]);
    await expectLater(
      prepare(entries[1]),
      throwsA(isA<DiaryExportTooLargeException>()),
    );
  });

  group('DiaryExportOptions', () {
    test('round-trips and falls back per field', () {
      const options = DiaryExportOptions(
        format: DiaryExportFormat.markdown,
        includeMedia: false,
        order: DiaryExportOrder.newestFirst,
      );
      expect(DiaryExportOptions.fromRaw(options.toRaw()), options);
      expect(DiaryExportOptions.fromRaw(null), DiaryExportOptions.defaults);
      expect(DiaryExportOptions.fromRaw('[]'), DiaryExportOptions.defaults);
      expect(
        DiaryExportOptions.fromRaw('{"format":"epub","meta":false}'),
        DiaryExportOptions.defaults.copyWith(includeMeta: false),
      );
    });
  });
}
