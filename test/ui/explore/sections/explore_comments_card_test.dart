import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/l10n/app_localizations_gen_en.dart';
import 'package:node_diary/ui/explore/controllers/explore_comment_stats.dart';
import 'package:node_diary/ui/explore/controllers/explore_module_actions.dart';
import 'package:node_diary/ui/explore/models/explore_layout.dart';
import 'package:node_diary/ui/explore/models/explore_module_id.dart';
import 'package:node_diary/ui/explore/models/explore_period.dart';
import 'package:node_diary/ui/explore/pages/explore_page.dart';
import 'package:node_diary/ui/explore/providers/explore_providers.dart';
import 'package:node_diary/ui/explore/sections/explore_comments_card.dart';
import 'package:node_diary/ui/explore/sections/explore_content_view.dart';
import 'package:node_diary/ui/settings/pages/explore_layout_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/explore_page_harness.dart';
import '../../../support/expressive_test_theme.dart';

/// 记下卡片里“打开日记”的动作；其余动作用不到。
class _RecordingActions extends ExploreModuleActions {
  final List<(String, List<String>?)> opened = <(String, List<String>?)>[];

  @override
  void openDiary(String diaryId, {List<String>? sequence}) =>
      opened.add((diaryId, sequence));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  final l10n = AppLocalizationsEn();
  final now = DateTime(2026, 10, 28, 15);

  DiaryCommentSummary comment(
    String id, {
    required String diaryId,
    required String content,
    required DateTime diaryCreatedAt,
    required DateTime createdAt,
    String title = '',
    String? mood,
  }) => DiaryCommentSummary(
    commentId: id,
    diaryId: diaryId,
    content: content,
    mood: mood,
    createdAt: createdAt,
    diaryTitle: title,
    diaryCreatedAt: diaryCreatedAt,
  );

  final spring = DateTime(2026, 10, 1, 10);
  // 新 → 旧，与 watchRecentDiaryComments 的顺序一致。
  final comments = <DiaryCommentSummary>[
    comment(
      'c1',
      diaryId: 'd1',
      title: 'Spring walk',
      content: 'Line one\n\n  line two',
      mood: '😊',
      diaryCreatedAt: spring,
      createdAt: DateTime(2026, 10, 27, 20),
    ),
    comment(
      'c2',
      diaryId: 'd2',
      content: 'Untitled reply',
      diaryCreatedAt: DateTime(2026, 10, 20, 9),
      createdAt: DateTime(2026, 10, 26, 9),
    ),
    comment(
      'c3',
      diaryId: 'd1',
      title: 'Spring walk',
      content: 'Second look',
      diaryCreatedAt: spring,
      createdAt: DateTime(2026, 10, 25, 9),
    ),
    comment(
      'c4',
      diaryId: 'd3',
      title: 'Old one',
      content: 'A year later',
      diaryCreatedAt: DateTime(2025, 10, 1, 9),
      createdAt: DateTime(2026, 10, 20, 9),
    ),
  ];

  /// 只显示留言卡片的布局（其余卡片关掉、不显示范围条）。
  ExploreLayout onlyComments({int? count}) =>
      ExploreLayout.fromJson(<String, Object>{
        'bar': false,
        'm': <Object>[
          for (final id in ExploreModuleId.values)
            <String, Object>{
              'id': id.name,
              'on': id == ExploreModuleId.comments,
              if (id == ExploreModuleId.comments && count != null)
                'o': <String, Object>{'count': count},
            },
        ],
      });

