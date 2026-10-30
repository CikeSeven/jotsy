import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_table.dart';
import 'package:node_diary/ui/diaries/controllers/diary_block_editing.dart';
import 'package:node_diary/ui/diaries/controllers/diary_callout_editing.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_insert.dart';
import 'package:node_diary/ui/diaries/controllers/diary_table_editing.dart';
import 'package:node_diary/ui/diaries/controllers/diary_table_selection.dart';
import 'package:node_diary/ui/diaries/controllers/diary_table_structure.dart';
import 'package:node_diary/ui/diaries/controllers/diary_text_style_editing.dart';

/// 表格的结构操作、跨格选区删除与格内的块规则：每次操作后表格结构仍然
/// 有效（`DiaryTableGrid.of` 认得），一步撤销回到原样。

Map<String, Object?> _paragraph(String text) => {
  'type': 'paragraph',
  'data': {
    'delta': [
      if (text.isNotEmpty) {'insert': text},
    ],
  },
};

/// [rows] × [cols] 的表格，格子文字为 `r{row}c{col}`；[extra] 给某些格子
/// 追加第二段。
Map<String, Object?> _table(
  int rows,
  int cols, {
  bool headerRow = true,
  Map<(int, int), List<String>> extra = const {},
}) => {
  'type': 'table',
  'data': {'rowsLen': rows, 'colsLen': cols, if (headerRow) 'headerRow': true},
  'children': [
    for (var row = 0; row < rows; row++)
      for (var col = 0; col < cols; col++)
        {
          'type': 'table/cell',
          'data': {'rowPosition': row, 'colPosition': col},
          'children': [
            _paragraph('r${row}c$col'),
            for (final text in extra[(row, col)] ?? const <String>[])
              _paragraph(text),
          ],
        },
  ],
};

DiaryEditorController _document(List<Map<String, Object?>> blocks) {
  final controller = DiaryEditorController.fromContent(
    jsonEncode({
      'document': {'type': 'page', 'children': blocks},
    }),
  );
  addTearDown(controller.dispose);
  return controller;
}

List<String> _types(DiaryEditorController controller) => [
  for (final node in controller.document.root.children) node.type,
];

DiaryTableGrid _grid(af.Node table) {
  final grid = DiaryTableGrid.of(table.toJson());
  expect(grid, isNotNull, reason: 'table must stay structurally valid');
  return grid!;
}

/// 整张表的文字，每行一个字符串、格与格之间 `|`。
List<String> _rows(af.Node table) => [
  for (final row in _grid(table).rowTexts()) row,
];

af.Node _tableAt(DiaryEditorController controller, int index) =>
    controller.document.root.children.elementAt(index);

void _caretIn(
  DiaryEditorController controller,
  af.Path path, [
  int offset = 0,
]) {
  controller.select(
    af.Selection.collapsed(af.Position(path: path, offset: offset)),
  );
}

