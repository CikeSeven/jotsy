import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';

/// “规划今天”的分组（先后即面板里的顺序）。
enum TodoPlanSection {
  /// 截止日在今天之前。
  overdue,

  /// 明天起 [TodoDayPlan.soonDays] 天内到期。
  soon,

  /// 高优先级、没有日期。
  important,

  /// 最近 [TodoDayPlan.recentDays] 天里添加、没有日期（高优先级的归上一组）。
  recent,
}

/// “规划今天”的建议：从未完成的待办里挑出值得今天看一眼的，按
/// [TodoPlanSection] 分组；今天已经要做的不在其中。纯函数、无副作用，
/// 不另存数据。
@immutable
class TodoDayPlan {
  const TodoDayPlan(this.sections);

  static const int soonDays = 3;
  static const int recentDays = 3;

  /// 推迟到几次起在行上提示“拆小一点或放下”。
  static const int postponeHintAt = 3;

  /// 每组的待办（空组不在其中）：有日期的两组按截止先后，其余保持传入的顺序。
  final Map<TodoPlanSection, List<TodoRow>> sections;

  bool get isEmpty => sections.isEmpty;

  static TodoDayPlan build(List<TodoRow> open, DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    final todayText = formatAnniversaryDate(day);
    final soonText = formatAnniversaryDate(
      DateTime(day.year, day.month, day.day + soonDays),
    );
    final recentFrom = DateTime(day.year, day.month, day.day - recentDays);
    final sections = <TodoPlanSection, List<TodoRow>>{};
    void add(TodoPlanSection section, TodoRow row) =>
        sections.putIfAbsent(section, () => <TodoRow>[]).add(row);
    for (final row in open) {
      if (row.completedAt != null) continue;
      final due = row.dueDate;
      if (due != null) {
        if (due.compareTo(todayText) < 0) {
          add(TodoPlanSection.overdue, row);
        } else if (due != todayText && due.compareTo(soonText) <= 0) {
          add(TodoPlanSection.soon, row);
        }
      } else if (row.priority == TodoPriority.high.index) {
        add(TodoPlanSection.important, row);
      } else if (!row.createdAt.isBefore(recentFrom)) {
        add(TodoPlanSection.recent, row);
      }
    }
    // 有日期的两组按截止先后（同一天全天的在前、再按时刻）。
    int byDue(TodoRow a, TodoRow b) {
      final day = a.dueDate!.compareTo(b.dueDate!);
      if (day != 0) return day;
      return (a.dueMinute ?? -1).compareTo(b.dueMinute ?? -1);
    }

    sections[TodoPlanSection.overdue]?.sort(byDue);
    sections[TodoPlanSection.soon]?.sort(byDue);
    return TodoDayPlan(<TodoPlanSection, List<TodoRow>>{
      for (final section in TodoPlanSection.values)
        if (sections[section] case final rows?) section: rows,
    });
  }
}
