import '../../../support/diary_content_test_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/controllers/diary_block_language_tracker.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_language.dart';
import 'package:node_diary/ui/diaries/widgets/diary_code_block/diary_code_block_panel.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:node_diary/ui/diaries/widgets/diary_toolbar_more_panel.dart';

import '../../../support/diary_color_panel_harness.dart';

/// 悬浮工具栏的代码块工具与卡片内的代码块面板：转为代码块、开合与高度
/// 报告、选语言、自动识别标签、退出 / 转为正文 / 复制、从「更多」打开，以及
/// 选区离开代码块时收起；全程不推路由、正文保持焦点。
const String _codeTool = '代码块（多行）';

/// 代码块工具排在最前，360dp 下常驻在工具栏一排上。
final List<DiaryToolbarItem> _codeFirstOrder = <DiaryToolbarItem>[
  DiaryToolbarItem.codeBlock,
  for (final item in kDefaultDiaryToolbarOrder)
    if (item != DiaryToolbarItem.codeBlock) item,
];

/// 正文：`intro` / 两行代码块 `code1`、`code2` / `after`。
///
/// 偏移：intro 0–5，code1 6–11，code2 12–17，after 18–23（各含行尾换行）。
DiaryEditorController _codeController({
  Object codeValue = true,
  int caret = 8,
  String line1 = 'code1',
  String line2 = 'code2',
}) {
  final controller = DiaryEditorController(
    document: documentFromLegacyDelta(<Map<String, dynamic>>[
      <String, dynamic>{'insert': 'intro\n$line1'},
      <String, dynamic>{
        'insert': '\n',
        'attributes': <String, dynamic>{'code-block': codeValue},
      },
      <String, dynamic>{'insert': line2},
      <String, dynamic>{
        'insert': '\n',
        'attributes': <String, dynamic>{'code-block': codeValue},
      },
      <String, dynamic>{'insert': 'after\n'},
    ]),
  );
  controller.updateSelection(TextSelection.collapsed(offset: caret));
  addTearDown(controller.dispose);
  return controller;
}

/// 各行行尾换行上的 `code-block` 值（不是代码块为 null）。
List<Object?> _lineCodeValues(DiaryEditorController controller) => <Object?>[
  for (final op in controller.document.toDelta().toList())
    if (op.data case final String text)
      for (final _ in '\n'.allMatches(text)) op.attributes?['code-block'],
];

Future<ColorPanelHarness> _pump(
  WidgetTester tester,
  DiaryEditorController controller, {
  List<DiaryToolbarItem>? order,
  DiaryCodeBlockStyle codeBlockStyle = DiaryCodeBlockStyle.defaults,
}) async {
  final harness = await pumpColorPanel(
    tester,
    controller: controller,
    order: order ?? _codeFirstOrder,
    codeBlockStyle: codeBlockStyle,
  );
  harness.editorFocus.requestFocus();
  await tester.pumpAndSettle();
  return harness;
}

Future<void> _tapCodeTool(WidgetTester tester) async {
  // 默认顺序里代码块在最后，360dp 下落在「更多」露出的三行之外，先滚到它。
  await tester.ensureVisible(find.byTooltip(_codeTool));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip(_codeTool));
  await tester.pumpAndSettle();
}

/// 选项是否为选中态（选项用 Semantics(selected:) 标出）。
bool _chipSelected(WidgetTester tester, String label) {
  final semantics = tester.widget<Semantics>(
    find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.button == true,
      ),
    ),
  );
  return semantics.properties.selected ?? false;
}

