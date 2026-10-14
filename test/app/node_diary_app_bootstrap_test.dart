import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/node_diary_app.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:node_diary/ui/home/pages/home_page.dart';
import 'package:node_diary/ui/widgets/app_loading_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpApp(WidgetTester tester, {Duration? diariesDelay}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(database.close);
  final settings = await SettingsService.create();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        settingsServiceProvider.overrideWith((ref) async => settings),
        if (diariesDelay != null)
          pagedDiariesProvider.overrideWith(
            (ref, query) => Stream.fromFuture(
              Future<PagedDiariesResult>.delayed(
                diariesDelay,
                () => PagedDiariesResult(
                  items: const <DiaryWithTags>[],
                  limit: query.limit,
                  hasMore: false,
                ),
              ),
            ),
          ),
      ],
      child: const NodeDiaryApp(),
    ),
  );
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

void main() {
  testWidgets('fast bootstrap goes straight home without a loader flash', (
    tester,
  ) async {
    await _pumpApp(tester);
    for (var frame = 0; frame < 25; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(AppLoadingContent), findsNothing, reason: '$frame');
    }
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('slow bootstrap shows the loader for a minimum duration', (
    tester,
  ) async {
    await _pumpApp(tester, diariesDelay: const Duration(milliseconds: 400));

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(AppLoadingContent), findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AppLoadingContent), findsOneWidget);

    // 数据在 400ms 到达，但加载页需至少保留到 250 + 500 = 750ms。
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(HomePage), findsNothing);
    expect(find.byType(AppLoadingContent), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(AppLoadingContent), findsNothing);
    await _unmount(tester);
  });

  testWidgets('the diary list is already there on the first home frame', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = await SettingsService.create();
    // 非默认排序：预热必须与日记页首帧的查询完全一致才能命中同一实例。
    await settings.setDiarySortModeRaw('titleAsc');
    await tester.runAsync(
      () => database.createDiary(
        title: 'Warm start',
        contentDocJson: '[{"insert":"body\\n"}]',
        contentText: 'body',
        metadataJson: '{}',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: const NodeDiaryApp(),
      ),
    );
    var sawHome = false;
    for (var frame = 0; frame < 120 && !sawHome; frame++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      if (find.byType(HomePage).evaluate().isEmpty) {
        continue;
      }
      sawHome = true;
      // 首页出现的同一帧里列表已有数据，不会先空白/转圈再硬切。
      expect(find.text('Warm start'), findsOneWidget);
    }
    expect(sawHome, isTrue);
    await _unmount(tester);
  });
}
