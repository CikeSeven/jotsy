import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/mind_map/mind_map_blocks.dart';
import 'package:node_diary/core/database/mind_map/mind_map_document.dart';
import 'package:node_diary/core/database/mind_map/mind_map_ops.dart';
import 'package:node_diary/core/database/mind_map/mind_map_rich_text.dart';
import 'package:node_diary/core/database/mind_map/mind_map_text.dart';
import 'package:node_diary/ui/diaries/export/diary_export_blocks.dart';
import 'package:node_diary/ui/diaries/export/diary_export_entry.dart';
import 'package:node_diary/ui/diaries/export/diary_export_format.dart';
import 'package:node_diary/ui/diaries/export/diary_export_markdown.dart';
import 'package:node_diary/ui/diaries/export/diary_export_media.dart';
import 'package:node_diary/ui/diaries/export/diary_export_plain_text.dart';

import 'diary_export_test_fixtures.dart';

/// 导图按大纲导出：嵌入的导图先写加粗的中心主题，整篇导图日记的中心主题
/// 就是标题，只写下面的主题；主题逐级缩进成无序列表，空主题跳过。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final map = MindMapDocument.blank().copyWith(
    root: mindMapNodeFromOutline('Trip\n  Plan\n    Tickets\n  \n  Pack')!,
  );

  final DiaryExportOptions options = DiaryExportOptions.defaults.copyWith(
    includeMeta: false,
    includeMedia: false,
  );

  test('an embedded map exports its central topic and an indented list', () {
    final blocks = ExportBlockParser.parseDocument(<String, Object?>{
      'document': <String, Object?>{
        'type': 'page',
        'children': <Object?>[mindMapBlockNode(map)],
      },
    });
    expect(
      blocks.map((block) => (block.kind, block.indent, block.plainText)),
      <(ExportBlockKind, int, String)>[
        (ExportBlockKind.paragraph, 0, 'Trip'),
        (ExportBlockKind.bullet, 0, 'Plan'),
        (ExportBlockKind.bullet, 1, 'Tickets'),
        (ExportBlockKind.bullet, 0, 'Pack'),
      ],
    );
    expect(blocks.first.inlines.single.bold, isTrue);
  });

  test('topic text styles go out with the outline: local marks win, the '
      'rest follows the whole-topic style', () {
    final plan = map.root.children.first;
    var styled = MindMapOps.formatText(
      map,
      plan.id,
      0,
      2,
      (marks) => marks
          .withFlag(MindMapMark.bold, true)
          .withColor(MindMapColorMark.highlight, '#FFFDD835'),
    );
    styled = MindMapOps.updateNode(
      styled,
      plan.id,
      (node) => node.copyWith(style: <String, Object?>{'italic': true}),
    );
    final blocks = ExportBlockParser.parseDocument(<String, Object?>{
      'document': <String, Object?>{
        'type': 'page',
        'children': <Object?>[mindMapBlockNode(styled)],
      },
    });
    final inlines = blocks[1].inlines;
    expect(inlines.map((inline) => inline.text), <String>['Pl', 'an']);
    expect(inlines.map((inline) => inline.bold), <bool>[true, false]);
    expect(inlines.map((inline) => inline.italic), <bool>[true, true]);
    expect(inlines.first.background, isNotNull);
    expect(inlines.last.background, isNull);
  });

  test('a mind map diary leaves the title to the entry and writes the '
      'topics in Markdown and plain text', () async {
    final entry = DiaryExportEntry.parse(
      diaryId: 'map',
      title: 'Trip',
      createdAt: DateTime(2026, 11, 16, 9),
      updatedAt: DateTime(2026, 11, 16, 9),
      blockDocument: mindMapDiaryDocument(map),
    );
    expect(ExportPlainText.render(entry.blocks), contains('Plan'));
    expect(ExportPlainText.render(entry.blocks), isNot(startsWith('Trip')));
    final markdown = utf8.decode(
      (await DiaryMarkdownWriter.write(
        <DiaryExportEntry>[entry],
        options: options,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
      )).bytes!,
    );
    expect(markdown, contains('- Plan'));
    expect(markdown, contains('  - Tickets'));
    expect(markdown, contains('- Pack'));
  });
}
