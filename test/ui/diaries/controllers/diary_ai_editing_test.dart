import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/controllers/diary_ai_editing.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';

/// 写作助手写回正文：一次事务、一步撤销；保留块类型；跨块替换；插在下方。
void main() {
  DiaryEditorController controllerWith(List<Map<String, Object?>> children) =>
      DiaryEditorController.fromContent(
        jsonEncode({
          'document': {'type': 'page', 'children': children},
        }),
      );

  Map<String, Object?> block(String type, String text) => {
    'type': type,
    'data': {
      'delta': [
        {'insert': text},
      ],
    },
  };

  List<String> texts(DiaryEditorController controller) => [
    for (final node in walkDiaryEditorNodes(controller.document))
      if (node.delta != null) node.delta!.toPlainText(),
  ];

  List<String> types(DiaryEditorController controller) => [
    for (final node in controller.document.root.children) node.type,
  ];

  test('targets: selection, paragraph, before caret and document', () {
    final controller = controllerWith([
      block('paragraph', 'first line'),
      block('paragraph', 'second line'),
    ]);
    final range = af.Selection(
      start: af.Position(path: [0], offset: 6),
      end: af.Position(path: [1], offset: 6),
    );
    final selection = diaryAiTarget(
      controller,
      DiaryAiScope.selection,
      selection: range,
    )!;
    expect(selection.text, 'line\nsecond');

    final caret = af.Selection.collapsed(af.Position(path: [1], offset: 3));
    expect(
      diaryAiTarget(controller, DiaryAiScope.paragraph, selection: caret)!.text,
      'second line',
    );
    // 没有选区时“选中的文字”退回当前段落。
    expect(
      diaryAiTarget(
        controller,
        DiaryAiScope.selection,
        selection: caret,
      )!.scope,
      DiaryAiScope.paragraph,
    );
    expect(
      diaryAiTarget(
        controller,
        DiaryAiScope.beforeCaret,
        selection: caret,
      )!.text,
      'first line\nsec',
    );
    expect(
      diaryAiTarget(controller, DiaryAiScope.document)!.text,
      contains('second line'),
    );
    controller.dispose();
  });

  test(
    'a single-paragraph result merges into the block and keeps its type',
    () {
      final controller = controllerWith([
        block('bulleted_list', 'buy mlik now'),
      ]);
      final target = diaryAiTarget(
        controller,
        DiaryAiScope.selection,
        selection: af.Selection(
          start: af.Position(path: [0], offset: 4),
          end: af.Position(path: [0], offset: 8),
        ),
      )!;
      replaceDiaryAiTarget(controller, target, 'milk');
      expect(texts(controller), ['buy milk now']);
      expect(types(controller), ['bulleted_list']);
      controller.undo();
      expect(texts(controller), ['buy mlik now']);
      controller.dispose();
    },
  );

  test('replacing across blocks with markdown is one undo step', () {
    final controller = controllerWith([
      block('paragraph', 'keep A'),
      block('paragraph', 'old 1'),
      block('paragraph', 'old 2'),
      block('paragraph', 'keep B'),
    ]);
    final target = diaryAiTarget(
      controller,
      DiaryAiScope.selection,
      selection: af.Selection(
        start: af.Position(path: [1], offset: 0),
        end: af.Position(path: [2], offset: 5),
      ),
    )!;
    replaceDiaryAiTarget(controller, target, '- one\n- two');
    expect(texts(controller), ['keep A', 'one', 'two', 'keep B']);
    expect(types(controller), [
      'paragraph',
      'bulleted_list',
      'bulleted_list',
      'paragraph',
    ]);
    controller.undo();
    expect(texts(controller), ['keep A', 'old 1', 'old 2', 'keep B']);
    controller.dispose();
  });

  test('inserting below keeps the original and can be undone', () {
    final controller = controllerWith([
      block('paragraph', 'original'),
      block('paragraph', 'after'),
    ]);
    final target = diaryAiTarget(
      controller,
      DiaryAiScope.paragraph,
      selection: af.Selection.collapsed(af.Position(path: [0], offset: 2)),
    )!;
    insertDiaryAiBelow(controller, target, 'translated\n\nsecond paragraph');
    expect(texts(controller), [
      'original',
      'translated',
      'second paragraph',
      'after',
    ]);
    controller.undo();
    expect(texts(controller), ['original', 'after']);
    controller.dispose();
  });

  test('task list output becomes todo blocks', () {
    final nodes = diaryAiMarkdownNodes('- [ ] call mom\n- [x] pay rent');
    expect(nodes.map((node) => node.type), ['todo_list', 'todo_list']);
    expect(nodes.last.attributes['checked'], isTrue);
  });

  test('a stale target falls back to appending at the end', () {
    final controller = controllerWith([block('paragraph', 'only')]);
    final target = DiaryAiTarget(
      scope: DiaryAiScope.paragraph,
      selection: af.Selection(
        start: af.Position(path: [5], offset: 0),
        end: af.Position(path: [5], offset: 3),
      ),
      text: 'gone',
    );
    replaceDiaryAiTarget(controller, target, 'appended');
    expect(texts(controller), ['only', 'appended']);
    controller.dispose();
  });
}
