import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations_gen_en.dart';
import 'package:node_diary/ui/explore/models/explore_module_id.dart';
import 'package:node_diary/ui/explore/models/explore_period.dart';
import 'package:node_diary/ui/explore/models/explore_settings.dart';
import 'package:node_diary/ui/explore/pages/explore_page.dart';
import 'package:node_diary/ui/explore/sections/explore_greeting_card.dart';
import 'package:node_diary/ui/explore/sections/explore_linked_cards.dart';
import 'package:node_diary/ui/explore/sections/explore_overview_card.dart';
import 'package:node_diary/ui/explore/sections/explore_period_bar.dart';
import 'package:node_diary/ui/settings/pages/explore_layout_page.dart';

import '../../../support/explore_page_harness.dart';

void main() {
  final l10n = AppLocalizationsEn();
  final now = DateTime(2026, 10, 28, 15);
  Widget page() => Scaffold(body: ExplorePage(now: now));

  ExploreDiaryOverview diary(String id, DateTime created, String text) =>
      ExploreDiaryOverview(
        diaryId: id,
        title: id,
        contentText: text,
        metadata: '{}',
        createdAt: created,
        updatedAt: created,
        tags: const <Tag>[],
      );

  testWidgets('feature switches decide which linked cards appear', (
    tester,
  ) async {
    const layout =
        '{"v":1,"current":{"m":[{"id":"notebooks","on":true},'
        '{"id":"anniversaries","on":true},{"id":"capsules","on":true}]}}';
    await pumpExploreHarness(
      tester,
      page(),
      prefs: <String, Object>{
        'app.settings.explore_layout': layout,
        'app.settings.app_features':
            '{"anniversaries":true,"timeCapsules":false,"notebooks":true}',
      },
    );
    expect(find.byType(ExploreAnniversariesCard), findsOneWidget);
    expect(find.byType(ExploreNotebooksCard), findsOneWidget);
    expect(find.byType(ExploreCapsulesCard), findsNothing);

    await pumpExploreHarness(
      tester,
      page(),
      prefs: <String, Object>{
        'app.settings.explore_layout': layout,
        'app.settings.app_features':
            '{"anniversaries":false,"timeCapsules":true,"notebooks":false}',
      },
    );
    expect(find.byType(ExploreAnniversariesCard), findsNothing);
    expect(find.byType(ExploreNotebooksCard), findsNothing);
    expect(find.byType(ExploreCapsulesCard), findsOneWidget);
  });

  testWidgets('drafts card shows only while there are drafts', (tester) async {
    await pumpExploreHarness(tester, page(), draftCount: 0);
    expect(find.byType(ExploreDraftsCard), findsNothing);
    await pumpExploreHarness(tester, page(), draftCount: 2);
    expect(find.byType(ExploreDraftsCard), findsOneWidget);
    expect(find.text(l10n.exploreDraftsCount(0)), findsOneWidget);
  });

  testWidgets('long press hides a card and undo brings it back', (
    tester,
  ) async {
    final settings = await pumpExploreHarness(tester, page());
    expect(find.byType(ExploreGreetingCard), findsOneWidget);

    await tester.longPress(find.byType(ExploreGreetingCard));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.exploreModuleMenuHide));
    await tester.pumpAndSettle();
    expect(find.byType(ExploreGreetingCard), findsNothing);
    expect(
      ExploreSettings.decode(
        settings.exploreLayoutRaw,
      ).current.module(ExploreModuleId.greeting).visible,
      isFalse,
    );

    await tester.tap(find.text(l10n.commonUndo));
    await tester.pumpAndSettle();
    expect(find.byType(ExploreGreetingCard), findsOneWidget);
  });

  testWidgets('the range bar switches the dashboard and is remembered', (
    tester,
  ) async {
    final settings = await pumpExploreHarness(
      tester,
      page(),
      diaries: <ExploreDiaryOverview>[
        diary('a', DateTime(2026, 10, 27, 9), 'one two'),
        diary('b', DateTime(2026, 9, 1, 9), 'three'),
      ],
    );
    final overview = find.byType(ExploreOverviewCard);
    expect(
      find.descendant(of: overview, matching: find.text(l10n.explorePeriodAll)),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(ExplorePeriodBar),
        matching: find.text(l10n.explorePeriodMonth),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: overview,
        matching: find.text(l10n.explorePeriodMonth),
      ),
      findsOneWidget,
    );
    expect(
      ExploreSettings.decode(settings.exploreLayoutRaw).behavior.period,
      ExplorePeriod.month,
    );
  });

  testWidgets('hiding every card shows a hint that opens the customizer', (
    tester,
  ) async {
    await pumpExploreHarness(
      tester,
      page(),
      prefs: <String, Object>{
        'app.settings.explore_layout':
            '{"v":1,"current":{"bar":false,"m":['
            '${ExploreModuleId.values.map((id) => '{"id":"${id.name}","on":false}').join(',')}'
            ']}}',
      },
    );
    expect(find.text(l10n.exploreNoModules), findsOneWidget);
    expect(find.byType(ExplorePeriodBar), findsNothing);
    await tester.tap(find.text(l10n.exploreCustomize).last);
    await tester.pumpAndSettle();
    expect(find.byType(ExploreLayoutPage), findsOneWidget);
  });
}
