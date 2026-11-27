import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';

/// 重复待办的坚持记录（详情里的“坚持记录”卡）。
///
/// 输入是这串每一次的完成记录（已完成副本：`dueDate` 为那一次的截止日，
/// `completedAt` 为完成时刻），纯函数、无副作用：
/// - [total]：一共完成了几次（副本条数）；
/// - [streak]：从最近一次往前数，连续按时完成（完成那天不晚于那一次的
///   截止日）的次数，遇到一次迟交就停；
/// - [days]：最近 [weeks] 周（含本周，周一为一周的开始）每天完成了几次，
///   按列（周）从早到晚、列内周一到周日排，共 `weeks * 7` 格；今天之后的
///   格子为 -1（还没到）。
@immutable
class TodoStreak {
  const TodoStreak({
    required this.total,
    required this.streak,
    required this.days,
    required this.weeks,
  });

  final int total;
  final int streak;
  final List<int> days;
  final int weeks;

  static const int defaultWeeks = 12;

  /// 按完成记录 [occurrences] 与今天 [today]（本地零点）算出坚持记录。
  static TodoStreak build(
    List<TodoRow> occurrences,
    DateTime today, {
    int weeks = defaultWeeks,
  }) {
    final done = <({DateTime day, DateTime? due})>[
      for (final row in occurrences)
        if (row.completedAt case final at?)
          (
            day: DateTime(at.year, at.month, at.day),
            due: row.dueDate == null
                ? null
                : parseAnniversaryDate(row.dueDate!),
          ),
    ]..sort((a, b) => b.day.compareTo(a.day));

    var streak = 0;
    for (final item in done) {
      final due = item.due;
      if (due != null && item.day.isAfter(due)) break;
      streak++;
    }

    final monday = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - 1),
    );
    final start = DateTime(
      monday.year,
      monday.month,
      monday.day - (weeks - 1) * 7,
    );
    final counts = <DateTime, int>{};
    for (final item in done) {
      counts[item.day] = (counts[item.day] ?? 0) + 1;
    }
    final days = <int>[
      for (var i = 0; i < weeks * 7; i++)
        () {
          final day = DateTime(start.year, start.month, start.day + i);
          if (day.isAfter(today)) return -1;
          return counts[day] ?? 0;
        }(),
    ];
    return TodoStreak(
      total: done.length,
      streak: streak,
      days: days,
      weeks: weeks,
    );
  }
}
