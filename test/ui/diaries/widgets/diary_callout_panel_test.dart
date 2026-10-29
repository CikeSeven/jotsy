import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/widgets/diary_callout/diary_callout_panel.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:node_diary/ui/diaries/widgets/diary_toolbar_more_panel.dart';

import '../../../support/diary_color_panel_harness.dart';
import '../../../support/diary_content_test_helpers.dart';

/// 悬浮工具栏的提示块工具与卡片内的提示块面板：不在提示块里时转为提示块、
/// 在时打开面板；选图标 / 底色一步撤销、默认值删键；「转为正文」收起；选区
/// 离开提示块时收起；320dp 窄屏不溢出；全程不推路由、正文保持焦点。
const String _calloutTool = '提示块';

/// 提示块工具排在最前，320dp 下也常驻在工具栏一排上。
final List<DiaryToolbarItem> _calloutFirstOrder = <DiaryToolbarItem>[
  DiaryToolbarItem.callout,
  for (final item in kDefaultDiaryToolbarOrder)
    if (item != DiaryToolbarItem.callout) item,
];

Map<String, Object?> _block(
  String type,
  String text, {
  Map<String, Object?> data = const {},
}) => {
  'type': type,
  'data': {
    'delta': [
      {'insert': text},
    ],
    ...data,
  },
};

/// 正文：段落 `intro`、两个提示块 `tip1` / `tip2`、代码块 `x = 1`。
DiaryEditorController _controller() {
  final controller = DiaryEditorController.fromContent(
    jsonEncode({
      'document': {
        'type': 'page',
        'children': [
          _block('paragraph', 'intro', data: {'align': 'center'}),
          _block('callout', 'tip1'),
          _block('callout', 'tip2', data: {'icon': '📌', 'tone': 'blue'}),
          _block('code', 'x = 1'),
        ],
      },
    }),
  );
  addTearDown(controller.dispose);
  return controller;
}

af.Node _node(DiaryEditorController controller, int index) =>
    controller.document.root.children.elementAt(index);

