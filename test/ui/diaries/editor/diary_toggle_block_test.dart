import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_block_reorder.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_preferences.dart';
import 'package:node_diary/ui/diaries/providers/diary_code_block_style_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_block_commands.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_block_handle.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_toggle_block.dart';
import 'package:node_diary/ui/diaries/widgets/diary_toolbar_config.dart';

import '../../../support/diary_color_panel_harness.dart';
import '../../../support/expressive_test_theme.dart';

/// 折叠块（toggle_list）在编辑器里的行为：展开 / 收起的渲染与写入、只读
/// 只改本地显示、收起时光标移出、选区落进收起的内容时自动展开（不进撤销
/// 栈）、回车 / 退格 / Tab 规则、工具栏与 `/` 菜单、段落拖动与上下移动。

Map<String, Object?> _block(
  String type,
  String text, {
  Map<String, Object?> data = const {},
  List<Map<String, Object?>> children = const [],
}) => {
  'type': type,
  'data': {
    'delta': [
      if (text.isNotEmpty) {'insert': text},
    ],
    ...data,
  },
  if (children.isNotEmpty) 'children': children,
};

Map<String, Object?> _p(String text) => _block('paragraph', text);

Map<String, Object?> _toggle(
  String text, {
  bool collapsed = false,
  Map<String, Object?> data = const {},
  List<Map<String, Object?>> children = const [],
}) => _block(
  'toggle_list',
  text,
  data: {...data, if (collapsed) 'collapsed': true},
  children: children,
);

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
  EdgeInsets padding = EdgeInsets.zero,
}) async {
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
            padding: padding,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<FocusNode> _focus(
  WidgetTester tester,
  DiaryEditorController controller,
  af.Selection selection,
) async {
  final focus = FocusNode();
  addTearDown(focus.dispose);
  controller.select(selection);
  await _pump(tester, controller, focusNode: focus);
  focus.requestFocus();
  await tester.pumpAndSettle();
  return focus;
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

/// 渲染出来的这段文字（正文与占位都是 RichText）。
Finder _text(String text) => find.byWidgetPredicate(
  (widget) => widget is RichText && widget.text.toPlainText() == text,
);

/// 每块一行：层级缩进 + 类型 + 文字（+ 收起标记）。
String _outline(DiaryEditorController controller) => [
  for (final node in walkDiaryEditorNodes(controller.document))
    '${'  ' * (node.path.length - 1)}${node.type} '
        '${node.delta?.toPlainText() ?? ''}'
        '${node.attributes['collapsed'] == true ? ' [collapsed]' : ''}',
].join('\n');

af.Node _at(DiaryEditorController controller, af.Path path) =>
    controller.document.nodeAtPath(path)!;

double _turns(WidgetTester tester, int index) => tester
    .widget<AnimatedRotation>(
      find.descendant(
        of: find.byType(DiaryToggleMarker).at(index),
        matching: find.byType(AnimatedRotation),
      ),
    )
    .turns;

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('an expanded toggle shows its children, a collapsed one hides '
        'them ($brightness)', (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = _document([
        _toggle('open', children: [_p('inside open')]),
        _toggle('closed', collapsed: true, children: [_p('inside closed')]),
        _toggle(''),
      ]);
      await _pump(tester, controller, brightness: brightness);

      expect(find.byType(DiaryToggleBlock), findsNWidgets(3));
      expect(_text('inside open'), findsOneWidget);
      expect(_text('inside closed'), findsNothing);
      // 空标题显示占位；展开却没有子块时不另画占位。
      expect(_text('折叠块'), findsOneWidget);
      expect(_turns(tester, 0), 0.25);
      expect(_turns(tester, 1), 0);

      // 子块与标题文字同一起点（缩进 = 行首标记列宽，同列表）。
      expect(
        tester.getRect(_text('inside open')).left,
        tester.getRect(_text('open')).left,
      );
      // 三角用 onSurfaceVariant，标记点按区不小于标记格。
      final scheme = Theme.of(
        tester.element(find.byType(DiaryEditor)),
      ).colorScheme;
      final icon = tester.widget<FaIcon>(
        find.descendant(
          of: find.byType(DiaryToggleMarker).first,
          matching: find.byType(FaIcon),
        ),
      );
      expect(icon.color, scheme.onSurfaceVariant);
      expect(
        tester.getSemantics(find.byType(DiaryToggleMarker).at(0)),
        isSemantics(label: '收起', isButton: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.byType(DiaryToggleMarker).at(1)),
        isSemantics(label: '展开', isButton: true, hasTapAction: true),
      );
      semantics.dispose();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('alignment applies to the toggle title, justify included', (
    tester,
  ) async {
    final controller = _document([
      _toggle('centered', data: {'align': 'center'}),
      _toggle('justified', data: {'align': 'justify'}),
    ]);
    await _pump(tester, controller);
    expect(
      tester.widget<RichText>(_text('centered')).textAlign,
      TextAlign.center,
    );
    expect(
      tester.widget<RichText>(_text('justified')).textAlign,
      TextAlign.justify,
    );
  });

  testWidgets('tapping the marker while editing writes collapsed as one '
      'undo step', (tester) async {
    final controller = _document([
      _toggle('title', children: [_p('inner')]),
      _p('after'),
    ]);
    controller.select(af.Selection.collapsed(af.Position(path: [1])));
    final before = controller.contentJson;
    await _pump(tester, controller);

    await tester.tap(find.byType(DiaryToggleMarker));
    await tester.pumpAndSettle();
    expect(_at(controller, [0]).attributes['collapsed'], isTrue);
    expect(_text('inner'), findsNothing);
    expect(_turns(tester, 0), 0);
    // 光标不在折叠的内容里：原样不动。
    expect(controller.selection!.end.path, [1]);
    expect(controller.state.undoManager.undoStack.length, 1);

    controller.undo();
    await tester.pumpAndSettle();
    expect(controller.contentJson, before);
    expect(_text('inner'), findsOneWidget);

    // 再点展开：删掉键（缺省即展开），不写 false。
    await tester.tap(find.byType(DiaryToggleMarker));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DiaryToggleMarker));
    await tester.pumpAndSettle();
    expect(_at(controller, [0]).attributes.containsKey('collapsed'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the marker in read-only text only changes the view', (
    tester,
  ) async {
    final controller = _document([
      _toggle('title', collapsed: true, children: [_p('inner')]),
      _toggle('open', children: [_p('shown')]),
    ], readOnly: true);
    final before = controller.contentJson;
    await _pump(tester, controller);
    expect(_text('inner'), findsNothing);
    expect(_text('shown'), findsOneWidget);

    await tester.tap(find.byType(DiaryToggleMarker).first);
    await tester.pumpAndSettle();
    expect(_text('inner'), findsOneWidget);
    await tester.tap(find.byType(DiaryToggleMarker).last);
    await tester.pumpAndSettle();
    expect(_text('shown'), findsNothing);

    expect(controller.contentJson, before);
    expect(controller.revision, 0);
    expect(controller.hasUndo, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapsing moves a caret inside the children to the title end', (
    tester,
  ) async {
    final controller = _document([
      _toggle('title', children: [_p('inner')]),
      _p('after'),
    ]);
    controller.select(
      af.Selection.collapsed(af.Position(path: [0, 0], offset: 2)),
    );
    await _pump(tester, controller);

    await tester.tap(find.byType(DiaryToggleMarker));
    await tester.pumpAndSettle();
    expect(_at(controller, [0]).attributes['collapsed'], isTrue);
    expect(
      controller.selection,
      af.Selection.collapsed(af.Position(path: [0], offset: 5)),
    );
    // 光标没有被带回收起的内容（否则会自动展开）。
    expect(_text('inner'), findsNothing);

    controller.undo();
    await tester.pumpAndSettle();
    expect(_at(controller, [0]).attributes.containsKey('collapsed'), isFalse);
    expect(controller.selection!.end.path, [0, 0]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('undo that lands in collapsed content expands the toggle '
      'without an extra undo step', (tester) async {
    final controller = _document([
      _toggle('title', children: [_p('inner')]),
      _p('after'),
    ]);
    await _pump(tester, controller);
    final child = _at(controller, [0, 0]);
    controller.select(af.Selection.collapsed(af.Position(path: [0, 0])));
    await tester.pump();
    // 一次可撤销的编辑，光标停在子块里……
    controller.apply(
      controller.state.transaction
        ..insertText(child, 5, '!')
        ..afterSelection = af.Selection.collapsed(
          af.Position(path: [0, 0], offset: 6),
        ),
    );
    await tester.pumpAndSettle();
    // ……之后折叠块被收起（不在撤销历史里，如另一处的显示状态），光标在外面。
    controller.apply(
      controller.state.transaction
        ..updateNode(_at(controller, [0]), {'collapsed': true})
        ..afterSelection = af.Selection.collapsed(af.Position(path: [1])),
      recordUndo: false,
    );
    await tester.pumpAndSettle();
    expect(_text('inner!'), findsNothing);
    expect(controller.state.undoManager.undoStack.length, 1);

    controller.undo();
    await tester.pumpAndSettle();
    expect(_at(controller, [0, 0]).delta!.toPlainText(), 'inner');
    expect(controller.selection!.end.path, [0, 0]);
    // 撤销把光标带进收起的内容：折叠块展开、子块显示出来，且展开不占
    // 撤销 / 重做的步数。
    expect(_at(controller, [0]).attributes.containsKey('collapsed'), isFalse);
    expect(_text('inner'), findsOneWidget);
    expect(controller.state.undoManager.undoStack.length, 0);
    expect(controller.state.undoManager.redoStack.length, 1);

    controller.redo();
    await tester.pumpAndSettle();
    expect(_at(controller, [0, 0]).delta!.toPlainText(), 'inner!');
    expect(controller.state.undoManager.undoStack.length, 1);
    expect(controller.state.undoManager.redoStack.length, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a programmatic selection inside collapsed content expands '
      'every collapsed toggle around it', (tester) async {
    final controller = _document([
      _toggle(
        'outer',
        collapsed: true,
        children: [
          _toggle('inner', collapsed: true, children: [_p('deep')]),
        ],
      ),
      _p('after'),
    ]);
    await _pump(tester, controller);
    expect(_text('deep'), findsNothing);

    controller.select(af.Selection.collapsed(af.Position(path: [0, 0, 0])));
    await tester.pumpAndSettle();
    expect(
      _outline(controller),
      'toggle_list outer\n'
      '  toggle_list inner\n'
      '    paragraph deep\n'
      'paragraph after',
    );
    expect(_text('deep'), findsOneWidget);
    expect(controller.hasUndo, isFalse);
    expect(tester.takeException(), isNull);
  });

  group('Enter and Backspace in a toggle title', () {
    testWidgets('Enter in an expanded title starts its first child', (
      tester,
    ) async {
      final controller = _document([
        _toggle('title', children: [_p('kept')]),
      ]);
      final before = controller.contentJson;
      await _focus(
        tester,
        controller,
        af.Selection.collapsed(af.Position(path: [0], offset: 2)),
      );

      await _type(tester, '\n');
      expect(
        _outline(controller),
        'toggle_list ti\n  paragraph tle\n  paragraph kept',
      );
      expect(
        controller.selection,
        af.Selection.collapsed(af.Position(path: [0, 0])),
      );
      controller.undo();
      await tester.pumpAndSettle();
      expect(controller.contentJson, before);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Enter in a collapsed title starts a sibling toggle', (
      tester,
    ) async {
      final controller = _document([
        _toggle(
          'title',
          collapsed: true,
          data: {'align': 'center'},
          children: [_p('hidden')],
        ),
      ]);
      final before = controller.contentJson;
      await _focus(
        tester,
        controller,
        af.Selection.collapsed(af.Position(path: [0], offset: 2)),
      );

      await _type(tester, '\n');
      expect(
        _outline(controller),
        'toggle_list ti [collapsed]\n'
        '  paragraph hidden\n'
        'toggle_list tle',
      );
      // 新折叠块展开、对齐随原块；光标在它里面，原块的内容仍收着。
      expect(_at(controller, [1]).attributes['align'], 'center');
      expect(
        controller.selection,
        af.Selection.collapsed(af.Position(path: [1])),
      );
      expect(_text('hidden'), findsNothing);
      controller.undo();
      await tester.pumpAndSettle();
      expect(controller.contentJson, before);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Enter on an empty title turns the toggle into a paragraph '
        'that keeps the children', (tester) async {
      final controller = _document([
        _p('before'),
        _toggle(
          '',
          collapsed: true,
          data: {'align': 'right'},
          children: [_p('kept')],
        ),
      ]);
      final before = controller.contentJson;
      await _focus(
        tester,
        controller,
        af.Selection.collapsed(af.Position(path: [1])),
      );

      await _type(tester, '\n');
      expect(
        _outline(controller),
        'paragraph before\nparagraph \n  paragraph kept',
      );
      expect(_at(controller, [1]).attributes['align'], 'right');
      expect(_at(controller, [1]).attributes.containsKey('collapsed'), isFalse);
      expect(controller.selection!.end.path, [1]);
      expect(_text('kept'), findsOneWidget);
      controller.undo();
      await tester.pumpAndSettle();
      expect(controller.contentJson, before);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Backspace at the start of a title turns it into a paragraph', (
      tester,
    ) async {
      final controller = _document([
        _p('before'),
        _toggle('title', collapsed: true, children: [_p('kept')]),
      ]);
      final before = controller.contentJson;
      await _focus(
        tester,
        controller,
        af.Selection.collapsed(af.Position(path: [1])),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      // 不并进上一段：原地转为正文，折叠的内容留在段落下面。
      expect(
        _outline(controller),
        'paragraph before\nparagraph title\n  paragraph kept',
      );
      expect(controller.selection!.end.path, [1]);
      controller.undo();
      await tester.pumpAndSettle();
      expect(controller.contentJson, before);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('Tab indents the paragraph after a toggle into it', (
      tester,
    ) async {
      final controller = _document([
        _toggle('open', children: [_p('first')]),
        _p('moved'),
        _toggle('closed', collapsed: true, children: [_p('hidden')]),
        _p('also moved'),
      ]);
      await _focus(
        tester,
        controller,
        af.Selection.collapsed(af.Position(path: [1], offset: 1)),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        _outline(controller),
        'toggle_list open\n'
        '  paragraph first\n'
        '  paragraph moved\n'
        'toggle_list closed [collapsed]\n'
        '  paragraph hidden\n'
        'paragraph also moved',
      );
      expect(controller.selection!.end.path, [0, 1]);

      // 缩进进收起的折叠块：光标随段落进去，折叠块随之展开（展开不进
      // 撤销栈，撤销只把段落移回来）。
      controller.select(
        af.Selection.collapsed(af.Position(path: [2], offset: 1)),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        _outline(controller),
        'toggle_list open\n'
        '  paragraph first\n'
        '  paragraph moved\n'
        'toggle_list closed\n'
        '  paragraph hidden\n'
        '  paragraph also moved',
      );
      expect(_text('also moved'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  });

  testWidgets('the toolbar tool converts paragraphs to toggles and back, '
      'keeping alignment', (tester) async {
    final controller = _document([
      _block('paragraph', 'first', data: {'align': 'center'}),
      _block('code', 'x = 1'),
      _p('second'),
    ]);
    await pumpColorPanel(
      tester,
      controller: controller,
      order: [
        DiaryToolbarItem.toggle,
        for (final item in kDefaultDiaryToolbarOrder)
          if (item != DiaryToolbarItem.toggle) item,
      ],
    );
    final all = af.Selection(
      start: af.Position(path: [0]),
      end: af.Position(path: [2], offset: 6),
    );
    controller.select(all);
    await tester.pumpAndSettle();
    expect(
      isDiaryToolbarItemActive(
        DiaryToolbarItem.toggle,
        controller.activeAttributes,
      ),
      isFalse,
    );

    await tester.tap(find.byTooltip('折叠块'));
    await tester.pumpAndSettle();
    // 代码块不转换；对齐保留。
    expect(
      _outline(controller),
      'toggle_list first\ncode x = 1\ntoggle_list second',
    );
    expect(_at(controller, [0]).attributes['align'], 'center');
    controller.select(af.Selection.collapsed(af.Position(path: [0])));
    await tester.pumpAndSettle();
    expect(
      isDiaryToolbarItemActive(
        DiaryToolbarItem.toggle,
        controller.activeAttributes,
      ),
      isTrue,
    );

    // 选区里的文字块（代码块除外）全是折叠块：转回正文。
    controller.select(all);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('折叠块'));
    await tester.pumpAndSettle();
    expect(
      _outline(controller),
      'paragraph first\ncode x = 1\nparagraph second',
    );
    expect(_at(controller, [0]).attributes['align'], 'center');
    controller.undo();
    await tester.pumpAndSettle();
    expect(_at(controller, [2]).type, 'toggle_list');
    expect(tester.takeException(), isNull);
  });

  test('the / menu finds the toggle right after the callout', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    final commands = diaryBlockCommands(l10n);
    for (final query in ['toggle', 'zhedie', '折叠', 'fold', 'details', 'zdk']) {
      expect(
        commands.where((command) => command.matches(query)).map((c) => c.type),
        contains('toggle_list'),
        reason: query,
      );
    }
    final toggle = commands.singleWhere((c) => c.type == 'toggle_list');
    expect(toggle.label, '折叠块');
    expect(toggle.group, DiaryBlockCommandGroup.text);
    final types = commands.map((command) => command.type).toList();
    expect(types.indexOf('toggle_list'), types.indexOf('callout') + 1);

    final controller = _document([
      _block('paragraph', 'line', data: {'align': 'right'}),
    ]);
    controller.select(af.Selection.collapsed(af.Position(path: [0])));
    applyDiaryBlockCommand(controller, toggle);
    expect(_at(controller, [0]).type, 'toggle_list');
    expect(_at(controller, [0]).attributes['align'], 'right');
  });

  group('moving blocks around toggles', () {
    String text(af.Node node) => node.delta?.toPlainText() ?? '';
    af.Node named(DiaryEditorController controller, String value) =>
        walkDiaryEditorNodes(
          controller.document,
        ).firstWhere((node) => text(node) == value);

    test(
      'collapsed content offers no gaps, expanded toggles take children',
      () {
        final controller = _document([
          _toggle('closed', collapsed: true, children: [_p('hidden')]),
          _toggle('open', children: [_p('shown')]),
          _toggle('empty'),
          _p('p'),
        ]);
        final gaps = DiaryBlockGaps(
          controller.document.root,
          named(controller, 'p'),
        );
        expect(gaps.blocks.map(text), ['closed', 'open', 'shown', 'empty']);
        // 收起的折叠块之后只能是同级，放不进去。
        expect(gaps.depths(1), (1, 1));
        expect(gaps.destination(1, 2), [1]);
        // 展开的折叠块与列表一样能收子块（保持缩进的落点模型照旧）。
        expect(gaps.depths(2), (2, 2));
        expect(gaps.depths(4), (1, 2));
        expect(gaps.destination(4, 2), [2, 0]);
      },
    );

    test('up / down moves treat a collapsed toggle as one unit', () {
      final controller = _document([
        _p('a'),
        _toggle('closed', collapsed: true, children: [_p('hidden')]),
        _p('b'),
      ]);
      bool step(String value, {required bool up}) {
        final node = named(controller, value);
        final destination = DiaryBlockGaps(
          controller.document.root,
          node,
        ).step(up: up);
        return destination != null &&
            moveDiaryEditorBlock(controller, node, destination);
      }

      expect(step('b', up: true), isTrue);
      expect(
        _outline(controller),
        'paragraph a\nparagraph b\ntoggle_list closed [collapsed]\n'
        '  paragraph hidden',
      );
      expect(step('a', up: false), isTrue);
      expect(step('a', up: false), isTrue);
      expect(
        _outline(controller),
        'paragraph b\ntoggle_list closed [collapsed]\n'
        '  paragraph hidden\nparagraph a',
      );
      // 收起的折叠块自己移动时带着内容。
      expect(step('closed', up: true), isTrue);
      expect(
        _outline(controller),
        'toggle_list closed [collapsed]\n'
        '  paragraph hidden\nparagraph b\nparagraph a',
      );
    });

    test('an indented block never steps into collapsed content', () {
      final controller = _document([
        _toggle('closed', collapsed: true, children: [_p('hidden')]),
        _block('paragraph', 'p', children: [_p('c')]),
      ]);
      af.Path? up(String value) => DiaryBlockGaps(
        controller.document.root,
        named(controller, value),
      ).step(up: true);

      // 收起的折叠块里没有缝：缩进的块上移找不到放得下的位置。
      expect(up('c'), isNull);

      // 展开后同一步就能进去，接在最后一个子块后面。
      final open = _document([
        _toggle('open', children: [_p('shown')]),
        _block('paragraph', 'p', children: [_p('c')]),
      ]);
      final c = named(open, 'c');
      expect(DiaryBlockGaps(open.document.root, c).step(up: true), [0, 1]);
    });

    Future<void> drag(
      WidgetTester tester,
      double Function(Offset start) targetY,
    ) async {
      final start = tester.getCenter(find.byType(DiaryBlockHandle));
      final gesture = await tester.startGesture(start);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      final travel = targetY(start) - start.dy;
      for (var step = 1; step <= 6; step++) {
        await gesture.moveTo(start + Offset(0, travel * step / 6));
        await tester.pump();
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
    }

    testWidgets('dragging a collapsed toggle carries its hidden children', (
      tester,
    ) async {
      final focus = FocusNode();
      final controller = DiaryEditorController.fromContent(
        jsonEncode({
          'document': {
            'type': 'page',
            'children': [
              _toggle('fold', collapsed: true, children: [_p('hidden')]),
              _p('next'),
              _p('last'),
            ],
          },
        }),
      );
      final before = controller.contentJson;
      controller.select(af.Selection.collapsed(af.Position(path: [0])));
      await _pump(
        tester,
        controller,
        focusNode: focus,
        padding: const EdgeInsets.symmetric(horizontal: 16),
      );
      focus.requestFocus();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final next = tester.getRect(_text('next'));
      await drag(tester, (_) => next.bottom - 2);

      expect(
        _outline(controller),
        'paragraph next\n'
        'toggle_list fold [collapsed]\n'
        '  paragraph hidden\n'
        'paragraph last',
      );
      expect(_text('hidden'), findsNothing);
      controller.undo();
      await tester.pump();
      expect(controller.contentJson, before);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
      controller.dispose();
      focus.dispose();
    });

    testWidgets('a block dragged onto a collapsed toggle lands beside it, '
        'never inside', (tester) async {
      final focus = FocusNode();
      final controller = DiaryEditorController.fromContent(
        jsonEncode({
          'document': {
            'type': 'page',
            'children': [
              _p('moving'),
              _toggle('fold', collapsed: true, children: [_p('hidden')]),
              _p('last'),
            ],
          },
        }),
      );
      controller.select(af.Selection.collapsed(af.Position(path: [0])));
      await _pump(
        tester,
        controller,
        focusNode: focus,
        padding: const EdgeInsets.symmetric(horizontal: 16),
      );
      focus.requestFocus();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      // 停在折叠块下半区：落在它之后（同级），而不是它的子块里。
      await drag(
        tester,
        (_) => tester.getRect(find.byType(DiaryToggleBlock)).bottom - 2,
      );
      expect(
        _outline(controller),
        'toggle_list fold [collapsed]\n'
        '  paragraph hidden\n'
        'paragraph moving\n'
        'paragraph last',
      );
      // 上半区：落在它之前。
      await drag(
        tester,
        (_) => tester.getRect(find.byType(DiaryToggleBlock)).top + 2,
      );
      expect(
        _outline(controller),
        'paragraph moving\n'
        'toggle_list fold [collapsed]\n'
        '  paragraph hidden\n'
        'paragraph last',
      );
      expect(_text('hidden'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
      controller.dispose();
      focus.dispose();
    });
  });
}

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}
