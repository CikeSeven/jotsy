import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_table.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_block_reorder.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/providers/diary_code_block_style_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_block_commands.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_block_drop_targets.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_block_handle.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_table_block.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_table_keyboard_interceptor.dart';

import '../../../support/expressive_test_theme.dart';

/// 表格在编辑器里的渲染与键盘规则：等宽列、不横向滚动、表头行底色与加粗
/// （明暗）、12 列窄屏不溢出、只读；格内回车另起一段，退格 / Delete 不并出
/// 格子，Tab / 方向键在格子之间移动，Markdown 标记按原文；把手属于整个
/// 表格、落点不进表格；`/` 菜单能找到它。

Map<String, Object?> _paragraph(String text) => {
  'type': 'paragraph',
  'data': {
    'delta': [
      if (text.isNotEmpty) {'insert': text},
    ],
  },
};

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

DiaryEditorController _document(
  List<Map<String, Object?>> blocks, {
  bool readOnly = false,
}) {
  final controller = DiaryEditorController.fromContent(
    jsonEncode({
      'document': {'type': 'page', 'children': blocks},
    }),
    readOnly: readOnly,
  );
  addTearDown(controller.dispose);
  return controller;
}

Future<void> _pump(
  WidgetTester tester,
  DiaryEditorController controller, {
  FocusNode? focusNode,
  Brightness brightness = Brightness.light,
  double width = 360,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [diaryCodeBlockStyleProvider.overrideWith(() => _CodeStyle())],
      child: MaterialApp(
        theme: expressiveTestTheme(brightness),
        locale: const Locale('zh'),
        localizationsDelegates: const [
          ...AppLocalizations.localizationsDelegates,
          af.AppFlowyEditorLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DiaryEditor(
            controller: controller,
            appearance: const DiaryTextAppearance(
              typography: DiaryTypography(),
            ),
            focusNode: focusNode,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 软键盘输入：在当前光标处插入 [text]。
Future<void> _type(WidgetTester tester, String text) async {
  final state = tester.testTextInput.editingState!;
  final value = state['text'] as String;
  final caret = state['selectionBase'] as int;
  tester.testTextInput.updateEditingValue(
    TextEditingValue(
      text: '${value.substring(0, caret)}$text${value.substring(caret)}',
      selection: TextSelection.collapsed(offset: caret + text.length),
    ),
  );
  await tester.pumpAndSettle();
}

Future<FocusNode> _focus(
  WidgetTester tester,
  DiaryEditorController controller,
  af.Selection selection, {
  double width = 360,
}) async {
  final focus = FocusNode();
  addTearDown(focus.dispose);
  controller.select(selection);
  await _pump(tester, controller, focusNode: focus, width: width);
  focus.requestFocus();
  await tester.pumpAndSettle();
  return focus;
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

Future<void> _select(
  WidgetTester tester,
  DiaryEditorController controller,
  af.Path path, [
  int offset = 0,
]) async {
  controller.select(
    af.Selection.collapsed(af.Position(path: path, offset: offset)),
  );
  await tester.pumpAndSettle();
}

af.Node _tableNode(DiaryEditorController controller, [int index = 0]) =>
    controller.document.root.children.elementAt(index);

void _expectValid(af.Node table) =>
    expect(DiaryTableGrid.of(table.toJson()), isNotNull);

/// 正文 [text] 所在的那段 span 的字重（上游把块样式并进每一段 span，根
/// span 只是默认样式）。
FontWeight? _weightOf(WidgetTester tester, String text) {
  final rich = tester.widget<RichText>(
    find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText() == text,
    ),
  );
  FontWeight? weight;
  rich.text.visitChildren((span) {
    if (span is TextSpan && span.text == text) {
      weight = span.style?.fontWeight;
      return false;
    }
    return true;
  });
  return weight;
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'table fills the width with equal columns, header fill and bold '
      '($brightness)',
      (tester) async {
        final controller = _document([_paragraph('intro'), _table(2, 3)]);
        await _pump(tester, controller, brightness: brightness);
        final scheme = Theme.of(
          tester.element(find.byType(DiaryEditor)),
        ).colorScheme;

        final table = find.byType(DiaryTableBlock);
        expect(table, findsOneWidget);
        final cells = find.byType(DiaryTableCellBlock);
        expect(cells, findsNWidgets(6));
        final widths = [
          for (var i = 0; i < 3; i++) tester.getSize(cells.at(i)).width,
        ];
        expect(widths[0], closeTo(widths[1], 1));
        expect(widths[1], closeTo(widths[2], 1));
        // 整行铺满：表格宽度 = 编辑器宽度 - 左右各 16 的内边距。
        final outer = tester.getRect(
          find.descendant(
            of: table,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Container &&
                  widget.decoration is BoxDecoration &&
                  (widget.decoration! as BoxDecoration).borderRadius != null,
            ),
          ),
        );
        expect(outer.width, closeTo(360 - 32, 1));
        final decoration =
            tester
                    .widget<Container>(
                      find.descendant(
                        of: table,
                        matching: find.byWidgetPredicate(
                          (widget) =>
                              widget is Container &&
                              widget.decoration is BoxDecoration &&
                              (widget.decoration! as BoxDecoration)
                                      .borderRadius !=
                                  null,
                        ),
                      ),
                    )
                    .decoration!
                as BoxDecoration;
        expect(decoration.borderRadius, BorderRadius.circular(8));
        expect(decoration.border!.top.color, scheme.outlineVariant);
        expect(decoration.border!.top.width, 1);

        // 表头行底色与加粗；第二行不加粗、不写进正文。
        final header = tester.widget<ColoredBox>(
          find.descendant(of: table, matching: find.byType(ColoredBox)).first,
        );
        expect(header.color, scheme.surfaceContainerHigh);
        expect(_weightOf(tester, 'r0c0'), FontWeight.w700);
        expect(_weightOf(tester, 'r1c0'), isNot(FontWeight.w700));
        expect(controller.document.nodeAtPath([1, 0, 0])!.delta!.toJson(), [
          {'insert': 'r0c0'},
        ]);
        // 不横向滚动：表格子树里没有任何 Scrollable。
        expect(
          find.descendant(of: table, matching: find.byType(Scrollable)),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a 12-column imported table renders read-only at 320dp', (
    tester,
  ) async {
    final controller = _document([
      _table(2, 12, headerRow: false),
    ], readOnly: true);
    await _pump(tester, controller, width: 320);
    expect(find.byType(DiaryTableBlock), findsOneWidget);
    expect(find.byType(DiaryTableCellBlock), findsNWidgets(24));
    expect(
      find.descendant(
        of: find.byType(DiaryTableBlock),
        matching: find.byType(ColoredBox),
      ),
      findsNothing,
    );
    final cell = tester.getSize(find.byType(DiaryTableCellBlock).first);
    expect(cell.width, closeTo((320 - 32 - 2) / 12, 1.5));
    expect(
      find.descendant(
        of: find.byType(DiaryTableBlock),
        matching: find.byType(Scrollable),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Enter adds a paragraph inside the cell, typing stays in it', (
    tester,
  ) async {
    final controller = _document([_table(2, 2)]);
    await _focus(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [0, 0, 0], offset: 4)),
    );
    await _type(tester, '\n');
    expect(controller.document.nodeAtPath([0, 0])!.children.length, 2);
    expect(controller.selection!.end.path, [0, 0, 1]);
    await _type(tester, 'ab');
    expect(
      controller.document.nodeAtPath([0, 0, 1])!.delta!.toPlainText(),
      'ab',
    );
    expect(controller.document.root.children.length, 1);
    _expectValid(_tableNode(controller));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Backspace and Delete never leave the cell', (tester) async {
    final controller = _document([
      _paragraph('before'),
      _table(
        1,
        2,
        extra: {
          (0, 0): ['second'],
        },
      ),
      _paragraph('after'),
    ]);
    await _focus(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [1, 0, 0])),
    );
    final before = controller.contentJson;
    await _key(tester, LogicalKeyboardKey.backspace);
    expect(controller.contentJson, before);
    expect(controller.selection!.end.path, [1, 0, 0]);

    // 最后一段末尾 Delete：不并进下一格。
    await _select(tester, controller, [1, 0, 1], 6);
    await _key(tester, LogicalKeyboardKey.delete);
    expect(controller.contentJson, before);

    // 第二段开头退格：并进同格的第一段。
    await _select(tester, controller, [1, 0, 1]);
    await _key(tester, LogicalKeyboardKey.backspace);
    expect(controller.document.nodeAtPath([1, 0])!.children.length, 1);
    expect(
      controller.document.nodeAtPath([1, 0, 0])!.delta!.toPlainText(),
      'r0c0second',
    );
    expect(controller.selection!.end, af.Position(path: [1, 0, 0], offset: 4));
    controller.undo();
    await tester.pumpAndSettle();
    expect(controller.contentJson, before);

    // 第一段末尾 Delete：把同格的第二段并进来。
    await _select(tester, controller, [1, 0, 0], 4);
    await _key(tester, LogicalKeyboardKey.delete);
    expect(
      controller.document.nodeAtPath([1, 0, 0])!.delta!.toPlainText(),
      'r0c0second',
    );
    _expectValid(_tableNode(controller, 1));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('Tab moves between cells and appends a row at the end', (
    tester,
  ) async {
    final controller = _document([_table(2, 2)]);
    await _focus(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [0, 0, 0], offset: 2)),
    );
    await _key(tester, LogicalKeyboardKey.tab);
    expect(controller.selection!.end, af.Position(path: [0, 1, 0]));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pumpAndSettle();
    expect(controller.selection!.end, af.Position(path: [0, 0, 0]));
    // 格子里没有因 Tab 产生缩进。
    expect(controller.document.nodeAtPath([0, 0])!.children.length, 1);

    await _select(tester, controller, [0, 3, 0], 4);
    await _key(tester, LogicalKeyboardKey.tab);
    final grid = DiaryTableGrid.of(_tableNode(controller).toJson())!;
    expect((grid.rows, grid.cols), (3, 2));
    expect(controller.selection!.end, af.Position(path: [0, 4, 0]));
    controller.undo();
    await tester.pumpAndSettle();
    expect(DiaryTableGrid.of(_tableNode(controller).toJson())!.rows, 2);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('arrow keys cross cell borders and leave the table', (
    tester,
  ) async {
    final controller = _document([
      _paragraph('before'),
      _table(2, 2),
      _paragraph('after'),
    ]);
    await _focus(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [1, 0, 0], offset: 4)),
    );
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(controller.selection!.end, af.Position(path: [1, 1, 0]));
    await _key(tester, LogicalKeyboardKey.arrowLeft);
    expect(controller.selection!.end, af.Position(path: [1, 0, 0], offset: 4));

    await _select(tester, controller, [1, 0, 0]);
    await _key(tester, LogicalKeyboardKey.arrowLeft);
    expect(controller.selection!.end, af.Position(path: [0], offset: 6));

    await _select(tester, controller, [1, 3, 0], 4);
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(controller.selection!.end, af.Position(path: [2]));

    await _select(tester, controller, [1, 1, 0], 2);
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(controller.selection!.end, af.Position(path: [1, 3, 0], offset: 2));
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(controller.selection!.end.path, [2]);

    await _select(tester, controller, [1, 2, 0], 3);
    await _key(tester, LogicalKeyboardKey.arrowUp);
    expect(controller.selection!.end, af.Position(path: [1, 0, 0], offset: 3));
    await _key(tester, LogicalKeyboardKey.arrowUp);
    expect(controller.selection!.end.path, [0]);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('markdown shortcuts stay literal inside a cell', (tester) async {
    final controller = _document([_table(1, 1)]);
    await _focus(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [0, 0, 0])),
    );
    await _type(tester, '#');
    await _type(tester, ' ');
    var node = controller.document.nodeAtPath([0, 0, 0])!;
    expect(node.type, 'paragraph');
    expect(node.delta!.toPlainText(), '# r0c0');
    _expectValid(_tableNode(controller));

    // `--` 后再打 `-`：上游会换成分隔线，格子里按原文。
    final dashes = _document([
      {
        'type': 'table',
        'data': {'rowsLen': 1, 'colsLen': 1},
        'children': [
          {
            'type': 'table/cell',
            'data': {'rowPosition': 0, 'colPosition': 0},
            'children': [_paragraph('--')],
          },
        ],
      },
    ]);
    await _focus(
      tester,
      dashes,
      af.Selection.collapsed(af.Position(path: [0, 0, 0], offset: 2)),
    );
    await _type(tester, '-');
    node = dashes.document.nodeAtPath([0, 0, 0])!;
    expect(node.type, 'paragraph');
    expect(node.delta!.toPlainText(), '---');
    expect(dashes.document.nodeAtPath([0, 0])!.children.length, 1);
    _expectValid(_tableNode(dashes));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the soft keyboard interceptor applies the same backspace rule', (
    tester,
  ) async {
    final controller = _document([
      _paragraph('before'),
      _table(
        1,
        1,
        extra: {
          (0, 0): ['second'],
        },
      ),
    ]);
    final interceptor = DiaryTableKeyboardInterceptor();
    TextEditingDeltaDeletion deletion() => TextEditingDeltaDeletion(
      oldText: 'x',
      deletedRange: const TextRange.collapsed(0),
      selection: const TextSelection.collapsed(offset: 0),
      composing: TextRange.empty,
    );
    controller.select(af.Selection.collapsed(af.Position(path: [1, 0, 0])));
    final before = controller.contentJson;
    expect(
      await interceptor.interceptDelete(deletion(), controller.state),
      isTrue,
    );
    expect(controller.contentJson, before);

    controller.select(af.Selection.collapsed(af.Position(path: [1, 0, 1])));
    expect(
      await interceptor.interceptDelete(deletion(), controller.state),
      isTrue,
    );
    expect(
      controller.document.nodeAtPath([1, 0, 0])!.delta!.toPlainText(),
      'r0c0second',
    );

    // 段内的字符删除交给上游。
    controller.select(
      af.Selection.collapsed(af.Position(path: [1, 0, 0], offset: 2)),
    );
    expect(
      await interceptor.interceptDelete(
        TextEditingDeltaDeletion(
          oldText: 'r0c0second',
          deletedRange: const TextRange(start: 1, end: 2),
          selection: const TextSelection.collapsed(offset: 1),
          composing: TextRange.empty,
        ),
        controller.state,
      ),
      isFalse,
    );
    _expectValid(_tableNode(controller, 1));
  });

  testWidgets(
    'the block handle targets the whole table, drops never enter it',
    (tester) async {
      final controller = _document([
        _paragraph('before'),
        _table(2, 2),
        _paragraph('after'),
      ]);
      await _focus(
        tester,
        controller,
        af.Selection.collapsed(af.Position(path: [1, 2, 0], offset: 1)),
      );
      final handle = tester.widget<DiaryBlockHandle>(
        find.byType(DiaryBlockHandle),
      );
      expect(handle.node.type, 'table');
      expect(handle.node.path, [1]);

      final root = controller.document.root;
      final after = controller.document.nodeAtPath([2])!;
      final gaps = DiaryBlockGaps(root, after);
      expect(gaps.blocks.map((node) => node.type), ['paragraph', 'table']);
      // 手指落在表格各处：落点只能是表格之前或之后，不进格子。
      final rect = _tableNode(controller, 1).rect;
      for (final dy in [rect.top + 2, rect.center.dy, rect.bottom - 2]) {
        final destination = resolveDiaryBlockDrop(root, after, dy, depth: 1);
        expect(destination, anyOf(isNull, hasLength(1)), reason: '$dy');
      }
      // 上移 / 下移整个表格。
      final table = _tableNode(controller, 1);
      expect(DiaryBlockGaps(root, table).step(up: true), [0]);
      expect(moveDiaryEditorBlock(controller, table, [0]), isTrue);
      expect(controller.document.root.children.map((node) => node.type), [
        'table',
        'paragraph',
        'paragraph',
      ]);
      _expectValid(_tableNode(controller));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('/ menu finds the table and inserts it', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    final commands = diaryBlockCommands(l10n);
    for (final query in ['table', 'grid', '表格', 'biaoge', 'bg']) {
      expect(
        commands.where((command) => command.matches(query)).map((c) => c.type),
        contains('table'),
        reason: query,
      );
    }
    final table = commands.singleWhere((c) => c.type == 'table');
    expect(table.label, '表格');
    expect(table.group, DiaryBlockCommandGroup.insert);

    final controller = _document([_paragraph('')]);
    controller.select(af.Selection.collapsed(af.Position(path: [0])));
    applyDiaryBlockCommand(controller, table);
    expect(controller.document.root.children.single.type, 'table');
    final grid = DiaryTableGrid.of(_tableNode(controller).toJson())!;
    expect((grid.rows, grid.cols, grid.headerRow), (3, 3, true));
    expect(controller.selection!.end.path, [0, 0, 0]);
  });
}

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}
