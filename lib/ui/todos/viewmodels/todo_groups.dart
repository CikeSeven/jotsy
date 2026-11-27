import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../models/todo_settings.dart';
import '../models/todo_view.dart';

/// 待办列表里一组的种类，决定标题怎么写。
enum TodoGroupKind {
  /// 不显示标题的一组（重要、清单与收集箱里未完成的）。
  plain,
  overdue,
  today,
  tomorrow,

  /// 计划视图里后天起七天内的某一天（[TodoGroup.day]）。
  day,
  later,

  /// “全部”视图里按清单分的一组（[TodoGroup.listId] 为 null 即收集箱）。
  list,

  /// 清单视图里的一个分区（[TodoGroup.section]）；可折叠、可为空（标题
  /// 照常出现，便于往里加）。
  section,

  /// 清单底部可折叠的已完成。
  completed,

  /// “今天”视图底部可折叠的今天已完成。
  completedToday,

  /// “已完成”视图里按完成日期分的一组（[TodoGroup.day]）。
  completedDay,
}

/// 列表里的一组待办。
@immutable
class TodoGroup {
  const TodoGroup({
    required this.kind,
    required this.rows,
    this.listId,
    this.day,
    this.section,
  });

  final TodoGroupKind kind;
  final List<TodoRow> rows;
  final String? listId;
  final DateTime? day;

  /// [TodoGroupKind.section] 的分区。
  final TodoSection? section;

  /// 稳定的键：切换视图、增删条目时分组标题与折叠状态按它对应。
  String get key => switch (kind) {
    TodoGroupKind.list => 'list:${listId ?? ''}',
    TodoGroupKind.completedDay => 'day:${day!.toIso8601String()}',
    TodoGroupKind.day => 'due:${day!.toIso8601String()}',
    TodoGroupKind.section => 'section:${section!.id}',
    _ => kind.name,
  };
}