  Future<_RecordingActions> pumpCard(
    WidgetTester tester, {
    required List<DiaryCommentSummary> rows,
    int? count,
    Size size = const Size(400, 1600),
  }) async {
    final actions = _RecordingActions();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exploreRecentCommentsProvider.overrideWith(
            (ref) => Stream.value(rows),
          ),
          exploreCommentStatsProvider.overrideWith(
            (ref) => Stream.value(
              ExploreCommentStats.of(<DiaryCommentTiming>[
                for (final row in rows)
                  DiaryCommentTiming(
                    diaryId: row.diaryId,
                    createdAt: row.createdAt,
                    diaryCreatedAt: row.diaryCreatedAt,
                  ),
              ]),
            ),
          ),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExploreActionsScope(
                actions: actions,
                child: ExploreContentView(
                  diaries: const <ExploreDiaryOverview>[],
                  layout: onlyComments(count: count),
                  period: ExplorePeriod.all,
                  features: const AppFeatures(comments: true),
                  moodOptions: SettingsService.defaultMoodOptions,
                  firstWeekday: DateTime.monday,
                  now: now,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return actions;
  }

  group('ExploreCommentsCard', () {
    testWidgets('shows the stats line and the latest comments', (tester) async {
      await pumpCard(tester, rows: comments);
      expect(find.byType(ExploreCommentsCard), findsOneWidget);
      expect(find.text(l10n.exploreModuleComments), findsOneWidget);
      // 4 条留言、3 篇日记，平均 (26 + 6 + 24 + 384) / 4 = 110 天。
      expect(find.text(l10n.diaryCommentsCount(4)), findsOneWidget);
      expect(
        find.text(
          '${l10n.exploreCommentsDiaries(3)} · '
          '${l10n.exploreCommentsAverageGap(110)}',
        ),
        findsOneWidget,
      );
      // 默认只列最近 3 条；多行留言收成一行摘录。
      expect(find.text('Line one line two'), findsOneWidget);
      expect(find.text('Untitled reply'), findsOneWidget);
      expect(find.text('Second look'), findsOneWidget);
      expect(find.text('A year later'), findsNothing);
      // 心情为表情；没有标题的日记写“无标题”，标题与间隔分两段。
      expect(find.text('😊'), findsOneWidget);
      expect(find.text('Spring walk'), findsNWidgets(2));
      expect(find.text(l10n.autoT0033), findsOneWidget);
      expect(find.text(' · ${l10n.diaryCommentDaysLater(26)}'), findsOneWidget);
      expect(find.text(' · ${l10n.diaryCommentDaysLater(6)}'), findsOneWidget);
    });

    testWidgets('the count option decides how many comments are listed', (
      tester,
    ) async {
      await pumpCard(tester, rows: comments, count: 5);
      expect(find.text('A year later'), findsOneWidget);
      expect(find.text(' · ${l10n.diaryCommentYearsLater(1)}'), findsOneWidget);
    });

    testWidgets('tapping a comment opens its diary among the listed ones', (
      tester,
    ) async {
      final actions = await pumpCard(tester, rows: comments);
      await tester.tap(find.text('Untitled reply'));
      await tester.pump();
      expect(actions.opened, hasLength(1));
      final (diaryId, sequence) = actions.opened.single;
      expect(diaryId, 'd2');
      // 同一篇的两条留言在顺序里只出现一次。
      expect(sequence, <String>['d1', 'd2']);
    });

    testWidgets('shows a hint when there are no comments yet', (tester) async {
      await pumpCard(tester, rows: const <DiaryCommentSummary>[]);
      expect(find.text(l10n.exploreCommentsEmpty), findsOneWidget);
      expect(find.text(l10n.diaryCommentsCount(0)), findsNothing);
    });

    testWidgets('stays inside a 320dp card with large text', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpCard(
        tester,
        rows: <DiaryCommentSummary>[
          comment(
            'long',
            diaryId: 'd9',
            title: 'A very long diary title that keeps going and going',
            content: 'A long comment ' * 10,
            mood: '🥳',
            diaryCreatedAt: DateTime(2024, 1, 31, 9),
            createdAt: DateTime(2026, 12, 30, 9),
          ),
        ],
        size: const Size(320, 1600),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(ExploreCommentsCard), findsOneWidget);
    });
  });

  group('explore page', () {
    for (final enabled in <bool>[true, false]) {
      testWidgets('the comments card follows the comments feature ($enabled)', (
        tester,
      ) async {
        await pumpExploreHarness(
          tester,
          Scaffold(body: ExplorePage(now: now)),
          prefs: <String, Object>{
            // 留言卡片排在最前，免得被前面的卡片挤到可见区域以外。
            'app.settings.explore_layout':
                '{"v":1,"current":{"m":[{"id":"comments","on":true}]}}',
            'app.settings.app_features': '{"comments":$enabled}',
          },
          comments: comments,
        );
        expect(
          find.byType(ExploreCommentsCard),
          enabled ? findsOneWidget : findsNothing,
        );
      });
    }

    testWidgets('the card is hidden by default because comments are off', (
      tester,
    ) async {
      await pumpExploreHarness(
        tester,
        Scaffold(body: ExplorePage(now: now)),
        comments: comments,
      );
      expect(find.byType(ExploreCommentsCard), findsNothing);
    });
  });

  testWidgets('the customize preview shows sample comments in sample mode', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final service = await SettingsService.create();
    await pumpExploreHarness(
      tester,
      ExploreLayoutPage(settingsService: service),
      prefs: <String, Object>{'app.settings.app_features': '{"comments":true}'},
      size: const Size(1200, 1600),
    );
    // 我的数据：没有留言，卡片为空态。
    expect(find.byType(ExploreCommentsCard), findsOneWidget);
    expect(find.text(l10n.exploreCommentsEmpty), findsOneWidget);

    await tester.tap(find.text(l10n.exploreLayoutPreviewSample));
    await tester.pumpAndSettle();
    expect(find.text(l10n.exploreCommentsEmpty), findsNothing);
    expect(find.text(l10n.exploreSampleComment), findsWidgets);

    await tester.tap(find.text(l10n.exploreLayoutPreviewMine));
    await tester.pumpAndSettle();
    expect(find.text(l10n.exploreCommentsEmpty), findsOneWidget);
    expect(find.text(l10n.exploreSampleComment), findsNothing);
  });
}
