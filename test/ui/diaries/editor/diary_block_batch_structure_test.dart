import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/controllers/diary_block_batch_structure.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';

Map<String, Object?> _block(
  String type,
  String text, {
  Map<String, Object?> data = const {},
  List<Map<String, Object?>> children = const [],
  List<Map<String, Object?>>? delta,
}) => {
  'type': type,
  'data': {
    'delta':
        delta ??
        [
          {'insert': text},
        ],
    ...data,
  },
  if (children.isNotEmpty) 'children': children,
};

Map<String, Object?> _p(
  String text, [
  List<Map<String, Object?>> children = const [],
]) => _block('paragraph', text, children: children);

DiaryEditorController _controller(List<Map<String, Object?>> blocks) =>
    DiaryEditorController.fromContent(
      jsonEncode({
        'document': {'type': 'page', 'children': blocks},
      }),
    );

String _text(af.Node node) => node.delta?.toPlainText() ?? '<${node.type}>';

/// 每块一行：缩进、类型、文字（换行写成 ⏎）。
String _outline(DiaryEditorController controller) =>
    walkDiaryEditorNodes(controller.document)
        .map(
          (node) =>
              '${'  ' * (node.path.length - 1)}${node.type}:'
              '${_text(node).replaceAll('\n', '⏎')}',
        )
        .join('\n');

List<af.Node> _top(DiaryEditorController controller) =>
    controller.document.root.children.toList();

void main() {
  test(
    'deleting every block leaves one empty paragraph, undo brings all back',
    () {
      final controller = _controller([_p('a'), _p('b')]);
      final before = controller.contentJson;
      expect(deleteDiaryBlocks(controller, _top(controller)), 2);
      expect(_outline(controller), 'paragraph:');
      controller.undo();
      expect(controller.contentJson, before);
      controller.dispose();
    },
  );

  test('duplicates go after the last block and become the new selection', () {
    final controller = _controller([
      _p('a', [_p('child')]),
      _p('b'),
      _p('c'),
    ]);
    final copies = duplicateDiaryBlocks(controller, [
      _top(controller)[0],
      _top(controller)[1],
    ]);
    expect(
      _outline(controller),
      'paragraph:a\n  paragraph:child\nparagraph:b\n'
      'paragraph:a\n  paragraph:child\nparagraph:b\nparagraph:c',
    );
    expect(copies.map((node) => node.path), [
      [2],
      [3],
    ]);
    controller.dispose();
  });

  test('splitting cuts a pasted block into one block per line, keeping the '
      'inline formatting and dropping blank lines', () {
    final controller = _controller([
      _block(
        'paragraph',
        '',
        delta: [
          {'insert': 'one\n\n'},
          {
            'insert': 'two',
            'attributes': {'bold': true},
          },
          {'insert': '\nthree\n'},
        ],
      ),
    ]);
    final before = controller.contentJson;
    expect(canSplitDiaryBlockLines(_top(controller)), isTrue);
    final after = splitDiaryBlockLines(controller, _top(controller));
    expect(
      _outline(controller),
      'paragraph:one\nparagraph:two\nparagraph:three',
    );
    expect(controller.document.nodeAtPath([1])!.delta!.toJson(), [
      {
        'insert': 'two',
        'attributes': {'bold': true},
      },
    ]);
    expect(after.map(_text), ['one', 'two', 'three']);
    expect(canSplitDiaryBlockLines(after), isFalse);
    controller.undo();
    expect(controller.contentJson, before);
    expect(controller.hasUndo, isFalse);
    controller.dispose();
  });

  test('split pieces keep the block type and attributes; children stay with '
      'the last line; code is never split', () {
    final controller = _controller([
      _block('todo_list', 'x\ny', data: {'checked': true}),
      _block(
        'bulleted_list',
        'l1\nl2',
        children: [_block('bulleted_list', 'c')],
      ),
      _block('code', 'a\nb'),
    ]);
    splitDiaryBlockLines(controller, _top(controller));
    expect(
      _outline(controller),
      'todo_list:x\ntodo_list:y\n'
      'bulleted_list:l1\nbulleted_list:l2\n  bulleted_list:c\n'
      'code:a⏎b',
    );
    expect(
      [for (final node in _top(controller).take(2)) node.attributes['checked']],
      [true, true],
    );
    controller.dispose();
  });

  test('merging joins text blocks into the first one with line breaks and '
      'keeps the children of the merged blocks', () {
    final controller = _controller([
      _p('a'),
      {
        'type': 'image',
        'data': {'url': 'x.png'},
      },
      _block(
        'paragraph',
        'b',
        delta: [
          {
            'insert': 'b',
            'attributes': {'italic': true},
          },
        ],
        children: [_p('b-child')],
      ),
      _p('c'),
    ]);
    final before = controller.contentJson;
    final roots = _top(controller);
    expect(canMergeDiaryBlocks(roots), isTrue);
    final after = mergeDiaryBlocks(controller, roots);
    expect(
      _outline(controller),
      'paragraph:a⏎b⏎c\n  paragraph:b-child\nimage:<image>',
    );
    expect(controller.document.nodeAtPath([0])!.delta!.toJson(), [
      {'insert': 'a\n'},
      {
        'insert': 'b',
        'attributes': {'italic': true},
      },
      {'insert': '\nc'},
    ]);
    expect(after.single.path, [0]);
    // 合并与拆分互为反操作。
    splitDiaryBlockLines(controller, after);
    expect(
      _outline(controller),
      'paragraph:a\nparagraph:b\nparagraph:c\n  paragraph:b-child\n'
      'image:<image>',
    );
    controller.undo();
    controller.undo();
    expect(controller.contentJson, before);
    controller.dispose();
  });

  test('merged children go after a heading, which cannot hold them', () {
    final controller = _controller([
      _block('heading', 'h', data: {'level': 1}),
      _p('p', [_p('kid')]),
      _p('tail'),
    ]);
    mergeDiaryBlocks(controller, [_top(controller)[0], _top(controller)[1]]);
    expect(_outline(controller), 'heading:h⏎p\nparagraph:kid\nparagraph:tail');
    controller.dispose();
  });
}
