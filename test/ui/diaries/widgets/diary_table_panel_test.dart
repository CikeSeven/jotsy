import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_table.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:node_diary/ui/diaries/widgets/diary_table/diary_table_panel.dart';
import 'package:node_diary/ui/diaries/widgets/diary_toolbar_more_panel.dart';

import '../../../support/diary_color_panel_harness.dart';
import '../../../support/diary_content_test_helpers.dart';

/// 悬浮工具栏的表格工具与卡片内的表格面板：不在表格里时插入 3 × 3 表格、
/// 在时打开面板；每个操作一步撤销且表格仍有效、停用态与表头行的选中态只看
/// 正文；删除表格与选区离开表格时收起；320dp 窄屏不溢出；全程不推路由、
/// 正文保持焦点。
const String _tableTool = '表格';

/// 表格工具排在最前，320dp 下也常驻在工具栏一排上。
final List<DiaryToolbarItem> _tableFirstOrder = <DiaryToolbarItem>[
  DiaryToolbarItem.table,
  for (final item in kDefaultDiaryToolbarOrder)
    if (item != DiaryToolbarItem.table) item,
];

Map<String, Object?> _paragraph(String text) => {
  'type': 'paragraph',
  'data': {
    'delta': [
      if (text.isNotEmpty) {'insert': text},
    ],
  },
};

Map<String, Object?> _table(int rows, int cols, {bool headerRow = true}) => {
  'type': 'table',
  'data': {'rowsLen': rows, 'colsLen': cols, if (headerRow) 'headerRow': true},
  'children': [
    for (var row = 0; row < rows; row++)
      for (var col = 0; col < cols; col++)
        {
          'type': 'table/cell',
          'data': {'rowPosition': row, 'colPosition': col},
          'children': [_paragraph('r${row}c$col')],
        },
  ],
};

/// 正文：段落 `intro`、2 × 2 表格、段落 `outro`。
DiaryEditorController _controller([List<Map<String, Object?>>? blocks]) {
  final controller = DiaryEditorController.fromContent(
    jsonEncode({
      'document': {
        'type': 'page',
        'children':
            blocks ?? [_paragraph('intro'), _table(2, 2), _paragraph('outro')],
      },
    }),
  );
  addTearDown(controller.dispose);
  return controller;
}

af.Node _node(DiaryEditorController controller, int index) =>
    controller.document.root.children.elementAt(index);

DiaryTableGrid _grid(DiaryEditorController controller, int index) {
  final grid = DiaryTableGrid.of(_node(controller, index).toJson());
  expect(grid, isNotNull);
  return grid!;
}

Future<ColorPanelHarness> _pump(
  WidgetTester tester,
  DiaryEditorController controller, {
  double screenWidth = 360,
  Locale locale = const Locale('zh'),
}) async {
  final harness = await pumpColorPanel(
    tester,
    controller: controller,
    order: _tableFirstOrder,
    screenWidth: screenWidth,
    locale: locale,
  );
  harness.editorFocus.requestFocus();
  await tester.pumpAndSettle();
  return harness;
}

Future<void> _select(
  WidgetTester tester,
  DiaryEditorController controller,
  af.Selection selection,
) async {
  controller.select(selection);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _action(String label) => find.descendant(
  of: find.byType(DiaryTablePanel),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is Semantics &&
        widget.properties.button == true &&
        widget.properties.label == label,
  ),
);

Semantics _semantics(WidgetTester tester, String label) =>
    tester.widget<Semantics>(_action(label).first);

