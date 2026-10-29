import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/controllers/diary_text_style_editing.dart';
import 'package:node_diary/ui/diaries/models/diary_text_style_options.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:node_diary/ui/diaries/widgets/diary_toolbar_config.dart';

import '../../../support/diary_color_panel_harness.dart';
import '../../../support/diary_content_test_helpers.dart';

/// 工具栏「上标」「下标」：作用于选中的文字（一步撤销）、互相替换、再点
/// 恢复；折叠光标时作用于接下来输入的字；代码块里停用、不写；桌面另有
/// Ctrl + . / Ctrl + , 快捷键。
const String _superTool = '上标';
const String _subTool = '下标';

/// 两个工具排在最前，常驻在工具栏一排上。
final List<DiaryToolbarItem> _scriptFirstOrder = <DiaryToolbarItem>[
  DiaryToolbarItem.superscript,
  DiaryToolbarItem.subscript,
  for (final item in kDefaultDiaryToolbarOrder)
    if (item != DiaryToolbarItem.superscript &&
        item != DiaryToolbarItem.subscript)
      item,
];

/// 正文：段落 `first`、段落 `second` 与代码块 `x = 1`。
DiaryEditorController _controller() {
  Map<String, Object?> block(String type, String text) => {
    'type': type,
    'data': {
      'delta': [
        {'insert': text},
      ],
    },
  };
  final controller = DiaryEditorController.fromContent(
    jsonEncode({
      'document': {
        'type': 'page',
        'children': [
          block('paragraph', 'first'),
          block('paragraph', 'second'),
          block('code', 'x = 1'),
        ],
      },
    }),
  );
  addTearDown(controller.dispose);
  return controller;
}

Future<ColorPanelHarness> _pump(
  WidgetTester tester,
  DiaryEditorController controller,
) async {
  final harness = await pumpColorPanel(
    tester,
    controller: controller,
    order: _scriptFirstOrder,
  );
  harness.editorFocus.requestFocus();
  await tester.pumpAndSettle();
  return harness;
}

Future<void> _tap(WidgetTester tester, String tool) async {
  await tester.tap(find.byTooltip(tool));
  await tester.pumpAndSettle();
}

List<(String, Object?)> _runs(DiaryEditorController controller, int index) => [
  for (final op in controller.document.root.children.elementAt(index).delta!)
    ((op as af.TextInsert).text, op.attributes?['script']),
];

IconButton _button(WidgetTester tester, String tool) => tester.widget(
  find.ancestor(of: find.byTooltip(tool), matching: find.byType(IconButton)),
);

