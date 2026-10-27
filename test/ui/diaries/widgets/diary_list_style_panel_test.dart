import '../../../support/diary_content_test_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_list_style.dart';
import 'package:node_diary/ui/diaries/widgets/diary_list_style/diary_list_style_panel.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:node_diary/ui/diaries/widgets/diary_toolbar_more_panel.dart';

import '../../../support/diary_color_panel_harness.dart';

/// 悬浮工具栏的列表工具与卡片内的列表面板：列表外转为列表、列表里开合
/// 面板、选样式整段生效、转为另一种列表时面板跟着换、转为正文与离开列表时
/// 收起；全程不推路由、正文保持焦点。
const String _orderedTool = '有序列表';
const String _bulletTool = '无序列表';

/// 两个列表工具排在最前，360dp 下常驻在工具栏一排上。
final List<DiaryToolbarItem> _listFirstOrder = <DiaryToolbarItem>[
  DiaryToolbarItem.orderedList,
  DiaryToolbarItem.bulletList,
  for (final item in kDefaultDiaryToolbarOrder)
    if (item != DiaryToolbarItem.orderedList &&
        item != DiaryToolbarItem.bulletList)
      item,
];

/// 正文：`intro` / 有序列表 `one`、`two`、`three` / `after`。
///
/// 偏移：intro 0–5，one 6–9，two 10–13，three 14–19，after 20–25。
DiaryEditorController _listController({int caret = 7}) {
  const ordered = <String, dynamic>{
    'insert': '\n',
    'attributes': <String, dynamic>{'list': 'ordered'},
  };
  final controller = DiaryEditorController(
    document: documentFromLegacyDelta(<Map<String, dynamic>>[
      <String, dynamic>{'insert': 'intro\none'},
      ordered,
      <String, dynamic>{'insert': 'two'},
      ordered,
      <String, dynamic>{'insert': 'three'},
      ordered,
      <String, dynamic>{'insert': 'after\n'},
    ]),
  );
  controller.updateSelection(TextSelection.collapsed(offset: caret));
  addTearDown(controller.dispose);
  return controller;
}

/// 顶层各块的类型与列表样式值。
List<(String, Object?)> _blocks(DiaryEditorController controller) => [
  for (final node in controller.document.root.children)
    (node.type, node.attributes[kDiaryListStyleKey]),
];

Future<ColorPanelHarness> _pump(
  WidgetTester tester,
  DiaryEditorController controller,
) async {
  final harness = await pumpColorPanel(
    tester,
    controller: controller,
    order: _listFirstOrder,
  );
  harness.editorFocus.requestFocus();
  await tester.pumpAndSettle();
  return harness;
}

/// 正文里的序号（面板的样式格子里也画着同样的序号）。
Finder _marker(String label) =>
    find.descendant(of: find.byType(DiaryEditor), matching: find.text(label));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// 样式格子是否为选中态（格子用 Semantics(selected:) 标出）。
bool _tileSelected(WidgetTester tester, String label) {
  final semantics = tester.widget<Semantics>(
    find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == label,
    ),
  );
  return semantics.properties.selected ?? false;
}

