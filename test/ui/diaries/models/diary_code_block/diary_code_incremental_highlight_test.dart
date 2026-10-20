import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_highlighter.dart';

void main() {
  const lines = <String, String>{
    'dart': 'final value = "Hello 🌍"; // note\n',
    'python': 'value = "Hello 🌍" # note\n',
    'javascript': 'const value = {name: "Hello 🌍", count: 42};\n',
    'typescript': 'const value: string = "Hello 🌍";\n',
    'json': '  "value": "Hello 🌍",\n',
  };
  for (final entry in lines.entries) {
    test('incremental ${entry.key} edits match a fresh full parse', () {
      final cached = DiaryCodeHighlighter.forTesting();
      var text = entry.key == 'json'
          ? '{\n${entry.value * 180}  "end": true\n}'
          : entry.value * 180;
      final baseline = text;
      cached.tokens(text, entry.key);
      final random = Random(47);
      const edits = <String>[
        'x',
        '',
        '\n',
        '\n\n',
        '42',
        '🌍',
        '"',
        "'",
        '`',
        '/* note\ncontinued */',
        ' // note',
        ' # note',
        'class A\n{',
        'def f(\n    value\n):',
        '\\\n',
      ];
      for (var i = 0; i < 70; i++) {
        // 前半段在完整快照上独立改动，后半段连续编辑，覆盖容错后的恢复。
        if (i < 35) {
          text = baseline;
          cached.tokens(text, entry.key);
        }
        final at = random.nextInt(text.length + 1);
        final remove = min(random.nextInt(5), text.length - at);
        text = text.replaceRange(at, at + remove, edits[i % edits.length]);
        final actual = cached.tokens(text, entry.key);
        final fresh = DiaryCodeHighlighter.forTesting().tokens(text, entry.key);
        expect(
          actual.tokens,
          fresh.tokens,
          reason: '${entry.key} edit $i at $at',
        );
      }
    });
  }

  test('a local edit reuses unchanged prefix tokens', () {
    final highlighter = DiaryCodeHighlighter.forTesting();
    final text = 'const count = 42;\n' * 300;
    final before = highlighter.tokens(text, 'javascript');
    final edited = text.replaceRange(2500, 2500, ' ');
    final after = highlighter.tokens(edited, 'javascript');
    expect(after.tokens.first, same(before.tokens.first));
    expect(
      after.tokens,
      DiaryCodeHighlighter.forTesting().tokens(edited, 'javascript').tokens,
    );
  });

  test(
    'long edit snapshots are evicted by capacity before the entry limit',
    () {
      final highlighter = DiaryCodeHighlighter.forTesting();
      final text = 'const item = {name: "Hello", value: 42};\n' * 450;
      final first = highlighter.tokens(text, 'javascript');
      DiaryCodeTokens? last;
      for (var i = 0; i < 20; i++) {
        last = highlighter.tokens('$text// $i', 'javascript');
      }
      expect(highlighter.tokens('$text// 19', 'javascript'), same(last));
      expect(highlighter.tokens(text, 'javascript'), isNot(same(first)));
    },
  );

  test(
    'adding and removing multiline syntax invalidates the affected suffix',
    () {
      final highlighter = DiaryCodeHighlighter.forTesting();
      final text = 'const count = 42;\n' * 220;
      highlighter.tokens(text, 'javascript');
      for (final insertion in <String>['/*', '`', '"', 'function f(\n']) {
        final edited = text.replaceRange(500, 500, insertion);
        expect(
          highlighter.tokens(edited, 'javascript').tokens,
          DiaryCodeHighlighter.forTesting().tokens(edited, 'javascript').tokens,
          reason: insertion,
        );
        expect(
          highlighter.tokens(text, 'javascript').tokens,
          DiaryCodeHighlighter.forTesting().tokens(text, 'javascript').tokens,
        );
      }
    },
  );
}
