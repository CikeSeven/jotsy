import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_find_query.dart';

/// 正文查找的纯计算：查找条件编译成正则（原文 / 正则 / 大小写 / 整词，
/// Unicode 模式与退回普通模式）、按阅读顺序逐块找匹配（含子块与表格格子，
/// 记下路径与顶层块、上限截断、零宽匹配不拆 emoji），以及替换串里的分组
/// 引用展开。

Map<String, Object?> _block(
  String type,
  String text, {
  Map<String, Object?> data = const {},
  List<Map<String, Object?>> children = const [],
}) => {
  'type': type,
  'data': {
    'delta': [
      if (text.isNotEmpty) {'insert': text},
    ],
    ...data,
  },
  if (children.isNotEmpty) 'children': children,
};

Map<String, Object?> _p(String text) => _block('paragraph', text);

Document _doc(List<Map<String, Object?>> blocks) => diaryEditorDocument(
  jsonEncode({
    'document': {'type': 'page', 'children': blocks},
  }),
);

List<String> _found(String text, DiaryFindQuery query) {
  final pattern = compileDiaryFindPattern(query)!;
  return pattern.allMatches(text).map((m) => m[0]!).toList();
}

RegExpMatch _match(String pattern, String text) =>
    RegExp(pattern).firstMatch(text)!;

