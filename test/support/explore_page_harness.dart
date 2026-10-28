import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/anniversaries/providers/anniversary_providers.dart';
import 'package:node_diary/ui/calendar/providers/day_mood_providers.dart';
import 'package:node_diary/ui/diaries/providers/diary_draft_providers.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_draft_list_item.dart';
import 'package:node_diary/ui/explore/controllers/explore_comment_stats.dart';
import 'package:node_diary/ui/explore/providers/explore_providers.dart';
import 'package:node_diary/ui/notebooks/providers/notebook_providers.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'expressive_test_theme.dart';

/// 探索页与自定义页的测试外壳：设置服务用内存偏好（[prefs] 为初始值），
/// 各数据 provider 用固定数据，不打开数据库。返回设置服务，供断言写入。
///
/// [comments] 为“最近的留言”卡片的留言（新 → 旧），统计按它现算。
Future<SettingsService> pumpExploreHarness(
  WidgetTester tester,
  Widget home, {
  Map<String, Object> prefs = const <String, Object>{},
  List<ExploreDiaryOverview> diaries = const <ExploreDiaryOverview>[],
  int draftCount = 0,
  List<DiaryCommentSummary> comments = const <DiaryCommentSummary>[],
  Size size = const Size(400, 2400),
}) async {
  // 同一个测试里第二次调用时先拆掉上一棵树：ProviderScope 原位复用时不会
  // 换用新的 overrides。
  await tester.pumpWidget(const SizedBox.shrink());
  SharedPreferences.setMockInitialValues(prefs);
  final settings = await SettingsService.create();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsServiceProvider.overrideWith((ref) async => settings),
        exploreDiariesProvider.overrideWith((ref) => Stream.value(diaries)),
        tagListProvider.overrideWith((ref) => Stream.value(const <Tag>[])),
        moodOptionsProvider.overrideWith(
          (ref) => Stream.value(SettingsService.defaultMoodOptions),
        ),
        dayMoodsProvider.overrideWith(
          (ref) => Stream.value(const <DateTime, DayMood>{}),
        ),
        diaryDraftCountProvider.overrideWith((ref) => Stream.value(draftCount)),
        diaryDraftsProvider.overrideWith(
          (ref) => Stream.value(const <DiaryDraftListItem>[]),
        ),
        exploreLockedCapsulesProvider.overrideWith(
          (ref) => Stream.value(const <LockedCapsuleSummary>[]),
        ),
        anniversaryListProvider.overrideWith(
          (ref) => Stream.value(const <Anniversary>[]),
        ),
        notebooksProvider.overrideWith(
          (ref) => Stream.value(const <NotebookView>[]),
        ),
        notebookEntryCountsProvider.overrideWith(
          (ref) => Stream.value(const <String, int>{}),
        ),
        explorePhotoCountsProvider.overrideWith(
          (ref) => Stream.value(const <String, int>{}),
        ),
        exploreRecentCommentsProvider.overrideWith(
          (ref) => Stream.value(comments),
        ),
        exploreCommentStatsProvider.overrideWith(
          (ref) => Stream.value(
            ExploreCommentStats.of(<DiaryCommentTiming>[
              for (final comment in comments)
                DiaryCommentTiming(
                  diaryId: comment.diaryId,
                  createdAt: comment.createdAt,
                  diaryCreatedAt: comment.diaryCreatedAt,
                ),
            ]),
          ),
        ),
      ],
      child: MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return settings;
}
