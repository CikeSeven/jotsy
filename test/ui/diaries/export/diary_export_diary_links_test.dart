import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_link_target.dart';
import 'package:node_diary/ui/diaries/export/diary_export_blocks.dart';
import 'package:node_diary/ui/diaries/export/diary_export_docx.dart';
import 'package:node_diary/ui/diaries/export/diary_export_entry.dart';
import 'package:node_diary/ui/diaries/export/diary_export_format.dart';
import 'package:node_diary/ui/diaries/export/diary_export_html.dart';
import 'package:node_diary/ui/diaries/export/diary_export_markdown.dart';
import 'package:node_diary/ui/diaries/export/diary_export_media.dart';
import 'package:node_diary/ui/diaries/export/diary_export_plain_text.dart';
import 'package:node_diary/ui/diaries/models/diary_share_content.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_to_delta.dart';

import 'diary_export_test_fixtures.dart';

/// 日记链接只在应用里打得开：导出与分享只留文字，卡片按快照标题成段。
final Map<String, Object?> _document = {
  'document': {
    'type': 'page',
    'children': [
      {
        'type': 'paragraph',
        'data': {
          'delta': [
            {'insert': '想起'},
            {
              'insert': '那天',
              'attributes': {
                'href': const DiaryLinkTarget.diary('d-1').toHref(),
                'bold': true,
              },
            },
            {'insert': '，见'},
            {
              'insert': '官网',
              'attributes': {'href': 'https://example.com'},
            },
          ],
        },
      },
      {
        'type': 'link_card',
        'data': diaryLinkCardData(
          const DiaryLinkTarget.notebook('nb-1'),
          '旅行\n手账',
        ),
      },
      // 没有快照的卡片没有可导出的内容。
      {
        'type': 'link_card',
        'data': {'target': const DiaryLinkTarget.diary('d-2').toHref()},
      },
      {
        'type': 'paragraph',
        'data': {
          'delta': [
            {'insert': 'end'},
          ],
        },
      },
    ],
  },
};

final DiaryExportOptions _options = DiaryExportOptions.defaults.copyWith(
  includeMeta: false,
  includeMedia: false,
);

DiaryExportEntry _entry() => DiaryExportEntry.parse(
  diaryId: 'links',
  title: '链接',
  createdAt: DateTime(2026, 10, 29, 9),
  updatedAt: DateTime(2026, 10, 29, 9),
  blockDocument: _document,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('internal links keep their text but lose the address', () {
    final blocks = ExportBlockParser.parseDocument(_document);
    expect(blocks.map((ExportBlock block) => block.kind), [
      ExportBlockKind.paragraph,
      ExportBlockKind.paragraph,
      ExportBlockKind.paragraph,
    ]);
    final runs = blocks.first.inlines;
    expect(runs.map((ExportInline run) => (run.text, run.link)), [
      ('想起', null),
      ('那天', null),
      ('，见', null),
      ('官网', 'https://example.com'),
    ]);
    // 其余行内样式照常保留。
    expect(runs[1].bold, isTrue);
  });

  test('link cards export as their single-line title snapshot', () {
    final blocks = ExportBlockParser.parseDocument(_document);
    expect(blocks[1].plainText, '旅行 手账');
    expect(blocks[1].inlines.single.link, isNull);
    expect(blocks[2].plainText, 'end');
  });

  test('no writer emits the internal address', () async {
    final entry = _entry();
    final text = ExportPlainText.render(entry.blocks);
    expect(text, '想起那天，见官网 (https://example.com)\n旅行 手账\nend');

    final markdown = utf8.decode(
      (await DiaryMarkdownWriter.write(
        <DiaryExportEntry>[entry],
        options: _options,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
      )).bytes!,
    );
    expect(markdown, contains('想起**那天**，见[官网](https://example.com)'));
    expect(markdown, contains('旅行 手账'));

    final html = utf8.decode(
      (await DiaryHtmlWriter.write(
        <DiaryExportEntry>[entry],
        options: _options,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        documentTitle: '链接',
        languageTag: 'zh',
      )).bytes!,
    );
    expect(html, contains('<a href="https://example.com">官网</a>'));

    final docx = await DiaryDocxWriter.write(
      <DiaryExportEntry>[entry],
      options: _options,
      labels: testExportLabels,
      media: DiaryExportMediaLibrary(),
      documentTitle: '链接',
      languageTag: 'zh-CN',
      now: DateTime.utc(2026, 10, 29),
    );
    for (final output in [markdown, html]) {
      expect(output, isNot(contains('jotsy://')));
    }
    for (final file in docx.files!) {
      expect(
        utf8.decode(file.bytes!, allowMalformed: true),
        isNot(contains('jotsy://')),
        reason: file.path,
      );
    }
  });

  test('share text keeps link text and the card title only', () {
    final body = DiaryShareBodyFormatter.format(
      diaryBlocksToQuillOps(_document),
    );
    expect(body.text, '想起那天，见官网 (https://example.com)\n旅行 手账\nend');
  });
}
