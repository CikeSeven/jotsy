import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/expressive_icon_swap.dart';

Widget _host(String key) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: ExpressiveIconSwap(switchKey: key, child: Text(key)),
    ),
  ),
);

void main() {
  testWidgets('swaps with a springy scale and a bounded fade', (tester) async {
    await tester.pumpWidget(_host('a'));
    expect(find.text('a'), findsOneWidget);

    await tester.pumpWidget(_host('b'));
    var maxScale = 0.0;
    var maxOpacity = 0.0;
    // 逐帧走完整个过渡：弹簧缩放中途会越过 1，淡入淡出必须始终在 [0,1] 内；
    // 过去把弹簧曲线再喂给断言 [0,1] 的曲线，会在这里直接抛错。
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      for (final transition in tester.widgetList<ScaleTransition>(
        find.byType(ScaleTransition),
      )) {
        maxScale = math.max(maxScale, transition.scale.value);
      }
      for (final transition in tester.widgetList<FadeTransition>(
        find.descendant(
          of: find.byType(ExpressiveIconSwap),
          matching: find.byType(FadeTransition),
        ),
      )) {
        maxOpacity = math.max(maxOpacity, transition.opacity.value);
      }
    }

    expect(tester.takeException(), isNull);
    expect(maxScale, greaterThan(1.0), reason: 'spring overshoot on scale');
    expect(maxOpacity, lessThanOrEqualTo(1.0));
    expect(find.text('a'), findsNothing);
    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('keeps both children mounted only while transitioning', (
    tester,
  ) async {
    await tester.pumpWidget(_host('a'));
    await tester.pumpWidget(_host('b'));
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('a'), findsNothing);
    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('reduce motion replaces the child without a transition', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(_host('a'));
    await tester.pumpWidget(_host('b'));
    await tester.pump();

    expect(find.text('a'), findsNothing);
    expect(find.text('b'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
