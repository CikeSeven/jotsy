import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_password/app_password_store.dart';
import 'package:node_diary/core/database/notebook_payload.dart';
import 'package:node_diary/ui/notebooks/controllers/notebook_editor_controller.dart';
import 'package:node_diary/ui/notebooks/sections/notebook_editor_behavior.dart';
import 'package:node_diary/ui/widgets/expressive_choice_tile.dart';

import 'notebook_test_support.dart';

class _FixedPasswordConfig extends AppPasswordConfigNotifier {
  _FixedPasswordConfig(this.value);

  final AppPasswordConfig value;

  @override
  AppPasswordConfig build() => value;
}

Future<NotebookEditorController> _pump(
  WidgetTester tester, {
  AppPasswordConfig password = AppPasswordConfig.initial,
}) async {
  final controller = NotebookEditorController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appPasswordConfigProvider.overrideWith(
          () => _FixedPasswordConfig(password),
        ),
      ],
      child: notebookTestApp(
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => SingleChildScrollView(
            child: NotebookEditorPrivacySection(controller: controller),
          ),
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
    expect(
      find.text('这台设备没有系统验证，在 数据与隐私 → 应用锁与密码 里设置应用密码后才能上锁'),
      findsOneWidget,
    );
    await tester.tap(find.text('上锁'));
    await tester.pumpAndSettle();
    expect(controller.visibility, NotebookVisibility.normal);
    // 其他选项照常可选。
    await tester.tap(find.text('不在全部日记中显示'));
    await tester.pumpAndSettle();
    expect(controller.visibility, NotebookVisibility.hidden);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('Linux can lock notebooks once an app password is set', (
    tester,
  ) async {
    final controller = await _pump(
      tester,
      password: const AppPasswordConfig(
        secret: AppPasswordSecret(
          hash: <int>[1],
          salt: <int>[2],
          iterations: 1,
        ),
      ),
    );
    expect(_tile(tester, '上锁').onTap, isNotNull);
    await tester.tap(find.text('上锁'));
    await tester.pumpAndSettle();
    expect(controller.visibility, NotebookVisibility.locked);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
