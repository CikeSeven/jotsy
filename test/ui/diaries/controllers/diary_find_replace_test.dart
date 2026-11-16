import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_find_replace.dart';
import 'package:node_diary/ui/diaries/controllers/diary_toggle_state.dart';
import 'package:node_diary/ui/diaries/models/diary_find_query.dart';

/// 正文查找与替换会话：从插入点往下找、上一个 / 下一个循环、输入防抖、
/// 替换保留行内格式并停到下一处、全部替换（含正则分组与零宽匹配）一步
/// 撤销、跳进收起的折叠块时展开（不进撤销栈；只读正文只改显示状态）、
/// 正文被别处改动后重新查找但不滚动（模式仍是同一个对象）、正则写错、
/// 关闭后保留条件、带入整套条件从文首找，以及替换后旧选区夹回文字长度。

Map<String, Object?> _p(String text, {List<Map<String, Object?>>? delta}) => {
  'type': 'paragraph',
  'data': {
    'delta':
        delta ??
        [
          if (text.isNotEmpty) {'insert': text},
        ],
  },
};

DiaryEditorController _controller(
  List<Map<String, Object?>> blocks, {
  af.Selection? selection,
  bool readOnly = false,
}) {
  final controller = DiaryEditorController(
    document: diaryEditorDocument(
      jsonEncode({
        'document': {'type': 'page', 'children': blocks},
      }),
    ),
    selection: selection,
    readOnly: readOnly,
  );
  addTearDown(controller.dispose);
  return controller;
}

List<String> _texts(DiaryEditorController controller) => [
  for (final node in controller.document.root.children)
    node.delta?.toPlainText() ?? '',
];

