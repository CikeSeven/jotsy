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
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_markdown_input_interceptor.dart';

import '../../../support/expressive_test_theme.dart';

/// 输入法一次上屏的多行 Markdown（输入法剪贴板面板里的粘贴）与菜单粘贴
/// 同样转换；打字、回车、组字、代码块里的输入照旧交给上游。

DiaryEditorController _document(List<Map<String, Object?>> blocks) {
  final controller = DiaryEditorController.fromContent(
    jsonEncode({
      'document': {'type': 'page', 'children': blocks},
    }),
  );
  addTearDown(controller.dispose);
  return controller;
}

Map<String, Object?> _block(String type, String text) => {
  'type': type,
  'data': {
    'delta': [
      if (text.isNotEmpty) {'insert': text},
    ],
  },
};

/// 挂上编辑器并把光标放在 [selection]，取得输入法连接。
Future<void> _focus(
  WidgetTester tester,
  DiaryEditorController controller,
  af.Selection selection,
) async {
  final focus = FocusNode();
  addTearDown(focus.dispose);
  controller.select(selection);
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
            focusNode: focus,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  focus.requestFocus();
  await tester.pumpAndSettle();
}

/// 输入法在光标处一次上屏 [text]（与真机走同一条 updateEditingValue 链路）。
Future<void> _commit(WidgetTester tester, String text) async {
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

List<String> _types(DiaryEditorController controller) => [
  for (final node in controller.document.root.children) node.type,
];

void main() {
  testWidgets('a multi-line markdown commit converts like a paste', (
    tester,
  ) async {
    final controller = _document([_block('paragraph', '')]);
    await _focus(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [0])),
    );
    await _commit(tester, '# 标题\n**粗**体\n- a\n- b');
    expect(_types(controller), [
      'heading',
      'paragraph',
      'bulleted_list',
      'bulleted_list',
    ]);
    expect(controller.plainText, '标题\n粗体\na\nb');
    expect(controller.document.root.children.elementAt(1).delta!.toJson(), [
      {
        'insert': '粗',
        'attributes': {'bold': true},
      },
      {'insert': '体'},
    ]);
    // 一步撤销回到粘贴之前。
    controller.undo();
    await tester.pumpAndSettle();
    expect(controller.plainText, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plain multi-line text and a single Enter stay with upstream', (
    tester,
  ) async {
    final controller = _document([_block('paragraph', '')]);
    await _focus(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [0])),
    );
    await _commit(tester, '今天天气好\n去散步');
    expect(_types(controller), everyElement('paragraph'));
    expect(controller.plainText, '今天天气好\n去散步');

    final before = controller.document.root.children.length;
    await _commit(tester, '\n');
    expect(controller.document.root.children.length, before + 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('markdown committed inside a code block stays literal', (
    tester,
  ) async {
    final controller = _document([_block('code', 'x')]);
    await _focus(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [0], offset: 1)),
    );
    await _commit(tester, '\n# 不是标题\n- 也不是列表');
    expect(_types(controller), ['code']);
    expect(controller.plainText, 'x\n# 不是标题\n- 也不是列表');
    expect(tester.takeException(), isNull);
  });

  test('text still being composed is left to the input method', () async {
    final controller = _document([_block('paragraph', '')]);
    controller.select(af.Selection.collapsed(af.Position(path: [0])));
    final interceptor = DiaryMarkdownInputInterceptor(controller);
    const text = '# 标题\n- a\n- b';
    final handled = await interceptor.interceptInsert(
      const TextEditingDeltaInsertion(
        oldText: '',
        textInserted: text,
        insertionOffset: 0,
        selection: TextSelection.collapsed(offset: text.length),
        composing: TextRange(start: 0, end: text.length),
      ),
      controller.state,
      const [],
    );
    expect(handled, isFalse);
    expect(controller.plainText, isEmpty);
  });
}

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}
