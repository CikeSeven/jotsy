import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/providers/day_mood_providers.dart';
import 'package:node_diary/ui/diaries/providers/diary_draft_providers.dart';
import 'package:node_diary/ui/explore/pages/explore_page.dart';
import 'package:node_diary/ui/explore/providers/explore_providers.dart';
import 'package:node_diary/ui/explore/sections/explore_greeting_card.dart';
import 'package:node_diary/ui/explore/sections/explore_linked_cards.dart';
import 'package:node_diary/ui/explore/sections/explore_media_card.dart';
import 'package:node_diary/ui/explore/sections/explore_memory_card.dart';
import 'package:node_diary/ui/explore/sections/explore_mood_cards.dart';
import 'package:node_diary/ui/explore/sections/explore_random_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

/// 探索页外壳：数据 provider 用固定空数据，不打开数据库。[prefs] 为设置的
/// 初始值（如探索页布局）。
Future<void> _pumpExplore(
  WidgetTester tester,
  Size size, {
  Map<String, Object> prefs = const <String, Object>{},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        exploreDiariesProvider.overrideWith(
          (ref) => Stream.value(const <ExploreDiaryOverview>[]),
        ),
        tagListProvider.overrideWith((ref) => Stream.value(const <Tag>[])),
        moodOptionsProvider.overrideWith(
          (ref) => Stream.value(SettingsService.defaultMoodOptions),
        ),
        dayMoodsProvider.overrideWith(
          (ref) => Stream.value(const <DateTime, DayMood>{}),
        ),
        diaryDraftCountProvider.overrideWith((ref) => Stream.value(0)),
        exploreLockedCapsulesProvider.overrideWith(
          (ref) => Stream.value(const <LockedCapsuleSummary>[]),
        ),
      ],
      child: MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ExplorePage(now: DateTime(2026, 10, 28, 15))),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a 1280 wide window centres explore at 960 and pairs half '
      'width cards', (tester) async {
    await _pumpExplore(tester, const Size(1280, 1600));

    final greeting = tester.getRect(find.byType(ExploreGreetingCard));
    expect(greeting.width, 960);
    expect(greeting.center.dx, moreOrLessEquals(640));
    final memory = tester.getRect(find.byType(ExploreMemoryCard));
    final mood = tester.getRect(find.byType(ExploreMoodTrendCard));
    expect(memory.top, mood.top);
    expect(mood.left, greaterThan(memory.right));
    expect(memory.left, greeting.left);
    expect(mood.right, greeting.right);
    expect(tester.getRect(find.byType(ExploreMediaCard)).width, 960);
    expect(tester.takeException(), isNull);
  });

  testWidgets('three columns put three half cards side by side', (
    tester,
  ) async {
    await _pumpExplore(
      tester,
      const Size(1280, 1600),
      prefs: <String, Object>{
        'app.settings.explore_layout':
            '{"v":1,"current":{"m":[{"id":"onThisDay","on":true},'
            '{"id":"moodTrend","on":true},{"id":"randomMemory","on":true}],'
            '"look":{"columns":"three"}}}',
      },
    );
    final memory = tester.getRect(find.byType(ExploreMemoryCard));
    final mood = tester.getRect(find.byType(ExploreMoodTrendCard));
    final random = tester.getRect(find.byType(ExploreRandomCard));
    expect(memory.top, mood.top);
    expect(mood.top, random.top);
    expect(random.left, greaterThan(mood.right));
    // 布局里没写到的卡片按默认显隐补在后面：问候卡默认显示，排在这三张之后。
    expect(
      tester.getRect(find.byType(ExploreGreetingCard)).top,
      greaterThan(memory.bottom),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a phone width keeps one full width column', (tester) async {
    await _pumpExplore(tester, const Size(400, 2400));

    final greeting = tester.getRect(find.byType(ExploreGreetingCard));
    expect(greeting.left, 16);
    expect(greeting.width, 368);
    final memory = tester.getRect(find.byType(ExploreMemoryCard));
    final mood = tester.getRect(find.byType(ExploreMoodTrendCard));
    expect(mood.top, greaterThan(memory.bottom));
    expect(memory.width, 368);
    // 纪念日默认关闭：它的卡片不出现；时间胶囊默认开启。
    expect(find.byType(ExploreAnniversariesCard), findsNothing);
    expect(find.byType(ExploreCapsulesCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
