import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/providers/diary_code_block_style_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';

import '../../../support/expressive_test_theme.dart';

void main() {
  const appearance = DiaryTextAppearance(typography: DiaryTypography());
  Future<void> pump(
    WidgetTester tester,
    DiaryEditorController controller, {
    bool inline = false,
    FocusNode? focusNode,
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diaryCodeBlockStyleProvider.overrideWith(() => _CodeStyle()),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(brightness),
          locale: const Locale('zh'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            af.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: inline
                ? SingleChildScrollView(
                    child: DiaryEditor(
                      controller: controller,
                      appearance: appearance,
                      shrinkWrap: true,
                      focusNode: focusNode,
                    ),
                  )
                : DiaryEditor(
                    controller: controller,
                    appearance: appearance,
                    focusNode: focusNode,
                  ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('native editor renders nested text and code in both themes', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      final controller = DiaryEditorController.fromContent(
        jsonEncode({
          'document': {
            'type': 'page',
            'children': [
              {
                'type': 'paragraph',
                'data': {
                  'delta': [
                    {'insert': '正文'},
                  ],
                },
                'children': [
                  {
                    'type': 'bulleted_list',
                    'data': {
                      'delta': [
                        {'insert': '嵌套列表'},
                      ],
                    },
                  },
                  {
                    'type': 'code',
                    'data': {
                      'delta': [
                        {'insert': 'print(1)\nprint(2)'},
                      ],
                      'language': 'python',
                    },
                  },
                ],
              },
            ],
          },
        }),
      );
      await pump(tester, controller, brightness: brightness);
      expect(find.byType(af.AppFlowyEditor), findsOneWidget);
      expect(find.text('Python'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets(
    'readonly editor measures its full height inside page scrolling',
    (tester) async {
      final controller = DiaryEditorController.fromContent(
        List.generate(30, (i) => '第 $i 段').join('\n'),
        readOnly: true,
      );
      await pump(tester, controller, inline: true);
      final editorSize = tester.getSize(find.byType(af.AppFlowyEditor));
      expect(editorSize.height, greaterThan(600));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  test(
    'formatting uses native transactions and preserves child nodes on undo',
    () {
      final controller = DiaryEditorController.fromContent('text');
      controller.select(
        af.Selection.single(path: [0], startOffset: 0, endOffset: 4),
      );
      controller.format('font_color', '#FF123456');
      expect(
        controller.document
            .nodeAtPath([0])!
            .delta!
            .first
            .attributes?['font_color'],
        '#FF123456',
      );
      controller.undo();
      expect(
        controller.document
            .nodeAtPath([0])!
            .delta!
            .first
            .attributes?['font_color'],
        isNull,
      );
      controller.dispose();
    },
  );
  testWidgets(
    'a paragraph handle moves its whole block and undo restores order',
    (tester) async {
      final controller = DiaryEditorController.fromContent(
        'first\nsecond\nthird',
      );
      await pump(tester, controller);
      final blocks = find.byType(af.ParagraphBlockComponentWidget);
      final source = find.byTooltip('拖动段落').first;
      final start = tester.getCenter(source);
      final target = tester.getBottomLeft(blocks.at(2)) + const Offset(100, -2);
      final gesture = await tester.startGesture(start);
      await tester.pump(kLongPressTimeout);
      await gesture.moveTo(target);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.plainText, 'second\nthird\nfirst');
      controller.undo();
      await tester.pumpAndSettle();
      expect(controller.plainText, 'first\nsecond\nthird');
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'soft keyboard triggers Markdown and searchable mobile slash commands',
    (tester) async {
      final focus = FocusNode();
      final controller = DiaryEditorController.fromContent('');
      controller.select(af.Selection.single(path: [0], startOffset: 0));
      await pump(tester, controller, focusNode: focus);
      focus.requestFocus();
      await tester.pump();
      expect(tester.testTextInput.hasAnyClients, isTrue);
      final prefix = tester.testTextInput.editingState!['text'] as String;
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: '$prefix#',
          selection: TextSelection.collapsed(offset: prefix.length + 1),
        ),
      );
      await tester.pump(const Duration(milliseconds: 20));
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: '$prefix# ',
          selection: TextSelection.collapsed(offset: prefix.length + 2),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.document.nodeAtPath([0])!.type, 'heading');
      controller.setBlockType('paragraph');
      await tester.pump(const Duration(milliseconds: 20));
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: '$prefix/',
          selection: TextSelection.collapsed(offset: prefix.length + 1),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('插入区块'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'code');
      await tester.pump();
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();
      expect(controller.document.nodeAtPath([0])!.type, 'code');
      expect(controller.plainText, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      focus.dispose();
    },
  );
}

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}
