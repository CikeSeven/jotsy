import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/gestures.dart';
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
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor_selection_gestures.dart';
import 'package:node_diary/ui/widgets/text_selection_menu/app_text_context_menu.dart';

import '../../../support/expressive_test_theme.dart';

/// 代替上游手机选区服务（测试宿主上上游装的是桌面服务、不画把手）：记录
/// 收到的拖动坐标，每次移动把选区终点后移一个字，并像上游一样以 uiEvent
/// 交还选区。
class _FakeHandleDriver extends DiarySelectionHandleDriver {
  _FakeHandleDriver(this.controller, {this.extend = true});
  final DiaryEditorController controller;

  /// 为 false 时只记录坐标、不改选区（自动滚动的用例逐帧都会调用）。
  final bool extend;
  final starts = <(DiarySelectionHandleSide, Offset)>[];
  final updates = <Offset>[];
  int ends = 0;

  @override
  bool get available => true;

  @override
  void start(DragStartDetails details, DiarySelectionHandleSide side) =>
      starts.add((side, details.globalPosition));

  @override
  af.Selection? update(
    DragUpdateDetails details,
    DiarySelectionHandleSide side,
  ) {
    updates.add(details.globalPosition);
    if (!extend) return controller.state.selection;
    final current = controller.state.selection!.normalized;
    final next = af.Selection(
      start: current.start,
      end: current.end.copyWith(offset: current.end.offset + 1),
    );
    unawaited(
      controller.state.updateSelectionWithReason(
        next,
        reason: af.SelectionUpdateReason.uiEvent,
      ),
    );
    return next;
  }

  @override
  void end(DragEndDetails details, DiarySelectionHandleSide side) {
    ends++;
    unawaited(
      controller.state.updateSelectionWithReason(
        controller.state.selection,
        reason: af.SelectionUpdateReason.uiEvent,
        extraInfo: {af.selectionExtraInfoDoNotAttachTextService: false},
      ),
    );
  }
}

/// 第一段短到一行放得下（Ahem 字宽等于字号），第四段离第一段足够远。
const _content = 'alpha bravo\nline two\nline three\ncharlie delta echo';

