import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_day_content_switcher.dart';

void main() {
  Widget host(Widget child, {bool loading = false}) => MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: CalendarDayContentSwitcher(
          loading: loading,
          errorMessage: null,
          child: child,
        ),
      ),
    ),
  );

  testWidgets('switching to shorter content keeps the new child top-aligned', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const SizedBox(key: ValueKey<String>('tall'), height: 400)),
    );
    await tester.pumpWidget(
      host(const SizedBox(key: ValueKey<String>('short'), height: 80)),
    );
    await tester.pump(const Duration(milliseconds: 60));

    final switcherTop = tester.getTopLeft(find.byType(AnimatedSwitcher).first);
    final shortTop = tester.getTopLeft(
      find.byKey(const ValueKey<String>('short')),
    );
    // 默认居中布局时短内容会落在 (400-80)/2 = 160 处。
    expect(shortTop.dy, switcherTop.dy);
    await tester.pumpAndSettle();
  });

  testWidgets('brief loading does not flash the refresh scrim', (tester) async {
    const content = SizedBox(key: ValueKey<String>('day'), height: 200);
    await tester.pumpWidget(host(content, loading: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey<String>('day_loading')), findsNothing);
    await tester.pumpWidget(host(content));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('day_loading')), findsNothing);
  });

  testWidgets('reduce motion swaps day content without asserting', (
    tester,
  ) async {
    // 0 时长的 AnimatedSize 会在自身 performLayout 内重新标脏而触发断言；
    // 减少动画时改用 1ms 近似瞬时，高度应立刻到位。
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      host(const SizedBox(key: ValueKey<String>('tall'), height: 400)),
    );
    await tester.pumpWidget(
      host(const SizedBox(key: ValueKey<String>('short'), height: 80)),
    );
    await tester.pump(const Duration(milliseconds: 16));

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AnimatedSize)).height, 80);
  });
}
