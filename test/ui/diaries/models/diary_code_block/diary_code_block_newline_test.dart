import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_newline.dart';

typedef _Line = (String, Map<String, dynamic>?);

Map<String, dynamic> _code([Object value = true]) => <String, dynamic>{
  'code-block': value,
};

Document _doc(List<_Line> lines) {
  final delta = Delta();
  for (final (text, attributes) in lines) {
    if (text.isNotEmpty) {
      delta.insert(text);
    }
    delta.insert('\n', attributes);
  }
  return Document.fromDelta(delta);
}

/// 第 [line] 行（从 0 数）第 [column] 列的文档偏移。
int _offset(List<_Line> lines, int line, [int column = 0]) {
  var offset = 0;
  for (var index = 0; index < line; index += 1) {
    offset += lines[index].$1.length + 1;
  }
  return offset + column;
}

/// 在 [lines] 第 [line] 行第 [column] 列按回车，返回计划落地后的文档与光标。
({Delta delta, int caret}) _enter(List<_Line> lines, int line, [int? column]) {
  final document = _doc(lines);
  final index = _offset(lines, line, column ?? lines[line].$1.length);
  final plan = planDiaryCodeBlockNewline(document, index, 0, '\n');
  expect(plan, isNotNull);
  document.compose(plan!.delta, ChangeSource.local);
  return (delta: document.toDelta(), caret: plan.caret);
}

