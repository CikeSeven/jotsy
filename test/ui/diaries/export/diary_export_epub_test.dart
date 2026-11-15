import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:image/image.dart' as img;
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/ui/diaries/export/diary_export_book.dart';
import 'package:node_diary/ui/diaries/export/diary_export_code.dart';
import 'package:node_diary/ui/diaries/export/diary_export_entry.dart';
import 'package:node_diary/ui/diaries/export/diary_export_epub.dart';
import 'package:node_diary/ui/diaries/export/diary_export_epub_package.dart';
import 'package:node_diary/ui/diaries/export/diary_export_format.dart';
import 'package:node_diary/ui/diaries/export/diary_export_html.dart';
import 'package:node_diary/ui/diaries/export/diary_export_media.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../../../support/export_test_images.dart';
import 'diary_export_full_fixture.dart';
import 'diary_export_test_fixtures.dart';

/// EPUB 导出：包的结构必须让阅读器打得开（mimetype 在最前且不压缩、每份
/// XML 都合规、清单与文件一一对应、目录指向存在的锚点），内容与网页逐块
/// 一致（同一套正文写法，什么都不能漏），图片只收阅读器认得的格式。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final exportedAt = DateTime.utc(2026, 11, 15, 8, 30, 5);
  final code = DiaryExportCodeTheme.resolve(
    DiaryCodeBlockStyle.defaults.copyWith(theme: DiaryCodeThemeId.github),
    ColorScheme.fromSeed(seedColor: Colors.teal),
  );
  late Directory temp;
  late String jpg;
  late String png;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('export_epub_');
    jpg = p.join(temp.path, 'photo.jpg');
    await File(jpg).writeAsBytes(base64Decode(jpgBase64));
    png = p.join(temp.path, 'cover.png');
    await File(png).writeAsBytes(base64Decode(pngBase64));
  });
  tearDown(() => temp.delete(recursive: true));

  Future<DiaryExportOutput> epub(
    List<DiaryExportEntry> entries, {
    DiaryExportOptions options = DiaryExportOptions.defaults,
    DiaryExportBookLayout? book,
    DiaryExportCodeTheme? code,
    List<String> fonts = const <String>[],
    DiaryTypography typography = const DiaryTypography(),
    String title = '导出 <测试>',
  }) => DiaryEpubWriter.write(
    entries,
    options: options,
    labels: testExportLabels,
    media: DiaryExportMediaLibrary(),
    documentTitle: title,
    languageTag: 'zh-CN',
    fontFamilies: fonts,
    book: book,
    code: code,
    typography: typography,
    now: exportedAt,
  );

  Future<Map<String, Uint8List>> unpack(DiaryExportOutput output) async => {
    for (final file in output.files!)
      file.path: file.bytes != null
          ? Uint8List.fromList(file.bytes!)
          : await file.file!.readAsBytes(),
  };

  String text(Map<String, Uint8List> files, String path) =>
      utf8.decode(files[path]!);

  DiaryExportBookLayout bookOf(
    List<DiaryExportEntry> entries, {
    String? cover,
    required List<DiaryExportBookChapter> chapters,
  }) => DiaryExportBookLayout.resolve(
    DiaryExportBook(
      title: '旅行 & 日记',
      description: '走过的路',
      coverPath: cover,
      chapters: chapters,
    ),
    entries,
    labels: testBookLabels,
    exportedAt: DateTime(2026, 10, 19),
  );

  /// 包的完整性：阅读器（与 epubcheck）会检查的几件事都在这里核对。
  Future<Map<String, Uint8List>> checkPackage(DiaryExportOutput output) async {
    expect(output.containerExtension, 'epub');
    expect(output.containerMimeType, 'application/epub+zip');
    final first = output.files!.first;
    expect(first.path, 'mimetype');
    expect(first.stored, isTrue);
    expect(utf8.decode(first.bytes!), 'application/epub+zip');
    expect(
      output.files!.skip(1).where((DiaryExportBundleFile f) => f.stored),
      isEmpty,
    );
    final files = await unpack(output);

    // 每份 XML 都能按 XML 解析，且没有 XML 不允许的字符。
    final forbidden = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F￾￿]');
    final documents = <String, XmlDocument>{};
    for (final path in files.keys) {
      if (path.endsWith('.xhtml') ||
          path.endsWith('.opf') ||
          path.endsWith('.ncx') ||
          path.endsWith('.xml')) {
        final source = text(files, path);
        expect(source.contains(forbidden), isFalse, reason: path);
        documents[path] = XmlDocument.parse(source);
      }
    }

    final container = documents['META-INF/container.xml']!;
    final opfPath = container
        .findAllElements('rootfile')
        .single
        .getAttribute('full-path')!;
    expect(opfPath, 'OEBPS/content.opf');
    final opf = documents[opfPath]!;
    final package = opf.rootElement;
    expect(package.getAttribute('version'), '3.0');
    final uidId = package.getAttribute('unique-identifier');
    final identifier = opf
        .findAllElements('dc:identifier')
        .singleWhere((XmlElement e) => e.getAttribute('id') == uidId)
        .innerText;
    expect(identifier, matches(RegExp(r'^urn:uuid:[0-9a-f-]{36}$')));
    expect(opf.findAllElements('dc:title').single.innerText, isNotEmpty);
    expect(opf.findAllElements('dc:language').single.innerText, 'zh-CN');
    expect(
      opf
          .findAllElements('meta')
          .where((e) => e.getAttribute('property') == 'dcterms:modified')
          .single
          .innerText,
      '2026-11-15T08:30:05Z',
    );

    // 清单与包里的文件一一对应，id 不重复，恰好一份导航文档。
    final items = opf.findAllElements('item').toList();
    final hrefs = <String, String>{
      for (final item in items)
        item.getAttribute('id')!: 'OEBPS/${item.getAttribute('href')}',
    };
    expect(hrefs, hasLength(items.length));
    expect(
      hrefs.values.toSet(),
      files.keys
          .where((String path) => path.startsWith('OEBPS/') && path != opfPath)
          .toSet(),
    );
    expect(
      items.where((e) => e.getAttribute('properties') == 'nav'),
      hasLength(1),
    );
    for (final item in items) {
      final href = item.getAttribute('href')!;
      final type = item.getAttribute('media-type');
      if (href.endsWith('.xhtml')) {
        expect(type, 'application/xhtml+xml');
      } else if (href.endsWith('.jpg')) {
        expect(type, 'image/jpeg');
      } else if (href.endsWith('.png')) {
        expect(type, 'image/png');
      } else if (href.endsWith('.gif')) {
        expect(type, 'image/gif');
      }
    }
    final spine = opf.findAllElements('itemref').map((e) {
      return e.getAttribute('idref')!;
    });
    expect(spine, isNotEmpty);
    expect(spine.every(hrefs.containsKey), isTrue);
    expect(opf.findAllElements('spine').single.getAttribute('toc'), 'ncx');

    // 内容文件里的图片都在清单里。
    for (final entry in documents.entries) {
      if (!entry.key.endsWith('.xhtml')) continue;
      for (final image in entry.value.findAllElements('img')) {
        final target = p.posix.normalize(
          p.posix.join(p.posix.dirname(entry.key), image.getAttribute('src')!),
        );
        expect(hrefs.values, contains(target), reason: entry.key);
      }
    }

    // 导航文档与 NCX 的每个目标都存在：文件在包里，锚点在文件里。
    void expectTarget(String base, String href) {
      final hash = href.indexOf('#');
      final file = p.posix.normalize(
        p.posix.join(base, hash < 0 ? href : href.substring(0, hash)),
      );
      expect(documents.containsKey(file), isTrue, reason: href);
      if (hash >= 0) {
        final id = href.substring(hash + 1);
        expect(
          documents[file]!.descendantElements.any(
            (XmlElement e) => e.getAttribute('id') == id,
          ),
          isTrue,
          reason: href,
        );
      }
    }

    final nav = documents['OEBPS/nav.xhtml']!;
    final toc = nav
        .findAllElements('nav')
        .singleWhere((e) => e.getAttribute('epub:type') == 'toc');
    final links = toc.findAllElements('a').toList();
    expect(links, isNotEmpty);
    for (final link in links) {
      expect(link.innerText.trim(), isNotEmpty);
      expectTarget('OEBPS', link.getAttribute('href')!);
    }
    final ncx = documents['OEBPS/toc.ncx']!;
    expect(
      ncx
          .findAllElements('meta')
          .singleWhere((e) => e.getAttribute('name') == 'dtb:uid')
          .getAttribute('content'),
      identifier,
    );
    final points = ncx.findAllElements('navPoint').toList();
    expect(points, hasLength(links.length));
    expect(points.map((e) => e.getAttribute('playOrder')), <String>[
      for (var i = 1; i <= points.length; i++) '$i',
    ]);
    for (final point in points) {
      expectTarget(
        'OEBPS',
        point.findElements('content').single.getAttribute('src')!,
      );
    }
    return files;
  }

  group('package', () {
    test('a single diary makes a valid book with one content file', () async {
      final files = await checkPackage(
        await epub(<DiaryExportEntry>[
          fullExportEntry(image: jpg, cover: png),
        ], code: code),
      );
      expect(
        files.keys.where((String path) => path.startsWith('OEBPS/text/')),
        <String>['OEBPS/text/0001.xhtml'],
      );
      final opf = text(files, 'OEBPS/content.opf');
      expect(opf, contains('<dc:title>导出 &lt;测试&gt;</dc:title>'));
      // 普通导出的目录只在阅读器的目录面板里，不占一页。
      expect(opf, contains('<spine toc="ncx">\n<itemref idref="e0001"/>\n'));
      expect(opf, isNot(contains('cover-image')));
    });

    test('several diaries become one file each, listed by date and title in '
        'the contents', () async {
      final output = await epub(<DiaryExportEntry>[
        fullExportEntry(image: jpg, diaryId: 'a'),
        richEntry(image: png),
        richEntry(title: ''),
      ]);
      final files = await checkPackage(output);
      expect(
        files.keys.where((String path) => path.startsWith('OEBPS/text/')),
        <String>[
          'OEBPS/text/0001.xhtml',
          'OEBPS/text/0002.xhtml',
          'OEBPS/text/0003.xhtml',
        ],
      );
      final nav = text(files, 'OEBPS/nav.xhtml');
      expect(nav, contains('<h1>目录</h1>'));
      expect(
        nav,
        contains(
          '<li><a href="text/0002.xhtml"><span class="toc-date">2026-4-3'
          '</span> 春日 *小记*</a></li>',
        ),
      );
      // 没有标题的一篇在目录里写“无标题”，链接不会没有文字。
      expect(nav, contains('</span> 无标题</a>'));
      expect(
        text(files, 'OEBPS/toc.ncx'),
        contains('<text>2026-4-3 春日 *小记*</text>'),
      );
      // 图片按原文件流式打包，不读进内存。
      final images = output.files!.where(
        (DiaryExportBundleFile f) => f.path.startsWith('OEBPS/images/'),
      );
      expect(images.map((f) => f.path), <String>[
        'OEBPS/images/0001.jpg',
        'OEBPS/images/0002.png',
      ]);
      expect(images.every((DiaryExportBundleFile f) => f.file != null), isTrue);
      expect(
        files.keys.any((String path) => path.contains(temp.path)),
        isFalse,
      );
      for (final page in files.keys.where((k) => k.endsWith('.xhtml'))) {
        expect(text(files, page), isNot(contains(temp.path)), reason: page);
      }
    });

    test('the identifier is stable for the same diaries and moment, and '
        'differs for another export', () {
      final a = DiaryEpubPackage.identifierFor(<String>['x', 'y'], exportedAt);
      expect(DiaryEpubPackage.identifierFor(<String>['x', 'y'], exportedAt), a);
      expect(
        DiaryEpubPackage.identifierFor(<String>[
          'x',
          'y',
        ], exportedAt.add(const Duration(seconds: 1))),
        isNot(a),
      );
      // RFC 4122：版本 5、变体 10xx。
      expect(a, matches(RegExp(r'^urn:uuid:.{14}5.{3}-[89ab]')));
    });
  });

  group('content', () {
    /// 元素的结构签名：名字、class 与其余属性（图片地址、懒加载除外；布尔
    /// 属性只记名字，两种语法写法不同）。
    List<String> htmlShape(dom.Element root) => <String>[
      for (final e in root.querySelectorAll('*'))
        _signature(e.localName!, <String, String>{
          for (final entry in e.attributes.entries)
            entry.key.toString(): entry.value,
        }),
    ];
    List<String> xmlShape(XmlElement root) => <String>[
      for (final e in root.descendantElements)
        _signature(e.localName, <String, String>{
          for (final a in e.attributes) a.qualifiedName: a.value,
        }),
    ];

    test('every block, inline style, image and comment of the diary is '
        'written exactly as in the web page', () async {
      final entries = <DiaryExportEntry>[
        fullExportEntry(image: jpg, cover: png),
        richEntry(image: jpg),
      ];
      final files = await unpack(
        await epub(
          entries,
          code: code,
          typography: const DiaryTypography(firstLineIndent: 1),
        ),
      );
      final web = await DiaryHtmlWriter.write(
        entries,
        options: DiaryExportOptions.defaults,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        documentTitle: 'web',
        languageTag: 'zh-CN',
        code: code,
        typography: const DiaryTypography(firstLineIndent: 1),
      );
      final page = html_parser.parse(utf8.decode(web.files!.first.bytes!));
      final articles = page.querySelectorAll('article');
      expect(articles, hasLength(2));
      final forbidden = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]');
      for (var i = 0; i < articles.length; i++) {
        final book = XmlDocument.parse(
          text(files, 'OEBPS/text/000${i + 1}.xhtml'),
        );
        final article = book.findAllElements('article').single;
        expect(xmlShape(article), htmlShape(articles[i]), reason: '$i');
        expect(
          article.innerText,
          articles[i].text.replaceAll(forbidden, ''),
          reason: '$i',
        );
      }
      // 抽查各块确实都在（避免两边一起漏）。
      final full = text(files, 'OEBPS/text/0001.xhtml');
      for (final marker in <String>[
        '<figure class="cover"><img src="../images/0001.png" alt=""/>',
        '<p class="meta">晴 · 杭州西湖 · 😊 · 精力 4/5</p>',
        '<li>#a&amp;b</li>',
        '<strong>粗</strong><em>斜</em><u>下划线</u><s>删除</s><code>a&lt;b</code>',
        // 链接地址规整成合法的 URL（阅读器与 epubcheck 不认引号、空格）。
        '<a href="https://example.com/?a=1&amp;b=%222%22">链接</a>坏链接',
        '<span style="color:#D32F2F;background-color:rgba(255,235,59,0.333)">彩色</span>',
        '<span style="font-size:1.25em">大字</span>',
        'x<sup>2</sup>H<sub>2</sub>O 😀👨‍👩‍👧 &amp; &lt;tag&gt;',
        '<p style="text-indent:2em">这一段标了缩进</p>',
        '<p>这一段取消缩进</p>',
        '<h3 style="text-align:right">标题 2</h3>',
        '<h6 class="h-level-7" aria-level="7">标题 6</h6>',
        '<ol><li class="ls-circled">第一<ul><li class="ls-star">',
        '<input type="checkbox" disabled="disabled" checked="checked" style="text-align:center"/> 做完了',
        '<input type="checkbox" disabled="disabled"/> 还没做',
        '<blockquote><p>一句引用</p></blockquote>',
        '<code class="language-dart"><span class="hl-keyword">if</span>',
        '<figure class="align-center"><img src="../images/0002.jpg" alt="" style="max-width:min(100%,240px)"/></figure>',
        '<figure class="thumbs"><img src="../images/0002.jpg" alt="" class="thumb"/><img src="../images/0002.jpg" alt="" class="thumb"/></figure>',
        '<p class="attachment">[录音 晨间录音 · 1:15]</p>',
        '<p class="attachment">[视频 海边]</p>',
        '<p class="attachment">[附件 报告.pdf]</p>',
        '<hr/>',
        '<div class="callout callout-blue"><span class="callout-icon">☔</span>',
        '<details open="open"><summary>展开看看</summary>',
        '<p style="text-indent:1em">折叠里的段落</p>',
        '<thead><tr><th>姓名</th><th>备注</th></tr></thead>',
        '<td>第一段<br/>第二段</td>',
        '<p>另一篇日记</p>',
        '<h2>留言</h2>',
        '<p class="comment-text">😊 第一条留言\n第二行 &lt;b&gt;</p>',
        // 第二条留言：一张写成图片，找不到的那张写成占位。
        '<p class="comment-text">[图片]</p><div class="comment-images"><img src="../images/0002.jpg" alt=""/></div>',
      ]) {
        expect(full, contains(marker), reason: marker);
      }
      expect(
        text(files, 'OEBPS/text/0002.xhtml'),
        contains('<a href="https://example.com/a%20b">西湖</a>'),
      );
      expect(full, isNot(contains('javascript')));
      expect(full, isNot(contains('loading=')));
      expect(full, isNot(contains('jotsy://')));
      expect(full, isNot(contains('/private/')));
    });

    test('leaves out images and meta when the options say so', () async {
      final files = await checkPackage(
        await epub(
          <DiaryExportEntry>[fullExportEntry(image: jpg, cover: png)],
          options: DiaryExportOptions.defaults.copyWith(
            includeMedia: false,
            includeMeta: false,
          ),
        ),
      );
      expect(files.keys.where((k) => k.contains('images/')), isEmpty);
      final page = text(files, 'OEBPS/text/0001.xhtml');
      expect(page, isNot(contains('<img')));
      expect(page, isNot(contains('杭州西湖')));
      expect(page, isNot(contains('class="tags"')));
      // 留言的两张图都写成占位，正文的媒体名称照常。
      expect(page, contains('<p class="comment-text">[图片 ×2]</p>'));
      expect(page, contains('[录音 晨间录音 · 1:15]'));
    });
  });

  group('images', () {
    /// 只有图片块的一篇日记，按 [sources] 的顺序各一张。
    DiaryExportEntry picturesEntry(List<String> sources) =>
        DiaryExportEntry.parse(
          diaryId: 'pictures',
          title: '图片',
          createdAt: DateTime(2026, 4, 3),
          updatedAt: DateTime(2026, 4, 3),
          blockDocument: <String, Object?>{
            'document': <String, Object?>{
              'type': 'page',
              'children': <Map<String, Object?>>[
                for (final source in sources)
                  <String, Object?>{
                    'type': 'image',
                    'data': <String, Object?>{'url': source},
                  },
              ],
            },
          },
        );

    test('keeps JPEG, PNG and GIF as they are, turns BMP and WebP into JPEG, '
        'and leaves out what no reader can show', () async {
      Future<String> write(String name, List<int> bytes) async {
        final path = p.join(temp.path, name);
        await File(path).writeAsBytes(bytes);
        return path;
      }

      final gif = await write('a.gif', base64Decode(gifBase64));
      final webp = await write('b.webp', base64Decode(webpBase64));
      final bmp = await write('c.bmp', base64Decode(bmpBase64));
      // 格式按文件头识别：扩展名是 .webp、内容是 PNG 的照原样收成 PNG。
      final misnamed = await write('d.webp', base64Decode(pngBase64));
      // HEIC 的文件头（ftypheic）：读不出尺寸，与网页一样不写。
      final heic = await write('e.heic', <int>[
        0, 0, 0, 24, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63, //
      ]);
      final files = await checkPackage(
        await epub(<DiaryExportEntry>[
          picturesEntry(<String>[
            jpg,
            png,
            gif,
            webp,
            bmp,
            misnamed,
            heic,
            p.join(temp.path, 'missing.jpg'),
          ]),
        ]),
      );
      expect(files.keys.where((k) => k.contains('/images/')), <String>[
        'OEBPS/images/0001.jpg',
        'OEBPS/images/0002.png',
        'OEBPS/images/0003.gif',
        'OEBPS/images/0004.jpg',
        'OEBPS/images/0005.jpg',
        'OEBPS/images/0006.png',
      ]);
      expect(files['OEBPS/images/0001.jpg'], base64Decode(jpgBase64));
      expect(files['OEBPS/images/0003.gif'], base64Decode(gifBase64));
      expect(files['OEBPS/images/0006.png'], base64Decode(pngBase64));
      final fromWebp = img.decodeJpg(files['OEBPS/images/0004.jpg']!)!;
      expect((fromWebp.width, fromWebp.height), (6, 4));
      final fromBmp = img.decodeJpg(files['OEBPS/images/0005.jpg']!)!;
      expect((fromBmp.width, fromBmp.height), (2, 9));
      // HEIC 与找不到的图片不写：正文里只有收进书里的六张。
      final page = text(files, 'OEBPS/text/0001.xhtml');
      expect('<img'.allMatches(page), hasLength(6));
    });

    test('a converted image with transparent pixels becomes a PNG, an opaque '
        'one a JPEG', () async {
      final image = img.Image(width: 3, height: 1, numChannels: 4);
      for (final pixel in image) {
        pixel
          ..r = 10
          ..g = 20
          ..b = 30
          ..a = pixel.x == 0 ? 0 : 255;
      }
      final transparent = await DiaryEpubWriter.transcodeImage(
        img.encodePng(image),
      );
      expect(transparent!.mimeType, 'image/png');
      final decoded = img.decodePng(transparent.bytes)!;
      expect(decoded.getPixel(0, 0).a, 0);
      expect(decoded.getPixel(1, 0).a, 255);

      for (final pixel in image) {
        pixel.a = 255;
      }
      final opaque = await DiaryEpubWriter.transcodeImage(img.encodePng(image));
      expect(opaque!.mimeType, 'image/jpeg');
      expect(opaque.extension, '.jpg');
      expect(
        await DiaryEpubWriter.transcodeImage(Uint8List.fromList(<int>[1, 2])),
        isNull,
      );
    });
  });

  group('book', () {
    test('opens with a title page and a visible contents page, starts each '
        'chapter in its first diary, and uses the book cover', () async {
      final a = fullExportEntry(image: jpg, diaryId: 'a');
      final b = richEntry(image: jpg);
      final c = fullExportEntry(
        image: jpg,
        diaryId: 'c',
        title: '回家',
        createdAt: DateTime(2026, 5, 2),
      );
      final layout = bookOf(
        <DiaryExportEntry>[a, b, c],
        cover: png,
        chapters: <DiaryExportBookChapter>[
          DiaryExportBookChapter(title: '春', diaryIds: <String>['a', 'd1']),
          DiaryExportBookChapter(diaryIds: <String>['c']),
        ],
      );
      final files = await checkPackage(
        await epub(layout.entries, book: layout, title: layout.title),
      );
      final opf = text(files, 'OEBPS/content.opf');
      expect(opf, contains('<dc:title>旅行 &amp; 日记</dc:title>'));
      expect(opf, contains('<dc:description>走过的路</dc:description>'));
      expect(opf, contains('<meta name="cover" content="cover-image"/>'));
      expect(
        opf,
        contains(
          '<item id="cover-image" href="images/0001.png" '
          'media-type="image/png" properties="cover-image"/>',
        ),
      );
      expect(
        opf,
        contains(
          '<spine toc="ncx">\n<itemref idref="titlepage"/>\n'
          '<itemref idref="nav"/>\n<itemref idref="e0001"/>\n'
          '<itemref idref="e0002"/>\n<itemref idref="e0003"/>\n</spine>',
        ),
      );

      final title = text(files, 'OEBPS/text/title.xhtml');
      for (final marker in <String>[
        '<section class="book-title" epub:type="titlepage">',
        '<img src="../images/0001.png" alt=""/>',
        '<h1>旅行 &amp; 日记</h1>',
        '<p class="book-description">走过的路</p>',
        '2026-4-3 – 2026-5-2 · 3 篇',
        '导出于 2026-10-19',
      ]) {
        expect(title, contains(marker), reason: marker);
      }

      final first = text(files, 'OEBPS/text/0001.xhtml');
      expect(
        first,
        contains(
          '<h1 class="chapter-title" id="chapter-1">春</h1>\n'
          '<article id="entry-1">',
        ),
      );
      expect(first, contains('<h2>全部 &lt;块&gt; &amp; “格式”</h2>'));
      // 正文标题顺延：1 级写成 h3。
      expect(first, contains('<h3>标题 1</h3>'));
      expect(
        text(files, 'OEBPS/text/0002.xhtml'),
        isNot(contains('chapter-title')),
      );
      expect(
        text(files, 'OEBPS/text/0003.xhtml'),
        contains('<h1 class="chapter-title" id="chapter-2">未分章</h1>'),
      );

      final nav = text(files, 'OEBPS/nav.xhtml');
      expect(nav, contains('<h1>目录</h1>\n<ol class="toc-chapters">'));
      expect(
        nav,
        contains(
          '<li><a href="text/0001.xhtml#chapter-1">春</a>\n'
          '<ol class="toc-entries">\n'
          '<li><a href="text/0001.xhtml#entry-1">',
        ),
      );
      expect(nav, contains('<a href="text/0003.xhtml#chapter-2">未分章</a>'));
      final ncx = text(files, 'OEBPS/toc.ncx');
      expect(ncx, contains('<meta name="dtb:depth" content="2"/>'));
      expect(ncx, contains('<docTitle><text>旅行 &amp; 日记</text></docTitle>'));
    });

    test('a book without chapters lists its diaries in one level', () async {
      final a = richEntry(image: jpg);
      final layout = bookOf(
        <DiaryExportEntry>[a],
        chapters: <DiaryExportBookChapter>[
          DiaryExportBookChapter(diaryIds: <String>['d1']),
        ],
      );
      final files = await checkPackage(
        await epub(
          layout.entries,
          book: layout,
          options: DiaryExportOptions.defaults.copyWith(includeMedia: false),
        ),
      );
      final nav = text(files, 'OEBPS/nav.xhtml');
      expect(nav, contains('<ol class="toc-entries">'));
      expect(nav, isNot(contains('toc-chapters')));
      expect(text(files, 'OEBPS/text/0001.xhtml'), isNot(contains('<h1')));
      expect(text(files, 'OEBPS/text/title.xhtml'), isNot(contains('<img')));
      expect(text(files, 'OEBPS/content.opf'), isNot(contains('cover')));
    });
  });

  group('styles', () {
    test('use fixed colors the reader themes can live with, the code theme '
        'and the body font, without CSS variables', () async {
      final files = await unpack(
        await epub(
          <DiaryExportEntry>[fullExportEntry(image: jpg)],
          code: code,
          fonts: <String>['LXGW WenKai', 'Bad"</style>'],
        ),
      );
      final css = text(files, 'OEBPS/style.css');
      expect(css, isNot(contains('var(')));
      expect(css, isNot(contains('prefers-color-scheme')));
      expect(
        css,
        contains('body{font-family:"LXGW WenKai","Bad\\22 \\3c /style\\3e "}'),
      );
      expect(css, contains('.callout-blue{background:rgba('));
      expect(css, contains('pre{background:#'));
      expect(css, contains('.hl-keyword{color:#'));
      // 代码块在阅读器里折行，不能横向滚动。
      expect(css, contains('white-space:pre-wrap'));
      expect(
        text(files, 'OEBPS/text/0001.xhtml'),
        contains(
          '<link rel="stylesheet" type="text/css" href="../style.css"/>',
        ),
      );
    });

    test('leave code highlighting out when no diary has code', () async {
      final files = await unpack(
        await epub(<DiaryExportEntry>[
          DiaryExportEntry.parse(
            diaryId: 'plain',
            title: '无代码',
            createdAt: DateTime(2026, 4, 3),
            updatedAt: DateTime(2026, 4, 3),
            deltaOps: <dynamic>[
              <String, dynamic>{'insert': '正文\n'},
            ],
          ),
        ], code: code),
      );
      expect(text(files, 'OEBPS/style.css'), isNot(contains('.hl-')));
    });
  });
}

/// 元素的结构签名：名字与属性（图片地址、懒加载除外）。两种语法的写法差异
/// 先抹平：布尔属性只记名字，链接地址按 [Uri] 规整（EPUB 写成百分号编码）。
String _signature(String name, Map<String, String> attributes) {
  const flags = <String>{'disabled', 'checked', 'open'};
  final kept =
      attributes.entries
          .where((e) => e.key != 'src' && e.key != 'loading')
          .map(
            (e) => flags.contains(e.key)
                ? e.key
                : e.key == 'href'
                ? 'href=${Uri.parse(e.value)}'
                : '${e.key}=${e.value}',
          )
          .toList()
        ..sort();
  return '$name[${kept.join(',')}]';
}