void main() {
  test('superscript and subscript follow strikethrough in the default order, '
      'past the pinned slots', () {
    final strike = kDefaultDiaryToolbarOrder.indexOf(
      DiaryToolbarItem.strikeThrough,
    );
    expect(kDefaultDiaryToolbarOrder.sublist(strike + 1, strike + 3), [
      DiaryToolbarItem.superscript,
      DiaryToolbarItem.subscript,
    ]);
    expect(strike + 1, greaterThanOrEqualTo(6));
    // 已保存过顺序的用户：新工具补到末尾，存储键往返不变。
    final decoded = decodeDiaryToolbarOrder('bold,italic');
    expect(decoded, contains(DiaryToolbarItem.superscript));
    expect(
      decodeDiaryToolbarOrder(
        encodeDiaryToolbarOrder(kDefaultDiaryToolbarOrder),
      ),
      kDefaultDiaryToolbarOrder,
    );
    expect(DiaryToolbarItem.superscript.storageKey, 'superscript');
    expect(DiaryToolbarItem.subscript.storageKey, 'subscript');
  });

  testWidgets('superscript toggles on a range, subscript replaces it, and '
      'each tap is one undo step', (tester) async {
    final controller = _controller();
    await _pump(tester, controller);
    controller.select(
      af.Selection.single(path: [0], startOffset: 1, endOffset: 4),
    );
    await tester.pumpAndSettle();
    final before = controller.contentJson;

    await _tap(tester, _superTool);
    expect(_runs(controller, 0), [('f', null), ('irs', 'super'), ('t', null)]);
    expect(
      isDiaryToolbarItemActive(
        DiaryToolbarItem.superscript,
        controller.activeAttributes,
      ),
      isTrue,
    );
    // 选区不变，可以接着换。
    expect(controller.selection!.normalized.startIndex, 1);
    expect(controller.selection!.normalized.endIndex, 4);

    await _tap(tester, _subTool);
    expect(_runs(controller, 0), [('f', null), ('irs', 'sub'), ('t', null)]);
    expect(
      isDiaryToolbarItemActive(
        DiaryToolbarItem.superscript,
        controller.activeAttributes,
      ),
      isFalse,
    );
    expect(
      isDiaryToolbarItemActive(
        DiaryToolbarItem.subscript,
        controller.activeAttributes,
      ),
      isTrue,
    );

    await _tap(tester, _superTool);
    expect(_runs(controller, 0), [('f', null), ('irs', 'super'), ('t', null)]);
    // 再点同一个恢复普通文字（移除属性，不留 null）。
    await _tap(tester, _superTool);
    expect(_runs(controller, 0), [('first', null)]);
    expect(
      controller.document.root.children.first.delta!.toList().single.attributes,
      anyOf(isNull, isEmpty),
    );

    for (final expected in ['super', 'sub', 'super']) {
      controller.undo();
      await tester.pumpAndSettle();
      expect(_runs(controller, 0)[1], ('irs', expected));
    }
    controller.undo();
    await tester.pumpAndSettle();
    expect(controller.contentJson, before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a range only partly superscript becomes superscript as a '
      'whole', (tester) async {
    final controller = _controller();
    await _pump(tester, controller);
    controller.select(
      af.Selection.single(path: [0], startOffset: 0, endOffset: 2),
    );
    await tester.pumpAndSettle();
    await _tap(tester, _superTool);
    controller.select(
      af.Selection.single(path: [0], startOffset: 0, endOffset: 5),
    );
    await tester.pumpAndSettle();
    expect(selectedDiaryScript(controller), isNull);

    await _tap(tester, _superTool);
    expect(_runs(controller, 0), [('first', 'super')]);
    expect(selectedDiaryScript(controller), DiaryScript.superscript);
  });

  testWidgets('on a collapsed caret the next typed characters inherit the '
      'script, and tapping again types normal text', (tester) async {
    final controller = _controller();
    await _pump(tester, controller);
    controller.select(
      af.Selection.collapsed(af.Position(path: [0], offset: 5)),
    );
    await tester.pumpAndSettle();

    // 连续输入时编辑器不把值回写给输入法，记住上一次发出的值接着改。
    TextEditingValue? sent;
    Future<void> type(String text) async {
      final state = tester.testTextInput.editingState!;
      final value = sent?.text ?? state['text'] as String;
      final caret = sent?.selection.baseOffset ?? state['selectionBase'] as int;
      sent = TextEditingValue(
        text: '${value.substring(0, caret)}$text${value.substring(caret)}',
        selection: TextSelection.collapsed(offset: caret + text.length),
      );
      tester.testTextInput.updateEditingValue(sent!);
      await tester.pumpAndSettle();
    }

    await _tap(tester, _superTool);
    expect(selectedDiaryScript(controller), DiaryScript.superscript);
    // 点按钮不写正文，只改接下来输入的样式。
    expect(controller.hasUndo, isFalse);
    await type('2');
    // 接着打的字沿用上标（上游按前一个字切取属性）。
    await type('3');
    expect(_runs(controller, 0), [('first', null), ('23', 'super')]);

    await _tap(tester, _superTool);
    expect(selectedDiaryScript(controller), isNull);
    await type('!');
    expect(_runs(controller, 0).map((run) => run.$1).join(), 'first23!');
    expect(_runs(controller, 0).last, ('!', null));
    expect(tester.takeException(), isNull);
  });

  testWidgets('inside a code block the buttons are disabled and nothing is '
      'written', (tester) async {
    final controller = _controller();
    await _pump(tester, controller);

    controller.select(
      af.Selection.single(path: [2], startOffset: 0, endOffset: 5),
    );
    await tester.pumpAndSettle();
    expect(_button(tester, _superTool).onPressed, isNull);
    expect(_button(tester, _subTool).onPressed, isNull);
    final before = controller.contentJson;
    toggleDiaryScript(controller, DiaryScript.superscript);
    await tester.pumpAndSettle();
    expect(controller.contentJson, before);
    expect(controller.hasUndo, isFalse);

    // 折叠光标在代码块里：也不改接下来输入的样式。
    controller.select(
      af.Selection.collapsed(af.Position(path: [2], offset: 1)),
    );
    await tester.pumpAndSettle();
    toggleDiaryScript(controller, DiaryScript.subscript);
    expect(controller.state.toggledStyle, isNot(contains('script')));

    // 跨段落与代码块的选区：只写段落。
    controller.select(
      af.Selection(
        start: af.Position(path: [1]),
        end: af.Position(path: [2], offset: 5),
      ),
    );
    await tester.pumpAndSettle();
    expect(_button(tester, _superTool).onPressed, isNotNull);
    await _tap(tester, _superTool);
    expect(_runs(controller, 1), [('second', 'super')]);
    expect(_runs(controller, 2), [('x = 1', null)]);
    expect(tester.takeException(), isNull);
  });

  Future<void> shortcut(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  testWidgets('Ctrl+. and Ctrl+, toggle superscript and subscript on desktop', (
    tester,
  ) async {
    final controller = _controller();
    await _pump(tester, controller);
    controller.select(
      af.Selection.single(path: [0], startOffset: 0, endOffset: 5),
    );
    await tester.pumpAndSettle();

    await shortcut(tester, LogicalKeyboardKey.period);
    expect(_runs(controller, 0), [('first', 'super')]);
    await shortcut(tester, LogicalKeyboardKey.comma);
    expect(_runs(controller, 0), [('first', 'sub')]);
    await shortcut(tester, LogicalKeyboardKey.comma);
    expect(_runs(controller, 0), [('first', null)]);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('phones have no script shortcuts', (tester) async {
    final controller = _controller();
    await _pump(tester, controller);
    controller.select(
      af.Selection.single(path: [0], startOffset: 0, endOffset: 5),
    );
    await tester.pumpAndSettle();
    final before = controller.contentJson;
    await shortcut(tester, LogicalKeyboardKey.period);
    expect(controller.contentJson, before);
  });
}