void main() {
  group('compileDiaryFindPattern', () {
    test('returns null for an empty query', () {
      expect(compileDiaryFindPattern(const DiaryFindQuery()), isNull);
    });

    test('plain text matches literally and ignores case by default', () {
      const query = DiaryFindQuery(text: 'a.b');
      expect(_found('A.B axb a.b', query), ['A.B', 'a.b']);
    });

    test('match case keeps letters exact', () {
      const query = DiaryFindQuery(text: 'Note', caseSensitive: true);
      expect(_found('note Note NOTE', query), ['Note']);
    });

    test('regex mode supports unicode property classes', () {
      const query = DiaryFindQuery(text: r'\p{Script=Han}+', regex: true);
      expect(_found('abc中文def日记', query), ['中文', '日记']);
    });

    test('falls back to non-unicode mode for lenient escapes', () {
      // `\-` is an error in unicode mode but fine in the classic syntax.
      const query = DiaryFindQuery(text: r'\d+\-\d+', regex: true);
      expect(_found('call 010-1234 now', query), ['010-1234']);
    });

    test('throws on an invalid regex', () {
      expect(
        () => compileDiaryFindPattern(
          const DiaryFindQuery(text: '(unclosed', regex: true),
        ),
        throwsFormatException,
      );
    });

    test('whole word skips matches inside longer words', () {
      const english = DiaryFindQuery(text: 'cat', wholeWord: true);
      expect(_found('cat concat cat.', english), ['cat', 'cat']);
      const chinese = DiaryFindQuery(text: '日记', wholeWord: true);
      expect(
        compileDiaryFindPattern(
          chinese,
        )!.allMatches('写日记 日记。').map((m) => m.start).toList(),
        [4],
      );
    });

    test('anchors match at block boundaries', () {
      const query = DiaryFindQuery(text: r'^\s*-', regex: true);
      expect(_found('- a', query), ['-']);
      expect(_found('a - b', query), isEmpty);
    });
  });

  group('findDiaryMatches', () {
    test('walks nested blocks in reading order with paths and blocks', () {
      final document = _doc([
        _p('cat one'),
        _block('bulleted_list', 'list cat', children: [_p('child cat')]),
        _p('no match'),
        _p('Cat end'),
      ]);
      final pattern = compileDiaryFindPattern(
        const DiaryFindQuery(text: 'cat'),
      )!;
      final result = findDiaryMatches(document.root, pattern);
      expect(result.truncated, isFalse);
      expect(
        result.matches.map((m) => '${m.path}:${m.start}-${m.end}').toList(),
        ['[0]:0-3', '[1]:5-8', '[1, 0]:6-9', '[3]:0-3'],
      );
      final blocks = document.root.children.toList();
      expect(identical(result.matches[2].block, blocks[1]), isTrue);
      expect(
        identical(result.matches[2].node, blocks[1].children.first),
        isTrue,
      );
      expect(identical(result.matches[3].block, blocks[3]), isTrue);
    });

    test('searches table cell paragraphs', () {
      final document = _doc([
        {
          'type': 'table',
          'data': {'colsLen': 1, 'rowsLen': 1},
          'children': [
            {
              'type': 'table/cell',
              'data': {'rowPosition': 0, 'colPosition': 0},
              'children': [_p('inside cell')],
            },
          ],
        },
      ]);
      final pattern = compileDiaryFindPattern(
        const DiaryFindQuery(text: 'cell'),
      )!;
      final matches = findDiaryMatches(document.root, pattern).matches;
      expect(matches, hasLength(1));
      expect(matches.single.path, [0, 0, 0]);
      expect(matches.single.start, 7);
    });

    test('stops at the limit and reports truncation', () {
      final document = _doc([_p('aaaa'), _p('aaaa')]);
      final pattern = compileDiaryFindPattern(const DiaryFindQuery(text: 'a'))!;
      final limited = findDiaryMatches(document.root, pattern, limit: 5);
      expect(limited.matches, hasLength(5));
      expect(limited.truncated, isTrue);
      final all = findDiaryMatches(document.root, pattern, limit: null);
      expect(all.matches, hasLength(8));
      expect(all.truncated, isFalse);
    });

    test('empty matches never split a surrogate pair', () {
      final document = _doc([_p('a😀b')]);
      // `\-` forces the non-unicode fallback, whose empty matches step by
      // code unit; the alternation keeps the empty branch.
      final pattern = compileDiaryFindPattern(
        const DiaryFindQuery(text: r'\-|', regex: true),
      )!;
      expect(pattern.isUnicode, isFalse);
      final offsets = findDiaryMatches(
        document.root,
        pattern,
      ).matches.map((m) => m.start).toList();
      expect(offsets, [0, 1, 3, 4]);
    });
  });

  group('compareDiaryFindPositions', () {
    test('orders parents before children before next siblings', () {
      expect(compareDiaryFindPositions([0], 5, [0, 0], 0), lessThan(0));
      expect(compareDiaryFindPositions([0, 3], 0, [1], 0), lessThan(0));
      expect(compareDiaryFindPositions([2], 4, [2], 4), 0);
      expect(compareDiaryFindPositions([2], 5, [2], 4), greaterThan(0));
    });
  });

  group('expandDiaryReplacement', () {
    test('expands numbered, whole and named groups', () {
      final match = _match(r'(?<year>\d{4})-(\d\d)', 'on 2024-05 we');
      expect(expandDiaryReplacement(r'$2/$1', match), '05/2024');
      expect(expandDiaryReplacement(r'[$&]', match), '[2024-05]');
      expect(expandDiaryReplacement(r'[$0]', match), '[2024-05]');
      expect(expandDiaryReplacement(r'${year}年', match), '2024年');
    });

    test(r'keeps $$ and unknown references literal', () {
      final match = _match(r'(a)', 'a');
      expect(expandDiaryReplacement(r'$$1', match), r'$1');
      expect(
        expandDiaryReplacement(r'$5 ${nope} $x $', match),
        r'$5 ${nope} $x $',
      );
    });

    test('prefers two-digit groups only when they exist', () {
      final match = _match(r'(a)(b)(c)(d)(e)(f)(g)(h)(i)(j)(k)', 'abcdefghijk');
      expect(expandDiaryReplacement(r'$11', match), 'k');
      final small = _match(r'(a)', 'a');
      expect(expandDiaryReplacement(r'$10', small), 'a0');
    });

    test('unmatched optional groups expand to nothing', () {
      final match = _match(r'(x)?(y)', 'y');
      expect(expandDiaryReplacement(r'<$1$2>', match), '<y>');
    });
  });
}
