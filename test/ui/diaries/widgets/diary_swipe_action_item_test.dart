import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/diaries/widgets/diary_swipe_action_item.dart';

import '../../../support/expressive_test_theme.dart';

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

Widget _host({
  required Brightness brightness,
  required VoidCallback onSwiped,
  bool enabled = true,
}) {
  final theme = expressiveTestTheme(brightness);
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: _itemWidth,
          height: _itemHeight,
          child: DiarySwipeActionItem(
            diaryId: 'diary-1',
            enabled: enabled,
            icon: FontAwesomeIcons.boxArchive,
            actionColor: theme.colorScheme.primaryContainer,
            actionIconColor: theme.colorScheme.onPrimaryContainer,
            borderRadius: _radius,
            onSwiped: onSwiped,
            child: Container(key: _cardKey, color: theme.colorScheme.surface),
          ),
        ),
      ),
    ),
  );
}

Color? _backgroundColor(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.byKey(DiarySwipeActionItem.backgroundKey),
  );
  return (box.decoration as BoxDecoration).color;
}

double _iconAlpha(WidgetTester tester) => tester
    .widget<FaIcon>(
      find.descendant(
        of: find.byKey(DiarySwipeActionItem.backgroundKey),
        matching: find.byType(FaIcon),
      ),
    )
    .color!
    .a;

