import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_media.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_table.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_walk.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_blocks.dart';

Map<String, Object?> _text(
  String type,
  String text, {
  Map<String, Object?> data = const {},
  List<Map<String, Object?>> children = const [],
  Map<String, Object?>? attributes,
}) => {
  'type': type,
  if (children.isNotEmpty) 'children': children,
  'data': {
    ...data,
    'delta': [
      {'insert': text, 'attributes': ?attributes},
    ],
  },
};

Map<String, Object?> _cell(int row, int col, List<Map<String, Object?>> body) =>
    {
      'type': 'table/cell',
      'children': body,
      'data': {'rowPosition': row, 'colPosition': col},
    };

Map<String, Object?> _document(List<Map<String, Object?>> children) => {
  'document': {'type': 'page', 'children': children},
};

List<Map<String, Object?>> _top(Map<String, Object?> document) =>
    diaryBlockChildren(diaryBlocksRoot(document)!);

void main() {
  test('keeps a valid callout icon and tone, drops bad ones', () {
    final clean = _top(
      sanitizeDiaryTemplateBlocks(
        _document([
          _text('callout', 'good', data: {'icon': '🌱', 'tone': 'green'}),
          _text('callout', 'family', data: {'icon': '👨‍👩‍👧'}),
          _text(
            'callout',
            'bad',
            data: {'icon': 'x' * 30, 'tone': 'neon', 'extra': 1},
          ),
          _text('callout', 'two', data: {'icon': 'ab', 'tone': 3}),
        ]),
      ),
    );
    expect(diaryBlockData(clean[0]), {
      'delta': [
        {'insert': 'good'},
      ],
      'icon': '🌱',
      'tone': 'green',
    });
    expect(diaryBlockData(clean[1])['icon'], '👨‍👩‍👧');
    expect(diaryBlockData(clean[2]).keys, ['delta']);
    expect(diaryBlockData(clean[3]).keys, ['delta']);
    expect(clean.map(diaryBlockText), ['good', 'family', 'bad', 'two']);
  });

  test('keeps toggle collapsed state and its sanitised children', () {
    final clean = _top(
      sanitizeDiaryTemplateBlocks(
        _document([
          _text(
            'toggle_list',
            'T',
            data: {'collapsed': true},
            children: [
              _text('paragraph', 'inside'),
              {
                'type': 'image',
                'data': {'url': '/private/photo.jpg'},
              },
            ],
          ),
          _text('toggle_list', 'U', data: {'collapsed': 'yes'}),
        ]),
      ),
    );
    expect(clean.length, 2);
    expect(diaryBlockData(clean[0])['collapsed'], true);
    expect(diaryBlockChildren(clean[0]).map(diaryBlockText), ['inside']);
    expect(diaryBlockData(clean[1]).containsKey('collapsed'), isFalse);
  });

  test('keeps script super and sub but drops other values', () {
    final clean = _top(
      sanitizeDiaryTemplateBlocks(
        _document([
          {
            'type': 'paragraph',
            'data': {
              'delta': [
                {
                  'insert': 'a',
                  'attributes': {'script': 'super'},
                },
                {
                  'insert': 'b',
                  'attributes': {'script': 'sub'},
                },
                {
                  'insert': 'c',
                  'attributes': {'script': 'mid'},
                },
              ],
            },
          },
        ]),
      ),
    );
    expect(diaryBlockDelta(clean.single), [
      {
        'insert': 'a',
        'attributes': {'script': 'super'},
      },
      {
        'insert': 'b',
        'attributes': {'script': 'sub'},
      },
      {'insert': 'c'},
    ]);
  });

  test('keeps a valid table with only its structure and cell text', () {
    final clean = sanitizeDiaryTemplateBlocks(
      _document([
        {
          'type': 'table',
          'children': [
            _cell(0, 0, [
              _text('paragraph', 'H', attributes: {'bold': true}),
            ]),
            _cell(0, 1, [
              _text('heading', 'Q', data: {'level': 2, 'align': 'center'}),
              {
                'type': 'image',
                'data': {'url': '/private/photo.jpg'},
              },
            ]),
            _cell(1, 0, []),
            _cell(1, 1, [_text('paragraph', 'v')]),
          ],
          'data': {
            'rowsLen': 2,
            'colsLen': 2,
            'headerRow': true,
            'colsHeight': 90,
          },
        },
      ]),
    );
    final table = _top(clean).single;
    expect(diaryBlockData(table), {
      'colsLen': 2,
      'rowsLen': 2,
      'headerRow': true,
    });
    final grid = DiaryTableGrid.of(table)!;
    expect(grid.rowTexts().toList(), ['H | Q', ' | v']);
    expect(grid.textBlocksAt(0, 1).single, {
      'type': 'paragraph',
      'data': {
        'delta': [
          {'insert': 'Q'},
        ],
        'align': 'center',
      },
    });
    expect(diaryBlockDelta(grid.textBlocksAt(0, 0).single).single, {
      'insert': 'H',
      'attributes': {'bold': true},
    });
    expect(grid.textBlocksAt(1, 0).single['type'], 'paragraph');
    expect(diaryBlocksMedia(clean), isEmpty);
  });

  test('an invalid table structure keeps its text as paragraphs', () {
    final clean = sanitizeDiaryTemplateBlocks(
      _document([
        {
          'type': 'table',
          'children': [
            _cell(0, 0, [_text('paragraph', 'one')]),
            _cell(0, 0, [_text('paragraph', 'dup')]),
          ],
          'data': {'rowsLen': 1, 'colsLen': 2},
        },
      ]),
    );
    expect(
      walkDiaryBlocks(clean).any((entry) => entry.$1['type'] == 'table'),
      isFalse,
    );
    expect(_top(clean).map(diaryBlockText), ['one', 'dup']);
  });

  test('v1 Quill ops with script still sanitise into blocks', () {
    final clean = _top(
      sanitizeDiaryTemplateBlocks([
        {
          'insert': '2',
          'attributes': {'script': 'super'},
        },
        {'insert': '\n'},
        {
          'insert': {'image': '/private/a.jpg'},
        },
        {'insert': '\n'},
      ]),
    );
    expect(diaryBlockDelta(clean.single), [
      {
        'insert': '2',
        'attributes': {'script': 'super'},
      },
    ]);
  });
}