/// 把待办分到视图 [view] 的各组里（纯函数，无 IO）。
///
/// 输入：未完成的待办 [open]（已按拖动顺序）、最近完成的 [completed]（最近
/// 完成的在前）、清单顺序 [listOrder]、排序方式与“今天” [today]（本地零点）；
/// 输出：要显示的各组，空组不出现。
///
/// - 今天：逾期 / 今天两组，[showCompleted] 时底部再加今天完成的一组；计划：
///   逾期 / 今天 / 明天 / 之后七天内每天一组 / 更晚。这两个视图里“手动”排序
///   按截止时刻（全天的在前），其余排序方式照常；
/// - 重要：高优先级的一组；
/// - 全部：按清单分组，收集箱在前，清单按拖动顺序，空清单不出现；
/// - 收集箱与清单：未完成一组，[showCompleted] 时底部再加这个清单的已完成；
///   清单有分区（[sections]）时，未分区的（含认不出分区的）在最上面一组，
///   再是各分区一组（按分区顺序，空的也在）；[sectionOf] 给出拖动后还没
///   推送回来的分区（没有时按行上的）；
/// - 已完成：按完成日期分组（最近的在前）。
List<TodoGroup> buildTodoGroups({
  required TodoView view,
  required List<TodoRow> open,
  required List<TodoRow> completed,
  required List<String> listOrder,
  required TodoSortMode sort,
  required DateTime today,
  required bool showCompleted,
  List<TodoSection> sections = const <TodoSection>[],
  String? Function(TodoRow row)? sectionOf,
}) {
  final todayText = formatAnniversaryDate(today);
  final tomorrowText = formatAnniversaryDate(
    DateTime(today.year, today.month, today.day + 1),
  );
  final weekText = formatAnniversaryDate(
    DateTime(today.year, today.month, today.day + 7),
  );

  List<TodoGroup> dated(List<TodoRow> rows, {required bool future}) {
    final buckets = <TodoGroupKind, List<TodoRow>>{};
    // 七天内每天一组（按日期字符串，正好按日子先后）。
    final days = <String, List<TodoRow>>{};
    for (final row in rows) {
      final due = row.dueDate;
      if (due == null) continue;
      final TodoGroupKind kind;
      if (due.compareTo(todayText) < 0) {
        kind = TodoGroupKind.overdue;
      } else if (due == todayText) {
        kind = TodoGroupKind.today;
      } else if (!future) {
        continue;
      } else if (due == tomorrowText) {
        kind = TodoGroupKind.tomorrow;
      } else if (due.compareTo(weekText) <= 0) {
        days.putIfAbsent(due, () => <TodoRow>[]).add(row);
        continue;
      } else {
        kind = TodoGroupKind.later;
      }
      buckets.putIfAbsent(kind, () => <TodoRow>[]).add(row);
    }
    final effectiveSort = sort == TodoSortMode.manual ? TodoSortMode.due : sort;
    TodoGroup? group(TodoGroupKind kind) => switch (buckets[kind]) {
      final rows? => TodoGroup(
        kind: kind,
        rows: sortTodoRows(rows, effectiveSort),
      ),
      null => null,
    };
    return <TodoGroup>[
      ?group(TodoGroupKind.overdue),
      ?group(TodoGroupKind.today),
      ?group(TodoGroupKind.tomorrow),
      for (final day in days.keys.toList()..sort())
        TodoGroup(
          kind: TodoGroupKind.day,
          day: parseAnniversaryDate(day),
          rows: sortTodoRows(days[day]!, effectiveSort),
        ),
      ?group(TodoGroupKind.later),
    ];
  }

  if (view.tag case final tag?) {
    final rows = <TodoRow>[
      for (final row in open)
        if (TodoTags.contains(TodoTags.ofMetadataText(row.metadata), tag)) row,
    ];
    return <TodoGroup>[
      if (rows.isNotEmpty)
        TodoGroup(kind: TodoGroupKind.plain, rows: sortTodoRows(rows, sort)),
    ];
  }

  switch (view.smart) {
    case TodoSmartView.today:
      final doneToday = <TodoRow>[
        if (showCompleted)
          for (final row in completed)
            if (_completedOn(row, today)) row,
      ];
      return <TodoGroup>[
        ...dated(open, future: false),
        if (doneToday.isNotEmpty)
          TodoGroup(kind: TodoGroupKind.completedToday, rows: doneToday),
      ];
    case TodoSmartView.planned:
      return dated(open, future: true);
    case TodoSmartView.important:
      final rows = <TodoRow>[
        for (final row in open)
          if (row.priority >= TodoPriority.high.index) row,
      ];
      return <TodoGroup>[
        if (rows.isNotEmpty)
          TodoGroup(kind: TodoGroupKind.plain, rows: sortTodoRows(rows, sort)),
      ];
    case TodoSmartView.all:
      final byList = <String?, List<TodoRow>>{};
      final known = listOrder.toSet();
      for (final row in open) {
        // 所在清单已不存在（同步或导入的中间状态）时归到收集箱显示。
        final key = known.contains(row.listId) ? row.listId : null;
        byList.putIfAbsent(key, () => <TodoRow>[]).add(row);
      }
      return <TodoGroup>[
        for (final id in <String?>[null, ...listOrder])
          if (byList[id] case final rows?)
            TodoGroup(
              kind: TodoGroupKind.list,
              listId: id,
              rows: sortTodoRows(rows, sort),
            ),
      ];
    case TodoSmartView.completed:
      final byDay = <String, List<TodoRow>>{};
      final days = <String, DateTime>{};
      for (final row in completed) {
        final at = row.completedAt!;
        final day = DateTime(at.year, at.month, at.day);
        final key = formatAnniversaryDate(day);
        days[key] = day;
        byDay.putIfAbsent(key, () => <TodoRow>[]).add(row);
      }
      return <TodoGroup>[
        for (final entry in byDay.entries)
          TodoGroup(
            kind: TodoGroupKind.completedDay,
            day: days[entry.key],
            rows: entry.value,
          ),
      ];
    case TodoSmartView.inbox:
    case null:
      final listId = view.listId;
      bool inThisList(TodoRow row) => row.listId == listId;
      final rows = <TodoRow>[
        for (final row in open)
          if (inThisList(row)) row,
      ];
      final done = <TodoRow>[
        if (showCompleted)
          for (final row in completed)
            if (inThisList(row)) row,
      ];
      final doneGroup = done.isEmpty
          ? null
          : TodoGroup(
              kind: TodoGroupKind.completed,
              listId: listId,
              rows: done,
            );
      if (listId == null || sections.isEmpty) {
        return <TodoGroup>[
          if (rows.isNotEmpty)
            TodoGroup(
              kind: TodoGroupKind.plain,
              rows: sortTodoRows(rows, sort),
            ),
          ?doneGroup,
        ];
      }
      final known = <String>{for (final section in sections) section.id};
      final bySection = <String?, List<TodoRow>>{};
      for (final row in rows) {
        final id = sectionOf?.call(row) ?? TodoSections.idOfTodo(row.metadata);
        bySection
            .putIfAbsent(known.contains(id) ? id : null, () => <TodoRow>[])
            .add(row);
      }
      final loose = bySection[null];
      return <TodoGroup>[
        if (loose != null)
          TodoGroup(kind: TodoGroupKind.plain, rows: sortTodoRows(loose, sort)),
        for (final section in sections)
          TodoGroup(
            kind: TodoGroupKind.section,
            listId: listId,
            section: section,
            rows: sortTodoRows(
              bySection[section.id] ?? const <TodoRow>[],
              sort,
            ),
          ),
        ?doneGroup,
      ];
  }
}

