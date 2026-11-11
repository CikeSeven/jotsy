import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';

/// 自定义提醒把截止日 / 截止时刻顺延到的位置（[minute] 为 null 即全天）。
typedef TodoDueMove = ({DateTime date, int? minute});

/// “自定义时间…”选出的日期与时刻换算成的提醒，以及随之顺延的截止时间。
@immutable
class TodoReminderPick {
  const TodoReminderPick({required this.reminder, this.dueMove});

  final TodoReminder reminder;

  /// 选的时间晚于截止时间时，截止时间要顺延到的位置；不需要顺延时为 null。
  final TodoDueMove? dueMove;
}

/// 把自定义提醒选的日期 [date] 与时刻 [minute]（一天中的分钟数）换算成相对
/// 截止日 [due]（[dueMinute] 为 null 即全天）的提醒（纯函数，无 IO）。
///
/// 提醒在数据里一律相对截止日（`TodoReminder` 的天数只能是 0 或负数），而
/// 用户选提醒时想的是“哪天几点叫我”：新建的待办没有日期时截止日按今天算，
/// 若只许选到截止日，就选不了今天之后。所以选在截止时间之后时，截止时间
/// 顺延过去，提醒相对新的截止时间：
/// - 日期晚于截止日：截止日改为那天（全天的仍全天，有时刻的先保留原时刻）；
/// - 有时刻、落在（顺延后的）截止日当天且晚于截止时刻：截止时刻改为提醒
///   时刻，提醒即“准时”，选的时刻不丢；
/// - 其余（截止日之前，或当天不晚于截止时刻）：截止时间不动，换算成
///   “提前若干天的某个时刻”。日期选择器把最早的一天限在截止日之前
///   [TodoReminder.maxDaysBefore] 天，这里不再兜底。
TodoReminderPick resolveTodoReminderPick({
  required DateTime due,
  required int? dueMinute,
  required DateTime date,
  required int minute,
}) {
  // 按 UTC 零点算相差的天数，避开夏令时那天只有 23 / 25 小时。
  final days = DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(due.year, due.month, due.day)).inDays;
  final later = days > 0;
  final dueDay = later
      ? DateTime(date.year, date.month, date.day)
      : DateTime(due.year, due.month, due.day);
  final offset = later ? 0 : days;
  if (dueMinute != null && offset == 0 && minute > dueMinute) {
    return TodoReminderPick(
      reminder: const TodoReminder.beforeDue(0),
      dueMove: (date: dueDay, minute: minute),
    );
  }
  return TodoReminderPick(
    reminder: TodoReminder.onDay(days: offset, minute: minute),
    dueMove: later ? (date: dueDay, minute: dueMinute) : null,
  );
}
