import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_callout_tone.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/providers/diary_code_block_style_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_block_commands.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_callout_block.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';

import '../../../support/expressive_test_theme.dart';

/// 提示块（callout）在编辑器里的渲染与键盘规则：图标、文字与底色（明暗
/// 主题）、只读、对齐；空提示块回车转正文、末尾回车接正文段落、开头退格
/// 转正文；`/` 菜单能找到它。

Map<String, Object?> _block(
  String type,
  String text, {
  Map<String, Object?> data = const {},
}) => {
  'type': type,
  'data': {
    'delta': [
      if (text.isNotEmpty) {'insert': text},
    ],
    ...data,
  },
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
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 提示块的底色框。
BoxDecoration _decoration(WidgetTester tester, Finder callout) {
  final box = tester.widget<Container>(
    find
        .descendant(
          of: callout,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).borderRadius != null,
          ),
        )
        .first,
  );
  return box.decoration! as BoxDecoration;
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

List<String> _types(DiaryEditorController controller) => [
  for (final node in controller.document.root.children) node.type,
];

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('callout renders icon, text and the tone background '
        '($brightness)', (tester) async {
      final controller = _document([
        _block('callout', 'plain tip'),
        _block('callout', 'red tip', data: {'icon': '⚠️', 'tone': 'red'}),
        _block('callout', 'odd tip', data: {'icon': '', 'tone': 'teal'}),
      ]);
      await _pump(tester, controller, brightness: brightness);

      final scheme = Theme.of(
        tester.element(find.byType(DiaryEditor)),
      ).colorScheme;
      expect(scheme.brightness, brightness);
      final callouts = find.byType(DiaryCalloutBlock);
      expect(callouts, findsNWidgets(3));

      expect(
        _decoration(tester, callouts.at(0)).color,
        DiaryCalloutTone.neutral.background(scheme),
      );
      expect(
        _decoration(tester, callouts.at(1)).color,
        DiaryCalloutTone.red.background(scheme),
      );
      // 认不出的底色按默认，空图标按默认图标。
      expect(
        _decoration(tester, callouts.at(2)).color,
        DiaryCalloutTone.neutral.background(scheme),
      );
      expect(
        _decoration(tester, callouts.at(0)).borderRadius,
        BorderRadius.circular(12),
      );

      Finder icon(int index) => find.descendant(
        of: callouts.at(index),
        matching: find.byType(DiaryCalloutIcon),
      );
      expect(tester.widget<DiaryCalloutIcon>(icon(0)).icon, '💡');
      expect(tester.widget<DiaryCalloutIcon>(icon(1)).icon, '⚠️');
      expect(tester.widget<DiaryCalloutIcon>(icon(2)).icon, '💡');
      expect(find.text('⚠️'), findsOneWidget);

      // 图标在文字起始侧、隔 8dp；框内留白 14dp。
      final text = find.descendant(
        of: callouts.at(1),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is RichText && widget.text.toPlainText() == 'red tip',
        ),
      );
      final iconRect = tester.getRect(icon(1));
      final textRect = tester.getRect(text);
      final boxRect = tester.getRect(
        find
            .descendant(
              of: callouts.at(1),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Container &&
                    widget.decoration is BoxDecoration &&
                    (widget.decoration! as BoxDecoration).borderRadius != null,
              ),
            )
            .first,
      );
      expect(iconRect.left - boxRect.left, 14);
      expect(textRect.left - iconRect.right, 8);
      // 单行时图标与文字首行上下居中对齐（图标格与首行同高、同起点）。
      expect(iconRect.top, textRect.top);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty callout shows the placeholder, read-only keeps the box', (
    tester,
  ) async {
    final controller = _document([
      _block('callout', ''),
      _block('callout', 'kept', data: {'tone': 'green'}),
    ], readOnly: true);
    await _pump(tester, controller);

    expect(find.byType(DiaryCalloutBlock), findsNWidgets(2));
    expect(
      find.byWidgetPredicate(
        (widget) => widget is RichText && widget.text.toPlainText() == '提示',
      ),
      findsOneWidget,
    );
    final scheme = Theme.of(
      tester.element(find.byType(DiaryEditor)),
    ).colorScheme;
    expect(
      _decoration(tester, find.byType(DiaryCalloutBlock).at(1)).color,
      DiaryCalloutTone.green.background(scheme),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('alignment applies to the callout text, justify included', (
    tester,
  ) async {
    final controller = _document([
      _block('callout', 'centered', data: {'align': 'center'}),
      _block('callout', 'justified', data: {'align': 'justify'}),
    ]);
    await _pump(tester, controller);

    RichText rich(String text) => tester.widget<RichText>(
      find.byWidgetPredicate(
        (widget) => widget is RichText && widget.text.toPlainText() == text,
      ),
    );
    expect(rich('centered').textAlign, TextAlign.center);
    expect(rich('justified').textAlign, TextAlign.justify);
  });

  testWidgets('Enter at the end of a callout continues with a paragraph', (
    tester,
  ) async {
    final controller = _document([
      _block('callout', 'tip', data: {'icon': '📌'}),
    ]);
    await _focus(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [0], offset: 3)),
    );

    await _type(tester, '\n');

    expect(_types(controller), ['callout', 'paragraph']);
    expect(controller.document.nodeAtPath([0])!.delta!.toPlainText(), 'tip');
    expect(controller.document.nodeAtPath([0])!.attributes['icon'], '📌');
    expect(controller.selection!.end.path, [1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Enter on an empty callout turns it into a paragraph', (
    tester,
  ) async {
    final controller = _document([
      _block('paragraph', 'before'),
      _block('callout', '', data: {'tone': 'red', 'align': 'center'}),
    ]);
    await _focus(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [1])),
    );

    await _type(tester, '\n');

    expect(_types(controller), ['paragraph', 'paragraph']);
    final node = controller.document.nodeAtPath([1])!;
    expect(node.attributes.containsKey('tone'), isFalse);
    expect(node.attributes['align'], 'center');
    expect(controller.selection!.end.path, [1]);

    controller.undo();
    await tester.pumpAndSettle();
    expect(_types(controller), ['paragraph', 'callout']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Backspace at the start of a callout turns it into a paragraph', (
    tester,
  ) async {
    final controller = _document([
      _block('paragraph', 'before'),
      _block('callout', 'tip', data: {'icon': '⭐'}),
    ]);
    await _focus(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [1])),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();

    // 不并进上一段，原地转为正文。
    expect(_types(controller), ['paragraph', 'paragraph']);
    expect(controller.document.nodeAtPath([0])!.delta!.toPlainText(), 'before');
    expect(controller.document.nodeAtPath([1])!.delta!.toPlainText(), 'tip');
    expect(controller.selection!.end.path, [1]);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('/ menu finds the callout and converts the line', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    final commands = diaryBlockCommands(l10n);
    for (final query in ['callout', 'tishi', '提示', 'tip', 'note', '标注']) {
      expect(
        commands.where((command) => command.matches(query)).map((c) => c.type),
        contains('callout'),
        reason: query,
      );
    }
    final callout = commands.singleWhere((c) => c.type == 'callout');
    expect(callout.label, '提示块');
    expect(callout.markdown, isNull);
    expect(callout.group, DiaryBlockCommandGroup.text);
    // 在文字组里紧跟引用。
    final types = commands.map((command) => command.type).toList();
    expect(types.indexOf('callout'), types.indexOf('quote') + 1);

    final controller = _document([
      _block('paragraph', 'line', data: {'align': 'right'}),
    ]);
    controller.select(af.Selection.collapsed(af.Position(path: [0])));
    applyDiaryBlockCommand(controller, callout);
    final node = controller.document.nodeAtPath([0])!;
    expect(node.type, 'callout');
    expect(node.attributes['align'], 'right');
    expect(node.attributes.containsKey('icon'), isFalse);
  });
}

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}
