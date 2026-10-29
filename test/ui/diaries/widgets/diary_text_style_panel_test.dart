import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:node_diary/ui/diaries/widgets/diary_text_style/diary_text_style_panel.dart';
import 'package:node_diary/ui/diaries/widgets/diary_text_style/diary_text_style_panels.dart';

import '../../../support/diary_color_panel_harness.dart';
import '../../../support/diary_content_test_helpers.dart';

/// 悬浮工具栏的标题、对齐、字号工具与卡片内的三块面板：点工具开合面板、
/// 选一档写进正文（一步撤销）、面板保持打开、代码块里停用；320dp 窄屏下
/// 一排放得下。
const String _headingTool = '标题样式';
const String _alignTool = '对齐';
const String _fontSizeTool = '字号';

/// 三个工具排在最前，360dp 与 320dp 下都常驻在工具栏一排上。
final List<DiaryToolbarItem> _textStyleFirstOrder = <DiaryToolbarItem>[
  DiaryToolbarItem.headerStyle,
  DiaryToolbarItem.align,
  DiaryToolbarItem.fontSize,
  for (final item in kDefaultDiaryToolbarOrder)
    if (item != DiaryToolbarItem.headerStyle &&
        item != DiaryToolbarItem.align &&
        item != DiaryToolbarItem.fontSize)
      item,
];

/// 正文：两个段落 `first` / `second` 与一个代码块 `x = 1`。
DiaryEditorController _controller() {
  final controller = DiaryEditorController.fromContent(
    jsonEncode({
      'document': {
        'type': 'page',
        'children': [
          {
            'type': 'paragraph',
            'data': {
              'delta': [
                {'insert': 'first'},
              ],
            },
          },
          {
            'type': 'paragraph',
            'data': {
              'delta': [
                {'insert': 'second'},
              ],
            },
          },
          {
            'type': 'code',
            'data': {
              'delta': [
                {'insert': 'x = 1'},
              ],
            },
          },
        ],
      },
    }),
  );
  addTearDown(controller.dispose);
  return controller;
}

/// 选中两个段落（从 first 开头到 second 末尾）。
af.Selection _bothParagraphs() => af.Selection(
  start: af.Position(path: [0]),
  end: af.Position(path: [1], offset: 6),
);

Future<ColorPanelHarness> _pump(
  WidgetTester tester,
  DiaryEditorController controller, {
  double screenWidth = 360,
  Locale locale = const Locale('zh'),
}) async {
  final harness = await pumpColorPanel(
    tester,
    controller: controller,
    order: _textStyleFirstOrder,
    screenWidth: screenWidth,
    locale: locale,
  );
  harness.editorFocus.requestFocus();
  await tester.pumpAndSettle();
  return harness;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// 面板里名为 [label] 的一段是否选中（按钮组用 Semantics(selected:) 标出）。
bool _segmentSelected(WidgetTester tester, Finder label) {
  final semantics = tester.widget<Semantics>(
    find
        .ancestor(
          of: label,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.inMutuallyExclusiveGroup == true,
          ),
        )
        .first,
  );
  return semantics.properties.selected ?? false;
}

Finder _panelText(String text) => find.descendant(
  of: find.byWidgetPredicate((widget) => widget is DiaryTextStylePanel),
  matching: find.text(text),
);

Finder _panelTooltip(String text) => find.descendant(
  of: find.byWidgetPredicate((widget) => widget is DiaryTextStylePanel),
  matching: find.byTooltip(text),
);

af.Node _node(DiaryEditorController controller, int index) =>
    controller.document.root.children.elementAt(index);

