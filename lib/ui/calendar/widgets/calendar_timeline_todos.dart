import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../todos/viewmodels/todo_calendar_index.dart';
import '../../todos/viewmodels/todo_groups.dart';
import '../../todos/widgets/todo_group_header.dart';
import '../../todos/widgets/todo_tile.dart';
import 'calendar_timeline_rail.dart';

/// 选中日时间线里待办要用的数据与操作，由页面给出（组件本身不读 provider、
/// 不写库）。待办功能关闭或显示选项关掉待办时页面不给，时间线只有日记。
@immutable
class CalendarTimelineTodos {
  const CalendarTimelineTodos({
    required this.entries,
    required this.today,
    required this.onToggle,
    required this.onOpen,
    required this.onAdd,
    required this.onMoveOverdueToToday,
    this.overdue = const <TodoCalendarEntry>[],
  });

  /// 选中日的待办（[TodoCalendarIndex.entriesOn]）。
  final List<TodoCalendarEntry> entries;

  /// 选中今天时今天之前还没完成的待办；其他日子为空。
  final List<TodoCalendarEntry> overdue;

  /// 本地零点的今天：待办行的相对日期与是否逾期。
  final DateTime today;

  /// 勾选 / 取消勾选（日历里勾选即写库）。
  final ValueChanged<TodoRow> onToggle;

  /// 点行打开详情。
  final ValueChanged<TodoRow> onOpen;

  /// 以选中日为截止日新建。
  final VoidCallback onAdd;

  /// 逾期组的“全部改到今天”。
  final ValueChanged<List<TodoRow>> onMoveOverdueToToday;

  /// 内容签名：勾选、改动、换日后时间线交叉淡入。
  String get signature => <TodoCalendarEntry>[...overdue, ...entries]
      .map(
        (TodoCalendarEntry entry) =>
            '${entry.row.todoId}:${entry.occurrence.millisecondsSinceEpoch}:'
            '${entry.done}:${entry.row.updatedAt.millisecondsSinceEpoch}',
      )
      .join('|');

  /// 时间线上的一条待办：与待办页同一种行（[TodoTile]），线从方框左侧经过、
  /// 锚点对着方框中心。重复待办以后的某一次方框淡化、不能勾选。
  CalendarRailEntry railEntry(BuildContext context, TodoCalendarEntry entry) {
    return CalendarRailEntry(
      id:
          'todo_${entry.row.todoId}_'
          '${entry.occurrence.millisecondsSinceEpoch}',
      // TodoTile：上内边距 4 + 48dp 方框格的一半。
      anchor: AppSpacing.xs + 24,
      node: _TodoRailNode(done: entry.done),
      child: _tile(context, entry),
    );
  }

  /// 逾期组：标题（“已逾期 N”与“全部改到今天”）+ 各条待办，放在当天时间线
  /// 之上——它们不属于这一天，不进时间线。
  Widget overdueBlock(BuildContext context) {
    final rows = <TodoRow>[for (final entry in overdue) entry.row];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TodoGroupHeader(
          group: TodoGroup(kind: TodoGroupKind.overdue, rows: rows),
          today: today,
          onMoveOverdueToToday: () => onMoveOverdueToToday(rows),
        ),
        for (final entry in overdue)
          Padding(
            key: ValueKey<String>('calendar_overdue_${entry.row.todoId}'),
            padding: const EdgeInsets.only(bottom: AppSpacing.s),
            child: _tile(context, entry),
          ),
      ],
    );
  }

  Widget _tile(BuildContext context, TodoCalendarEntry entry) {
    final row = entry.row;
    return TodoTile(
      row: row,
      today: today,
      onToggle: entry.projected ? null : () => onToggle(row),
      disabledHint: context.l10n.calendarTodoRepeatHint,
      onTap: () => onOpen(row),
    );
  }
}

/// 待办在线上的节点：比日记的实心圆点小一号的空心圆环，只标出它在这一天
/// 的位置；完成与否看行里的方框，这里已完成时只把圆环填满。
class _TodoRailNode extends StatelessWidget {
  const _TodoRailNode({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: done ? colorScheme.outline : colorScheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: colorScheme.outline, width: 1.5),
      ),
    );
  }
}
