import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/viewmodels/search_highlight.dart';

void main() {
  const highlight = TextStyle(fontWeight: FontWeight.w600);

  List<String> highlighted(String text, List<String> terms) => <String>[
    for (final span in searchHighlightSpans(text, terms, highlight))
      if ((span as TextSpan).style == highlight) span.text!,
  ];

  test('marks every occurrence of every word, case-insensitive', () {
    expect(
      highlighted('Kyoto rain, kyoto temple', <String>['KYOTO', 'rain']),
      <String>['Kyoto', 'rain', 'kyoto'],
    );
  });

  test('overlapping and adjacent matches merge into one span', () {
    expect(highlighted('秋天的京都红叶', <String>['京都', '都红', '红叶']), <String>[
      '京都红叶',
    ]);
  });

  test('without matches the text is a single plain span', () {
    final spans = searchHighlightSpans('hello', <String>['bye'], highlight);
    expect(spans, hasLength(1));
    expect((spans.single as TextSpan).text, 'hello');
  });

  group('searchExcerpt', () {
    test('keeps the start when the match is near the beginning', () {
      expect(searchExcerpt('今天\n去了京都', <String>['京都']), '今天 去了京都');
    });

    test('opens a window before a late match with an ellipsis', () {
      final text = '${'字' * 100}京都在这里';
      final excerpt = searchExcerpt(text, <String>['京都'])!;
      expect(excerpt.startsWith('…'), isTrue);
      expect(excerpt, '…${'字' * searchExcerptLead}京都在这里');
    });

    test('caps the length and never splits an emoji', () {
      final text = '${'a' * 20}😀${'b' * 5}hit';
      // 'hit' 在下标 27，往前 6 个码元正落在表情的低位代理（21）上：
      // 往后挪一位，不切开表情。
      final excerpt = searchExcerpt(text, <String>['hit'], lead: 6)!;
      expect(excerpt, '…${'b' * 5}hit');
      expect(
        searchExcerpt('x' * 50 + 'hit', <String>['x'], maxLength: 10),
        'x' * 10,
      );
    });

    test('returns null without a match', () {
      expect(searchExcerpt('abc', <String>['z']), isNull);
    });
  });
}
