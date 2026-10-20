import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_highlighter.dart';

import '../../../../support/diary_code_samples.dart';

void main() {
  final highlighter = DiaryCodeHighlighter.instance;

  for (final entry in diaryCodeSamples.entries) {
    test('recognizes and highlights a short ${entry.key} block', () {
      final language = highlighter.detect(entry.value);
      expect(language, entry.key);
      expect(highlighter.tokens(entry.value, language!).tokens, isNotEmpty);
    });
  }

  test('recognizes short code without requiring a complete declaration', () {
    const samples = <String, String>{
      'print("Hello")': 'python',
      'console.log("Hello");': 'javascript',
      'const count: number = 1;': 'typescript',
      'final count = 1;': 'dart',
      'SELECT * FROM diaries;': 'sql',
      '{"answer": 42}': 'json',
      'def greet(name):': 'python',
      'fn main() {': 'rust',
      'fun main() {': 'kotlin',
      'const count = 42;': 'javascript',
      'const note = {color: "blue", count: 42};': 'javascript',
      'final List<String> names = [];': 'dart',
      'let name: String = "world"': 'swift',
      'func main() {\n  fmt.Println("hello")\n}': 'go',
      'func greet(name: String) -> String { return name }': 'swift',
      'use std::collections::HashMap;': 'rust',
      'fn main() { let x = std::time::Instant::now(); }': 'rust',
      'UPDATE diaries SET title = "new" WHERE id = 1;': 'sql',
      'kind: number\nname: string': 'yaml',
      'body { color: red; }': 'css',
      'interface Note { title: string; }': 'typescript',
      'class Counter { #count = 1; read() { return this.#count; } }':
          'javascript',
    };
    for (final entry in samples.entries) {
      expect(highlighter.detect(entry.key), entry.value, reason: entry.key);
    }
  });

  test('ignores language signatures inside comments and strings', () {
    for (final text in <String>[
      'const note = "def greet(name): return None";',
      'const note = `# Heading\n- item\n[link](https://example.com)`;',
      'const note = `--- a/file\n+++ b/file\n@@ -1 +1 @@`;',
      '/*\nimport "dart:async";\n*/\nconsole.log("hello");',
      '/* def greet(name):\n  return None */\nconst count = 42;',
    ]) {
      expect(highlighter.detect(text), 'javascript', reason: text);
    }
    expect(highlighter.detect('/* def greet(name): return None */'), isNull);
    expect(highlighter.detect('# print("not running")'), isNull);
  });

  test(
    'finds code after a long leading license without unbounded sampling',
    () {
      final text = '/*${' copyright ' * 300}*/\nconsole.log("hello");';
      expect(highlighter.detect(text), 'javascript');
      expect(highlighter.detect(' ' * 1000000), isNull);
    },
  );

  test('does not infer a programming language from ordinary notes', () {
    for (final text in <String>[
      'Today I went for a walk and came home to read a book.',
      'I will return home for dinner and class starts tomorrow.',
      '这是普通日记，今天看了 Python 和 JavaScript 的教程。',
      'Remember to print the tickets tomorrow.',
      'https://example.com/path?name=hello',
      '10:30 meet at the station',
    ]) {
      expect(highlighter.detect(text), isNull, reason: text);
    }
  });
}
