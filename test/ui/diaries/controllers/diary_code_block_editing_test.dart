import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/controllers/diary_code_block_editing.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_newline.dart';

typedef _Line = (String, Map<String, dynamic>?);

Map<String, dynamic> _code([Object value = true]) => <String, dynamic>{
  'code-block': value,
};

Delta _delta(List<_Line> lines) {
  final delta = Delta();
  for (final (text, attributes) in lines) {
    if (text.isNotEmpty) {
      delta.insert(text);
    }
    delta.insert('\n', attributes);
  }
  // 经 Document 规整一次，与 document.toDelta() 的写法一致，便于直接比较。
  return Document.fromDelta(delta).toDelta();
}

int _offset(List<_Line> lines, int line, [int column = 0]) {
  var offset = 0;
  for (var index = 0; index < line; index += 1) {
    offset += lines[index].$1.length + 1;
  }
  return offset + column;
}

QuillController _controller(
  List<_Line> lines, {
  TextSelection selection = const TextSelection.collapsed(offset: 0),
}) {
  final controller = QuillController(
    document: Document.fromDelta(_delta(lines)),
    selection: selection,
  );
  addTearDown(controller.dispose);
  return controller;
}

/// 与编辑器输入法链路一致：在 [index] 插入换行，选区为输入法给出的 index + 1。
void _pressEnter(QuillController controller, int index) {
  controller.replaceText(
    index,
    0,
    '\n',
    TextSelection.collapsed(offset: index + 1),
  );
}

