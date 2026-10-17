import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/soft_keyboard_selection_keys.dart';

import '../../support/soft_keyboard_keys.dart';

/// 软键盘编辑面板的“选择”：方向键 / Home / End 带着 meta 里的 Shift 到达，
/// 框架看不到 Shift（flutter/flutter#185849），由 [SoftKeyboardSelectionKeys]
/// 补回扩选；实体键盘与未开“选择”时保持原样。
void main() {
  late TextEditingController controller;

  setUp(() {
    controller = TextEditingController(text: 'hello world');
  });
  tearDown(() => controller.dispose());

  Future<void> pumpField(WidgetTester tester, {bool wrapped = true}) async {
    final field = TextField(controller: controller, autofocus: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: wrapped ? SoftKeyboardSelectionKeys(child: field) : field,
        ),
      ),
    );
    await tester.pump();
    controller.selection = const TextSelection.collapsed(offset: 5);
    await tester.pump();
  }

  testWidgets('select mode arrows extend the selection', (tester) async {
    await pumpField(tester);

    await sendSoftKeyboardKey(
      tester,
      SoftKeyboardKey.arrowLeft,
      selecting: true,
    );
    await sendSoftKeyboardKey(
      tester,
      SoftKeyboardKey.arrowLeft,
      selecting: true,
    );
    expect(
      controller.selection,
      const TextSelection(baseOffset: 5, extentOffset: 3),
    );

    await sendSoftKeyboardKey(tester, SoftKeyboardKey.end, selecting: true);
    expect(
      controller.selection,
      const TextSelection(baseOffset: 5, extentOffset: 11),
    );
  });

  testWidgets('arrows without select mode still only move the caret', (
    tester,
  ) async {
    await pumpField(tester);

    await sendSoftKeyboardKey(tester, SoftKeyboardKey.arrowRight);
    expect(controller.selection, const TextSelection.collapsed(offset: 6));
  });

  testWidgets('hardware Shift + arrow still extends one character per press', (
    tester,
  ) async {
    await pumpField(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(
      controller.selection,
      const TextSelection(baseOffset: 5, extentOffset: 6),
    );
  });

  testWidgets('unwrapped field reproduces the upstream regression', (
    tester,
  ) async {
    // 模拟与真机一致：不包裹时“选择”模式的方向键只移动光标。
    await pumpField(tester, wrapped: false);

    await sendSoftKeyboardKey(
      tester,
      SoftKeyboardKey.arrowLeft,
      selecting: true,
    );
    expect(controller.selection, const TextSelection.collapsed(offset: 4));
  });
}
