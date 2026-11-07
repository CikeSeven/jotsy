import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_search_preferences.dart';
import 'package:node_diary/ui/diaries/pages/diary_search_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:node_diary/ui/diaries/providers/diary_search_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/calendar_test_harness.dart' show calendarTestDiary;
import '../../../support/expressive_test_theme.dart';

const Tag _travel = Tag(id: 1, name: 'Travel', color: 0xff336699);
const Tag _food = Tag(id: 2, name: 'Food', color: 0xff993366);

/// 搜索页的测试装配：查询全部经 provider 覆盖（不接真实数据库），记下页面
/// 每次订阅的分页查询，便于断言条件是否传到了查询里。
class _SearchHarness {
  _SearchHarness(this.settings);

  final SettingsService settings;
  final List<DiaryPageQuery> queries = <DiaryPageQuery>[];

  DiaryPageQuery get lastQuery => queries.last;

  DiarySearchPreferences get savedPreferences =>
      DiarySearchPreferences.decode(settings.diarySearchPreferencesRaw);
}

Future<_SearchHarness> _pumpSearch(
  WidgetTester tester, {
  String initialKeyword = '',
  List<String> recent = const <String>[],
  List<DiaryWithTags> results = const <DiaryWithTags>[],
  int count = 0,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    if (recent.isNotEmpty)
      'app.search.preferences': DiarySearchPreferences(recent: recent).encode(),
  });
  final settings = await SettingsService.create();
  final harness = _SearchHarness(settings);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsServiceProvider.overrideWith((ref) async => settings),
        tagListProvider.overrideWith(
          (ref) => Stream.value(const <Tag>[_travel, _food]),
        ),
        tagUsageCountsProvider.overrideWith(
          (ref, scope) => Stream.value(const <TagUsageCount>[
            TagUsageCount(tagId: 2, uses: 5),
            TagUsageCount(tagId: 1, uses: 3),
          ]),
        ),
        searchDiariesProvider.overrideWith((ref, query) {
          harness.queries.add(query);
          return Stream.value(
            PagedDiariesResult(
              items: results,
              limit: query.limit,
              hasMore: false,
            ),
          );
        }),
        searchDiaryCountProvider.overrideWith(
          (ref, query) => Stream.value(count),
        ),
      ],
      child: MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  DiarySearchPage.buildRoute(initialKeyword: initialKeyword),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return harness;
}

/// 收起当前的底部面板（点遮罩）。
Future<void> _closeSheet(WidgetTester tester) async {
  await tester.tapAt(const Offset(4, 4));
  await tester.pumpAndSettle();
}

