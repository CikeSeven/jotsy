import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_codec.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_to_delta.dart';
import 'package:node_diary/core/database/mind_map/mind_map_blocks.dart';
import 'package:node_diary/core/database/mind_map/mind_map_document.dart';
import 'package:node_diary/core/database/mind_map/mind_map_text.dart';

/// 正文里的导图块：导图日记的识别、纯文本镜像、“有没有内容”与分享文字。
void main() {
  final map = MindMapDocument.blank(
    text: 'Week',
  ).copyWith(root: mindMapNodeFromOutline('Week\n  Mon\n    Gym\n  Tue')!);

  Map<String, Object?> document(List<Map<String, Object?>> children) =>
      <String, Object?>{
        'document': <String, Object?>{'type': 'page', 'children': children},
      };

  Map<String, Object?> paragraph(String text) => <String, Object?>{
    'type': 'paragraph',
    'data': <String, Object?>{
      'delta': <Object?>[
        if (text.isNotEmpty) <String, Object?>{'insert': text},
      ],
    },
  };

  test('a page block with only empty paragraphs after it is a mind map '
      'diary; an embedded block is not', () {
    expect(diaryMindMapPage(mindMapDiaryDocument(map))?.root.text, 'Week');
    expect(
      diaryMindMapPage(
        document(<Map<String, Object?>>[
          mindMapBlockNode(map, page: true),
          paragraph(''),
        ]),
      ),
      isNotNull,
    );
    expect(
      diaryMindMapPage(
        document(<Map<String, Object?>>[
          mindMapBlockNode(map, page: true),
          paragraph('more'),
        ]),
      ),
      isNull,
    );
    expect(
      diaryMindMapPage(document(<Map<String, Object?>>[mindMapBlockNode(map)])),
      isNull,
    );
  });

  test('the stored content can be recognised without decoding it', () {
    final stored = encodeDiaryBlocks(mindMapDiaryDocument(map));
    expect(storedContentMayHaveMindMap(stored), isTrue);
    // 正文文字里写了同样的字：引号被转义，不会误中。
    final text = encodeDiaryBlocks(
      document(<Map<String, Object?>>[paragraph('"type":"mind_map"')]),
    );
    expect(storedContentMayHaveMindMap(text), isFalse);
    expect(decodeStoredDiaryBlocks(stored), jsonDecode(stored));
  });

  test('the plain text mirror carries the topics', () {
    final mirror = diaryBlocksPlainText(
      document(<Map<String, Object?>>[
        paragraph('Before'),
        mindMapBlockNode(map),
        paragraph('After'),
      ]),
    );
    expect(mirror, 'Before\nWeek\nMon\nGym\nTue\nAfter');
  });

  test('an empty map is not content, a written one is', () {
    final blank = mindMapDiaryDocument(MindMapDocument.blank());
    expect(diaryBlocksHaveVisibleContent(blank), isFalse);
    expect(diaryBlocksHaveEmbeds(blank), isFalse);
    expect(diaryBlocksHaveVisibleContent(mindMapDiaryDocument(map)), isTrue);
  });

  test('share text writes the map as an outline', () {
    final ops = diaryBlocksToQuillOps(
      document(<Map<String, Object?>>[mindMapBlockNode(map)]),
    );
    final text = ops.map((op) => op['insert']).whereType<String>().join();
    expect(text, 'Week\nMon\nGym\nTue\n');
    final page = diaryBlocksToQuillOps(mindMapDiaryDocument(map));
    final pageText = page.map((op) => op['insert']).whereType<String>().join();
    // 导图日记的中心主题就是标题，正文里不再重复。
    expect(pageText.startsWith('Mon'), isTrue);
  });
}
