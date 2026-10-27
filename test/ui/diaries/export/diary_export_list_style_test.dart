import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_list_style.dart';
import 'package:node_diary/ui/diaries/export/diary_export_blocks.dart';
import 'package:node_diary/ui/diaries/export/diary_export_docx.dart';
import 'package:node_diary/ui/diaries/export/diary_export_entry.dart';
import 'package:node_diary/ui/diaries/export/diary_export_format.dart';
import 'package:node_diary/ui/diaries/export/diary_export_html.dart';
import 'package:node_diary/ui/diaries/export/diary_export_media.dart';
import 'package:node_diary/ui/diaries/export/diary_export_plain_text.dart';

import 'diary_export_test_fixtures.dart';

/// 列表样式跟着导出：纯文本 / Word 写按样式排出的序号与标记，网页给每项
/// 标上样式类名；没选过的列表按层级轮换，与编辑器一致。
Map<String, Object?> _item(
  String type,
  String text, {
  String? style,
  List<Map<String, Object?>> children = const [],
}) => {
  'type': type,
  'data': {
    'delta': [
      {'insert': text},
    ],
    kDiaryListStyleKey: ?style,
  },
  if (children.isNotEmpty) 'children': children,
};

final Map<String, Object?> _document = {
  'document': {
    'type': 'page',
    'children': [
      _item(
        'numbered_list',
        '早饭',
        style: 'lower-alpha',
        children: [_item('numbered_list', '粥')],
      ),
      // 回车新起的一项没有样式键，沿用同段的样式。
      _item('numbered_list', '午饭'),
      _item('paragraph', '然后'),
      _item(
        'bulleted_list',
        '书',
        style: 'star',
        children: [_item('bulleted_list', '小说')],
      ),
      _item('numbered_list', '晚饭', style: 'cjk'),
      _item('numbered_list', '夜宵'),
    ],
  },
};

DiaryExportEntry _entry() => DiaryExportEntry.parse(
  diaryId: 'list-style',
  title: '清单',
  createdAt: DateTime(2026, 10, 27, 9),
  updatedAt: DateTime(2026, 10, 27, 9),
  deltaOps: const <dynamic>[],
  blockDocument: _document,
);

void main() {
  test('blocks carry the style the editor shows', () {
    final blocks = ExportBlockParser.parseDocument(_document);
    expect(blocks.map((block) => block.listMarker).where((m) => m.isNotEmpty), [
      'a.',
      // 嵌套的有序列表没选过：第 1 层轮换为 a.。
      'a.',
      'b.',
      '★',
      // 嵌套的无序列表没选过：第 1 层为空心圆。
      '○',
      '一、',
      '二、',
    ]);
  });

  test('plain text writes the styled markers', () {
    expect(
      ExportPlainText.render(_entry().blocks),
      'a. 早饭\n'
      '  a. 粥\n'
      'b. 午饭\n'
      '然后\n'
      '★ 书\n'
      '  ○ 小说\n'
      '一、 晚饭\n'
      '二、 夜宵',
    );
  });

  test('html tags each item with its style class', () async {
    final html = await DiaryHtmlWriter.write(
      <DiaryExportEntry>[_entry()],
      options: DiaryExportOptions.defaults.copyWith(
        includeMeta: false,
        includeMedia: false,
      ),
      labels: testExportLabels,
      media: DiaryExportMediaLibrary(),
      documentTitle: '清单',
      languageTag: 'zh',
    );
    final text = utf8.decode(html.bytes!);
    expect(text, contains('<li class="ls-lower-alpha">早饭'));
    expect(text, contains('<li class="ls-star">书'));
    expect(text, contains('<li class="ls-cjk">夜宵'));
    expect(text, contains('li.ls-cjk{list-style-type:simp-chinese-informal}'));
  });

  test('word writes the styled markers before the tab', () async {
    final docx = await DiaryDocxWriter.write(
      <DiaryExportEntry>[_entry()],
      options: DiaryExportOptions.defaults.copyWith(
        includeMeta: false,
        includeMedia: false,
      ),
      labels: testExportLabels,
      media: DiaryExportMediaLibrary(),
      documentTitle: '清单',
      languageTag: 'zh-CN',
      now: DateTime.utc(2026, 10, 27),
    );
    final document = utf8.decode(
      docx.files!.firstWhere((f) => f.path == 'word/document.xml').bytes!,
    );
    for (final marker in ['a.', 'b.', '★', '○', '一、', '二、']) {
      expect(document, contains('>$marker</w:t>'));
    }
  });

  test('legacy Delta lists keep plain numbers and dots', () {
    final blocks = ExportBlockParser.parse(<dynamic>[
      {'insert': 'one'},
      {
        'insert': '\n',
        'attributes': {'list': 'ordered'},
      },
      {'insert': 'dot'},
      {
        'insert': '\n',
        'attributes': {'list': 'bullet', 'indent': 1},
      },
    ]);
    expect(blocks.map((block) => block.listMarker), ['1.', '•']);
  });
}
