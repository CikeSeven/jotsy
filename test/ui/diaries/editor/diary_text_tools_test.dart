import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
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

/// 编辑器的文字工具周边：两端对齐的渲染。

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
}

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}