/// 测试宿主里卡片的横向拖动是唯一的手势识别器：越过触摸溢出距离即被接住，
/// 之后的位移 1:1 计入滑开距离（卡片宽 360，触发阈值 0.4 即 144）。
Future<TestGesture> _startSwipe(WidgetTester tester) =>
    tester.startGesture(tester.getCenter(find.byKey(_cardKey)));

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'background arms with one haptic past the threshold and disarms when '
      'dragged back in $brightness',
      (tester) async {
        final haptics = _recordHaptics(tester);
        var swiped = 0;
        await tester.pumpWidget(
          _host(brightness: brightness, onSwiped: () => swiped++),
        );
        final colorScheme = expressiveTestTheme(brightness).colorScheme;
        final restingOrigin = tester.getTopLeft(find.byKey(_cardKey));
        // 静止时卡片盖住整条，不画背景。
        expect(find.byKey(DiarySwipeActionItem.backgroundKey), findsNothing);

        final gesture = await _startSwipe(tester);
        await gesture.moveBy(const Offset(-40, 0));
        await tester.pump();
        // 未到阈值：弱化底色，图标随距离半透明露出，不震动。
        expect(_backgroundColor(tester), colorScheme.surfaceContainerHighest);
        expect(_iconAlpha(tester), inExclusiveRange(0, 1));
        expect(haptics, isEmpty);

        await gesture.moveBy(const Offset(-120, 0));
        await tester.pumpAndSettle();
        expect(_backgroundColor(tester), colorScheme.primaryContainer);
        expect(_iconAlpha(tester), 1);
        expect(haptics, <Object?>['HapticFeedbackType.lightImpact']);

        // 阈值以上继续拖动不再重复震动。
        await gesture.moveBy(const Offset(-40, 0));
        await tester.pumpAndSettle();
        expect(haptics, hasLength(1));

        // 拖回阈值以下：恢复弱化态，用户可以反悔。
        await gesture.moveBy(const Offset(120, 0));
        await tester.pumpAndSettle();
        expect(_backgroundColor(tester), colorScheme.surfaceContainerHighest);
        expect(haptics, hasLength(1));

        await gesture.up();
        await tester.pumpAndSettle();
        // 松手时未过阈值：卡片回弹到原位，不触发动作。
        expect(swiped, 0);
        expect(tester.getTopLeft(find.byKey(_cardKey)), restingOrigin);
        expect(find.byKey(DiarySwipeActionItem.backgroundKey), findsNothing);
      },
    );
  }

  testWidgets('releasing past the threshold slides out, collapses, then '
      'triggers the action once', (tester) async {
    _recordHaptics(tester);
    var swiped = 0;
    await tester.pumpWidget(
      _host(brightness: Brightness.light, onSwiped: () => swiped++),
    );

    final gesture = await _startSwipe(tester);
    await gesture.moveBy(const Offset(-_itemWidth * 0.5, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    // 滑出途中还没回调，背景仍在。
    expect(swiped, 0);
    expect(find.byKey(DiarySwipeActionItem.backgroundKey), findsOneWidget);

    await tester.pumpAndSettle();
    expect(swiped, 1);
    // 收起后卡片已移出树。
    expect(find.byKey(_cardKey), findsNothing);
  });

  testWidgets('a quick short flick does not trigger the action', (
    tester,
  ) async {
    _recordHaptics(tester);
    var swiped = 0;
    await tester.pumpWidget(
      _host(brightness: Brightness.light, onSwiped: () => swiped++),
    );
    final restingOrigin = tester.getTopLeft(find.byKey(_cardKey));

    // 滚动时起手偏横向的一甩：距离远不到阈值，但速度很快。
    await tester.fling(find.byKey(_cardKey), const Offset(-80, 0), 3000);
    await tester.pumpAndSettle();

    expect(swiped, 0);
    expect(tester.getTopLeft(find.byKey(_cardKey)), restingOrigin);
  });

  testWidgets('a mostly vertical drag never arms or triggers the action', (
    tester,
  ) async {
    final haptics = _recordHaptics(tester);
    var swiped = 0;
    await tester.pumpWidget(
      _host(brightness: Brightness.light, onSwiped: () => swiped++),
    );
    final colorScheme = expressiveTestTheme(Brightness.light).colorScheme;

    final gesture = await _startSwipe(tester);
    // 起手偏横向被卡片接住，之后手指主要在纵向移动（其实是在滚动）。
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-140, -260));
    await tester.pumpAndSettle();
    // 横向已超过阈值，但总位移以纵向为主：不武装、不震动。
    expect(_backgroundColor(tester), colorScheme.surfaceContainerHighest);
    expect(haptics, isEmpty);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(swiped, 0);
  });

  testWidgets('background shows inside the card corners, not the card area', (
    tester,
  ) async {
    _recordHaptics(tester);
    await tester.pumpWidget(
      _host(brightness: Brightness.light, onSwiped: () {}),
    );

    const slideBy = 100.0;
    final gesture = await _startSwipe(tester);
    await gesture.moveBy(const Offset(-slideBy, 0));
    await tester.pump();

    final clip = tester.widget<ClipPath>(
      find.ancestor(
        of: find.byKey(DiarySwipeActionItem.backgroundKey),
        matching: find.byType(ClipPath),
      ),
    );
    final path = clip.clipper!.getClip(const Size(_itemWidth, _itemHeight));
    const cardRight = _itemWidth - slideBy;
    // 卡片右上角圆角外、外接矩形内的缺口：要露出背景，不能是页面底色。
    expect(path.contains(const Offset(cardRight - 2, 2)), isTrue);
    expect(path.contains(const Offset(cardRight - 2, _itemHeight - 2)), isTrue);
    // 卡片右侧滑开的一条整条可见。
    expect(
      path.contains(const Offset(cardRight + 20, _itemHeight / 2)),
      isTrue,
    );
    // 卡片盖住的地方不画背景（半透明卡片也不会透出动作色）。
    expect(
      path.contains(const Offset(cardRight - 40, _itemHeight / 2)),
      isFalse,
    );
    expect(path.contains(const Offset(_radius + 4, 2)), isFalse);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('disabled item ignores swipes', (tester) async {
    var swiped = 0;
    await tester.pumpWidget(
      _host(
        brightness: Brightness.light,
        enabled: false,
        onSwiped: () => swiped++,
      ),
    );
    final restingOrigin = tester.getTopLeft(find.byKey(_cardKey));

    final gesture = await _startSwipe(tester);
    await gesture.moveBy(const Offset(-_itemWidth * 0.8, 0));
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(_cardKey)), restingOrigin);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(swiped, 0);
  });

  testWidgets('disabling mid-drag puts the card back', (tester) async {
    _recordHaptics(tester);
    var swiped = 0;
    await tester.pumpWidget(
      _host(brightness: Brightness.light, onSwiped: () => swiped++),
    );
    final restingOrigin = tester.getTopLeft(find.byKey(_cardKey));

    final gesture = await _startSwipe(tester);
    await gesture.moveBy(const Offset(-_itemWidth * 0.6, 0));
    await tester.pump();
    // 拖动途中进入选择模式。
    await tester.pumpWidget(
      _host(
        brightness: Brightness.light,
        enabled: false,
        onSwiped: () => swiped++,
      ),
    );
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(swiped, 0);
    expect(tester.getTopLeft(find.byKey(_cardKey)), restingOrigin);
  });

  testWidgets('armed state switches without animation under reduce motion', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    _recordHaptics(tester);
    var swiped = 0;
    await tester.pumpWidget(
      _host(brightness: Brightness.light, onSwiped: () => swiped++),
    );
    final colorScheme = expressiveTestTheme(Brightness.light).colorScheme;

    final gesture = await _startSwipe(tester);
    await gesture.moveBy(const Offset(-180, 0));
    await tester.pump();
    await tester.pump();

    expect(_backgroundColor(tester), colorScheme.primaryContainer);
    await gesture.up();
    // 滑出与收起瞬间完成，只等微任务里的后续步骤。
    await tester.pump();
    await tester.pump();
    expect(swiped, 1);
  });
}
