import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_table.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_block_reorder.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_clipboard.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/providers/diary_code_block_style_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_block_handle.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_table_block.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_toggle_block.dart';

import '../../../support/expressive_test_theme.dart';

/// 折叠块与表格、粘贴的相互作用：展开的折叠块里的表格照常渲染、随折叠块
/// 收起 / 展开 / 撤销仍是有效网格；拖动收起的折叠块连同里面的表格一起
/// 移动、表格内部没有缝；粘进格子的 Markdown 与 HTML 都只留成格内段落。

Map<String, Object?> _p(String text) => {
  'type': 'paragraph',
  'data': {
    'delta': [
      if (text.isNotEmpty) {'insert': text},
    ],
  },
};

Map<String, Object?> _toggle(
  String text, {
  bool collapsed = false,
  List<Map<String, Object?>> children = const [],
}) => {
  'type': 'toggle_list',
  'data': {
    'delta': [
      {'insert': text},
    ],
    if (collapsed) 'collapsed': true,
  },
  if (children.isNotEmpty) 'children': children,
};

Map<String, Object?> _table(int rows, int cols) => {
  'type': 'table',
  'data': {'rowsLen': rows, 'colsLen': cols, 'headerRow': true},
  'children': [
    for (var row = 0; row < rows; row++)
      for (var col = 0; col < cols; col++)
        {
          'type': 'table/cell',
          'data': {'rowPosition': row, 'colPosition': col},
          'children': [_p('r${row}c$col')],
        },
  ],
};

DiaryEditorController _document(List<Map<String, Object?>> blocks) =>
    DiaryEditorController.fromContent(
      jsonEncode({
        'document': {'type': 'page', 'children': blocks},
      }),
    );