bool _completedOn(TodoRow row, DateTime day) {
  final at = row.completedAt;
  return at != null &&
      at.year == day.year &&
      at.month == day.month &&
      at.day == day.day;
}

/// “今天”概览卡的数字。
@immutable
class TodoTodaySummary {
  const TodoTodaySummary({
    required this.remaining,
    required this.overdue,
    required this.doneToday,
  });

  /// 截止日不晚于今天、还没完成的（含逾期）。
  final int remaining;

  /// 其中已逾期的。
  final int overdue;

  /// 今天完成的。
  final int doneToday;

  int get total => remaining + doneToday;

  /// 今天的进度（0~1）；今天什么都没有时为 0。
  double get fraction => total == 0 ? 0 : doneToday / total;
}

/// 汇总“今天”概览卡的数字（纯函数）：剩余与逾期取未完成的 [open]，今天完成
/// 的取最近完成的 [completed] 里完成时间落在 [today] 的。
TodoTodaySummary todoTodaySummary(
  List<TodoRow> open,
  List<TodoRow> completed,
  DateTime today,
) {
  final todayText = formatAnniversaryDate(today);
  var remaining = 0;
  var overdue = 0;
  for (final row in open) {
    final due = row.dueDate;
    if (due == null || due.compareTo(todayText) > 0) continue;
    remaining++;
    if (due.compareTo(todayText) < 0) overdue++;
  }
  var doneToday = 0;
  for (final row in completed) {
    if (_completedOn(row, today)) doneToday++;
  }
  return TodoTodaySummary(
    remaining: remaining,
    overdue: overdue,
    doneToday: doneToday,
  );
}

/// 按排序方式排一组未完成的待办（稳定排序：同序时保持输入的拖动顺序）。
List<TodoRow> sortTodoRows(List<TodoRow> rows, TodoSortMode sort) {
  if (sort == TodoSortMode.manual) return rows;
  final indexed = <(int, TodoRow)>[
    for (var i = 0; i < rows.length; i++) (i, rows[i]),
  ];
  int byDue(TodoRow a, TodoRow b) {
    final da = a.dueDate;
    final db = b.dueDate;
    if (da != db) {
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    }
    // 同一天：全天的在前，有时间的按时刻。
    final ma = a.dueMinute ?? -1;
    final mb = b.dueMinute ?? -1;
    return ma.compareTo(mb);
  }

  indexed.sort((x, y) {
    final a = x.$2;
    final b = y.$2;
    final int result = switch (sort) {
      TodoSortMode.due => byDue(a, b),
      TodoSortMode.priority => () {
        final p = b.priority.compareTo(a.priority);
        return p != 0 ? p : byDue(a, b);
      }(),
      TodoSortMode.created => b.createdAt.compareTo(a.createdAt),
      TodoSortMode.manual => 0,
    };
    return result != 0 ? result : x.$1.compareTo(y.$1);
  });
  return <TodoRow>[for (final entry in indexed) entry.$2];
}

/// 每个智能视图里未完成的条数（侧栏与视图胶囊上的数字）。“已完成”不计数。
Map<TodoSmartView, int> todoSmartViewCounts(
  List<TodoRow> open,
  DateTime today,
) {
  final todayText = formatAnniversaryDate(today);
  var todayCount = 0;
  var planned = 0;
  var important = 0;
  var inbox = 0;
  for (final row in open) {
    final due = row.dueDate;
    if (due != null) {
      planned++;
      if (due.compareTo(todayText) <= 0) todayCount++;
    }
    if (row.priority >= TodoPriority.high.index) important++;
    if (row.listId == null) inbox++;
  }
  return <TodoSmartView, int>{
    TodoSmartView.today: todayCount,
    TodoSmartView.planned: planned,
    TodoSmartView.important: important,
    TodoSmartView.all: open.length,
    TodoSmartView.inbox: inbox,
  };
}
