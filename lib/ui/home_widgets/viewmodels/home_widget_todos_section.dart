// 快照的「待办」一节：未完成的待办（按截止日、时刻、优先级排好）、今天完成的、
// 以及清单名。
//
// 只给截止日本身（`YYYY-MM-DD`）与它的日期写法：“今天 / 明天 / 已逾期”由原生按本机
// 日期现算，过了零点不必等应用重建快照；视图（今天 / 计划 / 全部 / 某个清单）也在原生
// 筛，同一份数据供桌面上所有待办小组件用。
//
// 待办不是日记内容：应用锁开着也照常显示（用户的决定，见 docs/rules/home_widgets.md
// 「隐私」）。
//
// 条数上限：[kHomeWidgetTodoLimit] 条未完成、[kHomeWidgetDoneLimit] 条今天完成的——
// 小组件放不下更多，快照也不必为几百条待办变大。

import 'package:flutter/material.dart' show DateUtils;
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations.dart';

const int kHomeWidgetTodoLimit = 80;
const int kHomeWidgetDoneLimit = 20;

Map<String, Object?> buildHomeWidgetTodosSection({
  required DateTime now,
  required AppLocalizations l10n,
  required List<TodoRow> open,
  required List<TodoRow> completed,
  required List<TodoListRow> lists,
}) {
  final sorted = List<TodoRow>.of(open)..sort(_compare);
  final today = DateUtils.dateOnly(now);
  final done = <TodoRow>[
    for (final row in completed)
      if (row.completedAt case final DateTime at
          when DateUtils.isSameDay(at.toLocal(), today))
        row,
  ]..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
  final time = DateFormat.Hm(l10n.localeName);
  return <String, Object?>{
    'lists': <String, Object?>{
      for (final list in lists) list.listId: list.name,
    },
    'open': <Object?>[
      for (final row in sorted.take(kHomeWidgetTodoLimit))
        <String, Object?>{
          'id': row.todoId,
          'title': row.title,
          if (row.dueDate case final String due) ...<String, Object?>{
            'due': due,
            if (parseAnniversaryDate(due) case final DateTime date)
              'dueLabel': l10n.formatMonthDay(date),
          },
          if (row.dueMinute case final int minute)
            'time': time.format(
              DateTime(2024, 1, 1, minute ~/ 60, minute % 60),
            ),
          'list': ?row.listId,
          if (row.priority > 0) 'priority': row.priority,
          if (row.repeat != null && row.repeat!.isNotEmpty) 'repeat': true,
        },
    ],
    'done': <Object?>[
      for (final row in done.take(kHomeWidgetDoneLimit))
        <String, Object?>{
          'id': row.todoId,
          'title': row.title,
          'list': ?row.listId,
          'due': ?row.dueDate,
        },
    ],
  };
}

/// 小组件上的顺序：有截止日的在前、按日子早晚；同一天全天的在前、再按时刻；
/// 再按优先级（高的在前）；最后按标题，保证稳定。
int _compare(TodoRow a, TodoRow b) {
  final dueA = a.dueDate;
  final dueB = b.dueDate;
  if (dueA != dueB) {
    if (dueA == null) return 1;
    if (dueB == null) return -1;
    return dueA.compareTo(dueB);
  }
  final minuteA = a.dueMinute ?? -1;
  final minuteB = b.dueMinute ?? -1;
  if (minuteA != minuteB) return minuteA.compareTo(minuteB);
  if (a.priority != b.priority) return b.priority.compareTo(a.priority);
  return a.title.compareTo(b.title);
}
