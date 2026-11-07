import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_search_terms.dart';

void main() {
  group('splitSearchTerms', () {
    test('splits on any whitespace and drops blanks', () {
      expect(splitSearchTerms(''), isEmpty);
      expect(splitSearchTerms('   '), isEmpty);
      expect(splitSearchTerms(' 京都  雨\n寺庙\u3000红叶 '), <String>[
        '京都',
        '雨',
        '寺庙',
        '红叶',
      ]);
    });

    test('dedupes case-insensitively, keeping the first spelling', () {
      expect(splitSearchTerms('Kyoto kyoto KYOTO rain'), <String>[
        'Kyoto',
        'rain',
      ]);
    });

    test('keeps at most maxSearchTerms words', () {
      final many = List<String>.generate(12, (i) => 'w$i').join(' ');
      expect(splitSearchTerms(many), hasLength(maxSearchTerms));
      expect(splitSearchTerms(many).last, 'w${maxSearchTerms - 1}');
    });
  });

  test('escapeLike makes LIKE wildcards literal', () {
    expect(escapeLike('100%'), r'100\%');
    expect(escapeLike('a_b'), r'a\_b');
    expect(escapeLike(r'c:\d'), r'c:\\d');
    expect(containsLikePattern('50%'), r'%50\%%');
  });
}
