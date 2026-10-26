import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/controllers/diary_block_reorder.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';

Map<String, Object?> _block(
  String type,
  String text, {
  Map<String, Object?> data = const {},
  List<Map<String, Object?>> children = const [],
}) => {
  'type': type,
  'data': {
    'delta': [
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

/// 每块一行，按缩进层级前置两个空格。
String _outline(DiaryEditorController controller) => walkDiaryEditorNodes(
  controller.document,
).map((node) => '${'  ' * (node.path.length - 1)}${_text(node)}').join('\n');

String _text(af.Node node) =>
    node.delta?.toPlainText() ?? '<${node.type.toUpperCase()}>';

af.Node _node(DiaryEditorController controller, String text) =>
    walkDiaryEditorNodes(
      controller.document,
    ).firstWhere((node) => _text(node) == text);

bool _step(DiaryEditorController controller, String text, {required bool up}) {
  final node = _node(controller, text);
  final destination = DiaryBlockGaps(
    controller.document.root,
    node,
  ).step(up: up);
  return destination != null &&
      moveDiaryEditorBlock(controller, node, destination);
}

void main() {
  test('moving an indented paragraph up or down keeps its indent', () {
    final controller = _controller([
      _p('a', [_p('a1')]),
      _p('b'),
      _p('c'),
    ]);
    final before = controller.contentJson;

    // 第一个子块之上没有能收子块的位置。
    expect(_step(controller, 'a1', up: true), isFalse);
    // 下移：移出父块，接到下一块的子块里，仍缩进一级。
    expect(_step(controller, 'a1', up: false), isTrue);
    expect(_outline(controller), 'a\nb\n  a1\nc');
    expect(_step(controller, 'a1', up: false), isTrue);
    expect(_outline(controller), 'a\nb\nc\n  a1');
    expect(_step(controller, 'a1', up: false), isFalse);
    expect(_step(controller, 'a1', up: true), isTrue);
    expect(_outline(controller), 'a\nb\n  a1\nc');

    // 顶层块照旧越过整个同级块（连同子块），不会被并进去。
    expect(_step(controller, 'c', up: true), isTrue);
    expect(_outline(controller), 'a\nc\nb\n  a1');
    expect(_step(controller, 'a', up: false), isTrue);
    expect(_outline(controller), 'c\na\nb\n  a1');
    expect(_step(controller, 'a', up: false), isTrue);
    expect(_outline(controller), 'c\nb\n  a1\na');
    expect(_step(controller, 'a', up: false), isFalse);

    for (var i = 0; i < 6; i++) {
      controller.undo();
    }
    expect(controller.contentJson, before);
    controller.dispose();
  });

  test('moved blocks never nest under blocks that cannot show children', () {
    final controller = _controller([
      _block('heading', 'h', data: {'level': 2}),
      _block('quote', 'q'),
      _block('code', 'x'),
      _p('a', [_p('a1')]),
    ]);
    // 标题、引用、代码块不画子块：上移找不到放得下一级缩进的位置。
    expect(_step(controller, 'a1', up: true), isFalse);

    final a1 = _node(controller, 'a1');
    final gaps = DiaryBlockGaps(controller.document.root, a1);
    expect(gaps.blocks.map(_text), ['h', 'q', 'x', 'a']);
    expect(gaps.current, 4);
    // 拖到它们后面只能取顶层（放不下的层级取最近的一级）。
    expect(gaps.depths(1), (1, 1));
    expect(gaps.destination(1, a1.path.length), [1]);
    expect(gaps.destination(3, a1.path.length), [3]);
    // 段落能收子块：拖到它后面仍缩进。
    expect(gaps.depths(4), (1, 2));
    expect(gaps.destination(4, a1.path.length), [3, 0]);
    controller.dispose();
  });

  test('a drag keeps the starting depth wherever the gap allows it', () {
    final controller = _controller([
      _p('a', [_p('a1')]),
      _block('heading', 'h', data: {'level': 1}),
      _block(
        'bulleted_list',
        'l',
        children: [
          _block('bulleted_list', 'l1'),
          _block('bulleted_list', 'l2'),
        ],
      ),
      _p('z'),
    ]);
    final a1 = _node(controller, 'a1');
    final session = DiaryBlockDragSession(controller, a1);
    expect(session.depth, 2);
    DiaryBlockGaps gaps() => DiaryBlockGaps(controller.document.root, a1);
    int gapAfter(String text) =>
        gaps().blocks.indexWhere((node) => _text(node) == text) + 1;

    // 标题后面放不下缩进，只能取顶层……
    expect(session.preview(gaps().destination(gapAfter('h'), 2)!), isTrue);
    expect(_outline(controller), 'a\nh\na1\nl\n  l1\n  l2\nz');
    // ……拖到放得下的地方又恢复缩进，不以中途的层级为准。
    expect(session.preview(gaps().destination(gapAfter('z'), 2)!), isTrue);
    expect(_outline(controller), 'a\nh\nl\n  l1\n  l2\nz\n  a1');
    // 列表两项之间正好是同一层级。
    expect(session.preview(gaps().destination(gapAfter('l1'), 2)!), isTrue);
    expect(_outline(controller), 'a\nh\nl\n  l1\n  a1\n  l2\nz');
    expect(session.commit(), isTrue);
    controller.undo();
    expect(_outline(controller), 'a\n  a1\nh\nl\n  l1\n  l2\nz');

    // 顶层块拖过列表末项不会被并进列表；只有列表项之间（下面那块更深）
    // 才不得不跟着缩进。
    final z = _node(controller, 'z');
    final top = DiaryBlockDragSession(controller, z);
    DiaryBlockGaps zGaps() => DiaryBlockGaps(controller.document.root, z);
    int zGapAfter(String text) =>
        zGaps().blocks.indexWhere((node) => _text(node) == text) + 1;
    expect(top.preview(zGaps().destination(zGapAfter('a1'), 1)!), isTrue);
    expect(_outline(controller), 'a\n  a1\nz\nh\nl\n  l1\n  l2');
    expect(top.preview(zGaps().destination(zGapAfter('l2'), 1)!), isTrue);
    expect(_outline(controller), 'a\n  a1\nh\nl\n  l1\n  l2\nz');
    expect(top.preview(zGaps().destination(zGapAfter('l'), 1)!), isTrue);
    expect(_outline(controller), 'a\n  a1\nh\nl\n  z\n  l1\n  l2');
    top.cancel();
    expect(_outline(controller), 'a\n  a1\nh\nl\n  l1\n  l2\nz');
    controller.dispose();
  });

  test('moving blocks keeps every block attribute, inline style and child', () {
    final rich = [
      {
        'insert': 'bold',
        'attributes': {'bold': true, 'font_color': '#FFE53935'},
      },
      {
        'insert': ' mix',
        'attributes': {
          'italic': true,
          'underline': true,
          'strikethrough': true,
          'bg_color': '#66FFEB3B',
          'size': 'large',
        },
      },
      {
        'insert': ' link',
        'attributes': {'href': 'https://example.com', 'code': true},
      },
    ];
    Map<String, Object?> richBlock(
      String type,
      Map<String, Object?> data, [
      List<Map<String, Object?>> children = const [],
    ]) => {
      'type': type,
      'data': {'delta': rich, ...data},
      if (children.isNotEmpty) 'children': children,
    };
    final controller = _controller([
      richBlock('heading', {'level': 2, 'align': 'center'}),
      richBlock(
        'paragraph',
        {'align': 'right'},
        [
          richBlock('paragraph', {'align': 'justify'}),
        ],
      ),
      richBlock(
        'todo_list',
        {'checked': true},
        [
          richBlock('todo_list', {'checked': false}),
        ],
      ),
      richBlock('numbered_list', {}, [richBlock('bulleted_list', {})]),
      richBlock('quote', {}),
      {
        'type': 'code',
        'data': {
          'delta': [
            {'insert': 'void main() {}\n  print(1);'},
          ],
          'language': 'dart',
        },
      },
      {'type': 'divider'},
      {
        'type': 'image',
        'data': {'url': '/a.png', 'width': 120.0, 'align': 'center'},
      },
      _p('end'),
    ]);
    final before = controller.contentJson;
    final blocks = controller.document.root.children.toList();
    final snapshots = [for (final node in blocks) jsonEncode(node.toJson())];
    void expectIntact() {
      for (var i = 0; i < blocks.length; i++) {
        expect(jsonEncode(blocks[i].toJson()), snapshots[i]);
      }
      // 落盘再读回：嵌套与属性都在。
      final reloaded = DiaryEditorController.fromContent(
        controller.contentJson,
      );
      expect(
        jsonEncode(reloaded.document.toJson()),
        jsonEncode(controller.document.toJson()),
      );
      reloaded.dispose();
    }

    // 每一块都下移一格、上移一格，再整段拖到文末并松手。
    for (final node in blocks) {
      final gaps = DiaryBlockGaps(controller.document.root, node);
      final down = gaps.step(up: false);
      if (down != null) {
        expect(moveDiaryEditorBlock(controller, node, down), isTrue);
        expectIntact();
      }
      final up = DiaryBlockGaps(controller.document.root, node).step(up: true);
      if (up != null) {
        expect(moveDiaryEditorBlock(controller, node, up), isTrue);
        expectIntact();
      }
      final session = DiaryBlockDragSession(controller, node);
      final end = DiaryBlockGaps(controller.document.root, node);
      final destination = end.destination(end.blocks.length, session.depth);
      if (destination != null) session.preview(destination);
      session.commit();
      expectIntact();
    }
    while (controller.hasUndo) {
      controller.undo();
    }
    expect(controller.contentJson, before);
    controller.dispose();
  });
}
