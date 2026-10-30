import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_builder.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_codec.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_table.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_walk.dart';

Map<String, Object?> _text(
  String type,
  String text, {
  Map<String, Object?> data = const {},
  List<Map<String, Object?>> children = const [],
}) => {
  'type': type,
  if (children.isNotEmpty) 'children': children,
  'data': {
    ...data,
    'delta': [
      if (text.isNotEmpty) {'insert': text},
    ],
  },
};

Map<String, Object?> _cell(int row, int col, List<Map<String, Object?>> body) =>
    {
      'type': 'table/cell',
      'children': body,
      'data': {'rowPosition': row, 'colPosition': col},
    };

/// 按行优先给出格子文字；每格一个段落。
Map<String, Object?> _table(
  List<List<String>> rows, {
  Map<String, Object?> data = const {},
}) => {
  'type': 'table',
  'children': [
    for (final (row, cells) in rows.indexed)
      for (final (col, text) in cells.indexed)
        _cell(row, col, [_text('paragraph', text)]),
  ],
  'data': {'rowsLen': rows.length, 'colsLen': rows.first.length, ...data},
};

Map<String, Object?> _document(List<Map<String, Object?>> children) => {
  'document': {'type': 'page', 'children': children},
};

/// 每块一行：层级缩进 + 类型 + 文字。
String _outline(Map<String, Object?> document) => [
  for (final (node, depth) in walkDiaryBlocks(document))
    '${'  ' * depth}${node['type']} ${diaryBlockText(node)}'.trimRight(),
].join('\n');

Map<String, Object?> _decode(Map<String, Object?> document) =>
    decodeStoredDiaryBlocks(jsonEncode(document));

