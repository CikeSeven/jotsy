import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_highlighter.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_theme.dart';

const _dart = '''
import 'dart:math';

/// Doc comment.
class Point {
  const Point(this.x, this.y);
  final double x;
  final double y;

  double distanceTo(Point other) {
    final dx = x - other.x; // inline comment
    return sqrt(dx * dx + 2.5);
  }
}

void main() {
  final name = 'world';
  print('Hello, \$name! \${1 + 2}');
}
''';

const _python = '''
import os

# read the file
def greet(name, times=3):
    """Say hello."""
    for _ in range(times):
        print(f"Hello, {name}!")
    return None

class Greeter(object):
    def __init__(self):
        self.count = 0
''';

const _json = '''
{
  "name": "jotsy",
  "version": 3,
  "tags": ["diary", "notes"],
  "private": true,
  "nested": {"value": null, "ratio": 0.5}
}
''';

const _sql = '''
SELECT d.id, d.title, COUNT(t.id) AS tag_count
FROM diaries d
LEFT JOIN diary_tags t ON t.diary_id = d.id
WHERE d.deleted_at IS NULL AND d.title LIKE '%trip%'
GROUP BY d.id
ORDER BY d.created_at DESC
LIMIT 20;
''';

const _prose =
    '今天天气很好，我们去公园散步，看见湖边的柳树发了新芽。'
    '晚上回家做了一碗面，边吃边看书，觉得这一天过得很踏实。';

final _highlighter = DiaryCodeHighlighter.instance;

void _expectWellFormed(String text, DiaryCodeTokens result) {
  var cursor = 0;
  final rebuilt = StringBuffer();
  for (final token in result.tokens) {
    expect(token.start, greaterThanOrEqualTo(cursor), reason: '$token');
    expect(token.end, greaterThan(token.start), reason: '$token');
    expect(token.end, lessThanOrEqualTo(text.length), reason: '$token');
    rebuilt
      ..write(text.substring(cursor, token.start))
      ..write(text.substring(token.start, token.end));
    cursor = token.end;
  }
  rebuilt.write(text.substring(cursor));
  expect(rebuilt.toString(), text);
}

/// 覆盖 [needle]（第 [occurrence] 次出现）的那段区间的角色；不在任何区间
/// 里时为 null。
DiaryCodeTokenRole? _roleAt(
  String text,
  DiaryCodeTokens result,
  String needle, {
  int occurrence = 0,
}) {
  var index = -1;
  for (var i = 0; i <= occurrence; i++) {
    index = text.indexOf(needle, index + 1);
    expect(index, isNonNegative, reason: needle);
  }
  final hits = result
      .overlapping(index, index + needle.length)
      .where(
        (token) => token.start <= index && token.end >= index + needle.length,
      )
      .toList();
  return hits.isEmpty ? null : hits.single.role;
}