void main() {
  setUpAll(loadColorPanelFonts);

  testWidgets('outside a table the tool inserts a 3×3 header table, no panel', (
    tester,
  ) async {
    final controller = _controller([_paragraph(''), _paragraph('more')]);
    final harness = await _pump(tester, controller);
    await _select(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [0])),
    );
    final pushes = harness.routes.pushes;

    await _tap(tester, find.byTooltip(_tableTool));

    expect(_node(controller, 0).type, 'table');
    final grid = _grid(controller, 0);
    expect((grid.rows, grid.cols, grid.headerRow), (3, 3, true));
    expect(controller.selection!.end.path, [0, 0, 0]);
    expect(find.byType(DiaryTablePanel), findsNothing);
    expect(harness.extents.where((extent) => extent > 0), isEmpty);
    expect(harness.routes.pushes, pushes);
    expect(harness.editorFocus.hasFocus, isTrue);

    controller.undo();
    await tester.pumpAndSettle();
    expect(_node(controller, 0).type, 'paragraph');
    expect(tester.takeException(), isNull);
  });

  testWidgets('inside a table the tool opens the panel and the button lights', (
    tester,
  ) async {
    final controller = _controller();
    final harness = await _pump(tester, controller);
    await _select(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [1, 0, 0], offset: 2)),
    );
    final button = tester.widget<Semantics>(
      find
          .ancestor(
            of: find.byTooltip(_tableTool),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics && widget.properties.selected != null,
            ),
          )
          .first,
    );
    expect(button.properties.selected, isTrue);
    final pushes = harness.routes.pushes;

    await _tap(tester, find.byTooltip(_tableTool));

    expect(find.byType(DiaryTablePanel), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DiaryTablePanel),
        matching: find.text('表格'),
      ),
      findsOneWidget,
    );
    expect(
      harness.extents.last,
      kDiaryToolbarPanelChrome + kDiaryTablePanelHeight,
    );
    expect(harness.routes.pushes, pushes);
    expect(harness.editorFocus.hasFocus, isTrue);
    // 再点收起。
    await _tap(tester, find.byTooltip(_tableTool));
    expect(find.byType(DiaryTablePanel), findsNothing);
    expect(harness.extents.last, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every action keeps the table valid and undoes in one step', (
    tester,
  ) async {
    final controller = _controller();
    await _pump(tester, controller);
    await _select(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [1, 3, 0], offset: 2)),
    );
    await _tap(tester, find.byTooltip(_tableTool));

    final expectations = <String, (int, int, bool)>{
      '上方插入行': (3, 2, true),
      '下方插入行': (3, 2, true),
      '左侧插入列': (2, 3, true),
      '右侧插入列': (2, 3, true),
      '删除行': (1, 2, true),
      '删除列': (2, 1, true),
      '表头行': (2, 2, false),
    };
    for (final entry in expectations.entries) {
      final before = controller.contentJson;
      await _tap(tester, _action(entry.key));
      final grid = _grid(controller, 1);
      expect(
        (grid.rows, grid.cols, grid.headerRow),
        entry.value,
        reason: entry.key,
      );
      expect(find.byType(DiaryTablePanel), findsOneWidget, reason: entry.key);
      expect(controller.selection!.end.path.first, 1, reason: entry.key);
      expect(controller.selection!.end.path.length, 3, reason: entry.key);
      controller.undo();
      await tester.pumpAndSettle();
      expect(controller.contentJson, before, reason: entry.key);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('header toggle shows its state, limits disable actions', (
    tester,
  ) async {
    final controller = _controller([_table(1, 6, headerRow: false)]);
    await _pump(tester, controller);
    await _select(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [0, 2, 0])),
    );
    await _tap(tester, find.byTooltip(_tableTool));

    expect(_semantics(tester, '表头行').properties.selected, isFalse);
    await _tap(tester, _action('表头行'));
    expect(_semantics(tester, '表头行').properties.selected, isTrue);
    expect(_node(controller, 0).attributes['headerRow'], true);

    // 六列不能再加列；只剩一行不能删行；列还能删。
    expect(_semantics(tester, '左侧插入列').properties.enabled, isFalse);
    expect(_semantics(tester, '右侧插入列').properties.enabled, isFalse);
    expect(_semantics(tester, '删除行').properties.enabled, isFalse);
    expect(_semantics(tester, '删除列').properties.enabled, isTrue);
    final before = controller.contentJson;
    await _tap(tester, _action('右侧插入列'));
    await _tap(tester, _action('删除行'));
    expect(controller.contentJson, before);

    for (var i = 0; i < 5; i++) {
      await _tap(tester, _action('删除列'));
    }
    expect(_grid(controller, 0).cols, 1);
    expect(_semantics(tester, '删除列').properties.enabled, isFalse);
    expect(_semantics(tester, '左侧插入列').properties.enabled, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deleting the table or leaving it closes the panel', (
    tester,
  ) async {
    final controller = _controller();
    final harness = await _pump(tester, controller);
    await _select(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [1, 1, 0])),
    );
    await _tap(tester, find.byTooltip(_tableTool));
    expect(find.byType(DiaryTablePanel), findsOneWidget);

    await _select(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [2])),
    );
    expect(find.byType(DiaryTablePanel), findsNothing);
    expect(harness.extents.last, 0);

    await _select(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [1, 1, 0])),
    );
    await _tap(tester, find.byTooltip(_tableTool));
    await _tap(tester, _action('删除表格'));
    expect(controller.document.root.children.map((node) => node.type), [
      'paragraph',
      'paragraph',
    ]);
    expect(controller.selection!.end.path, [1]);
    expect(find.byType(DiaryTablePanel), findsNothing);
    expect(harness.extents.last, 0);
    controller.undo();
    await tester.pumpAndSettle();
    expect(_node(controller, 1).type, 'table');
    expect(harness.editorFocus.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final locale in const [Locale('zh'), Locale('en')]) {
    testWidgets('the panel fits a 320dp phone ($locale)', (tester) async {
      final controller = _controller();
      await _pump(tester, controller, screenWidth: 320, locale: locale);
      await _select(
        tester,
        controller,
        af.Selection.collapsed(af.Position(path: [1, 0, 0])),
      );
      await _tap(
        tester,
        find.byTooltip(locale.languageCode == 'zh' ? '表格' : 'Table'),
      );
      expect(find.byType(DiaryTablePanel), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DiaryTablePanel),
          matching: find.byWidgetPredicate(
            (widget) => widget is Semantics && widget.properties.button == true,
          ),
        ),
        findsNWidgets(8),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
