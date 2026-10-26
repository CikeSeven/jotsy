import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/notebook_payload.dart';
import 'package:node_diary/ui/notebooks/controllers/notebook_editor_controller.dart';
import 'package:node_diary/ui/notebooks/sections/notebook_editor_behavior.dart';
import 'package:node_diary/ui/widgets/expressive_choice_tile.dart';

import 'notebook_test_support.dart';

Future<NotebookEditorController> _pump(WidgetTester tester) async {
  final controller = NotebookEditorController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    notebookTestApp(
      ListenableBuilder(
        listenable: controller,
        builder: (context, _) => SingleChildScrollView(
          child: NotebookEditorPrivacySection(controller: controller),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

ExpressiveChoiceTile _tile(WidgetTester tester, String label) =>
    tester.widget<ExpressiveChoiceTile>(
      find.widgetWithText(ExpressiveChoiceTile, label),
    );

void main() {
  testWidgets('locking is available where the device can verify', (
    tester,
  ) async {
    final controller = await _pump(tester);
    expect(_tile(tester, '上锁').onTap, isNotNull);
    await tester.tap(find.text('上锁'));
    await tester.pumpAndSettle();
    expect(controller.visibility, NotebookVisibility.locked);
  });

  testWidgets('Linux cannot pick the locked option and says why', (
    tester,
  ) async {
    final controller = await _pump(tester);
    expect(_tile(tester, '上锁').onTap, isNull);
    expect(find.text('这台设备没有系统身份验证（指纹、面容或系统密码），无法上锁'), findsOneWidget);
    await tester.tap(find.text('上锁'));
    await tester.pumpAndSettle();
    expect(controller.visibility, NotebookVisibility.normal);
    // 其他选项照常可选。
    await tester.tap(find.text('不在全部日记中显示'));
    await tester.pumpAndSettle();
    expect(controller.visibility, NotebookVisibility.hidden);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
