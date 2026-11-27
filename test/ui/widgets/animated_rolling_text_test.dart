import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/animated_rolling_text.dart';
import 'package:node_diary/ui/widgets/rolling_text.dart';

/// 逐位滚动的计数：静止时是普通文字，变化时只滚变了的数字、读屏念最终
/// 文字，句子里没有数字时整句直接换，减少动画时直接换字。
void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    bool disableAnimations = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    );
  }

  testWidgets('a count rolls to its new value and rests as plain text', (
    tester,
  ) async {
    await pump(tester, const AnimatedRollingText('9'));
    expect(find.text('9'), findsOneWidget);
    expect(find.byType(RollingText), findsNothing);

    await pump(tester, const AnimatedRollingText('10'));
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byType(RollingText), findsOneWidget);
    // 滚动途中读屏只念最终的数字。
    expect(find.bySemanticsLabel('10'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(RollingText), findsNothing);
    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('a number inside a sentence rolls without rolling the words', (
    tester,
  ) async {
    await pump(tester, const AnimatedRollingText.sentence('还有 3 件', number: 3));
    await pump(tester, const AnimatedRollingText.sentence('还有 2 件', number: 2));
    await tester.pump(const Duration(milliseconds: 60));
    final rolling = tester.widget<RollingText>(find.byType(RollingText));
    expect(rolling.from, '3');
    expect(rolling.to, '2');
    expect(rolling.upward, isFalse);
    expect(find.bySemanticsLabel('还有 2 件'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('还有 2 件'), findsOneWidget);
  });

  testWidgets('a sentence without a number swaps at once', (tester) async {
    await pump(tester, const AnimatedRollingText.sentence('还有 1 件', number: 1));
    await pump(
      tester,
      const AnimatedRollingText.sentence('今天的事都做完了', number: null),
    );
    await tester.pump();
    expect(find.byType(RollingText), findsNothing);
    expect(find.text('今天的事都做完了'), findsOneWidget);
  });

  testWidgets('reduced motion swaps the text at once', (tester) async {
    await pump(tester, const AnimatedRollingText('3'), disableAnimations: true);
    await pump(tester, const AnimatedRollingText('4'), disableAnimations: true);
    await tester.pump();
    expect(find.byType(RollingText), findsNothing);
    expect(find.text('4'), findsOneWidget);
  });
}