/// 输入框里的文字。
String _fieldText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  testWidgets('empty state lists recent searches and frequent tags', (
    tester,
  ) async {
    final h = await _pumpSearch(tester, recent: <String>['kyoto', 'rain']);

    expect(find.text('Recent searches'), findsOneWidget);
    expect(find.text('Frequent tags'), findsOneWidget);
    expect(find.text('kyoto'), findsOneWidget);
    // 常用标签按篇数排：Food（5）在 Travel（3）前面。
    final food = tester.getTopLeft(find.text('# Food'));
    final travel = tester.getTopLeft(find.text('# Travel'));
    expect(food.dx, lessThan(travel.dx));
    // 没有条件时不查询。
    expect(h.queries, isEmpty);

    await tester.tap(find.text('kyoto'));
    await tester.pumpAndSettle();
    expect(_fieldText(tester), 'kyoto');
    expect(h.lastQuery.keyword, 'kyoto');
    expect(find.text('Recent searches'), findsNothing);
    // 点过的搜索移到最前。
    expect(h.savedPreferences.recent, <String>['kyoto', 'rain']);
  });

  testWidgets('recent searches can be removed one by one or cleared', (
    tester,
  ) async {
    final h = await _pumpSearch(tester, recent: <String>['kyoto', 'rain']);

    await tester.tap(
      find.bySemanticsLabel('Remove “kyoto” from recent searches'),
    );
    await tester.pumpAndSettle();
    expect(find.text('kyoto'), findsNothing);
    expect(h.savedPreferences.recent, <String>['rain']);

    await tester.tap(find.bySemanticsLabel('Clear recent searches'));
    await tester.pumpAndSettle();
    expect(find.text('Recent searches'), findsNothing);
    expect(h.savedPreferences.recent, isEmpty);
  });

  testWidgets('a frequent tag becomes a removable condition', (tester) async {
    final h = await _pumpSearch(tester);

    await tester.tap(find.text('# Travel'));
    await tester.pumpAndSettle();
    expect(h.lastQuery.requiredTagIds, <int>[1]);
    expect(find.bySemanticsLabel('Remove tag Travel'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Remove tag Travel'));
    await tester.pumpAndSettle();
    expect(find.text('Frequent tags'), findsOneWidget);
  });

  testWidgets('submitting a search remembers it and hides the keyboard', (
    tester,
  ) async {
    final h = await _pumpSearch(tester);

    await tester.enterText(find.byType(TextField), '  sea  breeze ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(h.lastQuery.keyword, 'sea  breeze');
    expect(h.savedPreferences.recent, <String>['sea  breeze']);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('results show the count, highlight words and sort', (
    tester,
  ) async {
    final h = await _pumpSearch(
      tester,
      initialKeyword: 'sea',
      count: 3,
      results: <DiaryWithTags>[
        calendarTestDiary(
          'search-highlight-1',
          DateTime(2026, 10, 1),
          title: 'By the sea',
          text: 'Waves',
        ),
      ],
    );

    expect(find.text('3 entries'), findsOneWidget);
    final title = tester.widget<RichText>(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText() == 'By the sea',
      ),
    );
    final spans = <InlineSpan>[];
    title.text.visitChildren((span) {
      spans.add(span);
      return true;
    });
    expect(
      spans.whereType<TextSpan>().where(
        (span) => span.text == 'sea' && span.style?.backgroundColor != null,
      ),
      hasLength(1),
    );

    expect(h.lastQuery.sortMode, DiarySortMode.updatedDesc);
    await tester.tap(find.text('Recently updated'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oldest').last);
    await tester.pumpAndSettle();
    expect(h.lastQuery.sortMode, DiarySortMode.createdAsc);
    expect(h.savedPreferences.sort, DiarySearchSort.createdAsc);
  });

  testWidgets('filters reach the query and can be cleared', (tester) async {
    final h = await _pumpSearch(tester, initialKeyword: 'sea');
    expect(h.lastQuery.filter, isNull);
    expect(h.lastQuery.includeArchived, isFalse);

    // 筛选行横向滚动，“含归档”排在最后，先滚出来。
    await tester.ensureVisible(find.text('Include archived'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Include archived'));
    await tester.pumpAndSettle();
    expect(h.lastQuery.includeArchived, isTrue);

    await tester.ensureVisible(find.text('Mood'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mood'));
    await tester.pumpAndSettle();
    // 筛选面板没有“完成”：点选即生效。
    expect(find.text('Done'), findsNothing);
    await tester.tap(find.text(SettingsService.defaultMoodOptions.first).last);
    await tester.pumpAndSettle();
    expect(h.lastQuery.filter, isNotNull);
    await _closeSheet(tester);
    expect(find.text('Mood'), findsNothing);
    final moodChip = find.byKey(const ValueKey<String>('search_filter_mood'));
    expect(
      find.descendant(
        of: moodChip,
        matching: find.text(SettingsService.defaultMoodOptions.first),
      ),
      findsOneWidget,
    );

    // 没有结果时可以一键清除全部筛选（含“含归档”）。
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(h.lastQuery.filter, isNull);
    expect(h.lastQuery.includeArchived, isFalse);
    expect(find.text('Mood'), findsOneWidget);
  });

  testWidgets('filter sheets apply live and opening alone changes nothing', (
    tester,
  ) async {
    final h = await _pumpSearch(tester, initialKeyword: 'sea');

    // 打开媒体面板不预选任何一项，什么都不点就关掉，筛选不变。
    await tester.ensureVisible(find.text('Media'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Media'));
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsNothing);
    await _closeSheet(tester);
    expect(h.lastQuery.filter, isNull);

    // 点一项立即生效，面板仍开着。
    await tester.tap(find.text('Media'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Has photos'));
    await tester.pumpAndSettle();
    expect(h.lastQuery.filter, isNotNull);
    expect(find.text('Has photos'), findsWidgets);
    await _closeSheet(tester);

    // 心情全部取消即清除这一项。
    await tester.tap(find.text('Mood'));
    await tester.pumpAndSettle();
    final mood = find.text(SettingsService.defaultMoodOptions.last).last;
    await tester.tap(mood);
    await tester.pumpAndSettle();
    final withMood = h.lastQuery.filter;
    await tester.tap(mood);
    await tester.pumpAndSettle();
    expect(h.lastQuery.filter, isNot(withMood));
    await _closeSheet(tester);
    expect(find.text('Mood'), findsOneWidget);
  });

  testWidgets('picked tags are written on the tag chip, not listed', (
    tester,
  ) async {
    final h = await _pumpSearch(tester, initialKeyword: 'sea');
    final tagChip = find.byKey(const ValueKey<String>('search_filter_tags'));
    expect(
      find.descendant(of: tagChip, matching: find.text('Tags')),
      findsOneWidget,
    );

    // 标签面板点选即生效，没有“完成”。
    await tester.tap(tagChip);
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsNothing);
    await tester.tap(find.text('# Travel'));
    await tester.pumpAndSettle();
    expect(h.lastQuery.requiredTagIds, <int>[1]);
    await tester.tap(find.text('# Food'));
    await tester.pumpAndSettle();
    expect(h.lastQuery.requiredTagIds, <int>[1, 2]);
    await _closeSheet(tester);

    // 所选标签都写在“标签”胶囊上（按标签列表的顺序），不再逐个列成胶囊。
    expect(
      find.descendant(of: tagChip, matching: find.text('#Travel #Food')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'search_tag_chip_',
            ),
      ),
      findsNothing,
    );

    // 行尾 × 一次清掉全部标签。
    await tester.tap(find.bySemanticsLabel('Remove filter #Travel #Food'));
    await tester.pumpAndSettle();
    expect(h.lastQuery.requiredTagIds, isEmpty);
    expect(
      find.descendant(of: tagChip, matching: find.text('Tags')),
      findsOneWidget,
    );
  });

  testWidgets('desktop: Escape clears the text first, then leaves', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await _pumpSearch(tester, initialKeyword: 'sea');
    expect(_fieldText(tester), 'sea');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_fieldText(tester), isEmpty);
    expect(find.byType(DiarySearchPage), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(DiarySearchPage), findsNothing);
    // 平台覆盖须在测试体内复位（框架在 tearDown 之前检查）。
    debugDefaultTargetPlatformOverride = null;
  });
}
