import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/export/diary_export_book.dart';
import 'package:node_diary/ui/diaries/export/diary_export_docx.dart';
import 'package:node_diary/ui/diaries/export/diary_export_entry.dart';
import 'package:node_diary/ui/diaries/export/diary_export_format.dart';
import 'package:node_diary/ui/diaries/export/diary_export_html.dart';
import 'package:node_diary/ui/diaries/export/diary_export_markdown.dart';
import 'package:node_diary/ui/diaries/export/diary_export_media.dart';
import 'package:node_diary/ui/diaries/export/diary_export_pdf.dart';
import 'package:node_diary/ui/diaries/export/diary_export_text.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_export_messages.dart';
import 'package:xml/xml.dart';

import 'diary_export_test_fixtures.dart';

/// 导出里的留言：选项的读写、各格式的留言区，以及没有留言时产物不变。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final diaryAt = DateTime(2026, 4, 3, 9, 5);
  final comments = <DiaryCommentRow>[
    DiaryCommentRow(
      id: 1,
      commentId: 'c1',
      diaryId: 'c',
      content: '第一行 <b>\n# 第二行',
      mood: '😀',
      createdAt: DateTime(2026, 4, 5, 21, 30),
      editedAt: DateTime(2026, 4, 6),
    ),
    DiaryCommentRow(
      id: 2,
      commentId: 'c2',
      diaryId: 'c',
      content: '=SUM(1)',
      createdAt: DateTime(2026, 4, 3, 22),
    ),
  ];

  DiaryExportEntry entry({List<DiaryCommentRow> withComments = const []}) {
    return DiaryExportEntry.parse(
      diaryId: 'c',
      title: '回看的日记',
      createdAt: diaryAt,
      updatedAt: diaryAt,
      metadata: testMetadata,
      deltaOps: <dynamic>[
        <String, dynamic>{'insert': '正文\n'},
      ],
      comments: withComments,
    );
  }

  group('DiaryExportOptions.includeComments', () {
    test('defaults on, round-trips and tolerates bad values', () {
      expect(DiaryExportOptions.defaults.includeComments, isTrue);
      final off = DiaryExportOptions.defaults.copyWith(includeComments: false);
      expect(DiaryExportOptions.fromRaw(off.toRaw()), off);
      expect(off, isNot(DiaryExportOptions.defaults));
      // 旧设置里没有这个键、或值不是布尔时回落默认（开）。
      expect(
        DiaryExportOptions.fromRaw('{"format":"text"}').includeComments,
        isTrue,
      );
      expect(
        DiaryExportOptions.fromRaw('{"comments":"no"}').includeComments,
        isTrue,
      );
      expect(
        DiaryExportOptions.fromRaw('{"comments":false}'),
        DiaryExportOptions.defaults.copyWith(includeComments: false),
      );
    });

    test('every format but the Jotsy diary file offers the switch', () {
      for (final format in DiaryExportFormat.values) {
        expect(
          format.supportsCommentsToggle,
          format != DiaryExportFormat.diaryFile,
          reason: format.name,
        );
      }
    });
  });

  group('labels', () {
    test('meta line shares one wording; mood can be left out', () {
      final e = entry(withComments: comments);
      expect(
        testExportLabels.commentMetaLine(e, comments[0]),
        '写下后 2 天 · 4-5 21:30 · 已编辑',
      );
      expect(
        testExportLabels.commentMetaLine(e, comments[1]),
        '当天写下 · 4-3 22:00',
      );
      expect(testExportLabels.commentText(comments[0]), startsWith('😀 第一行'));
      expect(
        testExportLabels.commentText(comments[0], includeMood: false),
        startsWith('第一行'),
      );
    });

    test('app labels use the relative label and the full date', () async {
      await initializeDateFormatting('zh');
      final l10n = lookupAppLocalizations(const Locale('zh'));
      final labels = buildDiaryExportLabels(l10n);
      expect(labels.commentsHeading, '留言');
      // 导出文件以后在别处打开：时间总带完整日期，不按“今天”省略。
      expect(
        labels.commentMetaLine(entry(), comments[0]),
        '写下后 2 天 · ${l10n.formatDateTimeMinute(comments[0].createdAt)} · 已编辑',
      );
      expect(l10n.formatDateTimeMinute(comments[0].createdAt), contains('年'));
    });
  });

  group('writers', () {
    test('Markdown appends a comments list after the body', () async {
      final output = await DiaryMarkdownWriter.write(
        <DiaryExportEntry>[entry(withComments: comments)],
        options: DiaryExportOptions.defaults,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
      );
      final markdown = utf8.decode(output.bytes!);
      expect(
        markdown,
        endsWith(
          '正文\n\n## 留言\n\n'
          '- *写下后 2 天 · 4-5 21:30 · 已编辑*\n\n'
          '  😀 第一行 \\<b\\>\n\n'
          '  \\# 第二行\n\n'
          '- *当天写下 · 4-3 22:00*\n\n'
          '  =SUM(1)\n',
        ),
      );
    });

    test('Markdown books put the comments one level below the entry', () {
      final e = entry(withComments: comments);
      final markdown = DiaryMarkdownWriter.renderBook(
        DiaryExportBookLayout.resolve(
          DiaryExportBook(
            title: '书',
            chapters: <DiaryExportBookChapter>[
              DiaryExportBookChapter(diaryIds: const <String>['c']),
            ],
          ),
          <DiaryExportEntry>[e],
          labels: testBookLabels,
          exportedAt: DateTime(2026, 10, 28),
        ),
        includeMeta: false,
        labels: testExportLabels,
        mediaPathOf: (_) => null,
      );
      expect(markdown, contains('正文\n\n### 留言\n\n- *写下后 2 天'));
    });

    test('plain text adds a ruled comments block', () {
      final text = utf8.decode(
        DiaryTextWriter.write(
          <DiaryExportEntry>[entry(withComments: comments)],
          options: DiaryExportOptions.defaults,
          labels: testExportLabels,
        ).bytes!,
      );
      expect(
        text,
        endsWith(
          '正文\n\n——— 留言 ———\n'
          '写下后 2 天 · 4-5 21:30 · 已编辑\n😀 第一行 <b>\n# 第二行\n\n'
          '当天写下 · 4-3 22:00\n=SUM(1)\n',
        ),
      );
    });

    test(
      'HTML writes an escaped comments section with its own styles',
      () async {
        Future<String> html(DiaryExportEntry e) async => utf8.decode(
          (await DiaryHtmlWriter.write(
            <DiaryExportEntry>[e],
            options: DiaryExportOptions.defaults,
            labels: testExportLabels,
            media: DiaryExportMediaLibrary(),
            documentTitle: 'Jotsy',
            languageTag: 'zh',
          )).bytes!,
        );
        final page = await html(entry(withComments: comments));
        expect(page, contains('<section class="comments">\n<h2>留言</h2>\n'));
        expect(
          page,
          contains(
            '<p class="meta">写下后 2 天 · 4-5 21:30 · 已编辑</p>'
            '<p class="comment-text">😀 第一行 &lt;b&gt;\n# 第二行</p>',
          ),
        );
        expect(page, contains('.comment-text{white-space:pre-wrap}'));
        expect(
          page.indexOf('<section class="comments">'),
          greaterThan(page.indexOf('<p>正文</p>')),
        );

        final plain = await html(entry());
        expect(plain, isNot(contains('comments')));
        expect(plain, isNot(contains('comment-text')));
      },
    );

    test('CSV adds the column only when comments are exported', () {
      String csv(List<DiaryExportEntry> entries, {bool? include}) =>
          utf8.decode(
            (include == null
                    ? DiaryCsvWriter.write(entries, labels: testExportLabels)
                    : DiaryCsvWriter.write(
                        entries,
                        labels: testExportLabels,
                        includeComments: include,
                      ))
                .bytes!,
          );

      final without = csv(<DiaryExportEntry>[entry()]);
      expect(without, contains('字数,最后编辑\r\n'));
      expect(csv(<DiaryExportEntry>[entry()], include: false), without);

      final withComments = csv(<DiaryExportEntry>[
        entry(withComments: comments),
        entry(),
      ], include: true);
      expect(withComments, contains('字数,最后编辑,留言\r\n'));
      expect(
        withComments,
        contains(
          ',"写下后 2 天 · 4-5 21:30 · 已编辑\n😀 第一行 <b>\n# 第二行\n\n'
          '当天写下 · 4-3 22:00\n=SUM(1)"\r\n',
        ),
      );
      // 没有留言的一篇留空格，列数不变。
      expect(withComments, endsWith(',\r\n'));
    });

    test('Word writes the comments with line breaks and stays valid', () async {
      final output = await DiaryDocxWriter.write(
        <DiaryExportEntry>[entry(withComments: comments)],
        options: DiaryExportOptions.defaults,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        documentTitle: 'Jotsy',
        languageTag: 'zh-CN',
        now: DateTime.utc(2026, 10, 28),
      );
      final part = output.files!.firstWhere(
        (f) => f.path == 'word/document.xml',
      );
      final document = XmlDocument.parse(utf8.decode(part.bytes!));
      final text = document
          .findAllElements('w:t')
          .map((e) => e.innerText)
          .toList();
      expect(
        text,
        containsAllInOrder(<String>[
          '正文',
          '留言',
          '写下后 2 天 · 4-5 21:30 · 已编辑',
          '😀 第一行 <b>',
          '# 第二行',
          '当天写下 · 4-3 22:00',
          '=SUM(1)',
        ]),
      );
      expect(document.findAllElements('w:br'), hasLength(1));

      final plain = await DiaryDocxWriter.write(
        <DiaryExportEntry>[entry()],
        options: DiaryExportOptions.defaults,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        documentTitle: 'Jotsy',
        languageTag: 'zh-CN',
        now: DateTime.utc(2026, 10, 28),
      );
      final plainXml = utf8.decode(
        plain.files!.firstWhere((f) => f.path == 'word/document.xml').bytes!,
      );
      expect(plainXml, isNot(contains('留言')));
    });

    test('PDF renders comments without failing', () async {
      final fonts = await DiaryPdfFonts.load();
      Future<List<int>> pdf(DiaryExportEntry e) async =>
          (await DiaryPdfWriter.write(
            <DiaryExportEntry>[e],
            options: DiaryExportOptions.defaults,
            labels: testExportLabels,
            media: DiaryExportMediaLibrary(),
            fonts: fonts,
            documentTitle: 'Jotsy',
          )).bytes!;
      final withComments = await pdf(entry(withComments: comments));
      expect(ascii.decode(withComments.sublist(0, 5)), '%PDF-');
      final without = await pdf(entry());
      expect(withComments.length, greaterThan(without.length));
    });
  });
}
