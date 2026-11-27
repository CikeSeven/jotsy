import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';

/// 待办的回顾数字（已完成视图的统计卡与探索页的待办卡共用），按最近完成
/// 的待办 [completed] 与今天 [today]（本地零点）算，纯函数：
/// - [weekDone]：本周（周一起）完成的件数；
/// - [days]：最近 7 天（含今天，从早到晚）每天完成的件数；
/// - [streak]：连续有完成的天数，算到今天；今天还没完成时算到昨天（今天
///   还有机会，不算断）。
@immutable
class TodoReviewStats {
  const TodoReviewStats({
    required this.weekDone,
    required this.days,
    required this.streak,
  });

  final int weekDone;
  final List<int> days;
  final int streak;

  static TodoReviewStats build(List<TodoRow> completed, DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    final monday = DateTime(day.year, day.month, day.day - (day.weekday - 1));
    final counts = <DateTime, int>{};
    for (final row in completed) {
      final at = row.completedAt;
      if (at == null) continue;
      final key = DateTime(at.year, at.month, at.day);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    var weekDone = 0;
    for (final MapEntry(key: d, value: n) in counts.entries) {
      if (!d.isBefore(monday) && !d.isAfter(day)) weekDone += n;
    }
    final days = <int>[
      for (var i = 6; i >= 0; i--)
        counts[DateTime(day.year, day.month, day.day - i)] ?? 0,
    ];
    var streak = 0;
    var cursor = (counts[day] ?? 0) > 0
        ? day
        : DateTime(day.year, day.month, day.day - 1);
    while ((counts[cursor] ?? 0) > 0) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return TodoReviewStats(weekDone: weekDone, days: days, streak: streak);
  }
}