void main() {
  group('Enter through the controller', () {
    test('exit removes the trailing blank lines and moves the caret up', () {
      final lines = <_Line>[
        ('x = 1', _code('python')),
        ('', _code('python')),
        ('', _code('python')),
        ('after', null),
      ];
      final controller = _controller(lines);
      attachDiaryCodeBlockEditing(controller);
      var notifications = 0;
      controller.addListener(() => notifications += 1);

      _pressEnter(controller, _offset(lines, 2));

      expect(
        controller.document.toDelta(),
        _delta(<_Line>[
          ('x = 1', _code('python')),
          ('', null),
          ('after', null),
        ]),
      );
      expect(
        controller.selection,
        TextSelection.collapsed(offset: _offset(lines, 1)),
      );
      expect(notifications, 1);
    });

    test('auto-indent keeps the block and puts the caret after the indent', () {
      final lines = <_Line>[('    foo', _code('python'))];
      final controller = _controller(lines);
      attachDiaryCodeBlockEditing(controller);

      _pressEnter(controller, 7);

      expect(
        controller.document.toDelta(),
        _delta(<_Line>[
          ('    foo', _code('python')),
          ('    ', _code('python')),
        ]),
      );
      expect(controller.selection, const TextSelection.collapsed(offset: 12));
    });

    test('one undo restores the document before the exit', () {
      final lines = <_Line>[
        ('x', _code()),
        ('  ', _code()),
        ('', _code()),
        ('after', null),
      ];
      final controller = _controller(lines);
      attachDiaryCodeBlockEditing(controller);
      final before = controller.document.toDelta();

      _pressEnter(controller, _offset(lines, 2));
      expect(controller.document.toDelta(), isNot(before));

      controller.undo();
      expect(controller.document.toDelta(), before);
      expect(controller.hasUndo, isFalse);
    });

    test('one undo restores the document before an auto-indent', () {
      final lines = <_Line>[('\tfoo', _code())];
      final controller = _controller(lines);
      attachDiaryCodeBlockEditing(controller);
      final before = controller.document.toDelta();

      _pressEnter(controller, 4);
      controller.undo();

      expect(controller.document.toDelta(), before);
      expect(controller.hasUndo, isFalse);
    });

    test('Enter outside code blocks keeps the stock behaviour', () {
      final lines = <_Line>[
        ('item', <String, dynamic>{'list': 'bullet'}),
        ('', <String, dynamic>{'list': 'bullet'}),
      ];
      final controller = _controller(lines);
      attachDiaryCodeBlockEditing(controller);

      // 列表的空末行按回车：默认规则退出列表。
      _pressEnter(controller, 5);

      expect(
        controller.document.toDelta(),
        _delta(<_Line>[
          ('item', <String, dynamic>{'list': 'bullet'}),
          ('', null),
        ]),
      );
    });

    test('attaching twice installs the hook once', () {
      final controller = _controller(<_Line>[('foo', _code())]);
      attachDiaryCodeBlockEditing(controller);
      final hook = controller.onReplaceText;
      attachDiaryCodeBlockEditing(controller);
      expect(identical(controller.onReplaceText, hook), isTrue);
    });

    test('a previous hook runs first and can veto the edit', () {
      final lines = <_Line>[('  foo', _code())];
      final calls = <(int, int, Object?)>[];
      var allow = true;
      final controller = _controller(lines)
        ..onReplaceText = (index, len, data) {
          calls.add((index, len, data));
          return allow;
        };
      attachDiaryCodeBlockEditing(controller);

      allow = false;
      _pressEnter(controller, 5);
      expect(calls, <(int, int, Object?)>[(5, 0, '\n')]);
      expect(controller.document.toDelta(), _delta(lines));

      allow = true;
      _pressEnter(controller, 5);
      expect(calls, hasLength(2));
      expect(
        controller.document.toDelta(),
        _delta(<_Line>[('  foo', _code()), ('  ', _code())]),
      );
    });

    test('a read-only controller is left to the stock path', () {
      final controller = _controller(<_Line>[('    foo', _code())])
        ..readOnly = true;
      attachDiaryCodeBlockEditing(controller);

      _pressEnter(controller, 7);

      // 默认链路不补缩进。
      expect(
        controller.document.toDelta(),
        _delta(<_Line>[('    foo', _code()), ('', _code())]),
      );
    });
  });

  group('code block actions', () {
    test('setDiaryCodeBlockLanguage formats every line of the block', () {
      final lines = <_Line>[
        ('before', null),
        ('a', _code()),
        ('b', _code()),
        ('c', _code()),
      ];
      final selection = TextSelection.collapsed(offset: _offset(lines, 2, 1));
      final controller = _controller(lines, selection: selection);

      setDiaryCodeBlockLanguage(controller, 'python');

      expect(
        controller.document.toDelta(),
        _delta(<_Line>[
          ('before', null),
          ('a', _code('python')),
          ('b', _code('python')),
          ('c', _code('python')),
        ]),
      );
      expect(controller.selection, selection);
    });

    test('setDiaryCodeBlockLanguage handles a single-line block', () {
      final lines = <_Line>[('x', _code('go')), ('after', null)];
      final controller = _controller(lines);

      setDiaryCodeBlockLanguage(controller, 'plain');

      expect(
        controller.document.toDelta(),
        _delta(<_Line>[('x', _code('plain')), ('after', null)]),
      );
    });

    test('setDiaryCodeBlockLanguage covers every block in the selection', () {
      final lines = <_Line>[
        ('a1', _code()),
        ('a2', _code()),
        ('mid', null),
        ('b1', _code('go')),
        ('b2', _code('go')),
        ('tail', <String, dynamic>{'list': 'bullet'}),
      ];
      final selection = TextSelection(
        baseOffset: 1,
        extentOffset: _offset(lines, 3, 1),
      );
      final controller = _controller(lines, selection: selection);

      setDiaryCodeBlockLanguage(controller, 'rust');

      expect(
        controller.document.toDelta(),
        _delta(<_Line>[
          ('a1', _code('rust')),
          ('a2', _code('rust')),
          ('mid', null),
          ('b1', _code('rust')),
          ('b2', _code('rust')),
          ('tail', <String, dynamic>{'list': 'bullet'}),
        ]),
      );
      expect(controller.selection, selection);
    });

    test('convertDiaryCodeBlockToText turns every line into body text', () {
      final lines = <_Line>[
        ('a', _code('python')),
        ('b', _code('python')),
        ('', _code('python')),
        ('after', null),
      ];
      final controller = _controller(
        lines,
        selection: const TextSelection.collapsed(offset: 2),
      );

      convertDiaryCodeBlockToText(controller);

      expect(
        controller.document.toDelta(),
        _delta(<_Line>[('a', null), ('b', null), ('', null), ('after', null)]),
      );
      expect(controller.hasUndo, isTrue);
      controller.undo();
      expect(controller.document.toDelta(), _delta(lines));
    });

    test('exitDiaryCodeBlock reuses an empty plain line after the block', () {
      final lines = <_Line>[('x', _code()), ('', null), ('y', null)];
      final controller = _controller(lines);

      exitDiaryCodeBlock(controller);

      expect(controller.document.toDelta(), _delta(lines));
      expect(controller.selection, const TextSelection.collapsed(offset: 2));
    });

    test('exitDiaryCodeBlock inserts a plain line before a list item', () {
      final lines = <_Line>[
        ('x', _code()),
        ('item', <String, dynamic>{'list': 'bullet'}),
      ];
      final controller = _controller(lines);

      exitDiaryCodeBlock(controller);

      expect(
        controller.document.toDelta(),
        _delta(<_Line>[
          ('x', _code()),
          ('', null),
          ('item', <String, dynamic>{'list': 'bullet'}),
        ]),
      );
      expect(controller.selection, const TextSelection.collapsed(offset: 2));
    });

    test('exitDiaryCodeBlock at the end of the document adds a line', () {
      final lines = <_Line>[('x', _code('go')), ('y', _code('go'))];
      final controller = _controller(
        lines,
        selection: const TextSelection.collapsed(offset: 1),
      );

      exitDiaryCodeBlock(controller);

      expect(
        controller.document.toDelta(),
        _delta(<_Line>[('x', _code('go')), ('y', _code('go')), ('', null)]),
      );
      expect(controller.selection, const TextSelection.collapsed(offset: 4));
    });

    test('exitDiaryCodeBlock does nothing outside code blocks', () {
      final lines = <_Line>[('x', null), ('y', _code())];
      final controller = _controller(lines);

      exitDiaryCodeBlock(controller);

      expect(controller.document.toDelta(), _delta(lines));
      expect(controller.selection, const TextSelection.collapsed(offset: 0));
    });

    test('toggleDiaryCodeBlockOn makes the current line a code block', () {
      final lines = <_Line>[('x', null), ('y', null)];
      final controller = _controller(
        lines,
        selection: const TextSelection.collapsed(offset: 2),
      );

      toggleDiaryCodeBlockOn(controller);

      expect(
        controller.document.toDelta(),
        _delta(<_Line>[('x', null), ('y', _code())]),
      );
    });

    testWidgets('copyDiaryCodeBlock writes the block text', (tester) async {
      final copied = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text']);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final document = Document.fromDelta(
        _delta(<_Line>[
          ('  a', _code()),
          ('', _code()),
          ('b', _code()),
          ('after', null),
        ]),
      );

      await copyDiaryCodeBlock(diaryCodeBlockAt(document, 0)!);

      expect(copied, <Object?>['  a\n\nb']);
    });
  });

  group('through the editor text input', () {
    Future<QuillController> pumpEditor(
      WidgetTester tester,
      List<_Line> lines,
    ) async {
      final controller = _controller(lines);
      attachDiaryCodeBlockEditing(controller);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [FlutterQuillLocalizations.delegate],
          home: Scaffold(
            body: QuillEditor.basic(
              controller: controller,
              focusNode: focusNode,
            ),
          ),
        ),
      );
      focusNode.requestFocus();
      await tester.pumpAndSettle();
      return controller;
    }

    /// 与真机一致：输入法在自己的文本里插入换行，经 updateEditingValue 交给
    /// 编辑器。
    Future<void> imeEnter(WidgetTester tester, int offset) async {
      final value = tester
          .state<QuillRawEditorState>(find.byType(QuillRawEditor))
          .currentTextEditingValue!;
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: value.text.replaceRange(offset, offset, '\n'),
          selection: TextSelection.collapsed(offset: offset + 1),
        ),
      );
      await tester.pumpAndSettle();
    }

    TextEditingValue remoteValue(WidgetTester tester) => tester
        .state<QuillRawEditorState>(find.byType(QuillRawEditor))
        .currentTextEditingValue!;

    testWidgets('auto-indent reaches the IME', (tester) async {
      final lines = <_Line>[('  foo', _code('python')), ('after', null)];
      final controller = await pumpEditor(tester, lines);
      controller.updateSelection(
        const TextSelection.collapsed(offset: 5),
        ChangeSource.local,
      );
      await tester.pumpAndSettle();
      expect(tester.testTextInput.hasAnyClients, isTrue);

      await imeEnter(tester, 5);

      expect(
        controller.document.toDelta(),
        _delta(<_Line>[
          ('  foo', _code('python')),
          ('  ', _code('python')),
          ('after', null),
        ]),
      );
      expect(controller.selection, const TextSelection.collapsed(offset: 8));
      // 输入法那边被纠正为补好缩进的文字与光标。
      expect(remoteValue(tester).text, '  foo\n  \nafter\n');
      expect(
        remoteValue(tester).selection,
        const TextSelection.collapsed(offset: 8),
      );
      expect(tester.testTextInput.editingState!['text'], '  foo\n  \nafter\n');
      expect(tester.testTextInput.editingState!['selectionBase'], 8);
    });

    testWidgets('exit reaches the IME', (tester) async {
      final lines = <_Line>[
        ('foo', _code()),
        ('', _code()),
        ('', _code()),
        ('after', null),
      ];
      final controller = await pumpEditor(tester, lines);
      controller.updateSelection(
        TextSelection.collapsed(offset: _offset(lines, 2)),
        ChangeSource.local,
      );
      await tester.pumpAndSettle();

      await imeEnter(tester, _offset(lines, 2));

      expect(
        controller.document.toDelta(),
        _delta(<_Line>[('foo', _code()), ('', null), ('after', null)]),
      );
      expect(controller.selection, const TextSelection.collapsed(offset: 4));
      expect(remoteValue(tester).text, 'foo\n\nafter\n');
      expect(
        remoteValue(tester).selection,
        const TextSelection.collapsed(offset: 4),
      );
      expect(tester.testTextInput.editingState!['text'], 'foo\n\nafter\n');
      expect(tester.testTextInput.editingState!['selectionBase'], 4);

      // 再输入的字落在块外的普通行上。
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'foo\nx\nafter\n',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        controller.document.toDelta(),
        _delta(<_Line>[('foo', _code()), ('x', null), ('after', null)]),
      );
    });
  });
}
