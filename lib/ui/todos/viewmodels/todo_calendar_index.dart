import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';

/// 日历上某一天的一条待办。
@immutable
class TodoCalendarEntry {
  const TodoCalendarEntry({
    required this.row,
    required this.occurrence,
    this.projected = false,
  });

  final TodoRow row;

  /// 落在哪一天（本地零点）。
  final DateTime occurrence;

  /// 重复待办以后的某一次（还没轮到）：只显示，不能勾选——勾选的总是当前
  /// 这一次，在日历后面的日子里勾掉会让人以为完成的是那一天。
  final bool projected;

  bool get done => row.completedAt != null;
}

/// 日历用的按日索引（纯函数构建，无 IO）。
///
/// - 未完成的待办落在截止日；重复待办另把截止日之后、[horizon] 内的各次
///   投影进来（按剩余次数截断，最多 [maxProjected] 次）；
/// - 已完成的落在它的截止日（已完成副本也是这样），没有截止日的不进日历。
///
/// 一天里的顺序：未完成在前（全天的在前、再按时刻），已完成在后。
class TodoCalendarIndex {
  TodoCalendarIndex._(this._byDay);

  factory TodoCalendarIndex.build({
    required List<TodoRow> open,
    required List<TodoRow> completed,
    required DateTime today,
    Duration horizon = const Duration(days: 400),
    int maxProjected = 400,
  }) {
    final byDay = <String, List<TodoCalendarEntry>>{};
    void add(TodoRow row, DateTime day, {bool projected = false}) {
      byDay
          .putIfAbsent(formatAnniversaryDate(day), () => <TodoCalendarEntry>[])
          .add(
            TodoCalendarEntry(row: row, occurrence: day, projected: projected),
          );
    }

    final end = today.add(horizon);
    for (final row in open) {
      final dueText = row.dueDate;
      final due = dueText == null ? null : parseAnniversaryDate(dueText);
      if (due == null) continue;
      add(row, due);
      final rule = decodeTodoRepeat(row.repeat);
      if (rule == null) continue;
      final done = decodeTodoMetadata(
        row.metadata,
      )[TodoMetadataKeys.repeatDone];
      final count = rule.count;
      var remaining =
          (count == null ? maxProjected : count - (done is int ? done : 0)) - 1;
      var cursor = due;
      while (remaining > 0) {
        final next = TodoRecurrence.nextAfter(rule, cursor);
        if (next == null || next.isAfter(end)) break;
        add(row, next, projected: true);
        cursor = next;
        remaining--;
      }
    }
    for (final row in completed) {
      final dueText = row.dueDate;
      final due = dueText == null ? null : parseAnniversaryDate(dueText);
      if (due != null) add(row, due);
    }
    for (final entries in byDay.values) {
      entries.sort((a, b) {
        if (a.done != b.done) return a.done ? 1 : -1;
        final ma = a.row.dueMinute ?? -1;
        final mb = b.row.dueMinute ?? -1;
        return ma.compareTo(mb);
      });
    }
    return TodoCalendarIndex._(byDay);
  }

  static final TodoCalendarIndex empty = TodoCalendarIndex._(
    const <String, List<TodoCalendarEntry>>{},
  );

  final Map<String, List<TodoCalendarEntry>> _byDay;

  bool get isEmpty => _byDay.isEmpty;

  /// [day] 的待办（只取年月日；table_calendar 传入 UTC 零点也可以）。
  List<TodoCalendarEntry> entriesOn(DateTime day) =>
      _byDay[formatAnniversaryDate(day)] ?? const <TodoCalendarEntry>[];

  /// [day] 有没有未完成的待办（日期格的角标）。
  bool hasOpenOn(DateTime day) => entriesOn(day).any((entry) => !entry.done);
}
