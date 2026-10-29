import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_codec.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_from_delta.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_walk.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor_globals.dart';

Map<String, Object?> _block(
  String type,
  String text, [
  List<Map<String, Object?>> children = const [],
]) => {
  'type': type,
  if (children.isNotEmpty) 'children': children,
  'data': {
    'delta': [
      {'insert': text},
    ],
  },
};

Map<String, Object?> _document(List<Map<String, Object?>> children) => {
  'document': {'type': 'page', 'children': children},
};

/// 每块一行：层级缩进 + 类型 + 文字。
String _outline(Map<String, Object?> document) => [
  for (final (node, depth) in walkDiaryBlocks(document))
    '${'  ' * depth}${node['type']} ${diaryBlockText(node)}',
].join('\n');

void main() {
  test('container block types are exactly the blocks the editor draws '
      'children for', () {
    // 上游可缩进的四种类型画出子块；折叠块由编辑器的全局登记补进上游的
    // 可缩进类型表（`ensureDiaryEditorGlobals`，编辑器挂载前调用）。登记
    // 之后两者必须严格相等：能挂子块的类型就是编辑器画得出子块、Tab 能
    // 缩进进去的那几种，多一种会留下看不见的子块，少一种会把能显示的子块
    // 在读取时提出来。
    ensureDiaryEditorGlobals();
    expect(af.indentableBlockTypes, contains(kDiaryBlockToggleList));
    expect(kDiaryContainerBlockTypes, af.indentableBlockTypes);
  });

  test('stored children of quotes and headings move after them in reading '
      'order', () {
    final stored = _document([
      _block('quote', 'q', [
        _block('paragraph', 'p1', [_block('paragraph', 'p2')]),
        _block('heading', 'h', [_block('paragraph', 'p3')]),
      ]),
      _block('paragraph', 'p4', [
        _block('code', 'c', [_block('paragraph', 'p5')]),
      ]),
    ]);
    final decoded = decodeStoredDiaryBlocks(jsonEncode(stored));
    expect(
      _outline(decoded),
      [
        'quote q',
        'paragraph p1',
        '  paragraph p2',
        'heading h',
        'paragraph p3',
        'paragraph p4',
        '  code c',
        '  paragraph p5',
      ].join('\n'),
    );
    // 阅读顺序不变：纯文本镜像与修正前一致。
    expect(diaryBlocksPlainText(decoded), diaryBlocksPlainText(stored));
  });

  test('documents without hidden children come back untouched', () {
    final stored = _document([
      _block('paragraph', 'a', [_block('bulleted_list', 'b')]),
      _block('quote', 'q'),
    ]);
    final document = stored.cast<String, Object?>();
    expect(identical(liftHiddenDiaryBlockChildren(document), document), isTrue);
    expect(
      jsonEncode(decodeStoredDiaryBlocks(jsonEncode(stored))),
      jsonEncode(stored),
    );
  });

  test('old indented lines after a quote are no longer hidden inside it', () {
    final document = diaryBlocksFromQuillOps([
      {'insert': 'q'},
      {
        'insert': '\n',
        'attributes': {'blockquote': true},
      },
      {'insert': 'indented'},
      {
        'insert': '\n',
        'attributes': {'indent': 1},
      },
    ]);
    expect(_outline(document), 'quote q\nparagraph indented');
  });
}
