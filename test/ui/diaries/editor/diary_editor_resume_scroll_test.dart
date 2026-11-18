import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../support/diary_content_test_helpers.dart';

const double _keyboard = 300;

ScrollPosition _scrollPosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(DiaryEditor),
            matching: find.byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            ),
          )
          .first,
    )
    .position;

Future<void> _frames(WidgetTester tester, [int count = 8]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// 键盘逐帧升到 [to]（或降到 [to]），每帧一次度量变化，同真机的键盘动画。
Future<void> _animateKeyboard(
  WidgetTester tester, {
  required double from,
  required double to,
}) async {
  for (var step = 1; step <= 5; step++) {
    final inset = from + (to - from) * step / 5;
    tester.view.viewInsets = FakeViewPadding(bottom: inset);
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void _lifecycle(WidgetTester tester, List<AppLifecycleState> states) {
  for (final state in states) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

const _leave = [
  AppLifecycleState.inactive,
  AppLifecycleState.hidden,
  AppLifecycleState.paused,
];
const _back = [
  AppLifecycleState.hidden,
  AppLifecycleState.inactive,
  AppLifecycleState.resumed,
];

/// 长正文、键盘升着、滚到末尾，光标停在可见区域中部：此时离末尾不到一个
/// 键盘高，键盘一收起视口变高，滚动位置就会被夹回去。
Future<(DiaryEditorController, FocusNode)> _pumpEditingNearEnd(
  WidgetTester tester,
) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final focus = FocusNode();
  addTearDown(focus.dispose);
  final controller = DiaryEditorController(
    document: documentFromLegacyDelta([
      {'insert': '${List.generate(60, (i) => 'line $i').join('\n')}\n'},
    ]),
    selection: af.Selection.collapsed(af.Position(path: [0])),
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        af.AppFlowyEditorLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: nativeTestEditor(controller: controller, focusNode: focus),
      ),
    ),
  );
  focus.requestFocus();
  await _frames(tester);
  await _animateKeyboard(tester, from: 0, to: _keyboard);
  await _frames(tester);
  final position = _scrollPosition(tester);
  position.jumpTo(position.maxScrollExtent);
  await _frames(tester);
  // 选可见区域（屏幕顶端到键盘上沿再减去底部遮挡）中部的一行放光标。
  final nodes = controller.document.root.children;
  final middle = nodes.lastWhere((node) {
    final rect = node.rect;
    return rect.height > 0 && rect.center.dy > 180 && rect.center.dy < 320;
  });
  controller.select(af.Selection.collapsed(af.Position(path: middle.path)));
  await _frames(tester);
  return (controller, focus);
}

void main() {
  // 拉起键盘编辑时切到别的应用再切回来：离开时键盘收起，视口变高，靠近末尾
  // 的滚动位置被夹回去；回来键盘升起，揭示只把光标顶到键盘上方，停不回原
  // 处——整页像是自己往上滚了一截。键盘先收起还是应用先变为 inactive，两种
  // 顺序真机上都会出现。
  for (final keyboardFirst in [false, true]) {
    testWidgets('returning from another app restores the scroll offset '
        '(${keyboardFirst ? 'keyboard hides first' : 'lifecycle first'})', (
      tester,
    ) async {
      final (controller, _) = await _pumpEditingNearEnd(tester);
      final position = _scrollPosition(tester);
      final before = position.pixels;
      final caretBefore = controller.state.selectionRects().first.top;

      if (keyboardFirst) {
        await _animateKeyboard(tester, from: _keyboard, to: 0);
        _lifecycle(tester, _leave);
      } else {
        _lifecycle(tester, _leave);
        await _animateKeyboard(tester, from: _keyboard, to: 0);
      }
      await _frames(tester, 30);
      // 前提：离开时滚动位置确实被夹回去了。
      expect(position.pixels, lessThan(before - 100));

      _lifecycle(tester, _back);
      await _animateKeyboard(tester, from: 0, to: _keyboard);
      await _frames(tester, 30);

      expect(position.pixels, moreOrLessEquals(before, epsilon: 0.5));
      expect(
        controller.state.selectionRects().first.top,
        moreOrLessEquals(caretBefore, epsilon: 0.5),
      );
    });
  }

  // 回来后键盘还没升起就点了别处：按新的光标揭示，键盘升起途中也不跳回
  // 离开前的位置。
  testWidgets('a caret moved after returning is revealed instead of restored', (
    tester,
  ) async {
    final (controller, _) = await _pumpEditingNearEnd(tester);
    final position = _scrollPosition(tester);
    final before = position.pixels;

    _lifecycle(tester, _leave);
    await _animateKeyboard(tester, from: _keyboard, to: 0);
    await _frames(tester, 30);
    _lifecycle(tester, _back);
    controller.select(af.Selection.collapsed(af.Position(path: [10])));
    await _frames(tester);
    final rising = <double>[];
    for (var step = 1; step <= 5; step++) {
      tester.view.viewInsets = FakeViewPadding(bottom: _keyboard * step / 5);
      await tester.pump(const Duration(milliseconds: 16));
      rising.add(position.pixels);
    }
    await _frames(tester, 30);

    expect(rising, everyElement(lessThan(before - 300)));

    // 可见区域：屏幕顶端到键盘上沿减去底部遮挡（autoScrollEdgeOffset 80）。
    const visibleBottom = 800 - _keyboard - 80;
    final caret = controller.state.selectionRects().first;
    expect(caret.top, greaterThanOrEqualTo(-0.5));
    expect(caret.bottom, lessThanOrEqualTo(visibleBottom + 0.5));
    expect(position.pixels, lessThan(before - 300));
  });

  // 只是被通知栏、输入法弹窗这类短暂盖住，键盘没动：什么都不滚，一秒后
  // 放弃等待键盘。
  testWidgets('an inactive blip without keyboard changes leaves the page '
      'where it is', (tester) async {
    final (controller, _) = await _pumpEditingNearEnd(tester);
    final position = _scrollPosition(tester);
    final before = position.pixels;

    _lifecycle(tester, [AppLifecycleState.inactive]);
    await _frames(tester);
    _lifecycle(tester, [AppLifecycleState.resumed]);
    await tester.pump(const Duration(seconds: 2));
    await _frames(tester);

    expect(position.pixels, before);
    expect(controller.state.selection?.start.path, isNot([0]));
  });
}
