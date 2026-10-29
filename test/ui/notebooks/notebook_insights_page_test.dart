import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/device_auth_service.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/explore/sections/explore_memory_card.dart';
import 'package:node_diary/ui/explore/widgets/explore_shared_widgets.dart';
import 'package:node_diary/ui/notebooks/pages/notebook_insights_page.dart';
import 'package:node_diary/ui/notebooks/sections/notebook_insights_cards.dart';
import 'package:node_diary/ui/notebooks/sections/notebook_insights_charts.dart';

import '../../support/diary_drafts_harness.dart';
import 'notebook_test_support.dart';

/// 日记本统计页：总览数字、心情分布、常用标签、写作节奏、那年今日与“随机
/// 翻一篇”；未解封的胶囊、回收站与本子外的日记都不计入；写作目标卡；空本子。
void main() {
  /// 一年前的今天（今天是 2 月 29 日时退到四年前，那年同样有这一天）。
  DateTime yearAgoToday() {
    final now = DateTime.now();
    final back = now.month == 2 && now.day == 29 ? 4 : 1;
    return DateTime(now.year - back, now.month, now.day, 10);
  }

  Future<String> diary(
    DiaryDraftsHarness h,
    String title, {
    required List<String> notebookIds,
    required DateTime createdAt,
    String? mood,
    List<int> tagIds = const <int>[],
    DateTime? capsuleUnlockAt,
  }) async {
    return (await h.tester.runAsync(
      () => h.database.createDiary(
        title: title,
        contentDocJson: '[{"insert":"$title 的正文\\n"}]',
        contentText: '$title 的正文',
        metadataJson: mood == null ? '{}' : '{"context":{"moodEmoji":"$mood"}}',
        tagIds: tagIds,
        createdAtOverride: createdAt,
        capsuleUnlockAt: capsuleUnlockAt,
        capsuleLockedAt: capsuleUnlockAt == null ? null : DateTime.now(),
        notebookIds: notebookIds,
      ),
    ))!;
  }

  late Map<String, String> ids;

  Future<(DiaryDraftsHarness, String)> open(
    WidgetTester tester, {
    NotebookPayload payload = NotebookPayload.defaults,
    bool seed = true,
  }) async {
    final h = await DiaryDraftsHarness.create(tester);
    tester.view.physicalSize = const Size(320, 1400);
    final travel = await h.notebook('旅行', payload: payload);
    final other = await h.notebook('工作');
    ids = <String, String>{};
    if (seed) {
      final sea = (await tester.runAsync(
        () => h.database.createTag(name: '海边', color: 0xFF2196F3),
      ))!;
      final now = DateTime.now();
      ids['去年今日'] = await diary(
        h,
        '去年今日',
        notebookIds: <String>[travel],
        createdAt: yearAgoToday(),
        mood: '😊',
        tagIds: <int>[sea],
      );
      ids['前天'] = await diary(
        h,
        '前天',
        notebookIds: <String>[travel],
        createdAt: DateTime(now.year, now.month, now.day - 2, 9),
        mood: '😊',
        tagIds: <int>[sea],
      );
      ids['归档的'] = await diary(
        h,
        '归档的',
        notebookIds: <String>[travel],
        createdAt: DateTime(now.year, now.month, now.day - 3, 9),
        mood: '😢',
      );
      await tester.runAsync(() => h.database.archiveDiary(ids['归档的']!));
      // 未解封的胶囊：心情、篇数、日期都不能出现。
      await diary(
        h,
        '胶囊',
        notebookIds: <String>[travel],
        createdAt: DateTime(now.year, now.month, now.day - 1, 9),
        mood: '😡',
        capsuleUnlockAt: now.add(const Duration(days: 30)),
      );
      final deleted = await diary(
        h,
        '删掉的',
        notebookIds: <String>[travel],
        createdAt: DateTime(now.year, now.month, now.day - 1, 9),
        mood: '🥶',
      );
      await tester.runAsync(() => h.database.softDeleteDiary(deleted));
      await diary(
        h,
        '别的本子',
        notebookIds: <String>[other],
        createdAt: DateTime(now.year, now.month, now.day - 1, 9),
        mood: '🤯',
      );
    }
    await h.pump(
      NotebookInsightsPage(notebookId: travel, random: Random(7)),
      overrides: [
        deviceAuthServiceProvider.overrideWithValue(FakeDeviceAuth()),
      ],
    );
    await h.settleAll();
    return (h, travel);
  }

  int tileValue(WidgetTester tester, String label) => tester
      .widget<ExploreStatTile>(find.widgetWithText(ExploreStatTile, label))
      .value;

  testWidgets('shows overview, moods, tags, rhythm and that year today', (
    tester,
  ) async {
    final (h, _) = await open(tester);
    expect(find.text('统计'), findsOneWidget);
    expect(find.text('旅行'), findsOneWidget);

    // 3 篇：含归档，不含胶囊、回收站与别的本子。
    expect(tileValue(tester, '篇数'), 3);
    expect(tileValue(tester, '记录天数'), 3);
    expect(tileValue(tester, '最长连续'), 2);
    expect(tileValue(tester, '照片数'), 0);

    final moods = find.byType(NotebookInsightsMoodCard);
    expect(moods, findsOneWidget);
    expect(find.descendant(of: moods, matching: find.text('😊')), findsOne);
    expect(find.descendant(of: moods, matching: find.text('😢')), findsOne);
    expect(find.text('2 篇 · 67%'), findsOneWidget);
    for (final hidden in <String>['😡', '🥶', '🤯', '胶囊', '删掉的', '别的本子']) {
      expect(find.text(hidden), findsNothing, reason: hidden);
    }

    expect(
      find.descendant(
        of: find.byType(NotebookInsightsTagsCard),
        matching: find.textContaining('海边', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(find.byType(NotebookInsightsRhythmCard), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byType(ExploreMemoryCard),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.descendant(
        of: find.byType(ExploreMemoryCard),
        matching: find.text('去年今日'),
      ),
      findsOneWidget,
    );
    await h.unmount();
  });

  testWidgets('random button opens a preview inside the notebook', (
    tester,
  ) async {
    final (h, _) = await open(tester);
    final button = find.byKey(
      const ValueKey<String>('notebook_insights_random'),
    );
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(button);
    await h.settleAll();

    final preview = tester.widget<DiaryPreviewPage>(
      find.byType(DiaryPreviewPage),
    );
    final members = <String>{ids['去年今日']!, ids['前天']!, ids['归档的']!};
    expect(members, contains(preview.diaryId));
    expect(preview.sequence!.ids.toSet(), members);
    await h.unmount();
  });

  testWidgets('random reading also draws from the sub-notebooks', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    tester.view.physicalSize = const Size(320, 1400);
    final travel = await h.notebook('旅行');
    final tokyo = await h.notebook('东京', parentId: travel);
    final now = DateTime.now();
    final own = await diary(
      h,
      '自己的',
      notebookIds: <String>[travel],
      createdAt: DateTime(now.year, now.month, now.day - 5, 9),
    );
    final sub = await diary(
      h,
      '子本的',
      notebookIds: <String>[tokyo],
      createdAt: DateTime(now.year, now.month, now.day - 1, 9),
    );
    await h.pump(
      NotebookInsightsPage(notebookId: travel, random: Random(7)),
      overrides: [
        deviceAuthServiceProvider.overrideWithValue(FakeDeviceAuth()),
      ],
    );
    await h.settleAll();
    expect(tileValue(tester, '篇数'), 2);

    final button = find.byKey(
      const ValueKey<String>('notebook_insights_random'),
    );
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(button);
    await h.settleAll();
    final preview = tester.widget<DiaryPreviewPage>(
      find.byType(DiaryPreviewPage),
    );
    // 本子自己的目录在前，子本的接在后面。
    expect(preview.sequence!.ids, <String>[own, sub]);
    await h.unmount();
  });

  test('random order keeps the book order and appends the rest', () {
    ExploreDiaryOverview overview(String id, int day) => ExploreDiaryOverview(
      diaryId: id,
      title: id,
      contentText: '',
      metadata: '{}',
      createdAt: DateTime(2026, 10, day),
      updatedAt: DateTime(2026, 10, day),
      tags: const <Tag>[],
    );
    final diaries = <ExploreDiaryOverview>[
      overview('a', 1),
      overview('b', 2),
      overview('c', 3),
      overview('d', 4),
    ];
    // 目录里有统计口径外的（x）与重复的只取一次；目录外的按新 → 旧接在后面。
    expect(
      notebookInsightsRandomOrder(
        diaries,
        bookOrder: <String>['b', 'x', 'a', 'b'],
      ),
      <String>['b', 'a', 'd', 'c'],
    );
    expect(notebookInsightsRandomOrder(diaries), <String>['d', 'c', 'b', 'a']);
  });

  testWidgets('goal card shows progress and recent periods', (tester) async {
    final (h, _) = await open(
      tester,
      payload: NotebookPayload(
        goal: NotebookGoal(period: NotebookGoalPeriod.month, target: 20),
      ),
    );
    final card = find.byType(NotebookInsightsGoalCard);
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('每月写 20 篇')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.textContaining('本月 ', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(find.text('最近 8 个周期'), findsOneWidget);
    await h.unmount();
  });

  testWidgets('empty notebook shows the empty hint', (tester) async {
    final (h, _) = await open(tester, seed: false);
    expect(find.text('这本还没有可统计的日记'), findsOneWidget);
    expect(find.byType(NotebookInsightsOverviewCard), findsNothing);
    await h.unmount();
  });
}