Future<void> _waitDebounce() =>
    Future<void>.delayed(kDiaryFindDebounce + const Duration(milliseconds: 60));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('starts at the caret and cycles through matches', () {
    final controller = _controller([
      _p('one cat'),
      _p('two cat'),
      _p('three cat'),
    ], selection: af.Selection.collapsed(af.Position(path: [1])));
    final find = controller.find;
    find.open(text: 'cat');
    expect(find.matches, hasLength(3));
    expect(find.currentIndex, 1);
    final requests = find.revealRequests.value;
    find.next();
    expect(find.currentIndex, 2);
    find.next();
    expect(find.currentIndex, 0);
    find.previous();
    expect(find.currentIndex, 2);
    expect(find.revealRequests.value, requests + 3);
  });

  test('debounces typed text but clears immediately', () async {
    final controller = _controller([_p('cat car cap')]);
    final find = controller.find..open();
    find.setText('ca');
    expect(find.matches, isEmpty);
    await _waitDebounce();
    expect(find.matches, hasLength(3));
    find.setText('cat');
    find.setText('');
    expect(find.matches, isEmpty);
    expect(find.currentIndex, -1);
  });

  test('replace keeps formatting, moves on and undoes in one step', () {
    final controller = _controller([
      _p(
        '',
        delta: [
          {'insert': 'a '},
          {
            'insert': 'cat',
            'attributes': {'bold': true},
          },
          {'insert': ' cat'},
        ],
      ),
    ]);
    final find = controller.find..open(text: 'cat');
    find.replacement = 'dog';
    expect(find.replaceCurrent(), isTrue);
    final delta = controller.document.root.children.first.delta!.toJson();
    expect(delta, [
      {'insert': 'a '},
      {
        'insert': 'dog',
        'attributes': {'bold': true},
      },
      {'insert': ' cat'},
    ]);
    expect(find.matches, hasLength(1));
    expect(find.current!.start, 6);
    controller.undo();
    expect(_texts(controller), ['a cat cat']);
  });

  test('replace all expands regex groups in one undo step', () {
    final controller = _controller([_p('2024年5月'), _p('1999年 and 2000年')]);
    final find = controller.find
      ..open(text: r'(\d{4})年')
      ..setOptions(regex: true);
    find.replacement = r'$1 年';
    expect(find.replaceAll(), 3);
    expect(_texts(controller), ['2024 年5月', '1999 年 and 2000 年']);
    // 换进去的“2024 年”中间多了空格，不再符合条件。
    expect(find.matches, isEmpty);
    controller.undo();
    expect(_texts(controller), ['2024年5月', '1999年 and 2000年']);
  });

  test('zero-width matches insert text at every paragraph start', () {
    final controller = _controller([_p('one'), _p(''), _p('three')]);
    final find = controller.find
      ..open(text: '^')
      ..setOptions(regex: true);
    find.replacement = '- ';
    expect(find.replaceAll(), 3);
    expect(_texts(controller), ['- one', '- ', '- three']);
  });

  test('a match inside a collapsed toggle expands it without undo', () {
    final controller = _controller([
      _p('top'),
      {
        'type': 'toggle_list',
        'data': {
          'delta': [
            {'insert': 'head'},
          ],
          'collapsed': true,
        },
        'children': [_p('hidden cat')],
      },
    ]);
    controller.find.open(text: 'cat');
    final toggle = controller.document.root.children.last;
    expect(toggle.attributes['collapsed'], isNull);
    expect(controller.hasUndo, isFalse);
  });

  test('a read-only match inside a collapsed toggle only expands the view', () {
    final controller = _controller([
      _p('top'),
      {
        'type': 'toggle_list',
        'data': {
          'delta': [
            {'insert': 'head'},
          ],
          'collapsed': true,
        },
        'children': [_p('hidden cat')],
      },
    ], readOnly: true);
    final toggle = controller.document.root.children.last;
    expect(diaryToggleViewCollapsed(toggle), isTrue);
    controller.find.open(text: 'cat');
    expect(controller.find.matches, hasLength(1));
    // 文档不变，只是这次显示为展开。
    expect(toggle.attributes['collapsed'], isTrue);
    expect(diaryToggleViewCollapsed(toggle), isFalse);
  });

  test('edits elsewhere refresh matches without a reveal', () async {
    final controller = _controller([_p('cat')]);
    final find = controller.find..open(text: 'cat');
    final requests = find.revealRequests.value;
    final pattern = find.pattern;
    expect(pattern, isNotNull);
    final node = controller.document.root.children.first;
    controller.apply(controller.state.transaction..insertText(node, 3, ' cat'));
    await _waitDebounce();
    expect(find.matches, hasLength(2));
    expect(find.currentIndex, 0);
    expect(find.revealRequests.value, requests);
    // 查找条件没变：同一个正则对象，高亮不必整篇重建。
    expect(identical(find.pattern, pattern), isTrue);
    find.setOptions(caseSensitive: true);
    expect(identical(find.pattern, pattern), isFalse);
  });

  test('a full query opens from the start regardless of the caret', () {
    final controller = _controller([
      _p('Cat one'),
      _p('dog two'),
      _p('cat three'),
    ], selection: af.Selection.collapsed(af.Position(path: [2])));
    final find = controller.find;
    find.open(
      query: DiaryFindQuery.fromSearchTerms(['cat', 'two']),
      fromStart: true,
    );
    expect(find.query.regex, isTrue);
    expect(find.matches.map((m) => m.match[0]), ['Cat', 'two', 'cat']);
    expect(find.currentIndex, 0);
    find.close();
    expect(find.pattern, isNull);
    expect(find.barHeight.value, 0);
  });

  test('an invalid regex reports instead of matching', () {
    final controller = _controller([_p('(a)')]);
    final find = controller.find..open(text: '(');
    expect(find.matches, hasLength(1));
    find.setOptions(regex: true);
    expect(find.invalid, isTrue);
    expect(find.matches, isEmpty);
    expect(find.replaceAll(), 0);
    // 关上再打开同一个写错的正则，仍报错而不是“无结果”。
    find
      ..close()
      ..open();
    expect(find.invalid, isTrue);
  });

  test('closing clears matches but keeps the query', () {
    final controller = _controller([_p('cat')]);
    final find = controller.find
      ..open(text: 'cat')
      ..setOptions(caseSensitive: true);
    find.close();
    expect(find.isOpen, isFalse);
    expect(find.matches, isEmpty);
    find.open();
    expect(find.query.text, 'cat');
    expect(find.query.caseSensitive, isTrue);
    expect(find.matches, hasLength(1));
  });

  test('a caret past the shortened text is clamped back', () {
    final controller = _controller([
      _p('cat cat cat'),
    ], selection: af.Selection.collapsed(af.Position(path: [0], offset: 11)));
    final find = controller.find..open(text: 'cat');
    find.replacement = '';
    expect(find.replaceAll(), 3);
    expect(_texts(controller), ['  ']);
    expect(controller.selection!.end.offset, 2);
  });
}
