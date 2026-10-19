import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_goal_progress.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_insights_data.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_labels.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:flutter/material.dart' show Locale;

/// 写作目标的进度计算：周期边界（天 / 周 / 月、每周起始日）、当前周期达成与
/// 否、连续达成（中间断开、当前周期加一）、最近周期圆点；以及统计页的最长
/// 连续天数与时间跨度写法。
void main() {
  // 2026-10-21 是星期三。
  final now = DateTime(2026, 10, 21, 15);

  NotebookGoalProgress compute(
    NotebookGoalPeriod period,
    int target,
    List<DateTime> dates, {
    int firstWeekday = DateTime.monday,
  }) => NotebookGoalProgress.compute(
    NotebookGoal(period: period, target: target),
    dates,
    now: now,
    firstWeekday: firstWeekday,
  );

  group('period start', () {
    test('weeks start on Monday by default and on Sunday when asked', () {
      expect(
        NotebookGoalProgress.periodStart(NotebookGoalPeriod.week, now),
        DateTime(2026, 10, 19),
      );
      expect(
        NotebookGoalProgress.periodStart(
          NotebookGoalPeriod.week,
          now,
          firstWeekday: DateTime.sunday,
        ),
        DateTime(2026, 10, 18),
      );
      // 周日本身：周一起始时属于上一周。
      expect(
        NotebookGoalProgress.periodStart(
          NotebookGoalPeriod.week,
          DateTime(2026, 10, 25, 23),
        ),
        DateTime(2026, 10, 19),
      );
    });

    test('months and days use local calendar boundaries', () {
      expect(
        NotebookGoalProgress.periodStart(NotebookGoalPeriod.month, now),
        DateTime(2026, 10),
      );
      expect(
        NotebookGoalProgress.previousPeriodStart(
          NotebookGoalPeriod.month,
          DateTime(2026, 1),
        ),
        DateTime(2025, 12),
      );
      expect(
        NotebookGoalProgress.periodStart(NotebookGoalPeriod.day, now),
        DateTime(2026, 10, 21),
      );
    });
  });

  test('daily goal: current day met adds one to the streak', () {
    final progress = compute(NotebookGoalPeriod.day, 1, <DateTime>[
      DateTime(2026, 10, 21, 8),
      DateTime(2026, 10, 20, 22),
      DateTime(2026, 10, 19, 9),
      // 17 日空着：连续在这里断开。
      DateTime(2026, 10, 16, 9),
    ]);
    expect(progress.current, 1);
    expect(progress.met, isTrue);
    expect(progress.streak, 3);
    // 10/14 … 10/21，最右为今天。
    expect(progress.recent, <bool>[
      false,
      false,
      true,
      false,
      false,
      true,
      true,
      true,
    ]);
  });

  test('daily goal unmet today keeps the streak of finished days', () {
    final progress = compute(NotebookGoalPeriod.day, 2, <DateTime>[
      DateTime(2026, 10, 21, 8),
      DateTime(2026, 10, 20, 8),
      DateTime(2026, 10, 20, 20),
    ]);
    expect(progress.current, 1);
    expect(progress.met, isFalse);
    expect(progress.fraction, 0.5);
    expect(progress.streak, 1);
    expect(progress.recent.last, isFalse);
  });

  test('weekly goal counts the streak with gaps and week start', () {
    final dates = <DateTime>[
      // 本周（10/19 起）2 篇。
      DateTime(2026, 10, 19), DateTime(2026, 10, 21),
      // 上周 3 篇、上上周 3 篇。
      DateTime(2026, 10, 12), DateTime(2026, 10, 14), DateTime(2026, 10, 18),
      DateTime(2026, 10, 5), DateTime(2026, 10, 6), DateTime(2026, 10, 7),
      // 再往前一周只有 1 篇：断开。
      DateTime(2026, 9, 30),
      DateTime(2026, 9, 22), DateTime(2026, 9, 23), DateTime(2026, 9, 24),
    ];
    final monday = compute(NotebookGoalPeriod.week, 3, dates);
    expect(monday.current, 2);
    expect(monday.met, isFalse);
    expect(monday.streak, 2);

    // 周日起始：10/18（周日）归入本周，本周变成 3 篇、上周只剩 2 篇。
    final sunday = compute(
      NotebookGoalPeriod.week,
      3,
      dates,
      firstWeekday: DateTime.sunday,
    );
    expect(sunday.current, 3);
    expect(sunday.met, isTrue);
    expect(sunday.streak, 1);
  });

  test('monthly goal crosses the year boundary', () {
    final progress = NotebookGoalProgress.compute(
      NotebookGoal(period: NotebookGoalPeriod.month, target: 1),
      <DateTime>[DateTime(2025, 12, 31, 23), DateTime(2025, 11, 2)],
      now: DateTime(2026, 1, 10),
    );
    expect(progress.current, 0);
    expect(progress.streak, 2);
    expect(progress.recent.sublist(5), <bool>[true, true, false]);
  });

  test('no entries means zero progress and no streak', () {
    final progress = compute(NotebookGoalPeriod.week, 3, const <DateTime>[]);
    expect(progress.current, 0);
    expect(progress.streak, 0);
    expect(progress.recent, List<bool>.filled(8, false));
  });

  group('labels', () {
    final l10n = lookupAppLocalizations(const Locale('zh'));

    test('progress line and met line per period', () {
      expect(
        notebookGoalLine(
          l10n,
          NotebookGoalPeriod.week,
          current: 2,
          target: 3,
          streak: 4,
        ),
        '本周 2 / 3 篇 · 连续达成 4 周',
      );
      expect(
        notebookGoalLine(
          l10n,
          NotebookGoalPeriod.day,
          current: 1,
          target: 1,
          streak: 1,
        ),
        '今天已完成 ✓ · 连续达成 1 天',
      );
      expect(
        notebookGoalLine(
          l10n,
          NotebookGoalPeriod.month,
          current: 0,
          target: 5,
          streak: 0,
        ),
        '本月 0 / 5 篇',
      );
    });
  });

  group('insights helpers', () {
    final l10n = lookupAppLocalizations(const Locale('zh'));

    test('longest streak of local days', () {
      expect(
        NotebookInsightsData.longestDayStreak(<DateTime>[
          DateTime(2026, 2, 27),
          DateTime(2026, 2, 28),
          DateTime(2026, 3, 1),
          DateTime(2026, 3, 3),
          DateTime(2026, 3, 4),
        ]),
        3,
      );
      expect(NotebookInsightsData.longestDayStreak(const <DateTime>[]), 0);
    });

    test('span label switches from days to years and months', () {
      final first = DateTime(2023, 8, 15);
      expect(notebookSpanDurationLabel(l10n, first, 12), '12 天');
      // 2023-08-15 起 3 年 2 个月零几天。
      final end = DateTime(2026, 10, 20);
      final days = end.difference(first).inDays + 1;
      expect(notebookSpanDurationLabel(l10n, first, days), '3 年 2 个月');
      // 闰年：2023-08-15 起第 367 天是 2024-08-15。
      expect(notebookSpanDurationLabel(l10n, first, 366), '11 个月');
      expect(notebookSpanDurationLabel(l10n, first, 367), '1 年');
      expect(notebookSpanDurationLabel(l10n, first, 62), '2 个月');
    });
  });
}
