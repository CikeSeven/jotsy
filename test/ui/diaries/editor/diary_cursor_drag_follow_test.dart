import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
// 模拟上游手机选区服务写进选区附加信息的拖动方式。
// ignore: implementation_imports
import 'package:appflowy_editor/src/editor/editor_component/service/selection/mobile_selection_service.dart'
    show MobileSelectionDragMode, selectionDragModeKey;
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
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_cursor_drag_follow.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor_selection_gestures.dart';

import '../../../support/expressive_test_theme.dart';

/// 编辑页拖选区到正文顶部曾经卡死：上游手机滚动服务不理会关掉的自动滚动，
/// 与选区手势自己的边缘滚动同时 animateTo 同一个滚动位置，互相顶掉对方的
/// 动画、在微任务里无限重来。测试宿主上上游装的是桌面服务（不画把手、不做
/// 长按选字），这里分别验证：整页可编辑正文不再交给上游滚动器；上游长按
/// 扩选的规则；长按后不松手拖到边缘时自动滚动并替上游扩选。
void main() {
  late FocusNode focus;

  setUp(() {
    focus = FocusNode();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  tearDown(() {
    focus.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diaryCodeBlockStyleProvider.overrideWith(() => _CodeStyle()),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            af.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget editor(DiaryEditorController controller, {bool shrinkWrap = false}) =>
      DiaryEditor(
        controller: controller,
        appearance: const DiaryTextAppearance(typography: DiaryTypography()),
        focusNode: focus,
        shrinkWrap: shrinkWrap,
      );

  Future<void> unmount(
    WidgetTester tester,
    DiaryEditorController controller,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await tester.pump(const Duration(milliseconds: 500));
  }

  String lines(int count) =>
      List.generate(count, (i) => 'line number $i here').join('\n');

  group('upstream auto scroll', () {
    testWidgets('is withheld from the full-page editable body', (tester) async {
      final controller = DiaryEditorController.fromContent(lines(40));
      await pumpApp(tester, Scaffold(body: editor(controller)));
      // 页面列表照常把滚动视图交给上游，但上游手机滚动服务取不到滚动器，
      // 选区变化后不会再与 DiaryEditorViewport / 选区手势争同一个滚动位置。
      expect(controller.state.scrollableState, isNotNull);
      expect(controller.state.disableAutoScroll, isTrue);
      expect(controller.state.autoScroller, isNull);
      await unmount(tester, controller);
    });
  });

  group('diaryLongPressWordSelection', () {
    final anchor = af.Selection(
      start: af.Position(path: [3], offset: 5),
      end: af.Position(path: [3], offset: 11),
    );
    af.Selection word(int path, int start, int end) => af.Selection(
      start: af.Position(path: [path], offset: start),
      end: af.Position(path: [path], offset: end),
    );

    test('extends from the pressed word to a later word', () {
      expect(
        diaryLongPressWordSelection(anchor, word(5, 0, 4)),
        af.Selection(
          start: anchor.start,
          end: af.Position(path: [5], offset: 4),
        ),
      );
      expect(
        diaryLongPressWordSelection(anchor, word(3, 12, 16)),
        af.Selection(
          start: anchor.start,
          end: af.Position(path: [3], offset: 16),
        ),
      );
    });

    test('extends from the pressed word back to an earlier word', () {
      expect(
        diaryLongPressWordSelection(anchor, word(1, 5, 11)),
        af.Selection(
          start: af.Position(path: [1], offset: 5),
          end: anchor.end,
        ),
      );
      expect(
        diaryLongPressWordSelection(anchor, word(3, 0, 4)),
        af.Selection(
          start: af.Position(path: [3], offset: 0),
          end: anchor.end,
        ),
      );
    });

    test('keeps only the pressed word while over it', () {
      expect(diaryLongPressWordSelection(anchor, anchor), anchor);
    });
  });

  group('a long press dragged to the edge', () {
    /// 编辑器本身不接触点（桌面服务的拖选与列表拖动会抢走这根手指），
    /// 透明层代替上游的长按手势占住触点；外层的选区手势只旁听触点，与真机上
    /// 外层旁听、上游长按手势占住触点相同。
    Future<void> pump(WidgetTester tester, DiaryEditorController controller) =>
        pumpApp(
          tester,
          Scaffold(
            body: DiaryEditorSelectionGestures(
              controller: controller,
              child: Stack(
                children: [
                  IgnorePointer(child: editor(controller)),
                  const Positioned.fill(
                    child: ColoredBox(color: Colors.transparent),
                  ),
                ],
              ),
            ),
          ),
        );

    /// 按上游 Android 长按开始时的写法选中 [point] 处的词。
    af.Selection pressWord(
      DiaryEditorController controller,
      Offset point, {
      bool cursorDrag = true,
    }) {
      final word = controller.state.service.selectionService
          .getNodeInOffset(point)!
          .selectable!
          .getWordBoundaryInOffset(point)!;
      unawaited(
        controller.state.updateSelectionWithReason(
          word,
          reason: af.SelectionUpdateReason.uiEvent,
          extraInfo: cursorDrag
              ? {
                  selectionDragModeKey: MobileSelectionDragMode.cursor,
                  af.selectionExtraInfoDisableFloatingToolbar: true,
                }
              : null,
        ),
      );
      return word;
    }

    Future<TestGesture> dragTo(
      WidgetTester tester,
      TestGesture gesture,
      Offset from,
      Offset to,
    ) async {
      const steps = 20;
      for (var i = 0; i < steps; i++) {
        await gesture.moveBy((to - from) / steps.toDouble());
        await tester.pump(const Duration(milliseconds: 16));
      }
      return gesture;
    }

    Future<void> hold(WidgetTester tester, Duration duration) async {
      for (
        var t = Duration.zero;
        t < duration;
        t += const Duration(milliseconds: 16)
      ) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    testWidgets(
      'scrolls up and keeps extending by words from the pressed word',
      (tester) async {
        final controller = DiaryEditorController.fromContent(lines(80));
        await pump(tester, controller);
        final position = controller.state.scrollableState!.position;
        position.jumpTo(800);
        await tester.pumpAndSettle();

        const press = Offset(100, 600);
        final gesture = await tester.startGesture(press);
        await tester.pump(const Duration(milliseconds: 500));
        final word = pressWord(controller, press);
        await tester.pump();
        await dragTo(tester, gesture, press, const Offset(100, 4));
        await hold(tester, const Duration(seconds: 3));

        // 一路滚到顶；手指没动，选区照样按词扩到首行，长按的词仍是另一端。
        expect(position.pixels, position.minScrollExtent);
        final selection = controller.state.selection!;
        expect(selection.start.path, [0]);
        expect(selection.end, word.end);
        expect(
          controller.state.selectionExtraInfo?[selectionDragModeKey],
          MobileSelectionDragMode.cursor,
        );

        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await unmount(tester, controller);
      },
    );

    testWidgets('stops scrolling when the finger lifts', (tester) async {
      final controller = DiaryEditorController.fromContent(lines(80));
      await pump(tester, controller);
      final position = controller.state.scrollableState!.position;
      position.jumpTo(800);
      await tester.pumpAndSettle();

      const press = Offset(100, 600);
      final gesture = await tester.startGesture(press);
      await tester.pump(const Duration(milliseconds: 500));
      pressWord(controller, press);
      await tester.pump();
      await dragTo(tester, gesture, press, const Offset(100, 4));
      await hold(tester, const Duration(milliseconds: 300));
      final scrolled = position.pixels;
      expect(scrolled, lessThan(800));

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
      final stopped = position.pixels;
      await hold(tester, const Duration(seconds: 1));
      expect(position.pixels, stopped);
      expect(stopped, greaterThan(position.minScrollExtent));
      expect(tester.takeException(), isNull);
      await unmount(tester, controller);
    });

    testWidgets('leaves other selections alone while a finger is down', (
      tester,
    ) async {
      final controller = DiaryEditorController.fromContent(lines(80));
      await pump(tester, controller);
      final position = controller.state.scrollableState!.position;
      position.jumpTo(800);
      await tester.pumpAndSettle();

      // 同样按着手指拖到顶，但选区不是上游插入点式拖动写下的：不跟随。
      const press = Offset(100, 600);
      final gesture = await tester.startGesture(press);
      await tester.pump(const Duration(milliseconds: 500));
      final word = pressWord(controller, press, cursorDrag: false);
      await tester.pump();
      await dragTo(tester, gesture, press, const Offset(100, 4));
      await hold(tester, const Duration(milliseconds: 500));

      expect(position.pixels, 800);
      expect(controller.state.selection, word);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await unmount(tester, controller);
    });
  });
}

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}
