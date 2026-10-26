import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/controllers/diary_block_editing.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';

Map<String, Object?> _p(
  String text, [
  List<Map<String, Object?>> children = const [],
]) => {
  'type': 'paragraph',
  'data': {
    'delta': [
      {'insert': text},
    ],
  },
  if (children.isNotEmpty) 'children': children,
};

DiaryEditorController _controller(List<Map<String, Object?>> blocks) =>
    DiaryEditorController.fromContent(
      jsonEncode({
        'document': {'type': 'page', 'children': blocks},
      }),
    );

/// 每块一行：层级缩进 + 类型 + 文字。
String _outline(DiaryEditorController controller) =>
    walkDiaryEditorNodes(controller.document)
        .map((node) {
          final text = node.delta?.toPlainText() ?? '';
          return '${'  ' * (node.path.length - 1)}${node.type} $text';
        })
        .join('\n');

void main() {
  test('a block with indented children turned into a heading keeps them '
      'visible after it', () {
    final controller = _controller([
      _p('a', [
        _p('a1', [_p('a2')]),
      ]),
      _p('b'),
    ]);
    final before = controller.contentJson;
    controller.select(
      af.Selection.collapsed(af.Position(path: [0], offset: 1)),
    );
    controller.setBlockType('heading', attributes: {'level': 2});
    final converted = [
      'heading a',
      'paragraph a1',
      '  paragraph a2',
      'paragraph b',
    ].join('\n');
    expect(_outline(controller), converted);
    expect(controller.document.nodeAtPath([0])!.attributes['level'], 2);
    expect(
      controller.selection,
      af.Selection.collapsed(af.Position(path: [0], offset: 1)),
    );
    // 一步撤销回到原样，重做再换回来。
    controller.undo();
    expect(controller.contentJson, before);
    controller.redo();
    expect(_outline(controller), converted);
    controller.dispose();
  });

  test('converting a selected parent and child flattens them and keeps the '
      'selection on the same text', () {
    final controller = _controller([
      _p('a', [
        _p('a1', [_p('a2')]),
      ]),
      _p('b', [_p('b1')]),
    ]);
    final before = controller.contentJson;
    controller.select(
      af.Selection(
        start: af.Position(path: [0]),
        end: af.Position(path: [0, 0], offset: 2),
      ),
    );
    controller.setBlockType('quote');
    expect(
      _outline(controller),
      [
        'quote a',
        'quote a1',
        'paragraph a2',
        'paragraph b',
        '  paragraph b1',
      ].join('\n'),
    );
    expect(
      controller.selection,
      af.Selection(
        start: af.Position(path: [0]),
        end: af.Position(path: [1], offset: 2),
      ),
    );
    controller.undo();
    expect(controller.contentJson, before);
    controller.dispose();
  });

  test('turning a block into a list keeps its children nested in place', () {
    final controller = _controller([
      _p('a', [_p('a1')]),
    ]);
    final a = controller.document.nodeAtPath([0])!;
    final a1 = controller.document.nodeAtPath([0, 0])!;
    controller.select(af.Selection.collapsed(af.Position(path: [0])));
    controller.setBlockType('bulleted_list');
    expect(_outline(controller), 'bulleted_list a\n  paragraph a1');
    // 原地换类型：节点 id 与子块对象都不变。
    expect(controller.document.nodeAtPath([0])!.id, a.id);
    expect(controller.document.nodeAtPath([0, 0]), same(a1));
    controller.dispose();
  });

  test('a code block made from a block with children lifts them too', () {
    final controller = _controller([
      _p('x = 1', [_p('note')]),
    ]);
    controller.select(af.Selection.collapsed(af.Position(path: [0])));
    toggleDiaryCodeBlockOn(controller);
    expect(_outline(controller), 'code x = 1\nparagraph note');
    controller.dispose();
  });

  test('quotes saved with children open with those children visible', () {
    final controller = DiaryEditorController.fromContent(
      jsonEncode({
        'document': {
          'type': 'page',
          'children': [
            {
              'type': 'quote',
              'data': {
                'delta': [
                  {'insert': 'q'},
                ],
              },
              'children': [_p('hidden')],
            },
          ],
        },
      }),
    );
    expect(_outline(controller), 'quote q\nparagraph hidden');
    controller.dispose();
  });
}
