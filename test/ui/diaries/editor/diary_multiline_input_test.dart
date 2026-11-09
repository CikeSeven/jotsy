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
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_multiline_input_interceptor.dart';

import '../../../support/expressive_test_theme.dart';

/// 输入法一次上屏的多行文字（输入法剪贴板面板里的粘贴）与菜单粘贴同样落成
/// 块：Markdown 照样转换，普通文字每行一段（#222：以前几十段挤在一个块里）；
/// 打字、回车、只在末尾带换行的上屏、组字、代码块里的输入照旧交给上游。

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

/// 输入法以 [text] 替换编辑值里选中的文字（选中文字时点输入法剪贴板）。
Future<void> _replaceSelected(WidgetTester tester, String text) async {
  final state = tester.testTextInput.editingState!;
  final value = state['text'] as String;
  final base = state['selectionBase'] as int;
  final extent = state['selectionExtent'] as int;
  final start = base < extent ? base : extent;
  final end = base < extent ? extent : base;
  expect(end, greaterThan(start), reason: '编辑值里应有选中的文字');
  tester.testTextInput.updateEditingValue(
    TextEditingValue(
      text: value.replaceRange(start, end, text),
      selection: TextSelection.collapsed(offset: start + text.length),
    ),
  );
  await tester.pumpAndSettle();
}

List<String> _types(DiaryEditorController controller) => [
  for (final node in controller.document.root.children) node.type,
];

List<String> _texts(DiaryEditorController controller) => [
  for (final node in controller.document.root.children)
    node.delta?.toPlainText() ?? '',
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

  testWidgets('plain multi-line text becomes one paragraph per line', (
    tester,
  ) async {
    final controller = _document([_block('paragraph', '')]);
    await _focus(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [0])),
    );
    await _commit(tester, '今天天气好\r\n去散步\n\n第三段');
    expect(_types(controller), everyElement('paragraph'));
    expect(_texts(controller), ['今天天气好', '去散步', '', '第三段']);

    // 输入法跟上了新的插入点：接着打的字落在最后一段末尾。
    await _commit(tester, '。');
    expect(_texts(controller).last, '第三段。');

    // 一步撤销回到粘贴之前（先撤掉接着打的字）。
    controller.undo();
    await tester.pumpAndSettle();
    controller.undo();
    await tester.pumpAndSettle();
    expect(_texts(controller), ['']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plain lines committed mid-paragraph split around the caret', (
    tester,
  ) async {
    final controller = _document([_block('paragraph', '开头结尾')]);
    await _focus(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [0], offset: 2)),
    );
    await _commit(tester, '一\n二\n三');
    expect(_texts(controller), ['开头一', '二', '三结尾']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plain lines replacing selected text split into paragraphs', (
    tester,
  ) async {
    final controller = _document([_block('paragraph', '甲乙丙')]);
    await _focus(
      tester,
      controller,
      af.Selection.single(path: [0], startOffset: 1, endOffset: 2),
    );
    await _replaceSelected(tester, 'A\nB');
    expect(_texts(controller), ['甲A', 'B丙']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a single Enter still starts a new block', (tester) async {
    final controller = _document([_block('paragraph', '一')]);
    await _focus(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [0], offset: 1)),
    );
    await _commit(tester, '\n');
    expect(_texts(controller), ['一', '']);
    expect(tester.takeException(), isNull);
  });

  test(
    'plain text whose only line break is trailing stays with upstream',
    () async {
      final controller = _document([_block('paragraph', '')]);
      controller.select(af.Selection.collapsed(af.Position(path: [0])));
      final interceptor = DiaryMultilineInputInterceptor(controller);
      // 分不清是粘贴还是输入法把确认的字和回车一起上屏，照旧交给上游。
      for (final text in ['好的\n', '好的\r\n', ' \n']) {
        final handled = await interceptor.interceptInsert(
          TextEditingDeltaInsertion(
            oldText: '',
            textInserted: text,
            insertionOffset: 0,
            selection: TextSelection.collapsed(offset: text.length),
            composing: TextRange.empty,
          ),
          controller.state,
          const [],
        );
        expect(handled, isFalse, reason: text);
      }
      expect(_texts(controller), ['']);
    },
  );

  // 每条一个测试：上游原样插入时不回传编辑值，测试输入法里的编辑值停在
  // 上一次，同一测试里接着上屏会按旧值算差异。
  for (final text in ['\n# 不是标题\n- 也不是列表', '\n普通一行\n普通二行']) {
    testWidgets('multi-line text committed inside a code block stays literal '
        '(${text.split('\n')[1]})', (tester) async {
      final controller = _document([_block('code', 'x')]);
      await _focus(
        tester,
        controller,
        af.Selection.collapsed(af.Position(path: [0], offset: 1)),
      );
      await _commit(tester, text);
      expect(_types(controller), ['code']);
      expect(controller.plainText, 'x$text');
      expect(tester.takeException(), isNull);
    });
  }

  test('text still being composed is left to the input method', () async {
    final controller = _document([_block('paragraph', '')]);
    controller.select(af.Selection.collapsed(af.Position(path: [0])));
    final interceptor = DiaryMultilineInputInterceptor(controller);
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
