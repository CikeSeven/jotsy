import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/diaries/widgets/diary_swipe_action_item.dart';

import '../../../support/expressive_test_theme.dart';

const _itemWidth = 360.0;
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
          height: 144,
          child: DiarySwipeActionItem(
            diaryId: 'diary-1',
            enabled: enabled,
            icon: FontAwesomeIcons.boxArchive,
            actionColor: theme.colorScheme.primaryContainer,
            actionIconColor: theme.colorScheme.onPrimaryContainer,
            borderRadius: 24,
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

/// 测试宿主里 Dismissible 是唯一的手势识别器，按下即在竞技场胜出，之后的
/// 位移 1:1 计入滑开距离（卡片宽 360，触发阈值 0.4 即 144）。
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
      },
    );
  }

  testWidgets('releasing past the threshold triggers the action once', (
    tester,
  ) async {
    _recordHaptics(tester);
    var swiped = 0;
    await tester.pumpWidget(
      _host(brightness: Brightness.light, onSwiped: () => swiped++),
    );

    final gesture = await _startSwipe(tester);
    await gesture.moveBy(const Offset(-_itemWidth * 0.5, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(swiped, 1);
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

    await tester.drag(find.byKey(_cardKey), const Offset(-_itemWidth, 0));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Dismissible>(find.byType(Dismissible)).direction,
      DismissDirection.none,
    );
    expect(swiped, 0);
  });

  testWidgets('armed state switches without animation under reduce motion', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    _recordHaptics(tester);
    await tester.pumpWidget(
      _host(brightness: Brightness.light, onSwiped: () {}),
    );
    final colorScheme = expressiveTestTheme(Brightness.light).colorScheme;

    final gesture = await _startSwipe(tester);
    await gesture.moveBy(const Offset(-180, 0));
    await tester.pump();
    await tester.pump();

    expect(_backgroundColor(tester), colorScheme.primaryContainer);
    await gesture.moveBy(const Offset(180, 0));
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
