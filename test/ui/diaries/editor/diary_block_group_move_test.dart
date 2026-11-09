import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/controllers/diary_block_drag_session.dart';
import 'package:node_diary/ui/diaries/controllers/diary_block_group_move.dart';
import 'package:node_diary/ui/diaries/controllers/diary_block_reorder.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';

Map<String, Object?> _block(
  String type,
  String text, {
  List<Map<String, Object?>> children = const [],
}) => {
  'type': type,
  'data': {
    'delta': [
      {'insert': text},
    ],
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

DiaryEditorController _flat(String texts) =>
    _controller([for (final text in texts.split('')) _p(text)]);

/// 每块一行，按缩进层级前置两个空格。
String _outline(DiaryEditorController controller) => walkDiaryEditorNodes(
  controller.document,
).map((node) => '${'  ' * (node.path.length - 1)}${_text(node)}').join('\n');

String _text(af.Node node) => node.delta?.toPlainText() ?? '<${node.type}>';

String _order(DiaryEditorController controller) =>
    walkDiaryEditorNodes(controller.document).map(_text).join();

List<af.Node> _nodes(DiaryEditorController controller, String texts) => [
  for (final text in texts.split(''))
    walkDiaryEditorNodes(
      controller.document,
    ).firstWhere((node) => _text(node) == text),
];

void main() {
  test('a contiguous run moves as one block and undo restores it', () {
    final controller = _flat('abcde');
    final before = controller.contentJson;
    final run = _nodes(controller, 'bc');

    expect(stepDiaryBlockGroup(controller, run, up: true), isTrue);
    expect(_order(controller), 'bcade');
    expect(canStepDiaryBlockGroup(controller, run, up: true), isFalse);
    expect(stepDiaryBlockGroup(controller, run, up: true), isFalse);
    expect(stepDiaryBlockGroup(controller, run, up: false), isTrue);
    expect(stepDiaryBlockGroup(controller, run, up: false), isTrue);
    expect(_order(controller), 'adbce');
    // 选择模式里移动不落光标。
    expect(controller.state.selection, isNull);

    controller.undo();
    controller.undo();
    controller.undo();
    expect(controller.contentJson, before);
    controller.dispose();
  });

  test('scattered blocks gather above the first or below the last', () {
    final up = _flat('abcde');
    expect(stepDiaryBlockGroup(up, _nodes(up, 'bd'), up: true), isTrue);
    expect(_order(up), 'bdace');
    up.dispose();

    final down = _flat('abcde');
    expect(stepDiaryBlockGroup(down, _nodes(down, 'bd'), up: false), isTrue);
    expect(_order(down), 'acebd');
    down.dispose();
  });

  test('inserting where a moved block used to be does not shift by one', () {
    final controller = _flat('abcd');
    final group = _nodes(controller, 'bd');
    // [1] 是 b 现在的位置，即“a 之后”：整组排在 a 后面。
    expect(moveDiaryEditorBlocks(controller, group, [1]), isTrue);
    expect(_order(controller), 'abdc');
    // 再移到同一处等于没动。
    expect(diaryBlocksMoveChanges(group, [1]), isFalse);
    expect(moveDiaryEditorBlocks(controller, group, [1]), isFalse);
    controller.dispose();
  });

  test('a group never moves into its own subtree', () {
    final controller = _controller([
      _p('a'),
      _block('bulleted_list', 'l', children: [_p('c')]),
    ]);
    final list = _nodes(controller, 'l');
    expect(moveDiaryEditorBlocks(controller, list, [1, 0]), isFalse);
    expect(diaryBlockRoots(_nodes(controller, 'lc')), list);
    controller.dispose();
  });

  test('a mixed-depth group takes its shallowest level', () {
    final controller = _controller([
      _p('x'),
      _block('bulleted_list', 'l', children: [_p('c')]),
      _p('p'),
    ]);
    expect(
      stepDiaryBlockGroup(controller, _nodes(controller, 'cp'), up: true),
      isTrue,
    );
    expect(_outline(controller), 'x\nc\np\nl');
    controller.dispose();
  });

  test('moving to the edges makes the group top-level', () {
    final controller = _controller([
      _p('a'),
      _block('bulleted_list', 'l', children: [_p('c'), _p('d')]),
      _p('e'),
    ]);
    final group = _nodes(controller, 'c');
    expect(moveDiaryBlockGroupToEdge(controller, group, top: true), isTrue);
    expect(_outline(controller), 'c\na\nl\n  d\ne');
    expect(moveDiaryBlockGroupToEdge(controller, group, top: true), isFalse);
    expect(moveDiaryBlockGroupToEdge(controller, group, top: false), isTrue);
    expect(_outline(controller), 'a\nl\n  d\ne\nc');
    controller.dispose();
  });

  test(
    'a group drag previews gathered, cancels back to the scattered origin and '
    'commits one undo step',
    () {
      final controller = _flat('abcde');
      final before = controller.contentJson;
      final group = _nodes(controller, 'bd');

      final cancelled = DiaryBlockDragSession(
        controller,
        group,
        selection: DiaryBlockMoveSelection.none,
      );
      expect(controller.draggingBlock, isTrue);
      expect(cancelled.depth, 1);
      expect(cancelled.preview([5]), isTrue);
      expect(_order(controller), 'acebd');
      expect(cancelled.preview([0]), isTrue);
      expect(_order(controller), 'bdace');
      cancelled.cancel();
      expect(controller.draggingBlock, isFalse);
      expect(controller.contentJson, before);
      expect(controller.hasUndo, isFalse);

      final session = DiaryBlockDragSession(
        controller,
        group,
        selection: DiaryBlockMoveSelection.none,
      );
      expect(session.preview([5]), isTrue);
      // [4] 是 d 自己现在的位置，等于没动；[2] 是 e 之前。
      expect(session.preview([4]), isFalse);
      expect(session.preview([2]), isTrue);
      expect(_order(controller), 'acbde');
      expect(controller.hasUndo, isFalse);
      expect(session.commit(), isTrue);
      expect(_order(controller), 'acbde');
      controller.undo();
      expect(controller.contentJson, before);
      expect(controller.hasUndo, isFalse);
      controller.dispose();
    },
  );

  test('Alt+Shift moves the caret block and keeps the caret in it', () {
    final controller = _flat('abc');
    controller.select(
      af.Selection.collapsed(af.Position(path: [1], offset: 1)),
    );
    expect(moveDiaryBlocksAtSelection(controller, up: true), isTrue);
    expect(_order(controller), 'bac');
    expect(
      controller.state.selection,
      af.Selection.collapsed(af.Position(path: [0], offset: 1)),
    );
    // 已在文首：什么也不做，但按键算处理过。
    expect(moveDiaryBlocksAtSelection(controller, up: true), isTrue);
    expect(_order(controller), 'bac');
    controller.dispose();
  });

  test('Alt+Shift moves every block a selection touches, '
      'but not one it only reaches at offset 0', () {
    final controller = _flat('abcd');
    final selection = af.Selection(
      start: af.Position(path: [0], offset: 0),
      end: af.Position(path: [2], offset: 0),
    );
    controller.select(selection);
    expect(diaryBlocksTouchedBySelection(controller).map(_text), ['a', 'b']);
    expect(moveDiaryBlocksAtSelection(controller, up: false), isTrue);
    expect(_order(controller), 'cabd');
    expect(
      controller.state.selection,
      af.Selection(
        start: af.Position(path: [1], offset: 0),
        end: af.Position(path: [2], offset: 1),
      ),
    );
    controller.dispose();
  });
}
