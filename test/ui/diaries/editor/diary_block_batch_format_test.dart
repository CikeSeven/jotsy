import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/controllers/diary_block_batch_format.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_text_style_options.dart';

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

/// 每块一行：缩进、类型、文字。
String _outline(DiaryEditorController controller) =>
    walkDiaryEditorNodes(controller.document)
        .map(
          (node) =>
              '${'  ' * (node.path.length - 1)}${node.type}:${_text(node)}',
        )
        .join('\n');

List<af.Node> _top(DiaryEditorController controller) =>
    controller.document.root.children.toList();

void main() {
  test('three pasted paragraphs become to-dos in one undo step', () {
    final controller = _controller([_p('a'), _p('b'), _p('c')]);
    final before = controller.contentJson;
    final roots = _top(controller);
    final after = setDiaryBlocksType(controller, roots, (
      type: 'todo_list',
      level: null,
    ));
    expect(_outline(controller), 'todo_list:a\ntodo_list:b\ntodo_list:c');
    expect(
      _top(controller).map((node) => node.attributes['checked']),
      everyElement(false),
    );
    expect(diaryBlocksType(after), (type: 'todo_list', level: null));
    // 已经是这种类型：不写，不留空的撤销步骤。
    setDiaryBlocksType(controller, after, (type: 'todo_list', level: null));
    controller.undo();
    expect(controller.contentJson, before);
    expect(controller.hasUndo, isFalse);
    controller.dispose();
  });

  test('turning a list with children into headings lifts and converts the '
      'children, and keeps them selected', () {
    final controller = _controller([
      _block(
        'bulleted_list',
        'l',
        children: [
          _block('bulleted_list', 'c1'),
          _block('bulleted_list', 'c2'),
        ],
      ),
      _p('x'),
    ]);
    final after = setDiaryBlocksType(
      controller,
      [_top(controller).first],
      (type: 'heading', level: 2),
    );
    expect(
      _outline(controller),
      'heading:l\nheading:c1\nheading:c2\nparagraph:x',
    );
    expect(after.map(_text), ['l', 'c1', 'c2']);
    expect(after.map((node) => node.attributes['level']), everyElement(2));
    controller.dispose();
  });

  test('type changes skip table cells, embeds and (for callouts) code', () {
    final controller = _controller([
      _block('code', 'print(1)'),
      {
        'type': 'image',
        'data': {'url': 'a.png'},
      },
      _p('p'),
    ]);
    expect(diaryBlocksType(_top(controller)), isNull);
    setDiaryBlocksType(controller, _top(controller), (
      type: 'callout',
      level: null,
    ));
    expect(_outline(controller), 'code:print(1)\nimage:<image>\ncallout:p');
    controller.dispose();
  });

  test('bold toggles over whole blocks and leaves code alone', () {
    final controller = _controller([
      _p('a'),
      _block(
        'paragraph',
        'bc',
        delta: [
          {
            'insert': 'b',
            'attributes': {'bold': true},
          },
          {'insert': 'c'},
        ],
      ),
      _block('code', 'x'),
    ]);
    final roots = _top(controller);
    expect(diaryBlocksHaveInline(roots, 'bold'), isFalse);
    toggleDiaryBlocksInline(controller, roots, 'bold');
    expect(diaryBlocksHaveInline(roots, 'bold'), isTrue);
    expect(controller.document.nodeAtPath([2])!.delta!.toJson(), [
      {'insert': 'x'},
    ]);
    toggleDiaryBlocksInline(controller, roots, 'bold');
    expect(diaryBlocksHaveInline(roots, 'bold'), isFalse);
    expect(controller.document.nodeAtPath([1])!.delta!.toJson(), [
      {'insert': 'bc'},
    ]);
    // 两次开关各一步撤销。
    controller.undo();
    expect(diaryBlocksHaveInline(roots, 'bold'), isTrue);
    controller.dispose();
  });

  test('alignment applies to nested text blocks, never to code', () {
    final controller = _controller([
      _p('a', [_p('child')]),
      _block('code', 'x'),
    ]);
    final roots = _top(controller);
    expect(diaryBlocksAlign(roots), DiaryTextAlign.left);
    setDiaryBlocksAlign(controller, roots, DiaryTextAlign.center);
    expect(diaryBlocksAlign(roots), DiaryTextAlign.center);
    expect(
      controller.document.nodeAtPath([0, 0])!.attributes['align'],
      'center',
    );
    expect(controller.document.nodeAtPath([1])!.attributes['align'], isNull);
    final steps = controller.hasUndo;
    // 取值相同时不写。
    setDiaryBlocksAlign(controller, roots, DiaryTextAlign.center);
    controller.undo();
    expect(diaryBlocksAlign(roots), DiaryTextAlign.left);
    expect(steps, isTrue);
    expect(controller.hasUndo, isFalse);
    controller.dispose();
  });

  test('clearing the format turns blocks back into plain paragraphs', () {
    final controller = _controller([
      _block(
        'heading',
        'h',
        data: {'level': 1, 'align': 'center'},
        delta: [
          {
            'insert': 'h',
            'attributes': {'italic': true},
          },
        ],
      ),
      _block('todo_list', 't', data: {'checked': true}),
    ]);
    final after = clearDiaryBlocksFormat(controller, _top(controller));
    expect(_outline(controller), 'paragraph:h\nparagraph:t');
    expect(controller.document.nodeAtPath([0])!.attributes, {
      'delta': [
        {'insert': 'h'},
      ],
    });
    expect(after, hasLength(2));
    controller.dispose();
  });
}
