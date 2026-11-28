import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';

/// 重复待办的坚持记录（详情里的“坚持记录”卡）。
///
/// 输入是这串每一次的完成记录（已完成副本：`dueDate` 为那一次的截止日，
/// `completedAt` 为完成时刻；若有限次数 / 截止日重复待办的最后一次直接完
/// 成在原待办上，通过 `masterRow` 一并纳入），纯函数、无副作用：
/// - [total]：一共完成了几次；
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
    required this.start,
    required this.today,
  });

  final int total;
  final int streak;
  final List<int> days;
  final int weeks;

  /// 第 0 列第 0 行（最早那周的周一，本地零点）。
  final DateTime start;

  /// 构建时使用的“今天”（本地零点）。
  final DateTime today;

  static const int defaultWeeks = 12;
  static const int maxWeeks = 24;

  /// 网格第 [column] 周、第 [row] 行（0 为周一）对应的本地日期。
  DateTime dateAt(int column, int row) =>
      DateTime(start.year, start.month, start.day + column * 7 + row);

  /// 网格第 [column] 周、第 [row] 行的完成次数；未来日期为 -1。
  int countAt(int column, int row) => days[column * 7 + row];

  /// 根据网格可用宽度估算最舒展的周数（12–24 周），让热力图在不同屏幕宽度
  /// 下都能左右对称铺满卡片，而不是缩在左半边。
  static int weeksForWidth(
    double availableWidth, {
    double gap = 3.5,
    double targetCell = 15,
    int minWeeks = defaultWeeks,
    int maxWeeks = TodoStreak.maxWeeks,
  }) {
    if (!availableWidth.isFinite || availableWidth <= 0) return minWeeks;
    return ((availableWidth + gap) / (targetCell + gap)).floor().clamp(
      minWeeks,
      maxWeeks,
    );
  }

  /// 按完成记录 [occurrences] 与今天 [today]（本地零点）算出坚持记录。
  /// 若 [masterRow] 本身已完成（有限次数 / 截止日重复的最后一次直接标在原
  /// 行上），按 `todoId` 去重后一并计入。
  static TodoStreak build(
    List<TodoRow> occurrences,
    DateTime today, {
    int weeks = defaultWeeks,
    TodoRow? masterRow,
  }) {
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final seenIds = <String>{};
    final done = <({DateTime at, DateTime day, DateTime? due})>[];
    void collect(TodoRow row) {
      final at = row.completedAt;
      if (at == null || !seenIds.add(row.todoId)) return;
      done.add((
        at: at,
        day: DateTime(at.year, at.month, at.day),
        due: row.dueDate == null ? null : parseAnniversaryDate(row.dueDate!),
      ));
    }

    for (final row in occurrences) {
      collect(row);
    }
    if (masterRow != null) collect(masterRow);

    done.sort((a, b) {
      final byDay = b.day.compareTo(a.day);
      if (byDay != 0) return byDay;
      final byAt = b.at.compareTo(a.at);
      if (byAt != 0) return byAt;
      final da = a.due;
      final db = b.due;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

    var streak = 0;
    for (final item in done) {
      final due = item.due;
      if (due != null && item.day.isAfter(due)) break;
      streak++;
    }

    final monday = DateTime(
      normalizedToday.year,
      normalizedToday.month,
      normalizedToday.day - (normalizedToday.weekday - 1),
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
          if (day.isAfter(normalizedToday)) return -1;
          return counts[day] ?? 0;
        }(),
    ];
    return TodoStreak(
      total: done.length,
      streak: streak,
      days: days,
      weeks: weeks,
      start: start,
      today: normalizedToday,
    );
  }
}
