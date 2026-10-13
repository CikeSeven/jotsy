import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/node_diary_app.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'diary list changes after bootstrap do not rebuild the app shell',
    (tester) async {
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
      // 越过启动最短展示时长并等待首帧列表。
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();
      final shellBefore = tester.widget<MaterialApp>(find.byType(MaterialApp));

      await tester.runAsync(
        () => database.createDiary(
          title: 'after bootstrap',
          contentDocJson: '[{"insert":"content\\n"}]',
          contentText: 'content',
          metadataJson: '{}',
        ),
      );
      await tester.pumpAndSettle();

      final shellAfter = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(identical(shellBefore, shellAfter), isTrue);

      // 卸载应用并冲刷 drift 流取消时排入的零时长计时器，避免测试结束时残留。
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}
