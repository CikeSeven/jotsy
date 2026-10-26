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
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_block_markers.dart';
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

      final grab = tester.getCenter(handle);
      final gesture = await tester.startGesture(grab);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      final target = tester.getBottomLeft(blocks.at(2)) + const Offset(100, -2);
      await gesture.moveTo(target - const Offset(0, 10));
      await tester.pump();
      await gesture.moveTo(target);
      await tester.pump();
      await tester.pump();
      // 实时预览：松手前正文已经是移动后的样子，但还不进撤销栈。
      expect(controller.plainText, 'second\nthird\nfirst');
      expect(controller.hasUndo, isFalse);
      // 把手跟着手指上下走（不随块一格一格跳），横向留在页边距里。
      expect(tester.getCenter(handle).dy, moreOrLessEquals(target.dy));
      expect(tester.getCenter(handle).dx, grab.dx);
      await gesture.up();
      await tester.pump();
      expect(controller.plainText, 'second\nthird\nfirst');
      // 光标落在被移动块的末尾，可以接着写。
      expect(
        controller.selection,
        af.Selection.collapsed(af.Position(path: [2], offset: 5)),
      );
      // 整次拖动只占一步撤销。
      controller.undo();
      await tester.pump();
      expect(controller.plainText, 'first\nsecond\nthird');
      expect(controller.hasUndo, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      focus.dispose();
    },
  );

  testWidgets(
    'holding the menu drag item folds the menu into a chip that follows the finger',
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
      final drag = find.text('长按拖动');
      final down = find.text('下移段落');
      expect(drag, findsOneWidget);
      // 拖动在上移与下移之间。
      expect(tester.getCenter(up).dy, lessThan(tester.getCenter(drag).dy));
      expect(tester.getCenter(drag).dy, lessThan(tester.getCenter(down).dy));

      // 轻点只收起菜单并提示用法，不移动任何段落。
      await tester.tap(drag);
      await frames();
      expect(drag, findsNothing);
      expect(find.text('按住“长按拖动”后上下滑动，段落会跟着移动；也可以直接长按左侧把手'), findsOneWidget);
      expect(controller.plainText, 'first\nsecond\nthird');

      await tester.tap(handle);
      await frames();
      final blocks = find.byType(af.ParagraphBlockComponentWidget);
      final item = tester.getCenter(drag);
      final handleAt = tester.getCenter(handle);
      double handleOpacity() => tester
          .widget<AnimatedOpacity>(
            find.descendant(of: handle, matching: find.byType(AnimatedOpacity)),
          )
          .opacity;
      // 手指在块下方几行：落点按位移找，长按生效时块不跳。
      final gesture = await tester.startGesture(item);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, 1));
      await frames();
      expect(controller.plainText, 'first\nsecond\nthird');
      // 菜单收起，上移 / 下移不再出现；“长按拖动”留在手指下，把手隐去。
      expect(up, findsNothing);
      expect(down, findsNothing);
      expect(drag, findsOneWidget);
      expect(tester.getCenter(drag), item + const Offset(0, 1));
      expect(handleOpacity(), 0);
      // 往下滑过两段：拖动条跟着手指，块在正文里跟着挪。
      final travel = tester.getBottomLeft(blocks.at(2)).dy - 4 - handleAt.dy;
      for (var step = 1; step <= 6; step++) {
        await gesture.moveTo(item + Offset(0, travel * step / 6));
        await tester.pump();
        await tester.pump();
      }
      expect(controller.plainText, 'second\nthird\nfirst');
      expect(controller.hasUndo, isFalse);
      expect(tester.getCenter(drag), item + Offset(0, travel));
      await gesture.up();
      await tester.pump();
      // 松手后拖动条淡出，把手回到块上。
      await frames();
      expect(drag, findsNothing);
      expect(handleOpacity(), 1);
      expect(controller.plainText, 'second\nthird\nfirst');
      expect(
        (tester.getCenter(handle).dy - tester.getCenter(blocks.at(2)).dy).abs(),
        lessThan(4),
      );
      controller.undo();
      await tester.pump();
      expect(controller.plainText, 'first\nsecond\nthird');
      expect(controller.hasUndo, isFalse);

      // 系统取消指针时放回原处。
      await frames();
      controller.select(af.Selection.collapsed(af.Position(path: [0])));
      focus.requestFocus();
      await frames(4);
      final again = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await again.moveTo(
        tester.getBottomLeft(blocks.at(2)) + const Offset(100, -2),
      );
      await tester.pump();
      await tester.pump();
      expect(controller.plainText, isNot('first\nsecond\nthird'));
      await again.cancel();
      await tester.pump();
      expect(controller.plainText, 'first\nsecond\nthird');
      expect(controller.hasUndo, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
      controller.dispose();
      focus.dispose();
    },
  );

  testWidgets(
    'the block handle lines up with the first-line marker and stays in the page margin',
    (tester) async {
      final focus = FocusNode();
      final controller = DiaryEditorController.fromContent(
        jsonEncode({
          'document': {
            'type': 'page',
            'children': [
              {
                'type': 'bulleted_list',
                'data': {
                  'delta': [
                    // 折成多行：首行光标比文字多出下方半个行距，不能拿它居中。
                    {'insert': List.filled(120, 'x').join()},
                  ],
                },
                'children': [
                  {
                    'type': 'bulleted_list',
                    'data': {
                      'delta': [
                        {'insert': 'child'},
                      ],
                    },
                  },
                ],
              },
            ],
          },
        }),
      );
      controller.select(af.Selection.collapsed(af.Position(path: [0])));
      await pump(
        tester,
        controller,
        focusNode: focus,
        padding: const EdgeInsets.symmetric(horizontal: 16),
      );
      focus.requestFocus();
      Future<void> frames() async {
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      await frames();
      final handle = find.byType(DiaryBlockHandle);
      Finder dot(int index) => find.descendant(
        of: find.byType(DiaryBulletMarker).at(index),
        matching: find.byType(DecoratedBox),
      );
      // 把手与圆点同高：都落在首行的字形中线上。
      expect(
        tester.getCenter(handle).dy,
        moreOrLessEquals(tester.getCenter(dot(0)).dy, epsilon: 0.5),
      );
      final topLevelX = tester.getCenter(handle).dx;
      // 顶层块的把手在 16dp 页面左边距里，紧贴正文左边界。
      expect(
        tester.getRect(handle).right - diaryBlockHandleHitSlop.right,
        moreOrLessEquals(16, epsilon: 0.5),
      );

      controller.select(af.Selection.collapsed(af.Position(path: [0, 0])));
      await frames();
      expect(
        tester.getCenter(handle).dy,
        moreOrLessEquals(tester.getCenter(dot(1)).dy, epsilon: 0.5),
      );
      // 缩进的块：把手不跟着缩进，仍在页面左边距的同一竖列。
      expect(tester.getCenter(handle).dx, topLevelX);

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      focus.dispose();
    },
  );

  testWidgets(
    'dragging an indented paragraph out of its parent keeps it indented',
    (tester) async {
      final focus = FocusNode();
      Map<String, Object?> paragraph(
        String text, [
        List<Map<String, Object?>> children = const [],
      ]) => {
        'type': 'paragraph',
        'data': {
          'delta': [
            {'insert': text},
          ],
        },
        if (children.isNotEmpty) 'children': children,
      };
      final controller = DiaryEditorController.fromContent(
        jsonEncode({
          'document': {
            'type': 'page',
            'children': [
              paragraph('parent', [paragraph('child')]),
              paragraph('next'),
              paragraph('last'),
            ],
          },
        }),
      );
      final before = controller.contentJson;
      controller.select(af.Selection.collapsed(af.Position(path: [0, 0])));
      await pump(
        tester,
        controller,
        focusNode: focus,
        padding: const EdgeInsets.symmetric(horizontal: 16),
      );
      focus.requestFocus();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final next = tester.getRect(
        find.ancestor(
          of: find.descendant(
            of: find.byType(af.AppFlowyRichText),
            matching: find.text('next', findRichText: true),
          ),
          matching: find.byType(af.ParagraphBlockComponentWidget),
        ),
      );
      final start = tester.getCenter(find.byType(DiaryBlockHandle));
      final gesture = await tester.startGesture(start);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      // 拖到下一段的下半区：落在它之后，仍缩进一级（成为它的子块），
      // 而不是变回顶层段落。
      final travel = next.bottom - 4 - start.dy;
      for (var step = 1; step <= 6; step++) {
        await gesture.moveTo(start + Offset(0, travel * step / 6));
        await tester.pump();
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
      String text(af.Path path) =>
          controller.document.nodeAtPath(path)!.delta!.toPlainText();
      expect(controller.document.nodeAtPath([0])!.children, isEmpty);
      expect(text([1]), 'next');
      expect(text([1, 0]), 'child');
      expect(text([2]), 'last');
      controller.undo();
      await tester.pump();
      expect(controller.contentJson, before);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
      controller.dispose();
      focus.dispose();
    },
  );

  testWidgets(
    'the dragged block and its handle follow the finger while the page scrolls',
    (tester) async {
      final focus = FocusNode();
      final lines = List.generate(40, (i) => 'line $i').join('\n');
      final controller = DiaryEditorController.fromContent(lines);
      controller.select(af.Selection.collapsed(af.Position(path: [1])));
      await pump(
        tester,
        controller,
        focusNode: focus,
        padding: const EdgeInsets.symmetric(horizontal: 16),
      );
      focus.requestFocus();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final handle = find.byType(DiaryBlockHandle);
      final block = find.descendant(
        of: find.byType(af.AppFlowyRichText),
        matching: find.text('line 1', findRichText: true),
      );
      final finger = tester.getCenter(handle);
      final gesture = await tester.startGesture(finger);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      final position = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(DiaryEditor),
                  matching: find.byWidgetPredicate(
                    (w) =>
                        w is Scrollable &&
                        w.axisDirection == AxisDirection.down,
                  ),
                )
                .first,
          )
          .position;
      // 手指不动、页面滚动：块随落点挪到手指旁，把手停在手指下。
      for (final offset in [30.0, 600.0]) {
        position.jumpTo(offset);
        for (var i = 0; i < 3; i++) {
          await tester.pump();
        }
        final rect = tester.getRect(
          find.ancestor(
            of: block,
            matching: find.byType(af.ParagraphBlockComponentWidget),
          ),
        );
        // 块落在离手指最近的位置：手指在它身上，或在相邻块靠它的半边。
        expect(
          (rect.center.dy - finger.dy).abs(),
          lessThanOrEqualTo(rect.height),
        );
        expect(tester.getCenter(handle), finger);
      }
      expect(controller.plainText, isNot(lines));
      await gesture.cancel();
      await tester.pump();
      expect(controller.plainText, lines);

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      focus.dispose();
    },
  );

  testWidgets(
    'moving the list anchor block upward keeps the rest of the page in place',
    (tester) async {
      final focus = FocusNode();
      final controller = DiaryEditorController.fromContent(
        List.generate(
          60,
          (i) => i == 42 ? 'line $i ${List.filled(60, '长').join()}' : 'line $i',
        ).join('\n'),
      );
      controller.select(af.Selection.collapsed(af.Position(path: [0])));
      await pump(
        tester,
        controller,
        focusNode: focus,
        padding: const EdgeInsets.symmetric(horizontal: 16),
      );
      focus.requestFocus();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      // 列表跳转到某一块后就以它为锚点排版（编辑页揭示光标就是这样跳的）。
      tester
          .widget<af.AppFlowyEditor>(find.byType(af.AppFlowyEditor))
          .editorScrollController!
          .itemScrollController
          .jumpTo(index: 42, alignment: 0.3);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final source = controller.document.nodeAtPath([42])!;
      final previous = controller.document.nodeAtPath([41])!;
      expect(source.rect, isNot(Rect.zero));
      await tester.tapAt(source.rect.topLeft + const Offset(20, 8));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final handle = find.byType(DiaryBlockHandle);
      final previousTop = previous.rect.top;
      // 高块：它占着锚点时直接换位，整页会按两块的高度差错开。
      expect(source.rect.height, greaterThan(previous.rect.height * 1.5));

      final start = tester.getCenter(handle);
      final gesture = await tester.startGesture(start);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      for (var dy = 2.0; source.path.first == 42 && dy < 60; dy += 2) {
        await gesture.moveTo(start - Offset(0, dy));
        await tester.pump();
        await tester.pump();
      }
      expect(source.path, [41]);
      // 与普通列表一样：块接替上一块的位置，上一块正好让出它的高度。
      expect(source.rect.top, moreOrLessEquals(previousTop, epsilon: 1));
      expect(
        previous.rect.top,
        moreOrLessEquals(previousTop + source.rect.height, epsilon: 1),
      );
      await gesture.cancel();
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      focus.dispose();
    },
  );

  testWidgets(
    'holding a dragged block at the top edge scrolls the page instead of hiding the block',
    (tester) async {
      final focus = FocusNode();
      final lines = List.generate(60, (i) => 'line $i').join('\n');
      final controller = DiaryEditorController.fromContent(lines);
      controller.select(af.Selection.collapsed(af.Position(path: [0])));
      await pump(
        tester,
        controller,
        focusNode: focus,
        padding: const EdgeInsets.symmetric(horizontal: 16),
      );
      focus.requestFocus();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final scrollable = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(DiaryEditor),
              matching: find.byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              ),
            )
            .first,
      );
      scrollable.position.jumpTo(
        30 * controller.document.root.children.first.rect.height,
      );
      await tester.pump();
      await tester.pump();
      final source = controller.document.root.children.firstWhere(
        (node) => node.rect.top > 200,
      );
      await tester.tapAt(source.rect.topLeft + const Offset(20, 8));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final from = source.path.first;
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(DiaryBlockHandle)),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveTo(const Offset(8, 1));
      // 按住不动：页面自动往回滚，块一路往前挪，从不回头；它停在视口顶边
      // （滚动中可能半露），不会挪到视口外看不见的地方。
      var last = from;
      for (var frame = 0; frame < 400 && source.path.first > 0; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        final index = source.path.first;
        expect(index, lessThanOrEqualTo(last));
        last = index;
        final rect = source.rect;
        if (rect != Rect.zero) expect(rect.bottom, greaterThan(0));
      }
      expect(source.path, [0]);
      await gesture.up();
      await tester.pump();
      expect(controller.plainText.split('\n').first, 'line $from');
      expect(controller.hasUndo, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
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
