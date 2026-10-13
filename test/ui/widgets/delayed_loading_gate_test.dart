import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/delayed_loading_gate.dart';

void main() {
  Widget gate(bool loading) => Directionality(
    textDirection: TextDirection.ltr,
    child: DelayedLoadingGate(
      loading: loading,
      builder: (context, showLoading) => Text(showLoading ? 'spinner' : 'idle'),
    ),
  );

  testWidgets('short loading never shows the indicator', (tester) async {
    await tester.pumpWidget(gate(true));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('idle'), findsOneWidget);

    await tester.pumpWidget(gate(false));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('spinner'), findsNothing);
  });

  testWidgets('slow loading shows after the delay and hides immediately', (
    tester,
  ) async {
    await tester.pumpWidget(gate(true));
    await tester.pump(DelayedLoadingGate.defaultDelay);
    await tester.pump();
    expect(find.text('spinner'), findsOneWidget);

    await tester.pumpWidget(gate(false));
    expect(find.text('idle'), findsOneWidget);
  });
}
