import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/rich_text/inline_rich_text.dart';

const InlineTextMarks _bold = InlineTextMarks(bold: true);
const InlineTextMarks _link = InlineTextMarks(href: 'https://example.com');

void main() {
  group('links', () {
    test('href round-trips through the delta and is a known mark', () {
      final runs = <InlineTextRun>[
        const InlineTextRun('see '),
        const InlineTextRun('docs', _link),
      ];
      final delta = encodeInlineDelta(runs)!;
      expect(delta.last['attributes'], <String, Object?>{
        'href': 'https://example.com',
      });
      final back = inlineRunsFromDelta(delta, 'see docs');
      expect(back, runs);
      expect(back.last.marks.extra, isEmpty);
    });

    test('a blank href reads as no link', () {
      final marks = InlineTextMarks.fromJson(<String, Object?>{'href': '  '});
      expect(marks.isEmpty, isTrue);
    });

    test('typing right after or before a link does not extend it', () {
      final runs = <InlineTextRun>[
        const InlineTextRun('ab'),
        const InlineTextRun('cd', _link),
      ];
      // 末尾接着打字。
      expect(remapRunsAfterEdit(runs, 'abcdx'), <InlineTextRun>[
        const InlineTextRun('ab'),
        const InlineTextRun('cd', _link),
        const InlineTextRun('x'),
      ]);
      // 只有链接时在开头打字。
      expect(
        remapRunsAfterEdit(const <InlineTextRun>[
          InlineTextRun('cd', _link),
        ], 'xcd'),
        <InlineTextRun>[
          const InlineTextRun('x'),
          const InlineTextRun('cd', _link),
        ],
      );
    });

    test('typing inside a link extends it and keeps its other marks', () {
      const boldLink = InlineTextMarks(bold: true, href: 'jotsy://diary/a');
      final runs = <InlineTextRun>[const InlineTextRun('cd', boldLink)];
      expect(remapRunsAfterEdit(runs, 'cxd'), <InlineTextRun>[
        const InlineTextRun('cxd', boldLink),
      ]);
      // 链接后面接着打的字保留粗体，只去掉链接。
      expect(remapRunsAfterEdit(runs, 'cdx'), <InlineTextRun>[
        const InlineTextRun('cd', boldLink),
        const InlineTextRun('x', _bold),
      ]);
    });

    test('setRunsLink links and unlinks a range', () {
      final runs = <InlineTextRun>[const InlineTextRun('hello world')];
      final linked = setRunsLink(runs, 6, 11, 'https://example.com');
      expect(linked, <InlineTextRun>[
        const InlineTextRun('hello '),
        const InlineTextRun('world', _link),
      ]);
      expect(setRunsLink(linked, 0, 11, null), runs);
    });
  });

  group('inlineLinkRangeAt', () {
    final runs = <InlineTextRun>[
      const InlineTextRun('a '),
      const InlineTextRun('link', _link),
      const InlineTextRun(' b'),
    ];

    test('finds the whole link around a caret inside or next to it', () {
      const whole = (start: 2, end: 6, href: 'https://example.com');
      expect(inlineLinkRangeAt(runs, 4, 4), whole);
      expect(inlineLinkRangeAt(runs, 2, 2), whole);
      expect(inlineLinkRangeAt(runs, 6, 6), whole);
      expect(inlineLinkRangeAt(runs, 0, 0), isNull);
      expect(inlineLinkRangeAt(runs, 8, 8), isNull);
    });

    test('a selection counts only when it stays inside one link', () {
      expect(inlineLinkRangeAt(runs, 3, 5)?.start, 2);
      expect(inlineLinkRangeAt(runs, 1, 5), isNull);
    });

    test('two links side by side: the caret takes the one before it', () {
      const other = InlineTextMarks(href: 'jotsy://diary/x');
      final pair = <InlineTextRun>[
        const InlineTextRun('ab', _link),
        const InlineTextRun('cd', other),
      ];
      expect(inlineLinkRangeAt(pair, 2, 2), (
        start: 0,
        end: 2,
        href: 'https://example.com',
      ));
    });
  });

  test('replaceRunsRange swaps the range for styled text', () {
    final runs = <InlineTextRun>[
      const InlineTextRun('hi @tr', _bold),
      const InlineTextRun(' end'),
    ];
    expect(replaceRunsRange(runs, 3, 6, 'Trip', _link), <InlineTextRun>[
      const InlineTextRun('hi ', _bold),
      const InlineTextRun('Trip', _link),
      const InlineTextRun(' end'),
    ]);
  });
}
