import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';

/// 提示条必须到时自动关闭：Flutter 3.38 起带 action 的 SnackBar 默认常驻，
/// 撤销窗口与 FAB 上移都等它关闭才结束。
void main() {
  Future<BuildContext> pumpHost(
    WidgetTester tester,
    HomeHintVisibilityController controller,
  ) async {
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            HomeHintVisibilityScope(controller: controller, child: child!),
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

  SnackBar undoSnackBar(String message) => SnackBar(
    content: Text(message),
    duration: const Duration(seconds: 4),
    persist: false,
    action: SnackBarAction(label: 'Undo', onPressed: () {}),
  );

  /// 假时钟下逐帧推进（入场、停留、退场动画都要帧驱动）。
  Future<void> pumpFor(WidgetTester tester, Duration total) async {
    const step = Duration(milliseconds: 100);
    for (var elapsed = Duration.zero; elapsed < total; elapsed += step) {
      await tester.pump(step);
    }
  }

  testWidgets('an undo snack bar closes by timeout and lowers the FAB', (
    tester,
  ) async {
    final controller = HomeHintVisibilityController();
    addTearDown(controller.dispose);
    final context = await pumpHost(tester, controller);

    SnackBarClosedReason? reason;
    HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: undoSnackBar('Deleted'),
    ).then((value) => reason = value);
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('Deleted'), findsOneWidget);
    expect(controller.isHintVisibleNotifier.value, isTrue);

    await pumpFor(tester, const Duration(seconds: 6));
    expect(reason, SnackBarClosedReason.timeout);
    expect(find.text('Deleted'), findsNothing);
    expect(controller.isHintVisibleNotifier.value, isFalse);
  });

  testWidgets('rapid undo snack bars all close, the last one included', (
    tester,
  ) async {
    final controller = HomeHintVisibilityController();
    addTearDown(controller.dispose);
    final context = await pumpHost(tester, controller);

    // 连续删除三条：后两条在前一条退场动画期间排队。
    final reasons = <String, SnackBarClosedReason>{};
    for (final message in ['First', 'Second', 'Third']) {
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: undoSnackBar(message),
      ).then((value) => reasons[message] = value);
      await tester.pump(const Duration(milliseconds: 50));
    }

    await pumpFor(tester, const Duration(seconds: 15));
    expect(reasons.keys, unorderedEquals(['First', 'Second', 'Third']));
    expect(reasons['Third'], SnackBarClosedReason.timeout);
    expect(find.byType(SnackBar), findsNothing);
    expect(controller.isHintVisibleNotifier.value, isFalse);
  });

  testWidgets('an action snack bar without persist: false is rejected', (
    tester,
  ) async {
    final controller = HomeHintVisibilityController();
    addTearDown(controller.dispose);
    final context = await pumpHost(tester, controller);

    await expectLater(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(
          content: const Text('Deleted'),
          action: SnackBarAction(label: 'Undo', onPressed: () {}),
        ),
      ),
      throwsAssertionError,
    );
  });

  test('every SnackBar with an action in lib opts out of persisting', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File file) => file.path.endsWith('.dart'));
    var actions = 0;
    for (final file in files) {
      final source = file.readAsStringSync();
      final actionCount = 'SnackBarAction('.allMatches(source).length;
      actions += actionCount;
      expect(
        'persist: false'.allMatches(source).length,
        greaterThanOrEqualTo(actionCount),
        reason:
            '${file.path}: SnackBar with an action must pass persist: false',
      );
    }
    expect(actions, greaterThan(0));
  });
}
