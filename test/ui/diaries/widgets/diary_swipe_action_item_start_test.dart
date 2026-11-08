import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/diaries/widgets/diary_swipe_action_background.dart';
import 'package:node_diary/ui/diaries/widgets/diary_swipe_action_item.dart';

import '../../../support/expressive_test_theme.dart';

// 行首动作（右滑，LTR 下从左往右）的回归：没传时与只有左滑时一致，传了时与
// 左滑完全镜像，且同一次拖动可以越过原位换侧。卡片宽 360，阈值 0.4 即 144。

const _itemWidth = 360.0;
const _itemHeight = 144.0;
const _radius = 24.0;
const _cardKey = ValueKey<String>('card');

/// 记录 HapticFeedback 调用（走 SystemChannels.platform）。
List<Object?> _recordHaptics(WidgetTester tester) {
  final calls = <Object?>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return calls;
}

ColorScheme get _scheme => expressiveTestTheme(Brightness.light).colorScheme;

/// 回调计数：分别记录行尾（左滑）与行首（右滑）动作。
class _Calls {
  int end = 0;
  int start = 0;
}

SwipeActionSpec _completeAction(_Calls calls) => SwipeActionSpec(
  icon: FontAwesomeIcons.check,
  actionColor: _scheme.primaryContainer,
  actionIconColor: _scheme.onPrimaryContainer,
  onSwiped: () => calls.start++,
);

Widget _host(
  _Calls calls, {
  bool withStartAction = true,
  TextDirection textDirection = TextDirection.ltr,
}) {
  final theme = expressiveTestTheme(Brightness.light);
  return MaterialApp(
    theme: theme,
    home: Directionality(
      textDirection: textDirection,
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: _itemWidth,
            height: _itemHeight,
            child: DiarySwipeActionItem(
              diaryId: 'todo-1',
              enabled: true,
              icon: FontAwesomeIcons.trashCan,
              actionColor: theme.colorScheme.errorContainer,
              actionIconColor: theme.colorScheme.onErrorContainer,
              borderRadius: _radius,
              onSwiped: () => calls.end++,
              startAction: withStartAction ? _completeAction(calls) : null,
              child: Container(key: _cardKey, color: theme.colorScheme.surface),
            ),
          ),
        ),
      ),
    ),
  );
}

Color? _colorOf(WidgetTester tester, Key surfaceKey) {
  final box = tester.widget<DecoratedBox>(find.byKey(surfaceKey));
  return (box.decoration as BoxDecoration).color;
}

Finder _iconIn(Key surfaceKey) =>
    find.descendant(of: find.byKey(surfaceKey), matching: find.byType(FaIcon));

Future<TestGesture> _startSwipe(WidgetTester tester) =>
    tester.startGesture(tester.getCenter(find.byKey(_cardKey)));

