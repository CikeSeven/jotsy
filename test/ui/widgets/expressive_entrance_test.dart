import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/expressive_entrance.dart';

double _opacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.descendant(
        of: find.byType(ExpressiveEntrance),
        matching: find.byType(Opacity),
      ),
    )
    .opacity;

void main() {
  testWidgets('fades in when inserted', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ExpressiveEntrance(child: Text('panel'))),
    );
    expect(_opacity(tester), 0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_opacity(tester), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(_opacity(tester), 1);
  });

  testWidgets('appears immediately under reduce motion', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      const MaterialApp(home: ExpressiveEntrance(child: Text('panel'))),
    );
    await tester.pump();
    expect(_opacity(tester), 1);
  });
}
