import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:node_diary/ui/settings/pages/tag_management_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';

/// 使用内存数据库和隔离偏好验证真实删除链路，避免只测试数据库而遗漏
/// 排序、记忆筛选和当前筛选的清理，也不触碰用户已有标签与日记。
void main() {
  late AppDatabase database;
  late SettingsService settings;
  late int removedTagId;
  late int retainedTagId;
  late int lastTagId;
  late String diaryId;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
    removedTagId = await database.createTag(
      name: 'Removed tag',
      color: 0xff336699,
    );
    retainedTagId = await database.createTag(
      name: 'Retained tag',
      color: 0xff336699,
    );
    lastTagId = await database.createTag(name: 'Last tag', color: 0xff336699);
    diaryId = await database.createDiary(
      title: 'Retained diary',
      contentDocJson: '[{"insert":"content\\n"}]',
      contentText: 'content',
      metadataJson: '{}',
      tagIds: <int>[removedTagId, retainedTagId],
    );
  });
  tearDown(() => database.close());

  // 两份偏好都未保存时会先在排序清理处失败；单独保留排序的场景还需覆盖
  // 记忆筛选清理，确保修复没有仅绕过第一份只读空列表。
  const scenarios = [
    (
      description: 'without saved tag preferences',
      saveOrder: false,
      saveFilters: false,
    ),
    (
      description: 'with a saved order and no remembered filters',
      saveOrder: true,
      saveFilters: false,
    ),
    (
      description: 'with a saved order and remembered filters',
      saveOrder: true,
      saveFilters: true,
    ),
  ];

  for (final brightness in Brightness.values) {
    for (final scenario in scenarios) {
      testWidgets(
        'deleting a tag succeeds ${scenario.description} in ${brightness.name}',
        (tester) async {
          if (scenario.saveOrder) {
            await settings.setTagOrderRaw(
              '$lastTagId,$removedTagId,$retainedTagId',
            );
          }
          if (scenario.saveFilters) {
            await settings.setTagFilterMemoryEnabled(true);
            await settings.setRememberedTagFilterIdsRaw(
              '$retainedTagId,$removedTagId,$lastTagId',
            );
          }
          final container = ProviderContainer(
            overrides: [
              appDatabaseProvider.overrideWithValue(database),
              settingsServiceProvider.overrideWith((ref) async => settings),
            ],
          );
          addTearDown(container.dispose);
          final filters = container.read(diaryFilterProvider.notifier);
          filters.setKeyword('content');
          filters.setTags(<int>[removedTagId, retainedTagId]);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: expressiveTestTheme(brightness),
                locale: const Locale('zh'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const TagManagementPage(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final l10n = tester.element(find.byType(TagManagementPage)).l10n;
          final removedTile = find.byKey(ValueKey<int>(removedTagId));

          await tester.tap(
            find.descendant(
              of: removedTile,
              matching: find.byTooltip(l10n.autoT0038),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          await tester.tap(find.widgetWithText(TextButton, l10n.commonDelete));
          await tester.pumpAndSettle();

          expect(find.textContaining(l10n.autoT0036('')), findsNothing);
          expect(removedTile, findsNothing);
          expect(find.byKey(ValueKey<int>(retainedTagId)), findsOneWidget);
          expect(find.byKey(ValueKey<int>(lastTagId)), findsOneWidget);
          // Drift 的查询调度使用事件队列；无帧泵送的持久化校验需退出
          // widget 测试的虚拟时钟，避免查询等待真实事件却无法完成。
          final remainingTags = await tester.runAsync(
            () => database.select(database.tags).get(),
          );
          expect(
            remainingTags!.map((tag) => tag.id),
            unorderedEquals(<int>[retainedTagId, lastTagId]),
          );
          expect(
            settings.tagOrderRaw,
            scenario.saveOrder ? '$lastTagId,$retainedTagId' : '',
          );
          expect(
            settings.rememberedTagFilterIdsRaw,
            scenario.saveFilters ? '$retainedTagId,$lastTagId' : isNull,
          );
          expect(container.read(diaryFilterProvider).selectedTagIds, <int>{
            retainedTagId,
          });
          expect(container.read(diaryFilterProvider).keyword, 'content');
          final diary = await tester.runAsync(
            () => database.getDiaryWithTagsByDiaryId(diaryId),
          );
          expect(diary, isNotNull);
          expect(diary!.diary.contentText, 'content');
          expect(diary.tags.map((tag) => tag.id), <int>[retainedTagId]);
          expect(tester.takeException(), isNull);

          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