void main() {
  group('DiaryCodeHighlighter.tokens', () {
    test('produces sorted, non-overlapping ranges that rebuild the source', () {
      for (final (text, id) in [
        (_dart, 'dart'),
        (_python, 'python'),
        (_json, 'json'),
        (_sql, 'sql'),
      ]) {
        final result = _highlighter.tokens(text, id);
        expect(result.tokens, isNotEmpty, reason: id);
        _expectWellFormed(text, result);
      }
    });

    test('adjacent ranges never share a role', () {
      final result = _highlighter.tokens(_dart, 'dart');
      for (var i = 1; i < result.tokens.length; i++) {
        final previous = result.tokens[i - 1];
        final current = result.tokens[i];
        if (previous.end == current.start) {
          expect(previous.role, isNot(current.role));
        }
      }
    });

    test('assigns roles to python keywords, strings and comments', () {
      final result = _highlighter.tokens(_python, 'python');
      expect(_roleAt(_python, result, 'def'), DiaryCodeTokenRole.keyword);
      expect(_roleAt(_python, result, 'return'), DiaryCodeTokenRole.keyword);
      expect(_roleAt(_python, result, '"Hello, '), DiaryCodeTokenRole.string);
      expect(
        _roleAt(_python, result, '# read the file'),
        DiaryCodeTokenRole.comment,
      );
      expect(_roleAt(_python, result, 'greet'), DiaryCodeTokenRole.function);
      // `class` 声明里的标题记为类型名，而不是函数名。
      expect(_roleAt(_python, result, 'Greeter'), DiaryCodeTokenRole.type);
      // 声明包装只提供上下文：`def greet(...)` 末尾的冒号不着色。
      final colon = _python.indexOf('):') + 1;
      expect(
        _highlighter.tokens(_python, 'python').overlapping(colon, colon + 1),
        isEmpty,
      );
    });

    test('a multi-line block comment is one comment range', () {
      const js = 'const a = 1;\n/* first line\n   second line */\nlet b = 2;';
      final result = _highlighter.tokens(js, 'javascript');
      final start = js.indexOf('/*');
      final end = js.indexOf('*/') + 2;
      final comment = result.tokens.singleWhere(
        (token) => token.role == DiaryCodeTokenRole.comment,
      );
      expect(comment.start, start);
      expect(comment.end, end);
      _expectWellFormed(js, result);
    });

    test('modern private fields keep the whole block highlighted', () {
      const js =
          'class A {\n  #x = 1;\n  get() { return this.#x }\n}\n'
          'const y = 2;';
      final result = _highlighter.tokens(js, 'javascript');
      _expectWellFormed(js, result);
      expect(_roleAt(js, result, 'const'), DiaryCodeTokenRole.keyword);
      expect(_roleAt(js, result, 'class'), DiaryCodeTokenRole.keyword);
      expect(_roleAt(js, result, '2'), DiaryCodeTokenRole.number);
      expect(_roleAt(js, result, '1'), DiaryCodeTokenRole.number);
      expect(_roleAt(js, result, 'return'), DiaryCodeTokenRole.keyword);
      expect(result.hasFullContext, isTrue);
    });

    test('private fields preserve multiline comments and source offsets', () {
      const js =
          'class Counter {\n  #count = 1;\n  /* 🌍 first\n'
          '     second */\n  read() { return this.#count; }\n}';
      final result = _highlighter.tokens(js, 'javascript');
      _expectWellFormed(js, result);
      expect(_roleAt(js, result, 'return'), DiaryCodeTokenRole.keyword);
      final comment = result.tokens.singleWhere(
        (token) => token.role == DiaryCodeTokenRole.comment,
      );
      expect(
        js.substring(comment.start, comment.end),
        '/* 🌍 first\n     second */',
      );
    });

    test('an unterminated string keeps the rest of the block highlighted', () {
      const dart = 'void main() {\n  final s = "abc\n  print(s);\n}';
      final result = _highlighter.tokens(dart, 'dart');
      _expectWellFormed(dart, result);
      expect(_roleAt(dart, result, 'void'), DiaryCodeTokenRole.keyword);
      expect(_roleAt(dart, result, 'final'), DiaryCodeTokenRole.keyword);
      expect(_roleAt(dart, result, 'print'), isNotNull);
    });

    test(
      'unsupported syntax still falls back without dropping valid lines',
      () {
        const js = '# invalid syntax\nconst count = 42;';
        final result = _highlighter.tokens(js, 'javascript');
        _expectWellFormed(js, result);
        expect(_roleAt(js, result, 'const'), DiaryCodeTokenRole.keyword);
        expect(_roleAt(js, result, '42'), DiaryCodeTokenRole.number);
        expect(result.hasFullContext, isFalse);
      },
    );

    test('fallback results are cached too', () {
      const dart = 'void main() {\n  final s = "abc\n}';
      expect(
        identical(
          _highlighter.tokens(dart, 'dart'),
          _highlighter.tokens(dart, 'dart'),
        ),
        isTrue,
      );
    });

    test('plain prose in a code block stays unhighlighted', () {
      const text = '这不是代码\n只是两行文字';
      expect(_highlighter.tokens(text, 'python').tokens, isEmpty);
    });

    test('overlapping returns only intersecting ranges in order', () {
      final result = _highlighter.tokens(_sql, 'sql');
      final lineStart = _sql.indexOf('WHERE');
      final lineEnd = _sql.indexOf('\n', lineStart);
      final hits = result.overlapping(lineStart, lineEnd).toList();
      expect(hits, isNotEmpty);
      for (final token in hits) {
        expect(token.end, greaterThan(lineStart));
        expect(token.start, lessThan(lineEnd));
      }
      final expected = result.tokens
          .where((t) => t.end > lineStart && t.start < lineEnd)
          .toList();
      expect(hits, expected);
      expect(result.overlapping(5, 5), isEmpty);
    });

    test('unknown languages and oversized text are not highlighted', () {
      expect(
        _highlighter.tokens(_python, 'cobol'),
        same(DiaryCodeTokens.empty),
      );
      expect(
        _highlighter.tokens(_python, 'plain'),
        same(DiaryCodeTokens.empty),
      );
      expect(_highlighter.tokens('', 'dart'), same(DiaryCodeTokens.empty));
      final huge = 'var x = 1;\n' * 2000;
      expect(huge.length, greaterThan(DiaryCodeHighlighter.maxLength));
      expect(
        _highlighter.tokens(huge, 'javascript'),
        same(DiaryCodeTokens.empty),
      );
      final manyLines = 'x\n' * 700;
      expect(
        _highlighter.tokens(manyLines, 'javascript'),
        same(DiaryCodeTokens.empty),
      );
    });

    test('repeated calls return the cached instance', () {
      final first = _highlighter.tokens(_json, 'json');
      final second = _highlighter.tokens(_json, 'json');
      expect(identical(first, second), isTrue);
    });
  });

  group('DiaryCodeHighlighter.detect', () {
    test('recognizes clear samples', () {
      expect(_highlighter.detect(_python), 'python');
      expect(_highlighter.detect(_json), 'json');
      expect(_highlighter.detect(_sql), 'sql');
    });

    test('returns null for prose and empty text', () {
      expect(_highlighter.detect(_prose), isNull);
      expect(_highlighter.detect(''), isNull);
      expect(_highlighter.detect('   \n  '), isNull);
    });

    test('caches results', () {
      expect(_highlighter.detect(_python), _highlighter.detect(_python));
    });
  });
}
