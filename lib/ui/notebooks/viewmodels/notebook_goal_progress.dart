import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';

/// 写作目标的进度：本周期写了几篇、连续达成了几个周期、最近几个周期是否
/// 达成。纯计算，无副作用，`now` 由调用方注入（测试可固定时间）。
///
/// 输入是本子里日记的发表时间（`createdAt`，按本地日期归入周期）。口径：
/// 归档的算（写过就算），回收站里的不算（调用方不传），未解封的时间胶囊也算
/// （它们是那天写下的，只是内容暂不可见；这里只用日期，不泄露内容）。
///
/// 周期边界：
/// - 每天：本地自然日；
/// - 每周：从 [firstWeekday]（`DateTime.monday`..`DateTime.sunday`）开始的
///   7 天，调用方传日历显示选项里的“每周起始日”；
/// - 每月：自然月。
/// 逐个周期用日期构造（`DateTime(y, m, d - 7)`）而不是减 24 小时，跨夏令时也
/// 不会错位。
///
/// “连续达成”= 从上一个周期往回数、连续达标的已结束周期个数；当前周期已达标
/// 时再加 1（还没达标不算断：周期还没结束）。
@immutable
class NotebookGoalProgress {
  const NotebookGoalProgress({
    required this.goal,
    required this.current,
    required this.streak,
    required this.recent,
  });

  /// 最近几个周期的圆点个数（含当前周期）。
  static const int recentCount = 8;

  factory NotebookGoalProgress.compute(
    NotebookGoal goal,
    Iterable<DateTime> createdAts, {
    required DateTime now,
    int firstWeekday = DateTime.monday,
  }) {
    final counts = <DateTime, int>{};
    for (final createdAt in createdAts) {
      final start = periodStart(
        goal.period,
        createdAt.toLocal(),
        firstWeekday: firstWeekday,
      );
      counts[start] = (counts[start] ?? 0) + 1;
    }
    final currentStart = periodStart(
      goal.period,
      now,
      firstWeekday: firstWeekday,
    );
    final current = counts[currentStart] ?? 0;
    bool metAt(DateTime start) => (counts[start] ?? 0) >= goal.target;

    // 往回数到第一个没达标的周期为止；没有日记的周期计数为 0，必然中断，
    // 所以循环次数不超过有日记的周期数 + 1。
    var streak = 0;
    var probe = previousPeriodStart(goal.period, currentStart);
    while (metAt(probe)) {
      streak += 1;
      probe = previousPeriodStart(goal.period, probe);
    }
    if (current >= goal.target) streak += 1;

    final recent = <bool>[];
    var start = currentStart;
    for (var i = 0; i < recentCount; i++) {
      recent.add(metAt(start));
      start = previousPeriodStart(goal.period, start);
    }
    return NotebookGoalProgress(
      goal: goal,
      current: current,
      streak: streak,
      recent: List<bool>.unmodifiable(recent.reversed),
    );
  }

  final NotebookGoal goal;

  /// 当前周期已写的篇数。
  final int current;

  /// 连续达成的周期数（见类注释）。
  final int streak;

  /// 最近 [recentCount] 个周期是否达成，旧 → 新，最后一个是当前周期。
  final List<bool> recent;

  int get target => goal.target;
  bool get met => current >= goal.target;

  /// 进度条的比例（0..1）。
  double get fraction => (current / goal.target).clamp(0.0, 1.0);

  /// [date] 所在周期的第一天（本地零点）。
  static DateTime periodStart(
    NotebookGoalPeriod period,
    DateTime date, {
    int firstWeekday = DateTime.monday,
  }) {
    switch (period) {
      case NotebookGoalPeriod.day:
        return DateTime(date.year, date.month, date.day);
      case NotebookGoalPeriod.week:
        final back = (date.weekday - firstWeekday + 7) % 7;
        return DateTime(date.year, date.month, date.day - back);
      case NotebookGoalPeriod.month:
        return DateTime(date.year, date.month);
    }
  }

  /// [start]（某周期第一天）的上一个周期的第一天。
  static DateTime previousPeriodStart(
    NotebookGoalPeriod period,
    DateTime start,
  ) {
    return switch (period) {
      NotebookGoalPeriod.day => DateTime(
        start.year,
        start.month,
        start.day - 1,
      ),
      NotebookGoalPeriod.week => DateTime(
        start.year,
        start.month,
        start.day - 7,
      ),
      NotebookGoalPeriod.month => DateTime(start.year, start.month - 1),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is NotebookGoalProgress &&
      other.goal == goal &&
      other.current == current &&
      other.streak == streak &&
      listEquals(other.recent, recent);

  @override
  int get hashCode =>
      Object.hash(goal, current, streak, Object.hashAll(recent));
}