void main() {
  setUpAll(loadColorPanelFonts);

  testWidgets('outside a code block the tool converts the line, no panel', (
    tester,
  ) async {
    final controller = _codeController(caret: 2);
    final harness = await _pump(tester, controller);
    final pushes = harness.routes.pushes;

    await _tapCodeTool(tester);

    expect(
      controller.document.nodeAtPath(
        diaryEditorSelectionAtOffset(controller.document, 2).end.path,
      ),
      isNotNull,
    );
    expect(find.byType(DiaryCodeBlockPanel), findsNothing);
    expect(harness.extents.where((extent) => extent > 0), isEmpty);
    expect(harness.routes.pushes, pushes);
    expect(harness.editorFocus.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inside a code block the tool opens the panel, again closes', (
    tester,
  ) async {
    final harness = await _pump(tester, _codeController());
    final pushes = harness.routes.pushes;

    await _tapCodeTool(tester);

    expect(find.byType(DiaryCodeBlockPanel), findsOneWidget);
    expect(
      harness.extents.last,
      kDiaryToolbarPanelChrome + kDiaryCodeBlockPanelHeight,
    );
    expect(
      tester.getSize(find.byType(DiaryCodeBlockPanel)).height,
      kDiaryCodeBlockPanelHeight,
    );
    expect(find.text('代码块'), findsOneWidget);
    expect(harness.routes.pushes, pushes);
    expect(find.byType(Dialog), findsNothing);
    expect(harness.editorFocus.hasFocus, isTrue);
    // 未指定语言的块：第一个选项（自动）选中。
    expect(_chipSelected(tester, '纯文本'), isFalse);

    await _tapCodeTool(tester);
    expect(find.byType(DiaryCodeBlockPanel), findsNothing);
    expect(harness.extents.last, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a language chip sets every line of the block and stays open', (
    tester,
  ) async {
    final controller = _codeController();
    final harness = await _pump(tester, controller);
    await _tapCodeTool(tester);

    await tester.tap(find.text('Python'));
    await tester.pumpAndSettle();

    expect(_lineCodeValues(controller), <Object?>[
      null,
      'python',
      'python',
      null,
    ]);
    expect(find.byType(DiaryCodeBlockPanel), findsOneWidget);
    expect(_chipSelected(tester, 'Python'), isTrue);

    // 最后一个语言要先滑过去才能点到。
    await tester.ensureVisible(
      find.descendant(
        of: find.byType(DiaryCodeBlockPanel),
        matching: find.text('Diff'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(DiaryCodeBlockPanel),
        matching: find.text('Diff'),
      ),
    );
    await tester.pumpAndSettle();
    expect(_lineCodeValues(controller), <Object?>[null, 'diff', 'diff', null]);

    await tester.ensureVisible(find.text('纯文本'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('纯文本'));
    await tester.pumpAndSettle();
    expect(_lineCodeValues(controller), <Object?>[
      null,
      'plain',
      'plain',
      null,
    ]);
    expect(harness.editorFocus.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening scrolls the selected language into view', (
    tester,
  ) async {
    await _pump(tester, _codeController(codeValue: 'diff'));
    await _tapCodeTool(tester);

    final panel = tester.getRect(find.byType(DiaryCodeBlockPanel));
    final chip = tester.getRect(
      find.descendant(
        of: find.byType(DiaryCodeBlockPanel),
        matching: find.text('Diff'),
      ),
    );
    expect(chip.left, greaterThanOrEqualTo(panel.left));
    expect(chip.right, lessThanOrEqualTo(panel.right));
    expect(_chipSelected(tester, 'Diff'), isTrue);
  });

  testWidgets('the auto chip names the detected language', (tester) async {
    final controller = _codeController(
      line1: 'def greet(name):',
      line2: '    print(f"hello {name}")',
    );
    final block = controller.document.nodeAtPath(
      diaryEditorSelectionAtOffset(controller.document, 8).end.path,
    )!;
    final detected = DiaryBlockLanguageTracker.of(
      controller,
    ).languageFor(block, block.delta!.toPlainText());
    expect(detected, isNotNull);

    await _pump(tester, controller);
    await _tapCodeTool(tester);

    final name = diaryCodeLanguageById(detected!)!.name;
    expect(find.text('自动 · $name'), findsOneWidget);
    expect(_chipSelected(tester, '自动 · $name'), isTrue);
  });

  testWidgets('without detection the auto chip reads 自动识别', (tester) async {
    await _pump(tester, _codeController());
    await _tapCodeTool(tester);
    expect(find.text('自动识别'), findsOneWidget);
  });

  testWidgets('with auto-detect off the first chip reads 不指定', (tester) async {
    await _pump(
      tester,
      _codeController(),
      codeBlockStyle: DiaryCodeBlockStyle.defaults.copyWith(autoDetect: false),
    );
    await _tapCodeTool(tester);

    expect(find.text('不指定'), findsOneWidget);
    expect(find.text('自动识别'), findsNothing);
    expect(_chipSelected(tester, '不指定'), isTrue);
  });

  testWidgets('Exit moves the caret below the block and closes', (
    tester,
  ) async {
    final controller = _codeController();
    final harness = await _pump(tester, controller);
    await _tapCodeTool(tester);

    await tester.tap(find.text('退出代码块'));
    await tester.pumpAndSettle();

    final caret = controller.flatSelection.extentOffset;
    expect(caret, 18);
    expect(
      controller.document.nodeAtPath(
        diaryEditorSelectionAtOffset(controller.document, caret).end.path,
      ),
      isA<Node>().having((node) => node.type, 'type', 'paragraph'),
    );
    expect(_lineCodeValues(controller), <Object?>[
      null,
      true,
      true,
      null,
      null,
    ]);
    expect(find.byType(DiaryCodeBlockPanel), findsNothing);
    expect(harness.extents.last, 0);
    expect(harness.editorFocus.hasFocus, isTrue);
  });

  testWidgets('转为正文 removes the code block and closes', (tester) async {
    final controller = _codeController(codeValue: 'dart');
    final harness = await _pump(tester, controller);
    await _tapCodeTool(tester);

    await tester.tap(find.text('转为正文'));
    await tester.pumpAndSettle();

    expect(_lineCodeValues(controller), <Object?>[null, null, null, null]);
    expect(find.byType(DiaryCodeBlockPanel), findsNothing);
    expect(harness.extents.last, 0);
  });

  testWidgets('Copy writes the block to the clipboard and shows a hint', (
    tester,
  ) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add(
            (call.arguments as Map<Object?, Object?>)['text']! as String,
          );
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final harness = await _pump(tester, _codeController());
    await _tapCodeTool(tester);

    await tester.tap(find.text('复制代码'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(copied, <String>['code1\ncode2']);
    expect(find.text('已复制代码'), findsOneWidget);
    expect(find.byType(DiaryCodeBlockPanel), findsOneWidget);
    expect(harness.editorFocus.hasFocus, isTrue);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('from More the code panel keeps More expanded', (tester) async {
    final controller = _codeController();
    final harness = await _pump(
      tester,
      controller,
      order: kDefaultDiaryToolbarOrder,
    );
    await tester.tap(find.byTooltip(colorPanelMoreTooltip));
    await tester.pumpAndSettle();
    final moreExtent = harness.extents.last;

    await _tapCodeTool(tester);

    expect(find.byType(DiaryCodeBlockPanel), findsOneWidget);
    expect(find.byTooltip('插入图片'), findsNothing);
    expect(find.byTooltip(colorPanelHideMoreTooltip), findsOneWidget);
    expect(harness.extents.last, isNot(moreExtent));

    // 选区离开代码块：回到「更多」。
    controller.updateSelection(
      const TextSelection.collapsed(offset: 2),
      'local',
    );
    await tester.pumpAndSettle();
    expect(find.byType(DiaryCodeBlockPanel), findsNothing);
    expect(find.byTooltip('插入图片'), findsOneWidget);
    expect(find.byTooltip(colorPanelHideMoreTooltip), findsOneWidget);
    expect(harness.extents.last, moreExtent);
    expect(tester.takeException(), isNull);
  });

  testWidgets('outside a code block the tool in More leaves More open', (
    tester,
  ) async {
    final controller = _codeController(caret: 2);
    await _pump(tester, controller, order: kDefaultDiaryToolbarOrder);
    await tester.tap(find.byTooltip(colorPanelMoreTooltip));
    await tester.pumpAndSettle();

    await _tapCodeTool(tester);

    expect(
      controller.document.nodeAtPath(
        diaryEditorSelectionAtOffset(controller.document, 2).end.path,
      ),
      isNotNull,
    );
    expect(find.byType(DiaryCodeBlockPanel), findsNothing);
    expect(find.byTooltip('插入图片'), findsOneWidget);
    expect(find.byTooltip(colorPanelHideMoreTooltip), findsOneWidget);
  });

  testWidgets('moving the caret out of the block closes the panel', (
    tester,
  ) async {
    final controller = _codeController();
    final harness = await _pump(tester, controller);
    await _tapCodeTool(tester);

    // 块内移动不收起。
    controller.updateSelection(
      const TextSelection.collapsed(offset: 14),
      'local',
    );
    await tester.pumpAndSettle();
    expect(find.byType(DiaryCodeBlockPanel), findsOneWidget);

    controller.updateSelection(
      const TextSelection.collapsed(offset: 20),
      'local',
    );
    await tester.pumpAndSettle();
    expect(find.byType(DiaryCodeBlockPanel), findsNothing);
    expect(harness.extents.last, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('More lights its dot while the caret is in a language block', (
    tester,
  ) async {
    final controller = _codeController(codeValue: 'python', caret: 2);
    await _pump(tester, controller, order: kDefaultDiaryToolbarOrder);
    final dot = find.byKey(const ValueKey<String>('diary-toolbar-more-dot'));
    double scale() => tester.widget<AnimatedScale>(dot).scale;

    expect(scale(), 0);
    controller.updateSelection(
      const TextSelection.collapsed(offset: 8),
      'local',
    );
    await tester.pumpAndSettle();
    expect(scale(), 1);
  });
}
