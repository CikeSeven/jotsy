import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/controllers/diary_block_editing.dart';
import 'package:node_diary/ui/diaries/controllers/diary_block_reorder.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_insert.dart';
import 'package:node_diary/ui/diaries/models/image_insertion.dart';

void main() {
  test(
    'images replace selected prose and undo restores the complete document',
    () {
      final controller = DiaryEditorController.fromContent('hello world');
      controller.select(
        af.Selection.single(path: [0], startOffset: 2, endOffset: 5),
      );
      final before = controller.contentJson;
      insertDiaryImages(controller: controller, imagePaths: ['/a.png']);
      final nodes = controller.document.root.children;
      expect(nodes.map((node) => node.type), [
        'paragraph',
        'image',
        'paragraph',
      ]);
      expect(nodes[0].delta!.toPlainText(), 'he');
      expect(nodes[2].delta!.toPlainText(), ' world');
      expect(controller.selection!.end.path, [2]);
      controller.undo();
      expect(controller.contentJson, before);
      controller.dispose();
    },
  );

  test('media in an empty document leaves a final editable paragraph', () {
    final controller = DiaryEditorController.fromContent('');
    insertDiaryEditorNodes(
      controller: controller,
      nodes: [
        af.Node(type: 'video', attributes: {'url': '/v.mp4'}),
      ],
    );
    expect(controller.document.root.children.map((node) => node.type), [
      'video',
      'paragraph',
    ]);
    expect(controller.selection!.end.path, [1]);
    controller.undo();
    expect(controller.plainText, isEmpty);
    controller.dispose();
  });

  test(
    'moving a parent preserves children, rejects cycles, and undoes atomically',
    () {
      final controller = DiaryEditorController.fromContent(
        jsonEncode({
          'document': {
            'type': 'page',
            'children': [
              {
                'type': 'paragraph',
                'data': {
                  'delta': [
                    {'insert': 'parent'},
                  ],
                },
                'children': [
                  {
                    'type': 'todo_list',
                    'data': {
                      'checked': true,
                      'delta': [
                        {'insert': 'child'},
                      ],
                    },
                  },
                ],
              },
              {
                'type': 'paragraph',
                'data': {
                  'delta': [
                    {'insert': 'last'},
                  ],
                },
              },
            ],
          },
        }),
      );
      final before = controller.contentJson;
      final parent = controller.document.nodeAtPath([0])!;
      expect(moveDiaryEditorBlock(controller, parent, [0, 0]), isFalse);
      expect(moveDiaryEditorBlock(controller, parent, [2]), isTrue);
      expect(
        controller.document.nodeAtPath([1, 0])!.attributes['checked'],
        isTrue,
      );
      expect(controller.document.nodeAtPath([1])!.id, parent.id);
      controller.undo();
      expect(controller.contentJson, before);
      controller.dispose();
    },
  );

  test('native indent and outdent preserve text', () {
    final controller = DiaryEditorController.fromContent('parent\nchild');
    controller.select(af.Selection.single(path: [1], startOffset: 2));
    af.indentCommand.handler(controller.state);
    expect(
      controller.document.nodeAtPath([0, 0])!.delta!.toPlainText(),
      'child',
    );
    af.outdentCommand.handler(controller.state);
    expect(controller.document.nodeAtPath([1])!.delta!.toPlainText(), 'child');
    controller.dispose();
  });

  test(
    'code return keeps indentation and exits only after two blank lines',
    () async {
      final controller = DiaryEditorController.fromContent(
        jsonEncode({
          'document': {
            'type': 'page',
            'children': [
              {
                'type': 'code',
                'data': {
                  'delta': [
                    {'insert': '  x'},
                  ],
                  'language': 'dart',
                },
              },
            ],
          },
        }),
      );
      controller.select(af.Selection.single(path: [0], startOffset: 3));
      final newline = diaryBlockCharacterShortcuts().first;
      expect(await newline.handler(controller.state), isTrue);
      expect(
        controller.document.nodeAtPath([0])!.delta!.toPlainText(),
        '  x\n  ',
      );
      await newline.handler(controller.state);
      expect(
        controller.document.nodeAtPath([0])!.delta!.toPlainText(),
        '  x\n  \n  ',
      );
      await newline.handler(controller.state);
      expect(controller.document.nodeAtPath([0])!.delta!.toPlainText(), '  x');
      expect(controller.document.nodeAtPath([1])!.type, 'paragraph');
      controller.undo();
      expect(
        controller.document.nodeAtPath([0])!.delta!.toPlainText(),
        '  x\n  \n  ',
      );
      controller.dispose();
    },
  );
  test(
    'turning selected sibling paragraphs into code combines them in one undo step',
    () {
      final controller = DiaryEditorController.fromContent('first\nsecond');
      final before = controller.contentJson;
      controller.select(
        af.Selection(
          start: af.Position(path: [0]),
          end: af.Position(path: [1], offset: 6),
        ),
      );
      toggleDiaryCodeBlockOn(controller);
      expect(controller.document.root.children, hasLength(1));
      expect(controller.document.root.children.single.type, 'code');
      expect(
        controller.document.root.children.single.delta!.toPlainText(),
        'first\nsecond',
      );
      controller.undo();
      expect(controller.contentJson, before);
      controller.dispose();
    },
  );
}
