import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/providers/diary_code_block_style_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';

import '../../../support/expressive_test_theme.dart';

/// 编辑器的文字工具周边：两端对齐的渲染、`> ` 转引用、Ctrl+Shift+H 高亮
/// 的颜色写法与桌面 Ctrl+K 打开应用自己的链接对话框。

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

DiaryEditorController _document(List<Map<String, Object?>> blocks) {
  final controller = DiaryEditorController.fromContent(
    jsonEncode({
      'document': {'type': 'page', 'children': blocks},
    }),
  );
  addTearDown(controller.dispose);
  return controller;
}

Future<void> _pump(
  WidgetTester tester,
  DiaryEditorController controller, {
  FocusNode? focusNode,
  DiaryTypography typography = const DiaryTypography(),
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
            appearance: DiaryTextAppearance(typography: typography),
            focusNode: focusNode,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 正文里显示 [text] 的那段文字（不含占位提示）。首行缩进时段首的字换成
/// 占位，所以按去掉首字的部分匹配。
RichText _richText(WidgetTester tester, String text) => tester.widget<RichText>(
  find.byWidgetPredicate((widget) {
    if (widget is! RichText) return false;
    final plain = widget.text.toPlainText();
    return plain.length == text.length && plain.endsWith(text.substring(1));
  }),
);

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

void main() {
  for (final indent in [0.0, 2.0]) {
    testWidgets('justify renders TextAlign.justify on text blocks '
        '(first-line indent $indent)', (tester) async {
      final controller = _document([
        _block('paragraph', 'para', data: {'align': 'justify'}),
        _block('heading', 'head', data: {'align': 'justify', 'level': 2}),
        _block('bulleted_list', 'bullet', data: {'align': 'justify'}),
        _block('numbered_list', 'number', data: {'align': 'justify'}),
        _block(
          'todo_list',
          'todo',
          data: {'align': 'justify', 'checked': false},
        ),
        _block('quote', 'quote', data: {'align': 'justify'}),
        _block('paragraph', 'plain'),
        _block('paragraph', 'centered', data: {'align': 'center'}),
        _block('code', 'code', data: {'align': 'justify'}),
      ]);
      await _pump(
        tester,
        controller,
        typography: DiaryTypography(firstLineIndent: indent),
      );

      for (final text in [
        'para',
        'head',
        'bullet',
        'number',
        'todo',
        'quote',
      ]) {
        expect(
          _richText(tester, text).textAlign,
          TextAlign.justify,
          reason: text,
        );
      }
      // 不设对齐与居中照旧；代码按原文排版。
      expect(_richText(tester, 'plain').textAlign, TextAlign.start);
      expect(_richText(tester, 'centered').textAlign, TextAlign.center);
      expect(_richText(tester, 'code').textAlign, TextAlign.start);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('typing > and a space turns a paragraph into a quote', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final controller = _document([
      _block('paragraph', 'text', data: {'align': 'center'}),
    ]);
    controller.select(af.Selection.collapsed(af.Position(path: [0])));
    await _pump(tester, controller, focusNode: focus);
    focus.requestFocus();
    await tester.pumpAndSettle();

    await _type(tester, '>');
    expect(controller.document.nodeAtPath([0])!.delta!.toPlainText(), '>text');
    await _type(tester, ' ');

    final node = controller.document.nodeAtPath([0])!;
    expect(node.type, 'quote');
    expect(node.delta!.toPlainText(), 'text');
    expect(node.attributes['align'], 'center');

    // 转换本身一步撤销。
    controller.undo();
    await tester.pumpAndSettle();
    expect(controller.document.nodeAtPath([0])!.type, 'paragraph');
    expect(tester.takeException(), isNull);
  });

  testWidgets('> and a space stay literal inside a code block', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final controller = _document([_block('code', '')]);
    controller.select(af.Selection.collapsed(af.Position(path: [0])));
    await _pump(tester, controller, focusNode: focus);
    focus.requestFocus();
    await tester.pumpAndSettle();

    await _type(tester, '>');
    await _type(tester, ' ');

    final node = controller.document.nodeAtPath([0])!;
    expect(node.type, 'code');
    expect(node.delta!.toPlainText(), '> ');
    expect(tester.takeException(), isNull);
  });

  Future<void> shortcut(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool shift = false,
  }) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Ctrl+Shift+H writes the uppercase #AARRGGBB highlight and toggles off',
    (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final controller = _document([_block('paragraph', 'hello')]);
      await _pump(tester, controller, focusNode: focus);
      focus.requestFocus();
      await tester.pumpAndSettle();
      controller.select(
        af.Selection.single(path: [0], startOffset: 0, endOffset: 5),
      );
      await tester.pumpAndSettle();

      await shortcut(tester, LogicalKeyboardKey.keyH, shift: true);
      final ops = controller.document.nodeAtPath([0])!.delta!.toList();
      expect(ops.single.attributes, {'bg_color': '#66FFC107'});

      await shortcut(tester, LogicalKeyboardKey.keyH, shift: true);
      expect(
        controller.document.nodeAtPath([0])!.delta!.toList().single.attributes,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets('Ctrl+K on desktop opens the app link dialog', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final controller = _document([_block('paragraph', 'hello')]);
    await _pump(tester, controller, focusNode: focus);
    focus.requestFocus();
    await tester.pumpAndSettle();
    controller.select(
      af.Selection.single(path: [0], startOffset: 0, endOffset: 5),
    );
    await tester.pumpAndSettle();

    await shortcut(tester, LogicalKeyboardKey.keyK);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('链接'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'example.com');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(
      controller.document.nodeAtPath([0])!.delta!.toList().single.attributes,
      {'href': 'https://example.com'},
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}
