import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/export/diary_export_docx.dart';
import 'package:node_diary/ui/diaries/export/diary_export_entry.dart';
import 'package:node_diary/ui/diaries/export/diary_export_format.dart';
import 'package:node_diary/ui/diaries/export/diary_export_html.dart';
import 'package:node_diary/ui/diaries/export/diary_export_markdown.dart';
import 'package:node_diary/ui/diaries/export/diary_export_media.dart';
import 'package:node_diary/ui/diaries/export/diary_export_pdf.dart';
import 'package:node_diary/ui/diaries/export/diary_export_text.dart';
import 'package:path/path.dart' as p;

import 'diary_export_test_fixtures.dart';

/// 导出里的留言图片：能写图片的格式在带媒体时写成图片，其余（或文件缺失、
/// 不带媒体）在文字里写成“[图片]”占位；只有图片的留言不留空行。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 1×1 的 PNG。
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  );
  late Directory root;
  late String photo;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('jotsy_export_photos_');
    photo = p.join(root.path, 'diary_images', 'media_1', 'sea.png');
    await File(photo).parent.create(recursive: true);
    await File(photo).writeAsBytes(png);
  });
  tearDown(() => root.delete(recursive: true));

  final diaryAt = DateTime(2026, 4, 3, 9, 5);

  DiaryCommentRow comment(String content, List<String> images) =>
      DiaryCommentRow(
        id: 1,
        commentId: 'c1',
        diaryId: 'c',
        content: content,
        createdAt: DateTime(2026, 4, 3, 22),
        images: encodeDiaryCommentImages(images),
      );

  DiaryExportEntry entry(DiaryCommentRow row) => DiaryExportEntry.parse(
    diaryId: 'c',
    title: '回看的日记',
    createdAt: diaryAt,
    updatedAt: diaryAt,
    metadata: testMetadata,
    deltaOps: <dynamic>[
      <String, dynamic>{'insert': '正文\n'},
    ],
    comments: <DiaryCommentRow>[row],
  );

  DiaryExportOptions options({required bool media}) =>
      DiaryExportOptions.defaults.copyWith(includeMedia: media);

  group('labels', () {
    test('photos that are not written become a note after the text', () {
      final both = comment('又来了', <String>[photo, '/gone/diary_images/x.jpg']);
      expect(testExportLabels.commentText(both), '又来了\n[图片 ×2]');
      expect(
        testExportLabels.commentText(both, unrenderedImages: 1),
        '又来了\n[图片]',
      );
      expect(testExportLabels.commentText(both, unrenderedImages: 0), '又来了');
      final only = comment('', <String>[photo]);
      expect(testExportLabels.commentText(only), '[图片]');
      expect(testExportLabels.commentText(only, unrenderedImages: 0), '');
      // 没有图片的留言与加图片之前一样。
      expect(testExportLabels.commentText(comment('字', const [])), '字');
    });

    test('photos count as image sources of the entry', () {
      expect(entry(comment('', <String>[photo])).imageSources, <String>[photo]);
    });
  });

  test('plain text writes the note line', () {
    final text = utf8.decode(
      DiaryTextWriter.write(
        <DiaryExportEntry>[
          entry(comment('', <String>[photo])),
        ],
        options: options(media: true),
        labels: testExportLabels,
      ).bytes!,
    );
    expect(text, contains('当天写下 · 4-3 22:00\n[图片]'));
  });

  group('HTML', () {
    Future<String> html(DiaryCommentRow row, {required bool media}) async =>
        utf8.decode(
          (await DiaryHtmlWriter.write(
            <DiaryExportEntry>[entry(row)],
            options: options(media: media),
            labels: testExportLabels,
            media: DiaryExportMediaLibrary(),
            documentTitle: 'Jotsy',
            languageTag: 'zh',
          )).bytes!,
        );

    test('embeds the photos under the comment', () async {
      final page = await html(comment('', <String>[photo]), media: true);
      expect(page, contains('.comment-images{'));
      expect(
        page,
        contains(
          '<p class="meta">当天写下 · 4-3 22:00</p>'
          '<div class="comment-images"><img src="data:image/png;base64,',
        ),
      );
      // 只有图片：没有空的文字段落。
      expect(page, isNot(contains('<p class="comment-text"></p>')));
    });

    test('without media the photos become a note and no styles', () async {
      final page = await html(comment('又来了', <String>[photo]), media: false);
      expect(page, contains('<p class="comment-text">又来了\n[图片]</p>'));
      expect(page, isNot(contains('comment-images')));
    });
  });

  test('Markdown bundles the photos after the text', () async {
    final output = await DiaryMarkdownWriter.write(
      <DiaryExportEntry>[
        entry(comment('又来了', <String>[photo])),
      ],
      options: options(media: true),
      labels: testExportLabels,
      media: DiaryExportMediaLibrary(),
    );
    final files = output.files!;
    final markdown = utf8.decode(
      files.firstWhere((f) => f.path.endsWith('.md')).bytes!,
    );
    final bundled = files.singleWhere((f) => f.path.startsWith('media/'));
    expect(
      markdown,
      endsWith(
        '- *当天写下 · 4-3 22:00*\n\n'
        '  又来了\n\n'
        '  ![](${bundled.path})\n',
      ),
    );
  });

  test('Word embeds the photos and notes the missing ones', () async {
    final output = await DiaryDocxWriter.write(
      <DiaryExportEntry>[
        entry(comment('又来了', <String>[photo, '/gone/diary_images/x.jpg'])),
      ],
      options: options(media: true),
      labels: testExportLabels,
      media: DiaryExportMediaLibrary(),
      documentTitle: 'Jotsy',
      languageTag: 'zh-CN',
      now: DateTime.utc(2026, 10, 28),
    );
    final document = utf8.decode(
      output.files!.firstWhere((f) => f.path == 'word/document.xml').bytes!,
    );
    expect('<w:drawing>'.allMatches(document), hasLength(1));
    expect(document, contains('[图片]'));
    expect(document.indexOf('[图片]'), lessThan(document.indexOf('<w:drawing>')));
    expect(
      output.files!.where((f) => f.path.startsWith('word/media/')),
      hasLength(1),
    );
  });

  test('PDF draws the photos without failing', () async {
    final fonts = await DiaryPdfFonts.load();
    Future<List<int>> pdf({required bool media}) async =>
        (await DiaryPdfWriter.write(
          <DiaryExportEntry>[
            entry(comment('', <String>[photo])),
          ],
          options: options(media: media),
          labels: testExportLabels,
          media: DiaryExportMediaLibrary(),
          fonts: fonts,
          documentTitle: 'Jotsy',
        )).bytes!;
    final withPhotos = await pdf(media: true);
    expect(ascii.decode(withPhotos.sublist(0, 5)), '%PDF-');
    final without = await pdf(media: false);
    expect(withPhotos.length, greaterThan(without.length));
  });
}
