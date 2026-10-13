import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/app_lock_layer.dart';

void main() {
  final contentFocus = FocusNode();
  tearDownAll(contentFocus.dispose);

  Widget host({required bool locked}) => MaterialApp(
    home: AppLockLayer(
      locked: locked,
      overlayBuilder: (_) =>
          const ColoredBox(color: Colors.grey, child: Text('Locked')),
      child: Scaffold(
        body: Column(
          children: <Widget>[
            const Text('Secret diary'),
            TextField(focusNode: contentFocus),
          ],
        ),
      ),
    ),
  );

  testWidgets('locked content is hidden from semantics and focus', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(locked: true));

    // 遮罩立即完全出现，不经历会透出内容的淡入。
    expect(find.text('Locked'), findsOneWidget);
    expect(find.bySemanticsLabel('Secret diary'), findsNothing);
    contentFocus.requestFocus();
    await tester.pump();
    expect(contentFocus.hasFocus, isFalse);

    await tester.pumpWidget(host(locked: false));
    await tester.pumpAndSettle();
    expect(find.text('Locked'), findsNothing);
    expect(find.bySemanticsLabel('Secret diary'), findsOneWidget);
    contentFocus.requestFocus();
    await tester.pump();
    expect(contentFocus.hasFocus, isTrue);
    semantics.dispose();
  });
}
