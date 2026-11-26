import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../todos/viewmodels/todo_calendar_index.dart';

/// 选中日时间线上的一条：一篇日记或一条待办。
@immutable
sealed class CalendarAgendaItem {
  const CalendarAgendaItem();
}

/// 一篇日记，按发表时刻排进时间线。
final class CalendarAgendaDiary extends CalendarAgendaItem {
  const CalendarAgendaDiary(this.diary);

  final DiaryWithTags diary;
}

/// 一条待办：全天的排在最前，有时刻的按截止时刻与日记穿插。
final class CalendarAgendaTodo extends CalendarAgendaItem {
  const CalendarAgendaTodo(this.entry);

  final TodoCalendarEntry entry;
}

/// 选中日的“这一天”：日记与待办合成一条时间线（纯函数构建，无 IO）。
///
/// 自上而下：
/// 1. [overdue]：只在选中今天时给出，今天之前还没完成的待办；
/// 2. [allDay]：这一天没定时刻的待办（未完成在前，已完成在后，沿用
///    [TodoCalendarIndex] 的顺序）；
/// 3. [timed]：日记（按发表时刻）与有时刻的待办（按截止时刻）穿插，同一
///    分钟日记在前。已完成的定时待办留在原来的时刻上，不挪到最后。
///
/// 选中今天时，逾期的重复待办在今天投影出来的那一次不再重复列出：它只在
/// 逾期里出现一次，勾的就是它。
@immutable
class CalendarDayAgenda {
  const CalendarDayAgenda._({
    required this.overdue,
    required this.allDay,
    required this.timed,
  });

  factory CalendarDayAgenda.build({
    required List<DiaryWithTags> diaries,
    List<TodoCalendarEntry> todos = const <TodoCalendarEntry>[],
    List<TodoCalendarEntry> overdue = const <TodoCalendarEntry>[],
  }) {
    final overdueIds = <String>{for (final entry in overdue) entry.row.todoId};
    final allDay = <TodoCalendarEntry>[];
    final timed = <(int, int, CalendarAgendaItem)>[];
    for (final entry in todos) {
      if (entry.projected && overdueIds.contains(entry.row.todoId)) continue;
      final minute = entry.row.dueMinute;
      if (minute == null) {
        allDay.add(entry);
      } else {
        timed.add((minute, 1, CalendarAgendaTodo(entry)));
      }
    }
    for (final diary in diaries) {
      final at = diary.diary.createdAt.toLocal();
      timed.add((at.hour * 60 + at.minute, 0, CalendarAgendaDiary(diary)));
    }
    // 稳定排序：先按分钟，同一分钟日记（0）在待办（1）前；再同类时保持
    // 传入顺序（日记已按发表时间升序，待办已按索引排好）。
    final indexed = timed.indexed.toList()
      ..sort((a, b) {
        final byMinute = a.$2.$1.compareTo(b.$2.$1);
        if (byMinute != 0) return byMinute;
        final byKind = a.$2.$2.compareTo(b.$2.$2);
        if (byKind != 0) return byKind;
        return a.$1.compareTo(b.$1);
      });
    return CalendarDayAgenda._(
      overdue: List<TodoCalendarEntry>.unmodifiable(overdue),
      allDay: List<TodoCalendarEntry>.unmodifiable(allDay),
      timed: List<CalendarAgendaItem>.unmodifiable(
        indexed.map((item) => item.$2.$3),
      ),
    );
  }

  final List<TodoCalendarEntry> overdue;
  final List<TodoCalendarEntry> allDay;
  final List<CalendarAgendaItem> timed;

  bool get hasDiaries => timed.any((item) => item is CalendarAgendaDiary);

  bool get hasTodos =>
      overdue.isNotEmpty ||
      allDay.isNotEmpty ||
      timed.any((item) => item is CalendarAgendaTodo);

  bool get isEmpty => overdue.isEmpty && allDay.isEmpty && timed.isEmpty;
}
