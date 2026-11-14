import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart'
    show LoadingIndicatorM3E;
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';

void main() {
  Widget host({
    bool ticking = true,
    bool reduceMotion = false,
    Brightness brightness = Brightness.light,
  }) => MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: TickerMode(
        enabled: ticking,
        child: const Center(
          child: ExpressiveLoadingIndicator(size: 48, semanticLabel: 'Waiting'),
        ),
      ),
    ),
  );

  for (final brightness in Brightness.values) {
    testWidgets('reduced motion stays visible and idle in ${brightness.name}', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(host(reduceMotion: true, brightness: brightness));
      expect(find.byType(LoadingIndicatorM3E), findsNothing);
      expect(find.bySemanticsLabel('Waiting'), findsOneWidget);
      expect(
        tester.getSize(find.byType(ExpressiveLoadingIndicator)),
        const Size(48, 48),
      );
      // 超过两轮形变周期，既没有 ticker，也没有周期定时器要求重绘。
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.hasScheduledFrame, isFalse);
      semantics.dispose();
    });
  }

  testWidgets('muting and resuming stops and restarts the indicator', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    expect(find.byType(LoadingIndicatorM3E), findsOneWidget);
    await tester.pumpWidget(host(ticking: false));
    expect(find.byType(LoadingIndicatorM3E), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(host());
    expect(find.byType(LoadingIndicatorM3E), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.hasScheduledFrame, isTrue);
  });
}
