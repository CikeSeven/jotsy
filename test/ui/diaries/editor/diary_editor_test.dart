import 'dart:async';
import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'
    show kDoubleTapTimeout, kLongPressTimeout;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_block_handle.dart';
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
    EdgeInsets padding = EdgeInsets.zero,
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
                    padding: padding,
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

  test('readonly sessions preserve initial noncollapsed selections', () {
    final range = af.Selection.single(path: [0], startOffset: 0, endOffset: 4);
    final controller = DiaryEditorController(
      document: diaryEditorDocument('只读正文 readonly body text'),
      selection: range,
      readOnly: true,
    );
    addTearDown(controller.dispose);
    expect(controller.state.selection, range);
    expect(controller.selection, range);
  });

  testWidgets('readonly text keeps selections but never leaves a caret', (
    tester,
  ) async {
    final controller = DiaryEditorController.fromContent(
      '只读正文 readonly body text',
      readOnly: true,
    );
    await pump(tester, controller, inline: true);
    final text = tester.getTopLeft(find.byType(af.AppFlowyEditor));
    await tester.tapAt(text + const Offset(40, 10));
    await tester.pump(kDoubleTapTimeout);
    expect(controller.state.selection, isNull);

    // 选中的文字照常保留，供复制。
    final range = af.Selection.single(path: [0], startOffset: 0, endOffset: 4);
    controller.select(range);
    await tester.pump();
    expect(controller.state.selection, range);

    // 拖动选区把手途中选区可能暂时折叠，拖动结束仍折叠才清掉。
    final collapsed = af.Selection.collapsed(af.Position(path: [0], offset: 2));
    unawaited(
      controller.state.updateSelectionWithReason(
        collapsed,
        reason: af.SelectionUpdateReason.uiEvent,
        extraInfo: {'selection_drag_mode': _DragMode.leftSelectionHandle},
      ),
    );
    await tester.pump();
    expect(controller.state.selection, collapsed);
    unawaited(
      controller.state.updateSelectionWithReason(
        collapsed,
        reason: af.SelectionUpdateReason.uiEvent,
        extraInfo: {'selection_drag_mode': _DragMode.none},
      ),
    );
    await tester.pump();
    expect(controller.state.selection, isNull);

    // 复制后收起选区同样不留光标。
    controller.select(range);
    controller.select(af.Selection.collapsed(range.end));
    await tester.pump();
    expect(controller.state.selection, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

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
    'the caret block handle drags its whole block and undo restores order',
    (tester) async {
      final focus = FocusNode();
      final controller = DiaryEditorController.fromContent(
        'first\nsecond\nthird',
      );
      controller.select(af.Selection.collapsed(af.Position(path: [0])));
      // 与编辑页相同的 16dp 页边距：顶层块的把手落在边距里。
      await pump(
        tester,
        controller,
        focusNode: focus,
        padding: const EdgeInsets.symmetric(horizontal: 16),
      );
      final handle = find.byType(DiaryBlockHandle);
      // 没有焦点时不显示把手：阅读与浏览时正文左侧保持干净。
      expect(handle, findsNothing);
      focus.requestFocus();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(handle, findsOneWidget);
      final blocks = find.byType(af.ParagraphBlockComponentWidget);
      // 把手在第一段左侧、与它的首行同高，不占正文的宽度。
      expect(
        tester.getCenter(handle).dx,
        lessThan(tester.getTopLeft(blocks.at(0)).dx),
      );
      expect(
        (tester.getCenter(handle).dy - tester.getCenter(blocks.at(0)).dy).abs(),
        lessThan(4),
      );

      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      final target = tester.getBottomLeft(blocks.at(2)) + const Offset(100, -2);
      await gesture.moveTo(target - const Offset(0, 10));
      await tester.pump();
      await gesture.moveTo(target);
      await tester.pump();
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(controller.plainText, 'second\nthird\nfirst');
      // 光标落在被移动块的末尾，可以接着写。
      expect(
        controller.selection,
        af.Selection.collapsed(af.Position(path: [2], offset: 5)),
      );
      controller.undo();
      await tester.pump();
      expect(controller.plainText, 'first\nsecond\nthird');
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      focus.dispose();
    },
  );

  testWidgets(
    'the handle menu offers drag between move up and move down and holding it drags the block',
    (tester) async {
      final focus = FocusNode();
      final controller = DiaryEditorController.fromContent(
        'first\nsecond\nthird',
      );
      controller.select(af.Selection.collapsed(af.Position(path: [0])));
      await pump(
        tester,
        controller,
        focusNode: focus,
        padding: const EdgeInsets.symmetric(horizontal: 16),
      );
      focus.requestFocus();
      Future<void> frames([int count = 6]) async {
        for (var i = 0; i < count; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      await frames(4);
      final handle = find.byType(DiaryBlockHandle);
      await tester.tap(handle);
      await frames();
      final up = find.text('上移段落');
      final drag = find.text('拖动段落');
      final down = find.text('下移段落');
      expect(drag, findsOneWidget);
      expect(find.text('长按'), findsOneWidget);
      // 拖动在上移与下移之间。
      expect(tester.getCenter(up).dy, lessThan(tester.getCenter(drag).dy));
      expect(tester.getCenter(drag).dy, lessThan(tester.getCenter(down).dy));

      // 轻点只收起菜单并提示长按，不移动任何段落。
      await tester.tap(drag);
      await frames();
      expect(drag, findsNothing);
      expect(find.text('长按“拖动段落”或左侧把手，拖到目标位置后松手'), findsOneWidget);
      expect(controller.plainText, 'first\nsecond\nthird');

      await tester.tap(handle);
      await frames();
      final gesture = await tester.startGesture(tester.getCenter(drag));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      // 长按生效即收起菜单，拖动不随菜单项卸载而中断。
      await frames();
      expect(drag, findsNothing);
      expect(find.byType(DiaryBlockDragFeedback), findsOneWidget);
      final blocks = find.byType(af.ParagraphBlockComponentWidget);
      final target = tester.getBottomLeft(blocks.at(2)) + const Offset(100, -2);
      await gesture.moveTo(target - const Offset(0, 10));
      await tester.pump();
      await gesture.moveTo(target);
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(find.byType(DiaryBlockDragFeedback), findsNothing);
      expect(controller.plainText, 'second\nthird\nfirst');
      controller.undo();
      await tester.pump();
      expect(controller.plainText, 'first\nsecond\nthird');

      // 系统取消指针时只放下，不移动。
      await frames();
      controller.select(af.Selection.collapsed(af.Position(path: [0])));
      focus.requestFocus();
      await frames(4);
      final again = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await again.moveTo(target);
      await tester.pump();
      await again.cancel();
      await tester.pump();
      expect(find.byType(DiaryBlockDragFeedback), findsNothing);
      expect(controller.plainText, 'first\nsecond\nthird');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
      controller.dispose();
      focus.dispose();
    },
  );

  testWidgets(
    'soft keyboard triggers Markdown and the inline slash command menu',
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
      Future<void> type(String text) async {
        tester.testTextInput.updateEditingValue(
          TextEditingValue(
            text: '$prefix$text',
            selection: TextSelection.collapsed(
              offset: prefix.length + text.length,
            ),
          ),
        );
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      // `/` 打开内联菜单，焦点留在正文（键盘不收起）。
      await type('/');
      expect(find.text('一级标题'), findsOneWidget);
      expect(focus.hasFocus, isTrue);
      // 斜杠后接着输入的文字就是筛选词。
      await type('/代码');
      expect(find.text('一级标题'), findsNothing);
      await tester.tap(find.textContaining('代码块'));
      await tester.pump();
      expect(controller.document.nodeAtPath([0])!.type, 'code');
      // 执行时删掉 `/筛选词`。
      expect(controller.plainText, isEmpty);
      expect(focus.hasFocus, isTrue);

      // 没有匹配项时以空格结束会话，已输入的文字原样保留。
      controller.setBlockType('paragraph');
      await tester.pump(const Duration(milliseconds: 20));
      final again = tester.testTextInput.editingState!['text'] as String;
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: '$again/',
          selection: TextSelection.collapsed(offset: again.length + 1),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('一级标题'), findsOneWidget);
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: '$again/xyz ',
          selection: TextSelection.collapsed(offset: again.length + 5),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('一级标题'), findsNothing);
      expect(
        controller.document.nodeAtPath([0])!.delta!.toPlainText(),
        '/xyz ',
      );
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

/// 与上游未导出的 MobileSelectionDragMode 同名的取值。
enum _DragMode { none, leftSelectionHandle }