void main() {
  late FocusNode focus;

  setUp(() {
    focus = FocusNode();
    // 把手拖动时的轻震走平台通道，测试里没有原生实现。
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

  Future<_FakeHandleDriver> pump(
    WidgetTester tester,
    DiaryEditorController controller, {
    bool extend = true,
  }) async {
    final driver = _FakeHandleDriver(controller, extend: extend);
    await pumpApp(
      tester,
      Scaffold(
        // 外面再套一层接上假服务的把手手势；编辑器自己那层在测试宿主上
        // 找不到手机选区服务，不接管触点。
        body: DiaryEditorSelectionGestures(
          controller: controller,
          driver: driver,
          child: DiaryEditor(
            controller: controller,
            appearance: const DiaryTextAppearance(
              typography: DiaryTypography(),
            ),
            focusNode: focus,
          ),
        ),
      ),
    );
    return driver;
  }

  /// 拖着手指停在 [to]，期间逐帧推进（自动滚动的每一步是一段 50ms 动画）。
  Future<TestGesture> dragAndHold(
    WidgetTester tester,
    Offset from,
    Offset to, {
    Duration hold = const Duration(seconds: 1),
  }) async {
    final gesture = await tester.startGesture(from);
    const steps = 10;
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy((to - from) / steps.toDouble());
      await tester.pump(const Duration(milliseconds: 16));
    }
    for (
      var t = Duration.zero;
      t < hold;
      t += const Duration(milliseconds: 16)
    ) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    return gesture;
  }

  Future<void> unmount(
    WidgetTester tester,
    DiaryEditorController controller,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Rect caretRect(DiaryEditorController controller, af.Position position) {
    final selectable = controller.document
        .nodeAtPath(position.path)!
        .selectable!;
    return selectable.transformRectToGlobal(
      selectable.getCursorRectInPosition(position)!,
    );
  }

  final menu = find.byType(AppTextSelectionToolbar);

  testWidgets(
    'selecting while a finger is down defers the phone menu until it lifts',
    (tester) async {
      final controller = DiaryEditorController.fromContent(_content);
      await pump(tester, controller);
      final gesture = await tester.startGesture(
        caretRect(controller, af.Position(path: [0], offset: 8)).center,
      );
      await tester.pump(const Duration(milliseconds: 200));

      // 长按选词与扩选：手指按着时选区一直在变，菜单不出来、让出放大镜。
      controller.select(
        af.Selection.single(path: [0], startOffset: 6, endOffset: 11),
      );
      await tester.pump();
      await tester.pump();
      expect(menu, findsNothing);
      controller.select(
        af.Selection.single(path: [0], startOffset: 0, endOffset: 11),
      );
      await tester.pump();
      await tester.pump();
      expect(menu, findsNothing);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(menu, findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester, controller);
    },
  );

  testWidgets(
    'dragging an end handle from below its ball hides the menu and keeps the '
    'end in place',
    (tester) async {
      final controller = DiaryEditorController.fromContent(_content);
      final driver = await pump(tester, controller);
      controller.select(
        af.Selection.single(path: [0], startOffset: 0, endOffset: 5),
      );
      await tester.pumpAndSettle();
      expect(menu, findsOneWidget);

      // 水滴下方 30px：上游把手自己的触控区只到水滴底边（文字下方 16px）。
      final caret = caretRect(controller, af.Position(path: [0], offset: 5));
      final gesture = await tester.startGesture(
        caret.bottomCenter + const Offset(8, 46),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      // 按住不动：既不交给正文长按，也还没开始拖，菜单照旧。
      expect(driver.starts, isEmpty);
      expect(menu, findsOneWidget);

      await gesture.moveBy(const Offset(6, 0));
      await tester.pump();
      await tester.pump();
      expect(driver.starts, hasLength(1));
      final (side, start) = driver.starts.single;
      expect(side, DiarySelectionHandleSide.end);
      // 从插入点中心开始、按手指的位移平移，而不是跳到手指所在的位置。
      expect(start, caret.center);
      expect(driver.updates.single, caret.center + const Offset(6, 0));
      expect(menu, findsNothing);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(driver.ends, 1);
      expect(
        controller.state.selection,
        af.Selection.single(path: [0], startOffset: 0, endOffset: 6),
      );
      expect(menu, findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester, controller);
    },
  );

  testWidgets('tapping a handle keeps the selection and the menu', (
    tester,
  ) async {
    final controller = DiaryEditorController.fromContent(_content);
    final driver = await pump(tester, controller);
    final range = af.Selection.single(path: [0], startOffset: 6, endOffset: 11);
    controller.select(range);
    await tester.pumpAndSettle();

    final caret = caretRect(controller, af.Position(path: [0], offset: 6));
    await tester.tapAt(caret.bottomCenter + const Offset(-8, 20));
    await tester.pumpAndSettle();
    expect(driver.starts, isEmpty);
    expect(driver.ends, 0);
    expect(controller.state.selection, range);
    expect(menu, findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester, controller);
  });

  testWidgets('touches outside the handles still reach the body', (
    tester,
  ) async {
    final controller = DiaryEditorController.fromContent(_content);
    final driver = await pump(tester, controller);
    controller.select(
      af.Selection.single(path: [0], startOffset: 6, endOffset: 11),
    );
    await tester.pumpAndSettle();

    final far = caretRect(controller, af.Position(path: [3], offset: 3));
    await tester.tapAt(far.center);
    await tester.pumpAndSettle();
    expect(driver.starts, isEmpty);
    expect(controller.state.selection?.isCollapsed, isTrue);
    expect(menu, findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester, controller);
  });

  testWidgets(
    'dragging a handle to the bottom edge scrolls the editor and keeps '
    'selecting as the text moves',
    (tester) async {
      final controller = DiaryEditorController.fromContent(
        List.generate(60, (i) => 'line $i alpha').join('\n'),
      );
      final driver = await pump(tester, controller, extend: false);
      controller.select(
        af.Selection.single(path: [2], startOffset: 0, endOffset: 4),
      );
      await tester.pumpAndSettle();
      final position = controller.state.scrollableState!.position;
      expect(position.pixels, 0);

      final caret = caretRect(controller, af.Position(path: [2], offset: 4));
      final gesture = await dragAndHold(
        tester,
        caret.bottomCenter + const Offset(8, 20),
        const Offset(200, 798),
      );
      final scrolled = position.pixels;
      expect(scrolled, greaterThan(100));
      // 手指停着，内容滚过时照样一路取选区；交给上游的位置夹在正文里。
      final held = driver.updates.length;
      await tester.pump(const Duration(milliseconds: 300));
      expect(position.pixels, greaterThan(scrolled));
      expect(driver.updates.length, greaterThan(held));
      expect(driver.updates.every((point) => point.dy < 800), isTrue);

      await gesture.up();
      await tester.pumpAndSettle();
      final stopped = position.pixels;
      await tester.pump(const Duration(milliseconds: 500));
      expect(position.pixels, stopped);
      expect(driver.ends, 1);
      expect(tester.takeException(), isNull);
      await unmount(tester, controller);
    },
  );

  testWidgets(
    'a reading-page handle scrolls the page up from under a pinned top bar',
    (tester) async {
      final controller = DiaryEditorController.fromContent(
        List.generate(60, (i) => 'line $i alpha').join('\n'),
        readOnly: true,
      );
      final driver = _FakeHandleDriver(controller, extend: false);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await pumpApp(
        tester,
        Scaffold(
          body: CustomScrollView(
            controller: scroll,
            slivers: [
              const SliverAppBar(pinned: true, title: Text('top bar')),
              SliverToBoxAdapter(
                child: DiaryEditorSelectionGestures(
                  controller: controller,
                  driver: driver,
                  pageScroll: true,
                  child: DiaryEditor(
                    controller: controller,
                    appearance: const DiaryTextAppearance(
                      typography: DiaryTypography(),
                    ),
                    shrinkWrap: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      scroll.jumpTo(400);
      await tester.pumpAndSettle();
      expect(scroll.offset, 400);
      final barBottom = tester.getRect(find.byType(AppBar)).bottom;
      // 取顶栏下方 150px 附近的一段，拖它的起点把手。
      final path = [
        for (var i = 0; i < 60; i++)
          if ((caretRect(controller, af.Position(path: [i])).top -
                      barBottom -
                      150)
                  .abs() <
              20)
            i,
      ].first;
      // 起点不在行首：行首的起点水滴挂在屏幕左缘之外。
      controller.select(
        af.Selection.single(path: [path], startOffset: 2, endOffset: 6),
      );
      await tester.pumpAndSettle();

      final caret = caretRect(controller, af.Position(path: [path], offset: 2));
      final gesture = await dragAndHold(
        tester,
        caret.bottomCenter + const Offset(-8, 20),
        Offset(200, barBottom - 20),
      );
      expect(driver.starts.single.$1, DiarySelectionHandleSide.start);
      expect(scroll.offset, lessThan(300));
      // 顶栏盖住的部分不算看得见：交给上游的位置不进顶栏。
      expect(driver.updates, isNotEmpty);
      expect(driver.updates.every((point) => point.dy > barBottom), isTrue);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(driver.ends, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await tester.pump(const Duration(milliseconds: 500));
    },
  );

  group('a hidden keyboard stays hidden', () {
    Future<void> dragEndHandle(
      WidgetTester tester,
      DiaryEditorController controller,
    ) async {
      final caret = caretRect(controller, af.Position(path: [0], offset: 5));
      final gesture = await tester.startGesture(
        caret.bottomCenter + const Offset(8, 20),
      );
      for (var i = 0; i < 3; i++) {
        await gesture.moveBy(const Offset(6, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    bool showed(WidgetTester tester) =>
        tester.testTextInput.log.any((call) => call.method == 'TextInput.show');

    testWidgets('while dragging a handle after the user hid it', (
      tester,
    ) async {
      final controller = DiaryEditorController.fromContent(_content);
      final driver = await pump(tester, controller);
      controller.select(
        af.Selection.single(path: [0], startOffset: 0, endOffset: 5),
      );
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
      // 用户收起键盘：连接还在。
      tester.testTextInput.hide();
      tester.testTextInput.log.clear();

      await dragEndHandle(tester, controller);
      expect(driver.updates, hasLength(3));
      expect(driver.ends, 1);
      expect(controller.state.selection!.end.offset, 8);
      expect(showed(tester), isFalse);
      expect(tester.testTextInput.isVisible, isFalse);

      // 之后照常：程序或点按换选区时上游重新接上并弹出。
      controller.select(af.Selection.collapsed(af.Position(path: [3])));
      await tester.pumpAndSettle();
      expect(showed(tester), isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(tester.takeException(), isNull);
      await unmount(tester, controller);
    });

    testWidgets('but a visible keyboard keeps following the handle', (
      tester,
    ) async {
      final controller = DiaryEditorController.fromContent(_content);
      await pump(tester, controller);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      controller.select(
        af.Selection.single(path: [0], startOffset: 0, endOffset: 5),
      );
      await tester.pumpAndSettle();
      tester.testTextInput.log.clear();

      await dragEndHandle(tester, controller);
      // 键盘本来就开着：输入法跟着新选区，接着打字落在新选区上。
      expect(showed(tester), isTrue);
      expect(tester.takeException(), isNull);
      await unmount(tester, controller);
    });

    testWidgets('when selecting all from the menu', (tester) async {
      final controller = DiaryEditorController.fromContent(_content);
      await pump(tester, controller);
      controller.select(
        af.Selection.single(path: [0], startOffset: 0, endOffset: 5),
      );
      await tester.pumpAndSettle();
      tester.testTextInput.hide();
      tester.testTextInput.log.clear();

      final labels = MaterialLocalizations.of(tester.element(menu));
      await tester.tap(find.text(labels.selectAllButtonLabel));
      await tester.pumpAndSettle();
      expect(controller.state.selection!.normalized.end.path, [3]);
      expect(showed(tester), isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.takeException(), isNull);
      await unmount(tester, controller);
    });

    test('holdingKeyboard only marks updates made inside it', () {
      final controller = DiaryEditorController.fromContent(_content);
      addTearDown(controller.dispose);
      final range = af.Selection.single(
        path: [0],
        startOffset: 0,
        endOffset: 5,
      );
      final result = controller.holdingKeyboard(() {
        unawaited(
          controller.state.updateSelectionWithReason(
            range,
            reason: af.SelectionUpdateReason.uiEvent,
            extraInfo: {
              af.selectionExtraInfoDoNotAttachTextService: false,
              af.selectionExtraInfoDisableFloatingToolbar: true,
            },
          ),
        );
        return 42;
      });
      expect(result, 42);
      // 补上“不接输入法”，其余信息原样保留。
      expect(controller.state.selectionExtraInfo, {
        af.selectionExtraInfoDoNotAttachTextService: true,
        af.selectionExtraInfoDisableFloatingToolbar: true,
      });

      unawaited(
        controller.state.updateSelectionWithReason(
          range,
          reason: af.SelectionUpdateReason.uiEvent,
          extraInfo: {af.selectionExtraInfoDoNotAttachTextService: false},
        ),
      );
      expect(controller.state.selectionExtraInfo, {
        af.selectionExtraInfoDoNotAttachTextService: false,
      });
    });
  });

  group('diarySelectionHandleTarget', () {
    const caret = Rect.fromLTWH(100, 200, 2, 30);

    test('android balls hang below the text with a tall touch zone', () {
      final end = diarySelectionHandleTarget(
        caret,
        DiarySelectionHandleSide.end,
        ios: false,
        ball: 8,
      );
      expect(end.ball, const Offset(109, 238));
      expect(end.zone, const Rect.fromLTRB(81, 214, 137, 278));
      final start = diarySelectionHandleTarget(
        caret,
        DiarySelectionHandleSide.start,
        ios: false,
        ball: 8,
      );
      expect(start.ball, const Offset(93, 238));
      // 自己的触控区不超出收缩正文在末行下方留出的高度。
      expect(start.zone.bottom, caret.bottom + kDiarySelectionHandleOverhang);
      expect(start.zone.width, 56);
    });

    test('the iOS start knob grows upward, the end knob downward', () {
      final start = diarySelectionHandleTarget(
        caret,
        DiarySelectionHandleSide.start,
        ios: true,
        ball: 8,
      );
      expect(start.ball, const Offset(101, 196));
      expect(start.zone, const Rect.fromLTRB(73, 152, 129, 220));
      final end = diarySelectionHandleTarget(
        caret,
        DiarySelectionHandleSide.end,
        ios: true,
        ball: 8,
      );
      expect(end.zone, const Rect.fromLTRB(73, 210, 129, 278));
    });
  });
}

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}