void main() {
  group('exit', () {
    test('two trailing blank lines leave the block on a plain line', () {
      final lines = <_Line>[
        ('intro', null),
        ('x = 1', _code()),
        ('', _code()),
        ('', _code()),
        ('after', null),
      ];
      final result = _enter(lines, 3);
      expect(
        result.delta,
        _doc(<_Line>[
          ('intro', null),
          ('x = 1', _code()),
          ('', null),
          ('after', null),
        ]).toDelta(),
      );
      expect(result.caret, _offset(lines, 2));
    });

    test('three trailing blank lines all collapse into one plain line', () {
      final lines = <_Line>[
        ('x = 1', _code()),
        ('', _code()),
        ('', _code()),
        ('', _code()),
      ];
      final result = _enter(lines, 3);
      expect(
        result.delta,
        _doc(<_Line>[('x = 1', _code()), ('', null)]).toDelta(),
      );
      expect(result.caret, _offset(lines, 1));
    });

    test('blank lines may hold spaces and tabs', () {
      final lines = <_Line>[
        ('x', _code()),
        ('    ', _code()),
        ('\t ', _code()),
      ];
      final result = _enter(lines, 2);
      expect(result.delta, _doc(<_Line>[('x', _code()), ('', null)]).toDelta());
      expect(result.caret, 2);
    });

    test('the caret may sit inside the blank line whitespace', () {
      final lines = <_Line>[('x', _code()), ('  ', _code()), ('    ', _code())];
      final result = _enter(lines, 2, 1);
      expect(result.delta, _doc(<_Line>[('x', _code()), ('', null)]).toDelta());
      expect(result.caret, 2);
    });

    test('a block of only blank lines collapses to one plain empty line', () {
      final lines = <_Line>[('before', null), ('', _code()), ('  ', _code())];
      final result = _enter(lines, 2);
      expect(
        result.delta,
        _doc(<_Line>[('before', null), ('', null)]).toDelta(),
      );
      expect(result.caret, _offset(lines, 1));
    });

    test('the remaining lines keep their language', () {
      final lines = <_Line>[
        ('a', _code('python')),
        ('b', _code('python')),
        ('', _code('python')),
        ('', _code('python')),
      ];
      final result = _enter(lines, 3);
      expect(
        result.delta,
        _doc(<_Line>[
          ('a', _code('python')),
          ('b', _code('python')),
          ('', null),
        ]).toDelta(),
      );
      expect(result.caret, _offset(lines, 2));
    });
  });

  group('stay in the block', () {
    test('a single trailing blank line does not exit', () {
      final lines = <_Line>[('x', _code()), ('', _code())];
      final result = _enter(lines, 1);
      expect(
        result.delta,
        _doc(<_Line>[('x', _code()), ('', _code()), ('', _code())]).toDelta(),
      );
      expect(result.caret, _offset(lines, 2));
    });

    test('two blank lines in the middle of the block do not exit', () {
      final lines = <_Line>[
        ('x', _code()),
        ('', _code()),
        ('', _code()),
        ('y', _code()),
      ];
      final result = _enter(lines, 2);
      expect(
        result.delta,
        _doc(<_Line>[
          ('x', _code()),
          ('', _code()),
          ('', _code()),
          ('', _code()),
          ('y', _code()),
        ]).toDelta(),
      );
      expect(result.caret, _offset(lines, 3));
    });

    test('the new line repeats the leading spaces', () {
      final lines = <_Line>[('    foo', _code('python'))];
      final result = _enter(lines, 0);
      expect(
        result.delta,
        _doc(<_Line>[
          ('    foo', _code('python')),
          ('    ', _code('python')),
        ]).toDelta(),
      );
      expect(result.caret, 8 + 4);
    });

    test('the new line repeats the leading tabs', () {
      final lines = <_Line>[('\t\tfoo', _code())];
      final result = _enter(lines, 0);
      expect(
        result.delta,
        _doc(<_Line>[('\t\tfoo', _code()), ('\t\t', _code())]).toDelta(),
      );
      expect(result.caret, 6 + 2);
    });

    test('a caret inside the indentation only repeats what is before it', () {
      final lines = <_Line>[('    foo', _code())];
      final result = _enter(lines, 0, 2);
      expect(
        result.delta,
        _doc(<_Line>[('  ', _code()), ('    foo', _code())]).toDelta(),
      );
      expect(result.caret, 3 + 2);
    });

    test('a caret at column 0 adds no indentation', () {
      final lines = <_Line>[('    foo', _code())];
      final result = _enter(lines, 0, 0);
      expect(
        result.delta,
        _doc(<_Line>[('', _code()), ('    foo', _code())]).toDelta(),
      );
      expect(result.caret, 1);
    });

    test('Enter mid-line splits and indents the tail', () {
      final lines = <_Line>[('  foo bar', _code())];
      final result = _enter(lines, 0, 5);
      expect(
        result.delta,
        _doc(<_Line>[('  foo', _code()), ('   bar', _code())]).toDelta(),
      );
      expect(result.caret, 6 + 2);
    });
  });

  group('not handled', () {
    final lines = <_Line>[('plain', null), ('code', _code())];

    test('a line outside a code block', () {
      expect(planDiaryCodeBlockNewline(_doc(lines), 5, 0, '\n'), isNull);
    });

    test('Enter that replaces a selection', () {
      expect(planDiaryCodeBlockNewline(_doc(lines), 6, 2, '\n'), isNull);
    });

    test('multi-character insertions', () {
      expect(planDiaryCodeBlockNewline(_doc(lines), 10, 0, '\n\n'), isNull);
      expect(planDiaryCodeBlockNewline(_doc(lines), 10, 0, 'a\nb'), isNull);
    });

    test('embeds', () {
      expect(
        planDiaryCodeBlockNewline(
          _doc(lines),
          10,
          0,
          BlockEmbed.image('a.png'),
        ),
        isNull,
      );
    });
  });

  group('block helpers', () {
    final lines = <_Line>[
      ('a1', _code()),
      ('a2', _code()),
      ('mid', null),
      ('b1', _code('go')),
      ('list', <String, dynamic>{'list': 'bullet'}),
    ];

    test('diaryCodeBlockAt finds the block of a line', () {
      final document = _doc(lines);
      expect(diaryCodeBlockText(diaryCodeBlockAt(document, 4)!), 'a1\na2');
      expect(diaryCodeBlockAt(document, _offset(lines, 2)), isNull);
      expect(
        diaryCodeBlockText(diaryCodeBlockAt(document, _offset(lines, 3))!),
        'b1',
      );
      expect(diaryCodeBlockAt(document, _offset(lines, 4)), isNull);
    });

    test('diaryCodeBlocksInRange lists each touched block once', () {
      final document = _doc(lines);
      final both = diaryCodeBlocksInRange(document, 1, _offset(lines, 3, 1));
      expect(both.map(diaryCodeBlockText), <String>['a1\na2', 'b1']);
      // 整行选中第二行（止于下一行行首）不算触及下一行之后的块。
      expect(
        diaryCodeBlocksInRange(document, _offset(lines, 2), _offset(lines, 3)),
        isEmpty,
      );
      // 光标停在块后一行的行首不算在块里。
      expect(
        diaryCodeBlocksInRange(document, _offset(lines, 2), _offset(lines, 2)),
        isEmpty,
      );
    });

    test('isDiaryCodeBlock ignores other blocks', () {
      final document = _doc(lines);
      final nodes = document.root.children.toList();
      expect(nodes.map(isDiaryCodeBlock), <bool>[true, false, true, false]);
      expect(isDiaryCodeBlock(null), isFalse);
    });
  });
}
