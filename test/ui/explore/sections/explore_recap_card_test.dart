import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/explore/controllers/explore_module_actions.dart';
import 'package:node_diary/ui/explore/models/explore_module_config.dart';
import 'package:node_diary/ui/explore/models/explore_module_data.dart';
import 'package:node_diary/ui/explore/models/explore_module_id.dart';
import 'package:node_diary/ui/explore/models/explore_period.dart';
import 'package:node_diary/ui/explore/models/explore_view_data.dart';
import 'package:node_diary/ui/explore/sections/explore_recap_card.dart';

import '../../../support/expressive_test_theme.dart';

/// 记下卡片里“按标签搜索”的动作；其余动作用不到。
class _RecordingActions extends ExploreModuleActions {
  final List<int> tagSearches = <int>[];

  @override
  void openTagSearch(int tagId) => tagSearches.add(tagId);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// 周期回顾：“最常用的标签”与标签卡一样，点按打开这个标签的搜索。
void main() {
  testWidgets('the top tag opens the search for it', (tester) async {
    final actions = _RecordingActions();
    final now = DateTime(2026, 10, 28);
    final topTag = ExploreTagUsage(
      id: 42,
      name: '散步',
      color: 0xFF4CAF50,
      count: 3,
      latestDiaryId: 'd1',
      latestAt: now,
      maxCount: 3,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ExploreActionsScope(
            actions: actions,
            child: ExploreRecapCard(
              config: ExploreModuleConfig(ExploreModuleId.recap, visible: true),
              data: ExploreRecapData(
                period: ExplorePeriod.month,
                range: ExploreDateRange(DateTime(2026, 10), DateTime(2026, 11)),
                current: ExploreRecapStats(
                  entries: 3,
                  words: 120,
                  days: 3,
                  topTag: topTag,
                ),
                previous: const ExploreRecapStats(
                  entries: 0,
                  words: 0,
                  days: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('散步', findRichText: true));
    expect(actions.tagSearches, <int>[42]);
  });
}
