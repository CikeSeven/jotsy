import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
import 'package:node_diary/ui/diaries/export/diary_export_blocks.dart';
import 'package:node_diary/ui/diaries/export/diary_export_docx.dart';
import 'package:node_diary/ui/diaries/export/diary_export_entry.dart';
import 'package:node_diary/ui/diaries/export/diary_export_format.dart';
import 'package:node_diary/ui/diaries/export/diary_export_html.dart';
import 'package:node_diary/ui/diaries/export/diary_export_media.dart';
import 'package:xml/xml.dart';

import '../../../support/export_test_images.dart';
import 'diary_export_pdf_test_support.dart';
import 'diary_export_test_fixtures.dart';

/// 正文里并排的小图在导出里同样三张一排：块模型按应用的分排标出每张所在
/// 的那一排（[ExportBlock.thumbnailRow]），PDF / Word / 网页把同一排写在
/// 同一行，容器块里的小图仍一张一行。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, Object?> image({
    bool thumbnail = true,
    String? align,
    String? url,
  }) => <String, Object?>{
    'type': kDiaryBlockImage,
    'data': <String, Object?>{
      'url': url ?? 'data:image/png;base64,$pngBase64',
      if (thumbnail) kDiaryImageThumbnailKey: true,
      'align': ?align,
    },
  };

  group('ExportBlock.thumbnailRow', () {
    test('groups top-level runs of thumbnails three to a row like the '
        'editor', () {
      final blocks = pdfEntryOf(<Map<String, Object?>>[
        image(),
        image(),
        image(),
        image(),
        pdfTextBlock(kDiaryBlockParagraph, 'gap'),
        image(),
        image(thumbnail: false),
        image(),
      ]).blocks;
      expect(blocks.map((ExportBlock b) => b.thumbnailRow), <int?>[
        0,
        0,
        0,
        3,
        null,
        5,
        null,
        7,
      ]);
      expect(exportThumbnailRowEnd(blocks, 0), 3);
      expect(exportThumbnailRowEnd(blocks, 1), 3);
      expect(exportThumbnailRowEnd(blocks, 3), 4);
      // 不在一排里的块只有自己；给了上限时不越过它。
      expect(exportThumbnailRowEnd(blocks, 4), 5);
      expect(exportThumbnailRowEnd(blocks, 6), 7);
      expect(exportThumbnailRowEnd(blocks, 0, 2), 2);
    });

    test('keeps thumbnails inside containers one per line, and a block the '
        'export drops still separates two runs', () {
      final blocks = pdfEntryOf(<Map<String, Object?>>[
        pdfTextBlock(
          kDiaryBlockToggleList,
          'fold',
          children: <Map<String, Object?>>[image(), image()],
        ),
        image(),
        // 没有标题快照的日记卡片导出时略过，在应用里仍隔开前后两串小图。
        <String, Object?>{
          'type': kDiaryBlockLinkCard,
          'data': <String, Object?>{kDiaryLinkCardTargetKey: 'jotsy://x'},
        },
        image(),
      ]).blocks;
      expect(blocks.map((ExportBlock b) => b.kind), <ExportBlockKind>[
        ExportBlockKind.toggle,
        ExportBlockKind.image,
        ExportBlockKind.image,
        ExportBlockKind.image,
        ExportBlockKind.image,
      ]);
      expect(blocks.map((ExportBlock b) => b.thumbnailRow), <int?>[
        null,
        null,
        null,
        1,
        3,
      ]);
      expect(exportThumbnailRowEnd(blocks, 1), 2);
      expect(exportThumbnailRowEnd(blocks, 3), 4);
    });
  });

  /// 三种格式共用的一篇：第一排三张里有一张读不出来、第四张另起一排、
  /// 居中的一排两张、折叠列表里的两张。
  List<Map<String, Object?>> document() => <Map<String, Object?>>[
    image(),
    image(url: '/missing/photo.jpg'),
    image(),
    image(),
    pdfTextBlock(kDiaryBlockParagraph, 'gap'),
    image(align: 'center'),
    image(),
    pdfTextBlock(
      kDiaryBlockToggleList,
      'fold',
      children: <Map<String, Object?>>[image(), image()],
    ),
  ];

  test('PDF draws each row side by side with the app gap, aligned like its '
      'first thumbnail', () async {
    final commands = await exportPdfBlocks(document(), includeMedia: true);
    // 正文每块都先平移到版心左缘（2cm 页边距）再绘制；一块里先是缩进与
    // 对齐的平移（第一张的圆角裁切路径之前），再是每张小图在这一排里的
    // 位置（90pt 见方）。
    final rows = <List<double>>[
      for (final block in commands.split(
        RegExp(r'q 1 0 0 1 56\.69291 [\d.]+ cm'),
      ))
        if (block.contains(' Do'))
          () {
            final head = block.substring(
              0,
              RegExp(r'q [\d.]+ 9 m').firstMatch(block)!.start,
            );
            final offset = RegExp(r'1 0 0 1 ([\d.]+) [\d.]+ cm')
                .allMatches(head)
                .fold<double>(0, (sum, m) => sum + double.parse(m.group(1)!));
            return <double>[
              for (final picture in RegExp(
                r'W n 1 0 0 1 ([\d.]+) 0 cm q 0 0 90 90 re W n',
              ).allMatches(block))
                offset + double.parse(picture.group(1)!),
            ];
          }(),
    ];
    const contentWidth = 17 / 2.54 * 72;
    // 读不出的那张去掉，同一排剩下的仍挨着；格间 8px = 6pt。
    expect(rows, hasLength(5));
    expect(rows[0], <double>[0, 96]);
    expect(rows[1], <double>[0]);
    final centered = (contentWidth - 186) / 2;
    expect(rows[2], hasLength(2));
    expect(rows[2][0], closeTo(centered, 0.01));
    expect(rows[2][1], closeTo(centered + 96, 0.01));
    // 折叠列表里的小图不并排，跟着层级缩进。
    expect(rows[3], <double>[18]);
    expect(rows[4], <double>[18]);
  });

  test('Word writes a row as one paragraph of inline pictures with the gap '
      'between them', () async {
    final docx = await DiaryDocxWriter.write(
      <DiaryExportEntry>[pdfEntryOf(document())],
      options: DiaryExportOptions.defaults,
      labels: testExportLabels,
      media: DiaryExportMediaLibrary(),
      documentTitle: 'Thumbnails',
      languageTag: 'zh-CN',
    );
    final body = XmlDocument.parse(
      utf8.decode(
        docx.files!.singleWhere((f) => f.path == 'word/document.xml').bytes!,
      ),
    ).findAllElements('w:body').single;
    final paragraphs = body.findElements('w:p').toList();
    final pictures = <XmlElement>[
      for (final p in paragraphs)
        if (p.findAllElements('w:drawing').isNotEmpty) p,
    ];
    expect(pictures.map((p) => p.findAllElements('w:drawing').length), <int>[
      2,
      1,
      2,
      1,
      1,
    ]);
    for (final p in pictures) {
      for (final extent in p.findAllElements('wp:extent')) {
        expect(extent.getAttribute('cx'), '${120 * 9525}');
        expect(extent.getAttribute('cy'), '${120 * 9525}');
      }
    }
    // 两张之间是一段 1pt 的空格加字符间距（约 6pt），只有一张时没有。
    List<String?> gaps(XmlElement p) => <String?>[
      for (final run in p.findElements('w:r'))
        if (run.getElement('w:t')?.innerText == ' ')
          run
              .getElement('w:rPr')
              ?.getElement('w:spacing')
              ?.getAttribute('w:val'),
    ];
    expect(gaps(pictures[0]), <String?>['114']);
    expect(gaps(pictures[1]), isEmpty);
    expect(gaps(pictures[2]), <String?>['114']);
    String? jc(XmlElement p) =>
        p.getElement('w:pPr')?.getElement('w:jc')?.getAttribute('w:val');
    expect(pictures.map(jc), <String?>[null, null, 'center', null, null]);
    // 读不出的那张与单张一样写成占位，排在这一排后面。
    final next = paragraphs[paragraphs.indexOf(pictures[0]) + 1];
    expect(next.innerText, '[图片]');
  });

  test('the web page puts each row in one flex figure whose thumbnails '
      'shrink together on narrow screens', () async {
    final html = await DiaryHtmlWriter.write(
      <DiaryExportEntry>[pdfEntryOf(document())],
      options: DiaryExportOptions.defaults,
      labels: testExportLabels,
      media: DiaryExportMediaLibrary(),
      documentTitle: 'Thumbnails',
      languageTag: 'zh-CN',
    );
    final page = utf8.decode(html.bytes!);
    final figures = RegExp(
      r'<figure class="thumbs([^"]*)"[^>]*>(.*?)</figure>',
    ).allMatches(page).toList();
    expect(figures.map((m) => '<img '.allMatches(m.group(2)!).length), <int>[
      2,
      1,
      2,
      1,
      1,
    ]);
    expect(figures.map((m) => m.group(1)), <String>[
      '',
      '',
      ' thumbs-center',
      '',
      '',
    ]);
    expect(RegExp(r'<img [^>]*class="thumb"').allMatches(page), hasLength(7));
    expect(page, contains('figure.thumbs{display:flex;gap:8px}'));
    // 边长与应用同一口径：一排三张恰好放下，最大 120px。
    expect(page, contains('width:calc((100% - 16px) / 3);max-width:120px;'));
  });
}
