import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/export/diary_export_blocks.dart';
import 'package:node_diary/ui/diaries/export/diary_export_docx.dart';
import 'package:node_diary/ui/diaries/export/diary_export_entry.dart';
import 'package:node_diary/ui/diaries/export/diary_export_format.dart';
import 'package:node_diary/ui/diaries/export/diary_export_html.dart';
import 'package:node_diary/ui/diaries/export/diary_export_image_box.dart';
import 'package:node_diary/ui/diaries/export/diary_export_media.dart';
import 'package:xml/xml.dart';

import '../../../support/export_test_images.dart';
import 'diary_export_pdf_test_support.dart';
import 'diary_export_test_fixtures.dart';

/// 正文图片的尺寸、小图与对齐：块模型读出应用里的设置，PDF / Word / 网页
/// 按同一口径（[ExportImageBox]）写出。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, Object?> image(Map<String, Object?> data) => <String, Object?>{
    'type': 'image',
    'data': <String, Object?>{
      'url': 'data:image/png;base64,$pngBase64',
      ...data,
    },
  };

  ExportBlock blockOf(Map<String, Object?> data) =>
      pdfEntryOf(<Map<String, Object?>>[image(data)]).blocks.single;

  group('ExportImageBox', () {
    test('keeps the original size and never enlarges a small image', () {
      final box = ExportImageBox.of(blockOf(const {}), 240, 90);
      expect((box.width, box.height, box.thumbnail), (240, 90, false));
    });

    test('treats the resize menu size as an upper bound that keeps the '
        'ratio, and fits the page the writer gives', () {
      final resized = blockOf(const {'style': 'width: 300.0; height: 900.0; '});
      expect(resized.imageMaxWidth, 300);
      expect(resized.imageMaxHeight, 900);
      final box = ExportImageBox.of(resized, 1200, 400);
      expect((box.width, box.height), (300, 100));
      // 导入写入的独立宽高同样只作上限。
      final imported = ExportImageBox.of(
        blockOf(const {'height': '50px'}),
        1200,
        400,
      );
      expect((imported.width, imported.height), (150, 50));
      final page = ExportImageBox.of(
        blockOf(const {}),
        1200,
        400,
        maxWidth: 600,
      );
      expect((page.width, page.height), (600, 200));
    });

    test('thumbnails are a fixed square cropped to cover, long images keep '
        'their top', () {
      final block = blockOf(const {'thumbnail': true});
      expect(block.imageThumbnail, isTrue);
      final wide = ExportImageBox.of(block, 1200, 400);
      expect((wide.width, wide.height, wide.thumbnail), (120, 120, true));
      expect(wide.cropLeft, closeTo(1 / 3, 1e-9));
      expect(wide.cropRight, closeTo(1 / 3, 1e-9));
      expect(wide.radius, 12);
      final tall = ExportImageBox.of(block, 300, 600);
      expect(
        (tall.cropTop, tall.cropBottom, tall.keepsTop),
        (0.25, 0.25, false),
      );
      final long = ExportImageBox.of(block, 200, 800);
      expect((long.cropTop, long.cropBottom, long.keepsTop), (0, 0.75, true));
    });
  });

  test('PDF draws images at their own size and alignment instead of '
      'stretching them across the page', () async {
    final commands = await exportPdfBlocks(<Map<String, Object?>>[
      image(const {}),
      image(const {'align': 'center'}),
      image(const {'align': 'right'}),
    ], includeMedia: true);
    // 3×2 像素按 96 DPI 是 2.25 × 1.5pt。
    final draws = RegExp(
      r'([\d.]+) 0 0 ([\d.]+) 0 0 cm /I\w+ Do',
    ).allMatches(commands).toList();
    expect(draws, hasLength(3));
    for (final draw in draws) {
      expect(double.parse(draw.group(1)!), closeTo(2.25, 1e-6));
      expect(double.parse(draw.group(2)!), closeTo(1.5, 1e-6));
    }
    const contentWidth = 17 / 2.54 * 72;
    // 每张图先按它在行里的位置裁出自己的框（re W n），再平移到那里绘制。
    final xs = <double>[
      for (final match in RegExp(
        r'q ([\d.]+) 0 2\.25 1\.5 re W n 1 0 0 1 [\d.]+ 0 cm',
      ).allMatches(commands))
        double.parse(match.group(1)!),
    ];
    expect(xs, hasLength(3));
    expect(xs[0], 0);
    expect(xs[1], closeTo((contentWidth - 2.25) / 2, 0.01));
    expect(xs[2], closeTo(contentWidth - 2.25, 0.01));
  });

  test('Word and the web page keep the image size, thumbnail and '
      'alignment', () async {
    final entry = pdfEntryOf(<Map<String, Object?>>[
      image(const {'align': 'right'}),
      image(const {'style': 'width: 2.0; height: 900.0; ', 'align': 'center'}),
      image(const {'thumbnail': true}),
    ]);
    final docx = await DiaryDocxWriter.write(
      <DiaryExportEntry>[entry],
      options: DiaryExportOptions.defaults,
      labels: testExportLabels,
      media: DiaryExportMediaLibrary(),
      documentTitle: 'Images',
      languageTag: 'zh-CN',
    );
    final document = XmlDocument.parse(
      utf8.decode(
        docx.files!.singleWhere((f) => f.path == 'word/document.xml').bytes!,
      ),
    );
    final pictures = <XmlElement>[
      for (final p in document.findAllElements('w:p'))
        if (p.findAllElements('w:drawing').isNotEmpty) p,
    ];
    String? jc(XmlElement p) =>
        p.getElement('w:pPr')?.getElement('w:jc')?.getAttribute('w:val');
    (int, int) extent(XmlElement p) {
      final e = p.findAllElements('wp:extent').single;
      return (
        int.parse(e.getAttribute('cx')!) ~/ 9525,
        int.parse(e.getAttribute('cy')!) ~/ 9525,
      );
    }

    expect(pictures.map(jc), <String?>['right', 'center', null]);
    expect(extent(pictures[0]), (3, 2));
    // 宽上限 2px：3×2 按比例缩到 2×1.33。
    expect(extent(pictures[1]).$1, 2);
    expect(extent(pictures[2]), (120, 120));
    final crop = pictures[2].findAllElements('a:srcRect').single;
    expect(crop.getAttribute('l'), '16667');
    expect(crop.getAttribute('r'), '16667');

    final html = await DiaryHtmlWriter.write(
      <DiaryExportEntry>[entry],
      options: DiaryExportOptions.defaults,
      labels: testExportLabels,
      media: DiaryExportMediaLibrary(),
      documentTitle: 'Images',
      languageTag: 'zh-CN',
    );
    final page = utf8.decode(html.bytes!);
    expect(page, contains('<figure class="align-right"><img '));
    expect(page, contains('style="max-width:min(100%,2px);max-height:900px"'));
    expect(page, contains('class="thumb"'));
  });
}
