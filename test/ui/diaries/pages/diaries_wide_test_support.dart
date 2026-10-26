import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_detail_provider.dart';
import 'package:node_diary/ui/diaries/providers/diary_draft_providers.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:node_diary/ui/diaries/sections/diaries_list_section.dart';
import 'package:node_diary/ui/diaries/widgets/diary_card/diary_card.dart';
import 'package:node_diary/ui/notebooks/providers/notebook_providers.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

/// 宽窗口日记页测试的夹具：日记列表、详情与删除都在内存里，不读真实库。
///
/// 列表由 [WideDiaryStore] 驱动（删除 / 恢复后重新推送），详情按 id 取同一
/// 份数据；数据库只用来承接软删除与恢复（写回 store）。

/// 一篇测试日记；[prefix] 区分用例（卡片派生数据按 id + 更新时间缓存）。
DiaryWithTags wideDiary(String prefix, int index, {DateTime? unlockAt}) {
  final at = DateTime(2026, 10, 20 - index % 10, 9);
  return DiaryWithTags(
    diary: Diary(
      id: index + 1,
      diaryId: '$prefix-$index',
      title: '$prefix title $index',
      content: '[{"insert":"$prefix body $index\\n"}]',
      contentText: '$prefix body $index',
      metadata: '{}',
      createdAt: at,
      updatedAt: at,
      isArchived: false,
      isPinned: false,
      isDeleted: false,
      capsuleLockedAt: unlockAt == null ? null : at,
      capsuleUnlockAt: unlockAt,
    ),
    tags: const <Tag>[],
  );
}

/// 内存里的日记集合：软删除的不再出现在列表里，恢复后回到原位。
class WideDiaryStore {
  WideDiaryStore(List<DiaryWithTags> diaries)
    : _diaries = List<DiaryWithTags>.of(diaries);

  final List<DiaryWithTags> _diaries;
  final Set<String> deleted = <String>{};
  final Set<String> restored = <String>{};

  /// 经 `pinDiary` 置顶过的日记（不改列表，只记录写入）。
  final Set<String> pinned = <String>{};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  List<DiaryWithTags> get visible => <DiaryWithTags>[
    for (final diary in _diaries)
      if (!deleted.contains(diary.diary.diaryId)) diary,
  ];

  DiaryWithTags? byId(String diaryId) {
    for (final diary in _diaries) {
      if (diary.diary.diaryId == diaryId) {
        return diary;
      }
    }
    return null;
  }

  void softDelete(String diaryId) {
    deleted.add(diaryId);
    _changes.add(null);
  }

  void restore(String diaryId) {
    deleted.remove(diaryId);
    restored.add(diaryId);
    _changes.add(null);
  }

  /// 每次变化都按查询的窗口重新推送一页。
  Stream<PagedDiariesResult> watch(DiaryPageQuery query) async* {
    PagedDiariesResult page() {
      final all = visible;
      return PagedDiariesResult(
        items: all.take(query.limit).toList(growable: false),
        limit: query.limit,
        hasMore: all.length > query.limit,
      );
    }

    yield page();
    await for (final _ in _changes.stream) {
      yield page();
    }
  }

  Future<void> close() => _changes.close();
}

/// 软删除与恢复写回 [WideDiaryStore]；其余查询走真实的内存库（多为空）。
class WideDiaryDatabase extends AppDatabase {
  WideDiaryDatabase(this.store) : super.forTesting(NativeDatabase.memory());

  final WideDiaryStore store;

  @override
  Future<void> softDeleteDiary(
    String diaryId, {
    bool touchUpdatedAt = true,
  }) async {
    store.softDelete(diaryId);
  }

  @override
  Future<void> pinDiary(String diaryId, {bool touchUpdatedAt = false}) async {
    store.pinned.add(diaryId);
  }

  @override
  Future<void> restoreDiary(
    String diaryId, {
    bool touchUpdatedAt = true,
  }) async {
    store.restore(diaryId);
  }
}

/// 以 [size] 的窗口挂载日记页（不经首页外壳：页面拿到整个窗口宽度）。
Future<WideDiaryStore> pumpWideDiariesPage(
  WidgetTester tester, {
  required Size size,
  required List<DiaryWithTags> diaries,
  Map<String, Object> preferences = const <String, Object>{},
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(preferences);
  final settings = await SettingsService.create();
  final store = WideDiaryStore(diaries);
  final database = WideDiaryDatabase(store);
  addTearDown(() async {
    await store.close();
    await database.close();
  });
  final theme = expressiveTestTheme(Brightness.light);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        diaryDraftCountProvider.overrideWith((ref) => Stream.value(0)),
        notebooksProvider.overrideWith(
          (ref) => Stream.value(const <NotebookView>[]),
        ),
        diaryNotebooksProvider.overrideWith(
          (ref, diaryId) async => const <NotebookView>[],
        ),
        settingsServiceProvider.overrideWith((ref) async => settings),
        tagListProvider.overrideWith((ref) => Stream.value(const <Tag>[])),
        pagedDiariesProvider.overrideWith((ref, query) => store.watch(query)),
        diaryDetailProvider.overrideWith(
          (ref, diaryId) async => store.byId(diaryId),
        ),
      ],
      child: MaterialApp(
        theme: theme,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DiariesPage(pageBackgroundColor: theme.colorScheme.surface),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

/// 卸载页面并让 drift 留下的 0 时长计时器走完。
Future<void> unmountWideDiariesPage(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

/// 列表里标题为 [title] 的卡片（点它的中心即点到前景浮层里的 InkWell）。
Finder wideCard(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(DiaryCard)).first;

/// 列表区里的所有卡片。
Finder get wideListCards => find.descendant(
  of: find.byType(DiariesListSection),
  matching: find.byType(DiaryCard),
);
