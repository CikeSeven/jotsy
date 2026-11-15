import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/export/diary_export_book.dart';
import 'package:node_diary/ui/diaries/export/diary_export_entry.dart';
import 'package:node_diary/ui/diaries/export/diary_export_format.dart';
import 'package:node_diary/ui/diaries/export/diary_export_media.dart';
import 'package:node_diary/ui/diaries/export/diary_export_pdf.dart';
import 'package:node_diary/ui/diaries/export/diary_export_pdf_emoji.dart';
import 'package:pdf/widgets.dart' as pw;

import 'diary_export_pdf_test_support.dart';
import 'diary_export_test_fixtures.dart';

/// PDF 里的 emoji（#262）：嵌入的字体没有 emoji 字形，emoji 画成图片按
/// 行内组件排进文字，不再印成方框。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  bool none(int rune) => false;
  bool all(int rune) => true;

  group('which graphemes become images', () {
    test('emoji the font cannot draw, flags, keycaps and ZWJ sequences', () {
      for (final emoji in <String>[
        '😀',
        '🇨🇳',
        '1️⃣',
        '👨‍👩‍👧',
        '👍🏽',
        '🏴‍☠️',
      ]) {
        expect(isDiaryPdfEmoji(emoji, fontCovers: none), isTrue, reason: emoji);
      }
    });

    test('symbols the font draws stay text unless color is asked for', () {
      // 字体有字形、没带 U+FE0F：照常写成文字，可以复制、搜索。
      for (final symbol in <String>['©', '★', '❤', '↔']) {
        expect(isDiaryPdfEmoji(symbol, fontCovers: all), isFalse);
        expect(isDiaryPdfEmoji(symbol, fontCovers: none), isTrue);
      }
      expect(isDiaryPdfEmoji('❤️', fontCovers: all), isTrue);
      // U+FE0E 要求文字呈现：字体画得出就写文字，画不出仍画成图片。
      expect(isDiaryPdfEmoji('☺︎', fontCovers: all), isFalse);
      expect(isDiaryPdfEmoji('☺︎', fontCovers: none), isTrue);
    });

    test('letters, CJK and punctuation are never images', () {
      for (final text in <String>['A', '中', '。', '1', ' ']) {
        expect(isDiaryPdfEmoji(text, fontCovers: none), isFalse);
      }
    });

    test('split keeps whole grapheme clusters and leaves plain text alone', () {
      final emoji = DiaryPdfEmoji(fontCovers: none);
      expect(emoji.split('今天 sunny 。'), isNull);
      expect(emoji.split('a👨‍👩‍👧b🇨🇳'), <(String, bool)>[
        ('a', false),
        ('👨‍👩‍👧', true),
        ('b', false),
        ('🇨🇳', true),
      ]);
    });

    test('the bundled font covers CJK but has no emoji glyphs', () async {
      final fonts = await DiaryPdfFonts.load();
      final covers = diaryPdfFontCoverage(<pw.Font>[fonts.regular]);
      expect(covers('中'.runes.single), isTrue);
      expect(covers('😀'.runes.single), isFalse);
    });
  });

  test('cropping removes transparent edges and drops empty bitmaps', () {
    // 4×3，只有 (2, 1) 不透明。
    final rgba = Uint8List(4 * 3 * 4);
    rgba.setRange((1 * 4 + 2) * 4, (1 * 4 + 2) * 4 + 4, <int>[255, 0, 0, 255]);
    final cropped = cropDiaryEmojiBitmap(
      DiaryPdfEmojiBitmap(width: 4, height: 3, rgba: rgba),
    )!;
    expect((cropped.width, cropped.height), (1, 1));
    expect(cropped.rgba, <int>[255, 0, 0, 255]);
    expect(
      cropDiaryEmojiBitmap(
        DiaryPdfEmojiBitmap(width: 2, height: 2, rgba: Uint8List(16)),
      ),
      isNull,
    );
  });

  group('PDF output', () {
    // 带透明度的图片是一个 RGB 图片对象加一个 SMask，按 SMask 计数。
    final imageObject = RegExp(r'/SMask\s+\d+\s+0\s+R');
    final drawImage = RegExp(r'\bDo\b');

    test('emoji in the body are drawn inline as images, one per distinct '
        'emoji, without tofu text', () async {
      final one = await exportPdfBlocks(<Map<String, Object?>>[
        pdfTextBlock('paragraph', 'Hi😀there'),
      ]);
      final two = await exportPdfBlocks(<Map<String, Object?>>[
        pdfTextBlock('paragraph', 'Hi😀😀there'),
      ]);
      expect(drawImage.allMatches(one), hasLength(1));
      expect(drawImage.allMatches(two), hasLength(2));
      // 文字照常排在 emoji 两侧：多一个 emoji，后面的文字右移一个 emoji
      // 宽（正文 12pt × 1.2）。
      expect(pdfXsOf(one, 'Hi'), <double>[0]);
      expect(pdfXsOf(two, 'Hi'), <double>[0]);
      expect(
        pdfXsOf(two, 'there').single - pdfXsOf(one, 'there').single,
        closeTo(12 * 1.2, 0.01),
      );
    });

    Future<String> exportRaw(
      DiaryExportEntry entry, {
      bool includeMeta = false,
      DiaryExportBookLayout? book,
    }) async {
      final output = await DiaryPdfWriter.write(
        <DiaryExportEntry>[entry],
        options: DiaryExportOptions.defaults.copyWith(
          includeMedia: false,
          includeMeta: includeMeta,
        ),
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        fonts: await pdfAsciiFonts(),
        documentTitle: 'Emoji',
        book: book,
      );
      return latin1.decode(output.bytes!);
    }

    test('the same emoji is embedded once however often it appears', () async {
      final raw = await exportRaw(
        pdfEntryOf(<Map<String, Object?>>[
          pdfTextBlock('paragraph', '😀 one'),
          pdfTextBlock('heading', '😀 two', data: {'level': 2}),
          pdfTextBlock('bulleted_list', '😀 three'),
        ]),
      );
      expect(imageObject.allMatches(raw), hasLength(1));
    });

    test('documents without emoji embed no images', () async {
      final raw = await exportRaw(
        pdfEntryOf(<Map<String, Object?>>[pdfTextBlock('paragraph', 'Plain')]),
        includeMeta: true,
      );
      expect(imageObject.allMatches(raw), isEmpty);
    });

    test('the mood in the meta line and the callout icon are drawn', () async {
      final withMood = DiaryExportEntry.parse(
        diaryId: 'mood',
        title: 'Mood',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        metadata: jsonEncode(<String, Object?>{
          'context': <String, Object?>{'moodEmoji': '😀'},
        }),
        deltaOps: <dynamic>[
          <String, dynamic>{'insert': 'Body\n'},
        ],
      );
      expect(
        imageObject.allMatches(await exportRaw(withMood, includeMeta: true)),
        hasLength(1),
      );
      expect(
        imageObject.allMatches(await exportRaw(withMood)),
        isEmpty,
        reason: 'meta line turned off',
      );

      final callout = await exportPdfBlocks(<Map<String, Object?>>[
        pdfTextBlock('callout', 'Note'),
      ]);
      expect(drawImage.allMatches(callout), hasLength(1));
    });

    test('book title page, chapter headings and contents draw emoji', () async {
      final entry = DiaryExportEntry.parse(
        diaryId: 'a',
        title: 'Day one',
        createdAt: DateTime(2026, 4, 1),
        updatedAt: DateTime(2026, 4, 1),
        deltaOps: <dynamic>[
          <String, dynamic>{'insert': 'Body\n'},
        ],
      );
      final book = DiaryExportBookLayout.resolve(
        DiaryExportBook(
          title: 'Trip 🌍',
          chapters: <DiaryExportBookChapter>[
            DiaryExportBookChapter(title: 'Spring 🌸', diaryIds: <String>['a']),
          ],
        ),
        <DiaryExportEntry>[entry],
        labels: testBookLabels,
        exportedAt: DateTime(2026, 10, 19),
      );
      final raw = await exportRaw(entry, book: book);
      // 🌍 与 🌸 各一份；扉页的 build 到保存时才调用，也画了出来。
      expect(imageObject.allMatches(raw), hasLength(2));
    });
  });

  group('rasterizing', () {
    // 与写出器同一顺序：先建组件（登记 emoji），再栅格化，最后保存。
    Future<String> render(DiaryPdfEmoji emoji) async {
      final text = buildDiaryPdfText(
        'a😀b😀',
        emoji: emoji,
        style: pw.TextStyle(font: pw.Font.helvetica()),
      );
      await emoji.rasterize();
      final document = pw.Document()
        ..addPage(pw.Page(build: (pw.Context context) => text));
      return latin1.decode(await document.save());
    }

    test(
      'each emoji is rendered once and embedded at its pixel size',
      () async {
        final drawn = <String>[];
        final emoji = DiaryPdfEmoji(
          fontCovers: none,
          rasterizer: (String text) async {
            drawn.add(text);
            return DiaryPdfEmojiBitmap(
              width: 3,
              height: 2,
              rgba: Uint8List.fromList(List<int>.filled(3 * 2 * 4, 255)),
            );
          },
        );
        final raw = await render(emoji);
        // 出现两次，只画一次、只嵌一份。
        expect(drawn, <String>['😀']);
        expect(RegExp(r'/SMask\s+\d+\s+0\s+R').allMatches(raw), hasLength(1));
        expect(raw, matches(RegExp(r'/Width\s+3\b')));
      },
    );

    test('a failed rasterization leaves a blank gap instead of failing the '
        'export', () async {
      final raw = await render(
        DiaryPdfEmoji(
          fontCovers: none,
          rasterizer: (String text) async => throw StateError('no engine'),
        ),
      );
      expect(raw, startsWith('%PDF-'));
      expect(RegExp(r'/Subtype\s*/Image').allMatches(raw), isEmpty);
    });
  });
}
