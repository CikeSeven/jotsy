import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';

void main() {
  testWidgets('tracked snack bar reports its rendered height', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = HomeHintVisibilityController();
    addTearDown(controller.dispose);
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          snackBarTheme: const SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            insetPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        ),
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

    Future<double> showAndMeasure(String message) async {
      final closed = HomeHintVisibilityScope.showTrackedSnackBar(
        context: pageContext,
        snackBar: SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final extent = controller.hintExtentNotifier.value;
      // 等提示超时并播完退场动画（假时钟下需逐帧推进，不能直接 await）。
      for (var frame = 0; frame < 60; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(closed, completes);
      return extent;
    }

    final singleLine = await showAndMeasure('Archived');
    expect(singleLine, greaterThan(0));
    // 关闭后（含防抖）归零，FAB 回落到默认位置。
    expect(controller.hintExtentNotifier.value, 0);

    final multiLine = await showAndMeasure(
      'A much longer failure message that certainly wraps onto a second '
      'line on a narrow phone screen and makes the snack bar taller',
    );
    expect(multiLine, greaterThan(singleLine + 10));
  });
}