void main() {
  group('insertDiaryTable', () {
    test(
      'replaces an empty paragraph with a 3×3 header table, caret in (0,0)',
      () {
        final controller = _document([_paragraph('')]);
        _caretIn(controller, [0]);
        final before = controller.contentJson;

        insertDiaryTable(controller);

        expect(_types(controller), ['table']);
        final grid = _grid(_tableAt(controller, 0));
        expect((grid.rows, grid.cols, grid.headerRow), (3, 3, true));
        expect(controller.selection!.end.path, [0, 0, 0]);
        controller.undo();
        expect(controller.contentJson, before);
      },
    );

    test('inserts after a non-empty block and after an enclosing table', () {
      final controller = _document([_paragraph('text'), _paragraph('after')]);
      _caretIn(controller, [0], 2);
      insertDiaryTable(controller);
      expect(_types(controller), ['paragraph', 'table', 'paragraph']);
      expect(controller.document.nodeAtPath([0])!.delta!.toPlainText(), 'text');
      expect(controller.selection!.end.path, [1, 0, 0]);

      // 光标已在表格里：新表格插到这个表格后面，不嵌套。
      insertDiaryTable(controller);
      expect(_types(controller), ['paragraph', 'table', 'table', 'paragraph']);
      expect(controller.selection!.end.path, [2, 0, 0]);
      _grid(_tableAt(controller, 1));
      _grid(_tableAt(controller, 2));
    });
  });

  group('row and column operations', () {
    test('every action keeps the grid valid and undoes in one step', () {
      final actions = <String, void Function(DiaryEditorController)>{
        'row above': (c) => insertDiaryTableRow(c, above: true),
        'row below': (c) => insertDiaryTableRow(c, above: false),
        'column left': (c) => insertDiaryTableColumn(c, before: true),
        'column right': (c) => insertDiaryTableColumn(c, before: false),
        'delete row': deleteDiaryTableRow,
        'delete column': deleteDiaryTableColumn,
        'header row': toggleDiaryTableHeaderRow,
        'delete table': deleteDiaryTable,
      };
      for (final entry in actions.entries) {
        final controller = _document([
          _paragraph('intro'),
          _table(
            2,
            3,
            extra: {
              (1, 1): ['second'],
            },
          ),
          _paragraph('outro'),
        ]);
        _caretIn(controller, [1, 4, 1], 3);
        final before = controller.contentJson;
        entry.value(controller);
        expect(controller.contentJson, isNot(before), reason: entry.key);
        for (final node in controller.document.root.children) {
          if (node.type == 'table') _grid(node);
        }
        controller.undo();
        expect(controller.contentJson, before, reason: entry.key);
        expect(controller.hasRedo, isTrue, reason: entry.key);
      }
    });

    test(
      'inserting rows keeps the caret in its cell and renumbers positions',
      () {
        final controller = _document([_table(2, 2)]);
        _caretIn(controller, [0, 3], 2); // r1c1
        insertDiaryTableRow(controller, above: true);
        var table = _tableAt(controller, 0);
        expect(_rows(table), ['r0c0 | r0c1', '', 'r1c0 | r1c1']);
        expect(
          controller.selection!.end,
          af.Position(path: [0, 5, 0], offset: 2),
        );

        insertDiaryTableRow(controller, above: false);
        table = _tableAt(controller, 0);
        expect(_rows(table), ['r0c0 | r0c1', '', 'r1c0 | r1c1', '']);
        expect(controller.selection!.end.path, [0, 5, 0]);
        final cell = controller.document.nodeAtPath([0, 7])!;
        expect(cell.attributes['rowPosition'], 3);
        expect(cell.attributes['colPosition'], 1);
      },
    );

    test('inserting columns stops at six, keeps the caret column', () {
      final controller = _document([_table(1, 5, headerRow: false)]);
      _caretIn(controller, [0, 2]);
      insertDiaryTableColumn(controller, before: true);
      expect(_rows(_tableAt(controller, 0)), [
        'r0c0 | r0c1 |  | r0c2 | r0c3 | r0c4',
      ]);
      expect(controller.selection!.end.path, [0, 3, 0]);
      expect(canInsertDiaryTableColumn(diaryTableCaret(controller)!), isFalse);

      final before = controller.contentJson;
      insertDiaryTableColumn(controller, before: false);
      expect(controller.contentJson, before);
    });

    test(
      'deleting rows and columns moves the caret to a neighbour and stops at one',
      () {
        final controller = _document([_table(3, 3)]);
        _caretIn(controller, [0, 4, 0], 2); // r1c1
        deleteDiaryTableRow(controller);
        expect(_rows(_tableAt(controller, 0)), [
          'r0c0 | r0c1 | r0c2',
          'r2c0 | r2c1 | r2c2',
        ]);
        expect(controller.selection!.end, af.Position(path: [0, 4, 0]));

        deleteDiaryTableColumn(controller);
        expect(_rows(_tableAt(controller, 0)), ['r0c0 | r0c2', 'r2c0 | r2c2']);
        expect(controller.selection!.end.path, [0, 3, 0]);

        deleteDiaryTableRow(controller);
        deleteDiaryTableRow(controller);
        deleteDiaryTableColumn(controller);
        deleteDiaryTableColumn(controller);
        // 删的是光标所在的列，剩下的是另一列。
        expect(_rows(_tableAt(controller, 0)), ['r0c0']);
        final caret = diaryTableCaret(controller)!;
        expect(canDeleteDiaryTableRow(caret), isFalse);
        expect(canDeleteDiaryTableColumn(caret), isFalse);
      },
    );

    test('header toggle writes the flag sparsely', () {
      final controller = _document([_table(2, 2)]);
      _caretIn(controller, [0, 0, 0]);
      toggleDiaryTableHeaderRow(controller);
      expect(
        _tableAt(controller, 0).attributes.containsKey('headerRow'),
        isFalse,
      );
      toggleDiaryTableHeaderRow(controller);
      expect(_tableAt(controller, 0).attributes['headerRow'], true);
      expect(diaryTableCaret(controller)!.headerRow, isTrue);
    });

    test('deleting the table moves the caret on, or leaves one paragraph', () {
      final controller = _document([
        _paragraph('a'),
        _table(1, 1),
        _paragraph('b'),
      ]);
      _caretIn(controller, [1, 0, 0]);
      deleteDiaryTable(controller);
      expect(_types(controller), ['paragraph', 'paragraph']);
      expect(controller.selection!.end, af.Position(path: [1]));

      final only = _document([_table(1, 1)]);
      _caretIn(only, [0, 0, 0]);
      deleteDiaryTable(only);
      expect(_types(only), ['paragraph']);
      expect(only.plainText, isEmpty);
    });
  });

  group('block rules inside cells', () {
    test('type conversions are no-ops for cell paragraphs', () {
      final controller = _document([_paragraph('p'), _table(1, 2)]);
      _caretIn(controller, [1, 0, 0]);
      final before = controller.contentJson;
      controller.setBlockType('heading', attributes: {'level': 2});
      controller.setBlockType('bulleted_list');
      controller.setBlockType('todo_list', attributes: {'checked': false});
      setDiaryHeadingLevel(controller, 1);
      convertDiaryBlocksToCallout(controller);
      toggleDiaryCodeBlockOn(controller);
      expect(controller.contentJson, before);
      // 选区从格子跨到表格外：外面的段落照常转换，格子里的不动。
      controller.select(
        af.Selection(
          start: af.Position(path: [0]),
          end: af.Position(path: [1, 1, 0], offset: 2),
        ),
      );
      controller.setBlockType('quote');
      expect(_types(controller), ['quote', 'table']);
      _grid(_tableAt(controller, 1));
    });

    test('inline formats still apply inside a cell', () {
      final controller = _document([_table(1, 1)]);
      controller.select(
        af.Selection.single(path: [0, 0, 0], startOffset: 0, endOffset: 2),
      );
      controller.toggle('bold');
      final delta = controller.document.nodeAtPath([0, 0, 0])!.delta!;
      expect(delta.toJson(), [
        {
          'insert': 'r0',
          'attributes': {'bold': true},
        },
        {'insert': 'c0'},
      ]);
      _grid(_tableAt(controller, 0));
    });

    test('media and dividers inserted from a cell land after the table', () {
      final controller = _document([_table(1, 2), _paragraph('after')]);
      _caretIn(controller, [0, 1, 0], 2);
      insertDiaryEditorNodes(
        controller: controller,
        nodes: [
          af.Node(type: 'image', attributes: {'url': '/a.png'}),
        ],
      );
      expect(_types(controller), ['table', 'image', 'paragraph', 'paragraph']);
      expect(controller.selection!.end.path, [2]);
      expect(_rows(_tableAt(controller, 0)), ['r0c0 | r0c1']);
    });

    test('paste flattening keeps only text as paragraphs', () {
      final nodes = [
        af.Node(
          type: 'heading',
          attributes: {
            'delta': [
              {'insert': 'h'},
            ],
            'level': 1,
          },
        ),
        af.Node(
          type: 'bulleted_list',
          attributes: {
            'delta': [
              {'insert': 'li'},
            ],
            'align': 'center',
          },
          children: [af.paragraphNode(text: 'child')],
        ),
        af.Node(type: 'image', attributes: {'url': '/a.png'}),
        af.Node.fromJson(_table(1, 2).cast<String, Object>()),
      ];
      final paragraphs = diaryTableCellParagraphs(nodes);
      expect(paragraphs.map((node) => node.type), everyElement('paragraph'));
      expect(paragraphs.map((node) => node.delta!.toPlainText()), [
        'h',
        'li',
        'child',
        'r0c0',
        'r0c1',
      ]);
      expect(paragraphs[1].attributes['align'], 'center');
      expect(paragraphs[0].attributes.containsKey('level'), isFalse);
    });
  });

  group('deleteDiaryTableSelection', () {
    /// 文档：段落、2 × 2 表格（r1c0 带第二段）、段落；枚举所有能当选区端点
    /// 的位置对，删掉后表格仍有效或整个消失。
    List<Map<String, Object?>> blocks() => [
      _paragraph('before'),
      _table(
        2,
        2,
        extra: {
          (1, 0): ['more'],
        },
      ),
      _paragraph('after'),
    ];

    List<af.Position> positions(DiaryEditorController controller) {
      final result = <af.Position>[];
      for (final node in walkDiaryEditorNodes(controller.document)) {
        final delta = node.delta;
        if (delta == null) {
          if (node.type == 'table') result.add(af.Position(path: node.path));
          continue;
        }
        for (final offset in {0, delta.length ~/ 2, delta.length}) {
          result.add(af.Position(path: node.path, offset: offset));
        }
      }
      return result;
    }

    test(
      'every selection touching the table leaves a valid table or none',
      () async {
        final probe = _document(blocks());
        final all = positions(probe);
        var checked = 0;
        for (var i = 0; i < all.length; i++) {
          for (var j = i + 1; j < all.length; j++) {
            final controller = _document(blocks());
            final selection = af.Selection(start: all[i], end: all[j]);
            if (!diarySelectionTouchesTable(controller.state, selection)) {
              continue;
            }
            final before = controller.contentJson;
            final handled = await deleteDiaryTableSelection(
              controller.state,
              selection,
            );
            expect(handled, isTrue, reason: '$selection');
            for (final node in controller.document.root.children) {
              if (node.type == 'table') _grid(node);
              expect(node.type, isNot('table/cell'), reason: '$selection');
            }
            // 光标停在起点（起点是表格块本身时换算成第一格开头）。
            final after = controller.selection!;
            expect(after.isCollapsed, isTrue, reason: '$selection');
            expect(
              controller.document.nodeAtPath(after.end.path),
              isNotNull,
              reason: '$selection',
            );
            controller.undo();
            expect(controller.contentJson, before, reason: '$selection');
            checked++;
            controller.dispose();
          }
        }
        expect(checked, greaterThan(100));
      },
    );

    test(
      'same cell merges, across cells clears, beyond the table trims',
      () async {
        // 同一格：末段并进首段。
        var controller = _document(blocks());
        await deleteDiaryTableSelection(
          controller.state,
          af.Selection(
            start: af.Position(path: [1, 2, 0], offset: 2),
            end: af.Position(path: [1, 2, 1], offset: 2),
          ),
        );
        expect(controller.document.nodeAtPath([1, 2])!.children.length, 1);
        expect(
          controller.document.nodeAtPath([1, 2, 0])!.delta!.toPlainText(),
          'r1re',
        );

        // 跨格：首尾各删一截，中间的格子清空、保留一段。
        controller = _document(blocks());
        await deleteDiaryTableSelection(
          controller.state,
          af.Selection(
            start: af.Position(path: [1, 0, 0], offset: 2),
            end: af.Position(path: [1, 3, 0], offset: 2),
          ),
        );
        expect(_rows(_tableAt(controller, 1)), ['r0 | ', ' | c1']);
        expect(controller.document.nodeAtPath([1, 2])!.children.length, 1);

        // 从表格外选到格子里：外面的文字删掉一截，表格留下、前面的格子清空。
        controller = _document(blocks());
        await deleteDiaryTableSelection(
          controller.state,
          af.Selection(
            start: af.Position(path: [0], offset: 3),
            end: af.Position(path: [1, 1, 0], offset: 2),
          ),
        );
        expect(_types(controller), ['paragraph', 'table', 'paragraph']);
        expect(
          controller.document.nodeAtPath([0])!.delta!.toPlainText(),
          'bef',
        );
        expect(_rows(_tableAt(controller, 1)), [' | c1', 'r1c0 more | r1c1']);

        // 从格子里选到表格外：后面的文字删掉一截。
        controller = _document(blocks());
        await deleteDiaryTableSelection(
          controller.state,
          af.Selection(
            start: af.Position(path: [1, 3, 0], offset: 2),
            end: af.Position(path: [2], offset: 3),
          ),
        );
        expect(_types(controller), ['paragraph', 'table', 'paragraph']);
        expect(controller.document.nodeAtPath([2])!.delta!.toPlainText(), 'er');
        expect(_rows(_tableAt(controller, 1)), [
          'r0c0 | r0c1',
          'r1c0 more | r1',
        ]);

        // 选区从表格块本身开始、越过表格：整个表格删掉。
        controller = _document(blocks());
        await deleteDiaryTableSelection(
          controller.state,
          af.Selection(
            start: af.Position(path: [1]),
            end: af.Position(path: [2], offset: 2),
          ),
        );
        expect(_types(controller), ['paragraph', 'paragraph']);
        expect(
          controller.document.nodeAtPath([1])!.delta!.toPlainText(),
          'ter',
        );

        // 两端都在表格外、表格只在中间：交给上游。
        controller = _document(blocks());
        expect(
          await deleteDiaryTableSelection(
            controller.state,
            af.Selection(
              start: af.Position(path: [0]),
              end: af.Position(path: [2]),
            ),
          ),
          isFalse,
        );
      },
    );
  });
}
