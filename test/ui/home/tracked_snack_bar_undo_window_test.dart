import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/editing_session_registry.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';

/// 带撤销按钮的提示显示期间登记撤销窗口，局域网同步写库前等它关闭。
void main() {
  final registry = EditingSessionRegistry.instance;
  setUp(registry.debugReset);
  tearDown(registry.debugReset);

  Future<BuildContext> pumpHost(WidgetTester tester) async {
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );
    return pageContext;
  }

  /// 假时钟下逐帧推进（入场、停留、退场动画都要帧驱动）。
  Future<void> pumpFor(WidgetTester tester, Duration total) async {
    const step = Duration(milliseconds: 100);
    for (var elapsed = Duration.zero; elapsed < total; elapsed += step) {
      await tester.pump(step);
    }
  }

  SnackBar undoSnackBar(String message) => SnackBar(
    content: Text(message),
    duration: const Duration(seconds: 4),
    persist: false,
    action: SnackBarAction(label: 'Undo $message', onPressed: () {}),
  );

  testWidgets('an undo snack bar holds an undo window until it closes', (
    tester,
  ) async {
    final context = await pumpHost(tester);
    SnackBarClosedReason? reason;
    HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: undoSnackBar('Deleted'),
    ).then((value) => reason = value);
    await tester.pump();
    expect(registry.openUndoWindowCount, 1);
    expect(registry.openUndoWindows.value, 1);

    await pumpFor(tester, const Duration(seconds: 6));
    expect(reason, SnackBarClosedReason.timeout);
    expect(registry.openUndoWindowCount, 0);
    expect(registry.openUndoWindows.value, 0);
  });

  testWidgets('tapping undo or replacing the snack bar closes its window', (
    tester,
  ) async {
    final context = await pumpHost(tester);
    HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: undoSnackBar('First'),
    );
    await pumpFor(tester, const Duration(seconds: 1));
    HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: undoSnackBar('Second'),
    );
    await pumpFor(tester, const Duration(seconds: 1));
    // 第一条被替换：它的窗口随 closed 结束，只剩第二条。
    expect(registry.openUndoWindowCount, 1);

    await tester.tap(find.text('Undo Second'));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(registry.openUndoWindowCount, 0);
  });

  testWidgets('a snack bar without an action opens no undo window', (
    tester,
  ) async {
    final context = await pumpHost(tester);
    HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: const SnackBar(
        content: Text('Saved'),
        duration: Duration(seconds: 2),
      ),
    );
    await tester.pump();
    expect(find.text('Saved'), findsOneWidget);
    expect(registry.openUndoWindowCount, 0);
    await pumpFor(tester, const Duration(seconds: 4));
    expect(registry.openUndoWindowCount, 0);
  });
}