void main() {
  setUpAll(loadColorPanelFonts);

  testWidgets('heading panel sets H5 on the selection and back to body', (
    tester,
  ) async {
    final controller = _controller();
    final harness = await _pump(tester, controller);
    controller.select(_bothParagraphs());
    await tester.pumpAndSettle();
    final pushes = harness.routes.pushes;

    await _tap(tester, find.byTooltip(_headingTool));
    expect(find.byType(DiaryHeadingPanel), findsOneWidget);
    expect(harness.extents.last, greaterThan(0));
    expect(_segmentSelected(tester, _panelText('正文')), isTrue);

    await _tap(tester, _panelText('H5'));
    for (final index in [0, 1]) {
      expect(_node(controller, index).type, 'heading');
      expect(_node(controller, index).attributes['level'], 5);
    }
    expect(_node(controller, 2).type, 'code');
    // 面板保持打开，选中刚选的一级。
    expect(find.byType(DiaryHeadingPanel), findsOneWidget);
    expect(_segmentSelected(tester, _panelText('H5')), isTrue);
    expect(_segmentSelected(tester, _panelText('正文')), isFalse);

    await _tap(tester, _panelText('正文'));
    expect(_node(controller, 0).type, 'paragraph');
    expect(_node(controller, 1).type, 'paragraph');

    // 一次一步撤销：撤回“转为正文”，回到五级标题。
    controller.undo();
    await tester.pumpAndSettle();
    expect(_node(controller, 0).type, 'heading');
    expect(_node(controller, 0).attributes['level'], 5);

    expect(harness.routes.pushes, pushes);
    expect(harness.editorFocus.hasFocus, isTrue);

    // 再点工具收起。
    await _tap(tester, find.byTooltip(_headingTool));
    expect(find.byType(DiaryHeadingPanel), findsNothing);
    expect(harness.extents.last, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('heading panel is disabled while the caret is in code', (
    tester,
  ) async {
    final controller = _controller();
    await _pump(tester, controller);
    controller.select(af.Selection.collapsed(af.Position(path: [2])));
    await tester.pumpAndSettle();

    await _tap(tester, find.byTooltip(_headingTool));
    final before = controller.contentJson;
    await _tap(tester, _panelText('H2'));
    expect(controller.contentJson, before);
    expect(find.byType(DiaryHeadingPanel), findsOneWidget);
  });

  testWidgets('align panel writes center, left removes the key, one undo', (
    tester,
  ) async {
    final controller = _controller();
    await _pump(tester, controller);
    controller.select(_bothParagraphs());
    await tester.pumpAndSettle();

    await _tap(tester, find.byTooltip(_alignTool));
    expect(find.byType(DiaryAlignPanel), findsOneWidget);

    await _tap(tester, _panelTooltip('居中'));
    expect(_node(controller, 0).attributes['align'], 'center');
    expect(_node(controller, 1).attributes['align'], 'center');
    expect(_node(controller, 2).attributes.containsKey('align'), isFalse);
    // 工具栏上的对齐按钮换成居中图标。
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('diary-toolbar-tool-align')),
        matching: find.byIcon(FontAwesomeIcons.alignCenter.data),
      ),
      findsOneWidget,
    );

    await _tap(tester, _panelTooltip('左对齐'));
    expect(_node(controller, 0).attributes.containsKey('align'), isFalse);
    expect(_node(controller, 1).attributes.containsKey('align'), isFalse);

    controller.undo();
    await tester.pumpAndSettle();
    expect(_node(controller, 0).attributes['align'], 'center');
    expect(_node(controller, 1).attributes['align'], 'center');
    expect(tester.takeException(), isNull);
  });

  testWidgets('font size on a range writes size large in one undo step', (
    tester,
  ) async {
    final controller = _controller();
    await _pump(tester, controller);
    controller.select(_bothParagraphs());
    await tester.pumpAndSettle();
    final before = controller.contentJson;

    await _tap(tester, find.byTooltip(_fontSizeTool));
    expect(_segmentSelected(tester, _panelTooltip('正文')), isTrue);

    await _tap(tester, _panelTooltip('大'));
    for (final index in [0, 1]) {
      final ops = _node(controller, index).delta!.toList();
      expect(ops.single.attributes, {'size': 'large'});
    }
    // 代码块不受影响。
    expect(_node(controller, 2).delta!.toList().single.attributes, isNull);
    expect(_segmentSelected(tester, _panelTooltip('大')), isTrue);

    controller.undo();
    await tester.pumpAndSettle();
    expect(controller.contentJson, before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('font size on a caret applies to the text typed next', (
    tester,
  ) async {
    final controller = _controller();
    await _pump(tester, controller);
    controller.select(
      af.Selection.collapsed(af.Position(path: [0], offset: 5)),
    );
    await tester.pumpAndSettle();

    await _tap(tester, find.byTooltip(_fontSizeTool));
    await _tap(tester, _panelTooltip('特大'));
    expect(_segmentSelected(tester, _panelTooltip('特大')), isTrue);

    final state = tester.testTextInput.editingState!;
    final text = state['text'] as String;
    final caret = state['selectionBase'] as int;
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: '${text.substring(0, caret)}!${text.substring(caret)}',
        selection: TextSelection.collapsed(offset: caret + 1),
      ),
    );
    await tester.pumpAndSettle();

    final ops = _node(controller, 0).delta!.toList();
    expect(ops.last.attributes, {'size': 'huge'});
    expect((ops.last as af.TextInsert).text, '!');
    expect(ops.first.attributes, isNull);
    expect(tester.takeException(), isNull);
  });

  for (final locale in [const Locale('zh'), const Locale('en')]) {
    testWidgets('text style panels fit one row at 320dp ($locale)', (
      tester,
    ) async {
      final controller = _controller();
      await _pump(tester, controller, screenWidth: 320, locale: locale);
      controller.select(_bothParagraphs());
      await tester.pumpAndSettle();
      final tools = [
        DiaryToolbarItem.headerStyle,
        DiaryToolbarItem.align,
        DiaryToolbarItem.fontSize,
      ];
      for (final tool in tools) {
        await _tap(
          tester,
          find.byKey(ValueKey('diary-toolbar-tool-${tool.storageKey}')),
        );
        final panel = find.byWidgetPredicate(
          (widget) => widget is DiaryTextStylePanel,
        );
        expect(panel, findsOneWidget);
        expect(tester.getSize(panel).height, kDiaryTextStylePanelHeight);
        // 按钮组横排一行：每段的顶边一致。
        final buttons = find.descendant(
          of: panel,
          matching: find.byType(FilledButton),
        );
        final tops = {
          for (final element in buttons.evaluate())
            tester.getTopLeft(find.byWidget(element.widget)).dy,
        };
        expect(tops, hasLength(1));
        expect(tester.takeException(), isNull);
      }
    });
  }
}
