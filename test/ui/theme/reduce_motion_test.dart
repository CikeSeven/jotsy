import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/expressive_controls.dart';
import 'package:node_diary/ui/diaries/widgets/diary_waveform_visualizer.dart';

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

  testWidgets('voiceprint stops its breathing loop under reduce motion', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LiveVoiceprintVisualizer(
            amplitude: 0.5,
            isRecording: true,
            isPaused: false,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
