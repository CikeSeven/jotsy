import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/node_diary_app.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Navigator 之上、颜色为当前主题 surface 的不透明底色。
Finder _surfaceBaseAboveNavigator(WidgetTester tester) {
  final navigator = find.byType(Navigator).first;
  final surface = Theme.of(tester.element(navigator)).colorScheme.surface;
  return find.ancestor(
    of: navigator,
    matching: find.byWidgetPredicate(
      (w) => w is ColoredBox && w.color == surface && w.color.a == 1.0,
    ),
  );
}

Future<void> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(database.close);
  final settings = await SettingsService.create();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        settingsServiceProvider.overrideWith((ref) async => settings),
      ],
      child: const NodeDiaryApp(),
    ),
  );
  // 越过启动最短展示时长。
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pumpAndSettle();
}

Future<void> _unmount(WidgetTester tester) async {
  // 冲刷 drift 流取消时排入的零时长计时器。
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  testWidgets('desktop puts an opaque surface base under the navigator', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await _pumpApp(tester);
    expect(_surfaceBaseAboveNavigator(tester), findsOneWidget);
    await _unmount(tester);
    // 测试框架在 tearDown 之前检查该覆盖已复位。
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('android keeps the navigator without the surface base', (
    tester,
  ) async {
    await _pumpApp(tester);
    expect(_surfaceBaseAboveNavigator(tester), findsNothing);
    await _unmount(tester);
  });
}