Future<ColorPanelHarness> _pump(
  WidgetTester tester,
  DiaryEditorController controller, {
  double screenWidth = 360,
  Locale locale = const Locale('zh'),
  List<DiaryToolbarItem>? order,
}) async {
  final harness = await pumpColorPanel(
    tester,
    controller: controller,
    order: order ?? _calloutFirstOrder,
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

Finder _inPanel(Finder finder) =>
    find.descendant(of: find.byType(DiaryCalloutPanel), matching: finder);

/// 面板里标签为 [label] 的选项是否选中（选项用 Semantics(selected:) 标出）。
bool _optionSelected(WidgetTester tester, String label) {
  final semantics = tester.widget<Semantics>(
    find
        .descendant(
          of: find.byType(DiaryCalloutPanel),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.button == true &&
                widget.properties.label == label,
          ),
        )
        .first,
  );
  return semantics.properties.selected ?? false;
}

void main() {
  setUpAll(loadColorPanelFonts);

  testWidgets('outside a callout the tool converts the paragraph, no panel', (
    tester,
  ) async {
    final controller = _controller();
    final harness = await _pump(tester, controller);
    await _select(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [0], offset: 2)),
    );
    final pushes = harness.routes.pushes;

    await _tap(tester, find.byTooltip(_calloutTool));

    final node = _node(controller, 0);
    expect(node.type, 'callout');
    expect(node.delta!.toPlainText(), 'intro');
    expect(node.attributes['align'], 'center');
    // 稀疏：默认图标与底色不写。
    expect(node.attributes.containsKey('icon'), isFalse);
    expect(node.attributes.containsKey('tone'), isFalse);
    expect(find.byType(DiaryCalloutPanel), findsNothing);
    expect(harness.extents.where((extent) => extent > 0), isEmpty);
    expect(harness.routes.pushes, pushes);
    expect(harness.editorFocus.hasFocus, isTrue);

    // 转换一步撤销。
    controller.undo();
    await tester.pumpAndSettle();
    expect(_node(controller, 0).type, 'paragraph');
    expect(tester.takeException(), isNull);
  });

  testWidgets('code blocks in the selection are not converted', (tester) async {
    final controller = _controller();
    await _pump(tester, controller);
    await _select(
      tester,
      controller,
      af.Selection(
        start: af.Position(path: [0]),
        end: af.Position(path: [3], offset: 2),
      ),
    );

    await _tap(tester, find.byTooltip(_calloutTool));

    expect(_node(controller, 0).type, 'callout');
    // 已有的提示块保留图标与底色，代码块不动。
    expect(_node(controller, 2).attributes['icon'], '📌');
    expect(_node(controller, 2).attributes['tone'], 'blue');
    expect(_node(controller, 3).type, 'code');
    expect(find.byType(DiaryCalloutPanel), findsNothing);

    // 现在选区里的文字块都是提示块：再点打开面板。
    await _tap(tester, find.byTooltip(_calloutTool));
    expect(find.byType(DiaryCalloutPanel), findsOneWidget);
  });

  testWidgets('inside a callout the tool opens the panel, again closes', (
    tester,
  ) async {
    final controller = _controller();
    final harness = await _pump(tester, controller);
    await _select(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [1], offset: 1)),
    );
    final pushes = harness.routes.pushes;

    await _tap(tester, find.byTooltip(_calloutTool));

    expect(find.byType(DiaryCalloutPanel), findsOneWidget);
    expect(
      harness.extents.last,
      kDiaryToolbarPanelChrome + kDiaryCalloutPanelHeight,
    );
    expect(
      tester.getSize(find.byType(DiaryCalloutPanel)).height,
      kDiaryCalloutPanelHeight,
    );
    expect(_inPanel(find.text('提示块')), findsOneWidget);
    expect(_optionSelected(tester, '💡'), isTrue);
    expect(_optionSelected(tester, '默认'), isTrue);
    expect(_optionSelected(tester, '红色'), isFalse);
    expect(harness.routes.pushes, pushes);
    expect(harness.editorFocus.hasFocus, isTrue);

    await _tap(tester, find.byTooltip(_calloutTool));
    expect(find.byType(DiaryCalloutPanel), findsNothing);
    expect(harness.extents.last, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('icon and tone apply to every callout, one undo step each', (
    tester,
  ) async {
    final controller = _controller();
    final harness = await _pump(tester, controller);
    await _select(
      tester,
      controller,
      af.Selection(
        start: af.Position(path: [1], offset: 1),
        end: af.Position(path: [2], offset: 2),
      ),
    );
    await _tap(tester, find.byTooltip(_calloutTool));
    // 两块取值不同：都不选中。
    expect(_optionSelected(tester, '💡'), isFalse);
    expect(_optionSelected(tester, '📌'), isFalse);

    await _tap(tester, _inPanel(find.text('⚠️')));
    for (final index in [1, 2]) {
      expect(_node(controller, index).attributes['icon'], '⚠️');
    }
    expect(_optionSelected(tester, '⚠️'), isTrue);

    await _tap(tester, _inPanel(find.byTooltip('红色')));
    for (final index in [1, 2]) {
      expect(_node(controller, index).attributes['tone'], 'red');
    }
    expect(_optionSelected(tester, '红色'), isTrue);
    // 面板保持打开，正文保持焦点。
    expect(find.byType(DiaryCalloutPanel), findsOneWidget);
    expect(harness.editorFocus.hasFocus, isTrue);

    // 一次一步撤销：先撤回底色（两块一起），再撤回图标。
    controller.undo();
    await tester.pumpAndSettle();
    expect(_node(controller, 1).attributes.containsKey('tone'), isFalse);
    expect(_node(controller, 2).attributes['tone'], 'blue');
    expect(_node(controller, 1).attributes['icon'], '⚠️');
    controller.undo();
    await tester.pumpAndSettle();
    expect(_node(controller, 1).attributes.containsKey('icon'), isFalse);
    expect(_node(controller, 2).attributes['icon'], '📌');
    expect(tester.takeException(), isNull);
  });

  testWidgets('default icon and tone remove the keys', (tester) async {
    final controller = _controller();
    await _pump(tester, controller);
    await _select(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [2], offset: 1)),
    );
    await _tap(tester, find.byTooltip(_calloutTool));
    expect(_optionSelected(tester, '📌'), isTrue);
    expect(_optionSelected(tester, '蓝色'), isTrue);

    await _tap(tester, _inPanel(find.text('💡')));
    await _tap(tester, _inPanel(find.byTooltip('默认')));

    final node = _node(controller, 2);
    expect(node.attributes.containsKey('icon'), isFalse);
    expect(node.attributes.containsKey('tone'), isFalse);
    expect(node.delta!.toPlainText(), 'tip2');
    expect(_optionSelected(tester, '💡'), isTrue);
    expect(_optionSelected(tester, '默认'), isTrue);

    // 已是默认值时再点不留空的撤销步骤。
    final before = controller.contentJson;
    await _tap(tester, _inPanel(find.text('💡')));
    controller.undo();
    await tester.pumpAndSettle();
    expect(controller.contentJson, isNot(before));
    expect(_node(controller, 2).attributes['icon'], isNull);
    expect(_node(controller, 2).attributes['tone'], 'blue');
  });

  testWidgets(
    'convert to text turns callouts back into paragraphs and closes',
    (tester) async {
      final controller = _controller();
      final harness = await _pump(tester, controller);
      await _select(
        tester,
        controller,
        af.Selection.collapsed(af.Position(path: [2], offset: 1)),
      );
      await _tap(tester, find.byTooltip(_calloutTool));

      await _tap(tester, _inPanel(find.text('转为正文')));

      final node = _node(controller, 2);
      expect(node.type, 'paragraph');
      expect(node.delta!.toPlainText(), 'tip2');
      expect(node.attributes.containsKey('icon'), isFalse);
      expect(node.attributes.containsKey('tone'), isFalse);
      expect(find.byType(DiaryCalloutPanel), findsNothing);
      expect(harness.extents.last, 0);
      expect(harness.editorFocus.hasFocus, isTrue);

      controller.undo();
      await tester.pumpAndSettle();
      expect(_node(controller, 2).type, 'callout');
      expect(_node(controller, 2).attributes['icon'], '📌');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the panel closes when the caret leaves the callout', (
    tester,
  ) async {
    final controller = _controller();
    final harness = await _pump(tester, controller);
    await _select(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [1], offset: 1)),
    );
    await _tap(tester, find.byTooltip(_calloutTool));
    expect(find.byType(DiaryCalloutPanel), findsOneWidget);

    // 换到另一个提示块：面板跟着显示那里的取值。
    await _select(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [2], offset: 1)),
    );
    expect(find.byType(DiaryCalloutPanel), findsOneWidget);
    expect(_optionSelected(tester, '📌'), isTrue);

    await _select(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [0], offset: 1)),
    );
    expect(find.byType(DiaryCalloutPanel), findsNothing);
    expect(harness.extents.last, 0);
    expect(tester.takeException(), isNull);
  });

  for (final locale in [const Locale('zh'), const Locale('en')]) {
    testWidgets('the panel fits a 320dp phone without overflow ($locale)', (
      tester,
    ) async {
      final controller = _controller();
      await _pump(tester, controller, screenWidth: 320, locale: locale);
      await _select(
        tester,
        controller,
        af.Selection.collapsed(af.Position(path: [1], offset: 1)),
      );
      await _tap(
        tester,
        find.byTooltip(locale.languageCode == 'zh' ? _calloutTool : 'Callout'),
      );

      expect(find.byType(DiaryCalloutPanel), findsOneWidget);
      expect(tester.takeException(), isNull);
      // 两排选项各自排成一行：8 个图标、6 个色点的上沿对齐。
      final iconTops = {
        for (final icon in ['💡', '📌', '⭐', '✅', '⚠️', '❗', '❓', '📝'])
          tester.getTopLeft(_inPanel(find.text(icon))).dy,
      };
      expect(iconTops, hasLength(1));
      final panel = tester.getRect(find.byType(DiaryCalloutPanel));
      for (final icon in ['💡', '📝']) {
        final rect = tester.getRect(_inPanel(find.text(icon)));
        expect(panel.left <= rect.left && rect.right <= panel.right, isTrue);
      }
    });
  }
}