Future<void> _pump(
  WidgetTester tester,
  DiaryEditorController controller, {
  FocusNode? focusNode,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [diaryCodeBlockStyleProvider.overrideWith(() => _CodeStyle())],
      child: MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
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

/// 每块一行：层级缩进 + 类型 + 文字（+ 收起标记）。
String _outline(DiaryEditorController controller) => [
  for (final node in walkDiaryEditorNodes(controller.document))
    '${'  ' * (node.path.length - 1)}${node.type} '
        '${node.delta?.toPlainText() ?? ''}'
        '${node.attributes['collapsed'] == true ? ' [collapsed]' : ''}',
].join('\n');

af.Node _firstOfType(DiaryEditorController controller, String type) =>
    walkDiaryEditorNodes(
      controller.document,
    ).firstWhere((node) => node.type == type);

void _expectValidGrid(af.Node table) => expect(
  DiaryTableGrid.of(
    jsonDecode(jsonEncode(table.toJson())) as Map<String, Object?>,
  ),
  isNotNull,
);

/// 格子里各段的文字。
List<String> _cellTexts(af.Node cell) => [
  for (final paragraph in cell.children) paragraph.delta!.toPlainText(),
];

Finder _text(String text) => find.byWidgetPredicate(
  (widget) => widget is RichText && widget.text.toPlainText() == text,
);

void main() {
  String? clipboardText;
  setUp(() {
    clipboardText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String?;
          }
          if (call.method == 'Clipboard.getData') {
            return {'text': clipboardText};
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('pasteboard'),
          (_) async => null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('pasteboard'), null);
  });

  testWidgets('a table inside a toggle renders, collapses with it and stays '
      'a valid grid after collapse, expand and undo', (tester) async {
    final controller = _document([
      _toggle('fold', children: [_p('intro'), _table(2, 2)]),
      _p('after'),
    ]);
    addTearDown(controller.dispose);
    controller.select(af.Selection.collapsed(af.Position(path: [1])));
    final before = controller.contentJson;
    await _pump(tester, controller);

    expect(find.byType(DiaryTableBlock), findsOneWidget);
    expect(find.byType(DiaryTableCellBlock), findsNWidgets(4));
    expect(_text('r1c1'), findsOneWidget);

    await tester.tap(find.byType(DiaryToggleMarker));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryTableBlock), findsNothing);
    expect(_text('r1c1'), findsNothing);
    _expectValidGrid(_firstOfType(controller, 'table'));

    await tester.tap(find.byType(DiaryToggleMarker));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryTableBlock), findsOneWidget);
    expect(find.byType(DiaryTableCellBlock), findsNWidgets(4));
    _expectValidGrid(_firstOfType(controller, 'table'));

    controller.undo();
    await tester.pumpAndSettle();
    expect(find.byType(DiaryTableBlock), findsNothing);
    _expectValidGrid(_firstOfType(controller, 'table'));
    controller.undo();
    await tester.pumpAndSettle();
    expect(controller.contentJson, before);
    expect(find.byType(DiaryTableBlock), findsOneWidget);
    _expectValidGrid(_firstOfType(controller, 'table'));
    expect(tester.takeException(), isNull);
  });

  test('gaps skip a collapsed toggle with a table, and never open inside a '
      'table in an expanded one', () {
    final controller = _document([
      _toggle('open', children: [_table(2, 2)]),
      _toggle('fold', collapsed: true, children: [_table(2, 2)]),
      _p('moving'),
    ]);
    addTearDown(controller.dispose);
    final moving = controller.document.nodeAtPath([2])!;
    final gaps = DiaryBlockGaps(controller.document.root, moving);
    expect(gaps.blocks.map((node) => node.type), [
      'toggle_list',
      'table',
      'toggle_list',
    ]);
  });

  testWidgets('dragging a collapsed toggle carries the table inside it', (
    tester,
  ) async {
    final focus = FocusNode();
    final controller = _document([
      _toggle('fold', collapsed: true, children: [_table(2, 2)]),
      _p('next'),
      _p('last'),
    ]);
    final before = controller.contentJson;
    controller.select(af.Selection.collapsed(af.Position(path: [0])));
    await _pump(tester, controller, focusNode: focus);
    focus.requestFocus();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final next = tester.getRect(_text('next'));
    final start = tester.getCenter(find.byType(DiaryBlockHandle));
    final gesture = await tester.startGesture(start);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    final travel = next.bottom - 2 - start.dy;
    for (var step = 1; step <= 6; step++) {
      await gesture.moveTo(start + Offset(0, travel * step / 6));
      await tester.pump();
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();

    expect(
      _outline(controller),
      'paragraph next\n'
      'toggle_list fold [collapsed]\n'
      '  table \n'
      '    table/cell \n'
      '      paragraph r0c0\n'
      '    table/cell \n'
      '      paragraph r0c1\n'
      '    table/cell \n'
      '      paragraph r1c0\n'
      '    table/cell \n'
      '      paragraph r1c1\n'
      'paragraph last',
    );
    _expectValidGrid(_firstOfType(controller, 'table'));
    expect(find.byType(DiaryTableBlock), findsNothing);
    controller.undo();
    await tester.pump();
    expect(controller.contentJson, before);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
    controller.dispose();
    focus.dispose();
  });

  group('pasting into a table cell', () {
    DiaryEditorController inCell() {
      final controller = _document([_table(2, 2), _p('after')]);
      addTearDown(controller.dispose);
      final paragraph = controller.document.nodeAtPath([0, 0, 0])!;
      controller.select(
        af.Selection.collapsed(
          af.Position(path: paragraph.path, offset: paragraph.delta!.length),
        ),
      );
      return controller;
    }

    test('markdown with a pipe table lands as plain paragraphs', () async {
      final controller = inCell();
      clipboardText = '# 题\n| a | b |\n|---|---|\n| 1 | 2 |';
      await DiaryEditorClipboard.paste(controller);

      final table = _firstOfType(controller, 'table');
      _expectValidGrid(table);
      expect(
        walkDiaryEditorNodes(
          controller.document,
        ).where((node) => node.type == 'table'),
        hasLength(1),
      );
      final cell = table.children.first;
      expect(cell.children.every((node) => node.type == 'paragraph'), isTrue);
      expect(_cellTexts(cell), [
        'r0c0# 题',
        '| a | b |',
        '|---|---|',
        '| 1 | 2 |',
      ]);
      expect(controller.document.root.children, hasLength(2));
    });

    test(
      'HTML with a heading, list and table flattens to paragraphs',
      () async {
        final controller = inCell();
        await DiaryEditorClipboard.pasteHtml(
          controller,
          '<h1>题</h1><ul><li>项</li></ul>'
          '<table><tr><th>a</th><th>b</th></tr><tr><td>1</td><td>2</td></tr>'
          '</table>',
        );

        final table = _firstOfType(controller, 'table');
        _expectValidGrid(table);
        expect(
          walkDiaryEditorNodes(
            controller.document,
          ).where((node) => node.type == 'table'),
          hasLength(1),
        );
        final cell = table.children.first;
        expect(cell.children.every((node) => node.type == 'paragraph'), isTrue);
        expect(cell.children.every((node) => node.children.isEmpty), isTrue);
        expect(_cellTexts(cell).first, 'r0c0题');
        expect(_cellTexts(cell).skip(1), containsAllInOrder(['项', 'a', '2']));
        expect(controller.document.root.children, hasLength(2));
      },
    );

    test('an app snapshot with a toggle and a table flattens too', () async {
      final controller = _document([
        _toggle('fold', children: [_p('inner')]),
        _table(1, 2),
      ]);
      addTearDown(controller.dispose);
      controller.select(
        af.Selection(
          start: af.Position(path: [0]),
          end: af.Position(path: [0, 0], offset: 5),
        ),
      );
      await DiaryEditorClipboard.copy(controller);
      final paragraph = controller.document.nodeAtPath([1, 1, 0])!;
      controller.select(
        af.Selection.collapsed(
          af.Position(path: paragraph.path, offset: paragraph.delta!.length),
        ),
      );
      await DiaryEditorClipboard.paste(controller);

      final table = controller.document.nodeAtPath([1])!;
      _expectValidGrid(table);
      final cell = table.children.last;
      expect(cell.children.every((node) => node.type == 'paragraph'), isTrue);
      expect(_cellTexts(cell), ['r0c1fold', 'inner']);
    });
  });
}

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}