void main() {
  group('valid tables', () {
    test('survive decoding and encoding unchanged', () {
      final stored = _document([
        _text('paragraph', 'before'),
        _table(
          [
            ['a', 'b'],
            ['c', 'd'],
          ],
          data: {'headerRow': true},
        ),
      ]);
      final raw = encodeDiaryBlocks(stored);
      final decoded = decodeStoredDiaryBlocks(raw);
      expect(encodeDiaryBlocks(decoded), raw);
      // 没有需要修正的地方时不做拷贝。
      expect(identical(liftHiddenDiaryBlockChildren(stored), stored), isTrue);
      final grid = DiaryTableGrid.of(
        diaryBlockChildren(diaryBlocksRoot(decoded)!)[1],
      )!;
      expect((grid.rows, grid.cols, grid.headerRow), (2, 2, true));
      expect(grid.rowTexts(), ['a | b', 'c | d']);
    });

    test('accept integral doubles and cells stored in column order', () {
      final table = {
        'type': 'table',
        'children': [
          _cell(0, 0, [_text('paragraph', 'a')]),
          _cell(1, 0, [_text('paragraph', 'c')]),
          _cell(0, 1, [_text('paragraph', 'b')]),
          _cell(1, 1, [_text('paragraph', 'd')]),
        ],
        'data': {'rowsLen': 2.0, 'colsLen': 2},
      };
      expect(DiaryTableGrid.of(table)!.rowTexts(), ['a | b', 'c | d']);
      expect(
        encodeDiaryBlocks(_decode(_document([table]))),
        encodeDiaryBlocks(_document([table])),
      );
    });

    test('turn other text blocks in a cell into paragraphs and lift nested '
        'blocks and embeds after the table', () {
      final stored = _document([
        {
          'type': 'table',
          'children': [
            _cell(0, 0, [
              _text('heading', 'title', data: {'level': 2, 'align': 'center'}),
              _text('code', 'x\ny', data: {'language': 'python'}),
            ]),
            _cell(0, 1, [
              _text('paragraph', 'p', children: [_text('paragraph', 'nested')]),
              {
                'type': 'image',
                'data': {'url': '/a.png'},
              },
              _text('bulleted_list', 'item'),
            ]),
          ],
          'data': {'rowsLen': 1, 'colsLen': 2},
        },
        _text('paragraph', 'after'),
      ]);
      final decoded = _decode(stored);
      expect(
        _outline(decoded),
        [
          'table',
          '  table/cell',
          '    paragraph title',
          '    paragraph x\ny',
          '  table/cell',
          '    paragraph p',
          '    paragraph item',
          'paragraph nested',
          'image',
          'paragraph after',
        ].join('\n'),
      );
      final cell = diaryBlockChildren(
        diaryBlockChildren(diaryBlocksRoot(decoded)!).first,
      ).first;
      // 只留行内文字与对齐，类型专有的字段去掉。
      expect(diaryBlockData(diaryBlockChildren(cell).first), {
        'delta': [
          {'insert': 'title'},
        ],
        'align': 'center',
      });
      expect(
        diaryBlocksPlainText(decoded),
        'title x\ny | p item\nnested\n\nafter',
      );
    });

    test('give an empty cell an empty paragraph', () {
      final stored = _document([
        {
          'type': 'table',
          'children': [
            _cell(0, 0, []),
            _cell(0, 1, [_text('paragraph', 'b')]),
          ],
          'data': {'rowsLen': 1, 'colsLen': 2},
        },
      ]);
      expect(
        _outline(_decode(stored)),
        [
          'table',
          '  table/cell',
          '    paragraph',
          '  table/cell',
          '    paragraph b',
        ].join('\n'),
      );
    });
  });

  group('invalid tables', () {
    Map<String, Object?> grid({Object? colsLen = 2, bool dropLast = false}) => {
      'type': 'table',
      'children': [
        // 存储顺序打乱：展开时按行优先。
        _cell(1, 1, [_text('paragraph', 'd')]),
        _cell(0, 1, [_text('paragraph', 'b')]),
        _cell(0, 0, [_text('paragraph', 'a')]),
        if (!dropLast) _cell(1, 0, [_text('paragraph', 'c')]),
      ],
      'data': {'rowsLen': 2, 'colsLen': colsLen},
    };

    String flattened(Map<String, Object?> table) =>
        _outline(_decode(_document([table, _text('paragraph', 'end')])));

    test('with a missing cell are flattened to paragraphs row by row', () {
      expect(
        flattened(grid(dropLast: true)),
        'paragraph a\nparagraph b\nparagraph d\nparagraph end',
      );
    });

    test('with a bad column count are flattened to paragraphs row by row', () {
      for (final colsLen in <Object?>[0, 13, '2', 1.5, null, -2]) {
        expect(
          flattened(grid(colsLen: colsLen)),
          'paragraph a\nparagraph b\nparagraph c\nparagraph d\nparagraph end',
          reason: 'colsLen: $colsLen',
        );
      }
    });

    test('keep blocks that are not cells and cells without a position', () {
      final table = {
        'type': 'table',
        'children': [
          _text('paragraph', 'stray'),
          {
            'type': 'table/cell',
            'children': [_text('quote', 'unplaced')],
          },
          _cell(0, 0, [_text('paragraph', 'a')]),
        ],
        'data': {'rowsLen': 1, 'colsLen': 1},
      };
      expect(
        flattened(table),
        'paragraph a\nparagraph stray\nquote unplaced\nparagraph end',
      );
    });

    test('leave no cell outside a table', () {
      expect(
        _outline(
          _decode(
            _document([
              _cell(0, 0, [_text('paragraph', 'loose')]),
              _text('paragraph', 'end'),
            ]),
          ),
        ),
        'paragraph loose\nparagraph end',
      );
    });

    test('without any content become one empty paragraph', () {
      expect(
        _outline(
          _decode(
            _document([
              {
                'type': 'table',
                'data': {'rowsLen': 1, 'colsLen': 1},
              },
            ]),
          ),
        ),
        'paragraph',
      );
    });
  });

  test('toggle children survive decoding while callout children move after '
      'it', () {
    final stored = _document([
      _text(
        'toggle_list',
        'more',
        data: {'collapsed': true},
        children: [
          _text('paragraph', 'hidden'),
          _text('callout', 'tip', children: [_text('paragraph', 'under')]),
        ],
      ),
    ]);
    expect(
      _outline(_decode(stored)),
      [
        'toggle_list more',
        '  paragraph hidden',
        '  callout tip',
        '  paragraph under',
      ].join('\n'),
    );
    expect(kDiaryTextBlockTypes, containsAll(['callout', 'toggle_list']));
    expect(kDiaryContainerBlockTypes, contains('toggle_list'));
    expect(kDiaryContainerBlockTypes, isNot(contains('callout')));
  });

  group('plain text', () {
    test('writes one line per table row with cells joined by a bar', () {
      final document = _document([
        _text('callout', 'note'),
        _table([
          ['a', 'b'],
          ['', ''],
          ['c', ''],
        ]),
        _text('toggle_list', 'open', children: [_text('paragraph', 'in')]),
      ]);
      expect(diaryBlocksPlainText(document), 'note\na | b\n\nc | \nopen\nin');
    });

    test('joins several paragraphs of one cell with a space', () {
      final table = {
        'type': 'table',
        'children': [
          _cell(0, 0, [
            _text('paragraph', 'one'),
            _text('paragraph', ''),
            _text('paragraph', 'two'),
          ]),
        ],
        'data': {'rowsLen': 1, 'colsLen': 1},
      };
      expect(diaryBlocksPlainText(_document([table])), 'one two');
    });

    test('counts table cell text as visible content', () {
      final empty = _document([
        _table([
          ['', ''],
        ]),
      ]);
      expect(diaryBlocksHaveVisibleContent(empty), isFalse);
      final filled = _document([
        _table([
          ['', 'x'],
        ]),
      ]);
      expect(diaryBlocksHaveVisibleContent(filled), isTrue);
    });
  });

  test('the import builder keeps a prebuilt table subtree and never nests '
      'later lines under it', () {
    final builder = DiaryBlocksBuilder()
      ..add(<String, Object?>{
        'type': 'table',
        // 导入方建好的子树：元素类型不限定为 Map。
        'children': <Object?>[
          _cell(0, 0, [_text('paragraph', 'a')]),
        ],
        'data': {'rowsLen': 1, 'colsLen': 1},
      }, 0)
      ..add(_text('paragraph', 'next'), 1);
    expect(
      _outline(builder.build()),
      'table\n  table/cell\n    paragraph a\nparagraph next',
    );
  });
}
