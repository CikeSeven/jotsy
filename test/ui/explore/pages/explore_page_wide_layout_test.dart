import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/explore/pages/explore_page.dart';
import 'package:node_diary/ui/explore/providers/explore_providers.dart';
import 'package:node_diary/ui/explore/sections/explore_insight_card.dart';
import 'package:node_diary/ui/explore/sections/explore_media_gallery_card.dart';
import 'package:node_diary/ui/explore/sections/explore_memory_card.dart';
import 'package:node_diary/ui/explore/sections/explore_stats_card.dart';

import '../../../support/expressive_test_theme.dart';

/// 探索页外壳：数据 provider 用固定空数据，不打开数据库。
Future<void> _pumpExplore(WidgetTester tester, Size size) async {
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
      ],
      child: MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: ExplorePage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a 1280 wide window centres explore at 960 and pairs the '
      'memory and insight cards', (tester) async {
    await _pumpExplore(tester, const Size(1280, 800));

    final stats = tester.getRect(find.byType(ExploreStatsCard));
    expect(stats.width, 960);
    expect(stats.center.dx, moreOrLessEquals(640));
    final memory = tester.getRect(find.byType(ExploreMemoryCard));
    final insight = tester.getRect(find.byType(ExploreInsightCard));
    expect(memory.top, insight.top);
    expect(insight.left, greaterThan(memory.right));
    expect(memory.left, stats.left);
    expect(insight.right, stats.right);
    expect(tester.getRect(find.byType(ExploreMediaGalleryCard)).width, 960);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a phone width keeps one full width column', (tester) async {
    await _pumpExplore(tester, const Size(400, 860));

    final stats = tester.getRect(find.byType(ExploreStatsCard));
    expect(stats.left, 16);
    expect(stats.width, 368);
    final memory = tester.getRect(find.byType(ExploreMemoryCard));
    final insight = tester.getRect(find.byType(ExploreInsightCard));
    expect(insight.top, greaterThan(memory.bottom));
    expect(memory.width, 368);
    expect(tester.takeException(), isNull);
  });
}
