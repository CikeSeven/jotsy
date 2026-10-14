import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/expressive_controls.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/ui/diaries/widgets/diary_live_voiceprint.dart';

import '../../support/expressive_test_theme.dart';

void main() {
  Future<void> pushSecondPage(WidgetTester tester, ThemeData theme) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: theme,
        home: const Scaffold(body: Text('First')),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Second')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
  }

  bool secondPageIsTransitioning(WidgetTester tester) {
    final second = find.text('Second');
    bool partial<T extends Widget>(bool Function(T) isPartial) => tester
        .widgetList<T>(find.ancestor(of: second, matching: find.byType(T)))
        .any(isPartial);
    return partial<FadeTransition>((w) => w.opacity.value < 1) ||
        partial<SlideTransition>((w) => w.position.value != Offset.zero) ||
        partial<ScaleTransition>((w) => w.scale.value != 1);
  }

  testWidgets('default page transition animates the pushed route', (
    tester,
  ) async {
    await pushSecondPage(tester, expressiveTestTheme(Brightness.light));
    expect(secondPageIsTransitioning(tester), isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('reduce-motion theme shows the pushed route immediately', (
    tester,
  ) async {
    await pushSecondPage(
      tester,
      ExpressiveControls.withoutMotion(expressiveTestTheme(Brightness.light)),
    );
    expect(secondPageIsTransitioning(tester), isFalse);
    expect(tester.getTopLeft(find.text('Second')), Offset.zero);
    await tester.pumpAndSettle();
  });

  testWidgets('animated size stays assertion-free when motion is reduced', (
    tester,
  ) async {
    // 时长为 0 的 AnimatedSize 在子树尺寸变化时会在 performLayout 内重新标脏
    // 自身；durationNonZero 用 1ms 近似瞬时规避，并且尺寸应立刻到位。
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    Widget host(double height) => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => AnimatedSize(
            duration: ExpressiveMotion.durationNonZero(context),
            child: SizedBox(key: const Key('child'), height: height, width: 40),
          ),
        ),
      ),
    );
    await tester.pumpWidget(host(20));
    await tester.pumpWidget(host(120));
    await tester.pump(const Duration(milliseconds: 16));

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AnimatedSize)).height, 120);
  });

  testWidgets('voiceprint stops scrolling under reduce motion', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final samples = <double>[0.3, 0.5];
    Widget voiceprint() => MaterialApp(
      home: Scaffold(
        body: LiveVoiceprintVisualizer(samples: samples, active: true),
      ),
    );
    await tester.pumpWidget(voiceprint());
    // 新采样到达：减少动画时直接落位，不启动滚动 ticker。
    samples.add(0.8);
    await tester.pumpWidget(voiceprint());
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