void main() {
  const startKey = DiarySwipeActionItem.startBackgroundKey;
  const endKey = DiarySwipeActionItem.backgroundKey;

  testWidgets('without a start action, dragging right leaves the card in '
      'place and triggers nothing', (tester) async {
    final haptics = _recordHaptics(tester);
    final calls = _Calls();
    await tester.pumpWidget(_host(calls, withStartAction: false));
    final restingOrigin = tester.getTopLeft(find.byKey(_cardKey));
    // 不多建行首背景这一层：子树与只有左滑时相同。
    expect(find.byType(DiarySwipeActionBackground), findsOneWidget);

    final gesture = await _startSwipe(tester);
    await gesture.moveBy(const Offset(_itemWidth * 0.6, 0));
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(_cardKey)), restingOrigin);
    expect(find.byKey(endKey), findsNothing);
    expect(find.byKey(startKey), findsNothing);
    await gesture.up();
    await tester.pumpAndSettle();

    // 快速右甩同样不触发。
    await tester.fling(find.byKey(_cardKey), const Offset(300, 0), 3000);
    await tester.pumpAndSettle();

    expect(calls.end, 0);
    expect(calls.start, 0);
    expect(haptics, isEmpty);
    expect(tester.getTopLeft(find.byKey(_cardKey)), restingOrigin);
  });

  testWidgets('dragging right past the threshold arms the start action and '
      'releasing slides out, collapses, then completes it once', (
    tester,
  ) async {
    final haptics = _recordHaptics(tester);
    final calls = _Calls();
    await tester.pumpWidget(_host(calls));
    final restingOrigin = tester.getTopLeft(find.byKey(_cardKey));
    expect(find.byType(DiarySwipeActionBackground), findsNWidgets(2));
    expect(find.byKey(startKey), findsNothing);

    final gesture = await _startSwipe(tester);
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    // 卡片跟手右移，左侧露出弱化底色的行首背景，图标靠左；行尾背景不画。
    expect(
      tester.getTopLeft(find.byKey(_cardKey)),
      restingOrigin + const Offset(40, 0),
    );
    expect(find.byKey(endKey), findsNothing);
    expect(_colorOf(tester, startKey), _scheme.surfaceContainerHighest);
    expect(
      tester.getCenter(_iconIn(startKey)).dx,
      lessThan(restingOrigin.dx + 60),
    );
    expect(haptics, isEmpty);

    await gesture.moveBy(const Offset(140, 0));
    await tester.pumpAndSettle();
    expect(_colorOf(tester, startKey), _scheme.primaryContainer);
    expect(haptics, <Object?>['HapticFeedbackType.lightImpact']);

    await gesture.up();
    await tester.pump();
    // 滑出途中还没回调，背景仍在。
    expect(calls.start, 0);
    expect(find.byKey(startKey), findsOneWidget);

    await tester.pumpAndSettle();
    expect(calls.start, 1);
    expect(calls.end, 0);
    expect(find.byKey(_cardKey), findsNothing);
  });

  testWidgets('releasing a right drag short of the threshold springs back '
      'without triggering', (tester) async {
    final haptics = _recordHaptics(tester);
    final calls = _Calls();
    await tester.pumpWidget(_host(calls));
    final restingOrigin = tester.getTopLeft(find.byKey(_cardKey));

    final gesture = await _startSwipe(tester);
    await gesture.moveBy(const Offset(180, 0));
    await tester.pumpAndSettle();
    expect(_colorOf(tester, startKey), _scheme.primaryContainer);

    // 拖回阈值以下：恢复弱化态，可以反悔。
    await gesture.moveBy(const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(_colorOf(tester, startKey), _scheme.surfaceContainerHighest);
    expect(haptics, hasLength(1));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(calls.start, 0);
    expect(calls.end, 0);
    expect(tester.getTopLeft(find.byKey(_cardKey)), restingOrigin);
    expect(find.byKey(startKey), findsNothing);
  });

  testWidgets('a mostly vertical right drag never arms the start action', (
    tester,
  ) async {
    final haptics = _recordHaptics(tester);
    final calls = _Calls();
    await tester.pumpWidget(_host(calls));

    final gesture = await _startSwipe(tester);
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(140, -260));
    await tester.pumpAndSettle();
    expect(_colorOf(tester, startKey), _scheme.surfaceContainerHighest);
    expect(haptics, isEmpty);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(calls.start, 0);
  });

  testWidgets('with a start action, swiping left still runs only the end '
      'action', (tester) async {
    _recordHaptics(tester);
    final calls = _Calls();
    await tester.pumpWidget(_host(calls));

    final gesture = await _startSwipe(tester);
    await gesture.moveBy(const Offset(-180, 0));
    await tester.pumpAndSettle();
    expect(_colorOf(tester, endKey), _scheme.errorContainer);
    expect(find.byKey(startKey), findsNothing);
    // 行尾动作的图标仍在右侧。
    expect(
      tester.getCenter(_iconIn(endKey)).dx,
      greaterThan(tester.getCenter(find.byType(DiarySwipeActionItem)).dx),
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(calls.end, 1);
    expect(calls.start, 0);
  });

  testWidgets('crossing the resting position mid-drag switches sides and the '
      'release position decides', (tester) async {
    final haptics = _recordHaptics(tester);
    final calls = _Calls();
    await tester.pumpWidget(_host(calls));

    final gesture = await _startSwipe(tester);
    await gesture.moveBy(const Offset(-180, 0));
    await tester.pumpAndSettle();
    expect(_colorOf(tester, endKey), _scheme.errorContainer);
    expect(haptics, hasLength(1));

    // 越过原位到右侧、还没到阈值：换成行首背景，且立刻是弱化色（左侧刚才的
    // 动作色不会带过来闪一下）。
    await gesture.moveBy(const Offset(200, 0));
    await tester.pump();
    expect(find.byKey(endKey), findsNothing);
    expect(_colorOf(tester, startKey), _scheme.surfaceContainerHighest);

    await gesture.moveBy(const Offset(160, 0));
    await tester.pumpAndSettle();
    expect(_colorOf(tester, startKey), _scheme.primaryContainer);
    expect(haptics, hasLength(2));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(calls.start, 1);
    expect(calls.end, 0);
  });

  testWidgets('switching back to the left side before release runs the end '
      'action', (tester) async {
    _recordHaptics(tester);
    final calls = _Calls();
    await tester.pumpWidget(_host(calls));

    final gesture = await _startSwipe(tester);
    await gesture.moveBy(const Offset(180, 0));
    await tester.pumpAndSettle();
    expect(_colorOf(tester, startKey), _scheme.primaryContainer);

    await gesture.moveBy(const Offset(-360, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(startKey), findsNothing);
    expect(_colorOf(tester, endKey), _scheme.errorContainer);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(calls.end, 1);
    expect(calls.start, 0);
  });

  testWidgets('start background fills the card corners on the left only', (
    tester,
  ) async {
    _recordHaptics(tester);
    await tester.pumpWidget(_host(_Calls()));

    const slideBy = 100.0;
    final gesture = await _startSwipe(tester);
    await gesture.moveBy(const Offset(slideBy, 0));
    await tester.pump();

    final clip = tester.widget<ClipPath>(
      find.ancestor(of: find.byKey(startKey), matching: find.byType(ClipPath)),
    );
    final path = clip.clipper!.getClip(const Size(_itemWidth, _itemHeight));
    const cardLeft = slideBy;
    // 卡片左上 / 左下圆角外、外接矩形内的缺口里同样是背景。
    expect(path.contains(const Offset(cardLeft + 2, 2)), isTrue);
    expect(path.contains(const Offset(cardLeft + 2, _itemHeight - 2)), isTrue);
    // 卡片左侧滑开的一条整条可见。
    expect(path.contains(const Offset(cardLeft - 20, _itemHeight / 2)), isTrue);
    // 卡片盖住的地方不画背景。
    expect(
      path.contains(const Offset(cardLeft + 40, _itemHeight / 2)),
      isFalse,
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('the start action follows the reading direction under RTL', (
    tester,
  ) async {
    _recordHaptics(tester);
    final calls = _Calls();
    await tester.pumpWidget(_host(calls, textDirection: TextDirection.rtl));

    // RTL 的行首在右侧：向左滑开的是行首动作，图标靠右。
    final gesture = await _startSwipe(tester);
    await gesture.moveBy(const Offset(-180, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(endKey), findsNothing);
    expect(_colorOf(tester, startKey), _scheme.primaryContainer);
    expect(
      tester.getCenter(_iconIn(startKey)).dx,
      greaterThan(tester.getCenter(find.byType(DiarySwipeActionItem)).dx),
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(calls.start, 1);
    expect(calls.end, 0);
  });

  testWidgets('removing the start action mid-drag puts the card back', (
    tester,
  ) async {
    _recordHaptics(tester);
    final calls = _Calls();
    await tester.pumpWidget(_host(calls));
    final restingOrigin = tester.getTopLeft(find.byKey(_cardKey));

    final gesture = await _startSwipe(tester);
    await gesture.moveBy(const Offset(200, 0));
    await tester.pump();
    await tester.pumpWidget(_host(calls, withStartAction: false));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(_cardKey)), restingOrigin);

    // 这次拖动不再跟手，松手也不触发。
    await gesture.moveBy(const Offset(-200, 0));
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(_cardKey)), restingOrigin);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(calls.start, 0);
    expect(calls.end, 0);
  });
}
