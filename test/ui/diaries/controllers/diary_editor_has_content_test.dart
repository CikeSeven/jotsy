import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_codec.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';

/// `hasContent` 按节点遍历、遇到内容就返回（不再整篇转 JSON），口径必须
/// 与存储侧的 `diaryBlocksHaveVisibleContent` 一致。
void main() {
  String doc(List<Map<String, Object?>> children) => jsonEncode({
    'document': {'type': 'page', 'children': children},
  });

  Map<String, Object?> paragraph(String text, {List<Object?>? children}) => {
    'type': 'paragraph',
    'data': {
      'delta': [
        if (text.isNotEmpty) {'insert': text},
      ],
    },
    'children': ?children,
  };

  final cases = <String, String>{
    'empty': doc([paragraph('')]),
    'whitespace only': doc([paragraph('   '), paragraph('\t')]),
    'text in the first block': doc([paragraph('hello'), paragraph('')]),
    'text after empty blocks': doc([
      paragraph(''),
      paragraph(''),
      paragraph('x'),
    ]),
    'text only in a nested child': doc([
      paragraph('', children: [paragraph('nested')]),
    ]),
    'divider only': doc([
      paragraph(''),
      {'type': 'divider', 'data': <String, Object?>{}},
    ]),
    'image only': doc([
      {
        'type': 'image',
        'data': {'url': '/tmp/a.png'},
      },
    ]),
  };

  for (final MapEntry(key: name, value: content) in cases.entries) {
    test('matches the stored-content check: $name', () {
      final controller = DiaryEditorController.fromContent(content);
      addTearDown(controller.dispose);
      final expected = diaryBlocksHaveVisibleContent(
        controller.document.toJson(),
      );
      expect(controller.hasContent, expected);
    });
  }

  test('reports the obvious answers', () {
    final empty = DiaryEditorController.fromContent(cases['empty']!);
    final text = DiaryEditorController.fromContent(
      cases['text after empty blocks']!,
    );
    addTearDown(empty.dispose);
    addTearDown(text.dispose);
    expect(empty.hasContent, isFalse);
    expect(text.hasContent, isTrue);
  });
}