void main() {
  setUpAll(loadColorPanelFonts);

  testWidgets('outside a list the tool converts the line, no panel', (
    tester,
  ) async {
    final controller = _listController(caret: 2);
    final harness = await _pump(tester, controller);

    await _tap(tester, find.byTooltip(_orderedTool));

    expect(controller.document.root.children.first.type, 'numbered_list');
    expect(find.byType(DiaryListStylePanel), findsNothing);
    expect(harness.extents.where((extent) => extent > 0), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inside a list the tool opens the panel, again closes', (
    tester,
  ) async {
    final harness = await _pump(tester, _listController());
    final pushes = harness.routes.pushes;

    await _tap(tester, find.byTooltip(_orderedTool));

    expect(find.byType(DiaryListStylePanel), findsOneWidget);
    expect(find.text('有序列表样式'), findsOneWidget);
    // 360dp：9 个格子排成 5 + 4 两行。
    final innerWidth = 360 - 2 * 12 - 2 * kDiaryToolbarHorizontalPadding;
    expect(diaryListStyleGrid(innerWidth, 'numbered_list'), (
      columns: 5,
      rows: 2,
    ));
    expect(
      harness.extents.last,
      kDiaryToolbarPanelChrome +
          diaryListStylePanelHeight(innerWidth, 'numbered_list'),
    );
    expect(_tileSelected(tester, '自动（按层级变化）'), isTrue);
    expect(harness.routes.pushes, pushes);
    expect(harness.editorFocus.hasFocus, isTrue);

    await _tap(tester, find.byTooltip(_orderedTool));
    expect(find.byType(DiaryListStylePanel), findsNothing);
    expect(harness.extents.last, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a style applies to the whole list and stays open', (
    tester,
  ) async {
    final controller = _listController();
    await _pump(tester, controller);
    await _tap(tester, find.byTooltip(_orderedTool));

    await _tap(tester, find.byTooltip('小写字母 a. b. c.'));

    expect(_blocks(controller), [
      ('paragraph', null),
      ('numbered_list', 'lower-alpha'),
      ('numbered_list', 'lower-alpha'),
      ('numbered_list', 'lower-alpha'),
      ('paragraph', null),
    ]);
    expect(_marker('a.'), findsOneWidget);
    expect(_marker('c.'), findsOneWidget);
    expect(find.byType(DiaryListStylePanel), findsOneWidget);
    expect(_tileSelected(tester, '小写字母 a. b. c.'), isTrue);
    expect(_tileSelected(tester, '自动（按层级变化）'), isFalse);

    // 一步撤销。
    controller.undo();
    await tester.pumpAndSettle();
    expect(_blocks(controller)[1], ('numbered_list', null));
    expect(_marker('1.'), findsOneWidget);

    // 选“自动”删掉样式键。
    await _tap(tester, find.byTooltip('中文数字 一、二、三、'));
    expect(_marker('三、'), findsOneWidget);
    await _tap(tester, find.byTooltip('自动（按层级变化）'));
    expect(_blocks(controller)[3], ('numbered_list', null));
    expect(tester.takeException(), isNull);
  });

  testWidgets('converting to a bulleted list switches the panel', (
    tester,
  ) async {
    final controller = _listController();
    await _pump(tester, controller);
    await _tap(tester, find.byTooltip(_orderedTool));
    await _tap(tester, find.byTooltip('小写字母 a. b. c.'));

    await _tap(tester, find.text('转为无序列表'));

    expect(controller.document.root.children[1].type, 'bulleted_list');
    // 换类型时样式随之丢弃：有序的格式不会留在无序列表上。
    expect(_blocks(controller)[1], ('bulleted_list', null));
    expect(find.text('无序列表样式'), findsOneWidget);

    await _tap(tester, find.byTooltip('星形'));
    expect(_blocks(controller)[1], ('bulleted_list', 'star'));
    // 只转了光标所在的一项，其余两项仍是有序列表，样式不变。
    expect(_blocks(controller)[2], ('numbered_list', 'lower-alpha'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('转为正文 and leaving the list close the panel', (tester) async {
    final controller = _listController();
    final harness = await _pump(tester, controller);
    await _tap(tester, find.byTooltip(_bulletTool));
    // 光标在有序列表里，无序列表工具只是把这一项转为无序列表。
    expect(find.byType(DiaryListStylePanel), findsNothing);
    expect(controller.document.root.children[1].type, 'bulleted_list');

    await _tap(tester, find.byTooltip(_bulletTool));
    expect(find.text('无序列表样式'), findsOneWidget);
    await _tap(tester, find.text('转为正文'));
    expect(controller.document.root.children[1].type, 'paragraph');
    expect(find.byType(DiaryListStylePanel), findsNothing);
    expect(harness.extents.last, 0);

    controller.updateSelection(const TextSelection.collapsed(offset: 11));
    await tester.pumpAndSettle();
    await _tap(tester, find.byTooltip(_orderedTool));
    expect(find.byType(DiaryListStylePanel), findsOneWidget);
    controller.updateSelection(const TextSelection.collapsed(offset: 22));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryListStylePanel), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
