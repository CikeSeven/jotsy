import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../viewmodels/todo_reschedule.dart';
import 'todo_labels.dart';
import 'todo_sheet.dart';

/// 截止日面板的结果：新的日期与时刻；[date] 为 null 即移除日期。
@immutable
class TodoDueChoice {
  const TodoDueChoice({required this.date, this.minute});

  const TodoDueChoice.remove() : date = null, minute = null;

  final DateTime? date;
  final int? minute;
}

/// 选截止日（改期面板，滑动、右键、多选、详情与规划今天共用）：今天 / 明天
/// / 本周末 / 下周一 / 一周后 / 选择日期…，每项写出具体的星期与日子
/// （日子见 [TodoRescheduleDays]）；再给“设置时间”（或“全天”）与已有日期时
/// 的“移除日期”。选日子时保留原来的时刻。关闭面板不改动时为 null。
Future<TodoDueChoice?> showTodoDueSheet(
  BuildContext context, {
  required DateTime? date,
  required int? minute,
  required DateTime today,
}) {
  return showTodoSheet<TodoDueChoice>(
    context: context,
    builder: (BuildContext sheetContext) {
      final l10n = sheetContext.l10n;
      final days = TodoRescheduleDays.of(today);
      String dayOf(DateTime day) => l10n.todoHeroDate(
        TodoLabels.weekdayName(l10n, day.weekday),
        l10n.formatMonthDay(day),
      );
      void pick(DateTime day) => Navigator.of(
        sheetContext,
      ).pop(TodoDueChoice(date: day, minute: minute));
      bool same(DateTime a) => date != null && DateUtils.isSameDay(a, date);

      Future<void> pickDate() async {
        final picked = await showDatePicker(
          context: sheetContext,
          initialDate: date ?? today,
          firstDate: DateTime(today.year - 10),
          lastDate: DateTime(today.year + 30, 12, 31),
        );
        if (picked != null && sheetContext.mounted) pick(picked);
      }

      Future<void> pickTime() async {
        final initial = minute ?? 9 * 60;
        final picked = await showTimePicker(
          context: sheetContext,
          initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
        );
        if (picked == null || !sheetContext.mounted) return;
        Navigator.of(sheetContext).pop(
          TodoDueChoice(
            date: date ?? today,
            minute: picked.hour * 60 + picked.minute,
          ),
        );
      }

      return TodoSheetBody(
        title: l10n.todoFieldDue,
        children: <Widget>[
          for (final (icon, label, day) in <(FaIconData, String, DateTime)>[
            (FontAwesomeIcons.solidSun, l10n.todoDueToday, days.today),
            (FontAwesomeIcons.arrowRight, l10n.todoDueTomorrow, days.tomorrow),
            (FontAwesomeIcons.mugHot, l10n.todoDueThisWeekend, days.weekend),
            (FontAwesomeIcons.forward, l10n.todoDueNextWeek, days.nextMonday),
            (FontAwesomeIcons.calendarWeek, l10n.todoDueInAWeek, days.inAWeek),
          ])
            TodoSheetOption(
              icon: icon,
              label: label,
              detail: dayOf(day),
              selected: same(day),
              onTap: () => pick(day),
            ),
          TodoSheetOption(
            icon: FontAwesomeIcons.calendarDays,
            label: l10n.todoDuePickDate,
            detail:
                date == null ||
                    <DateTime>[
                      days.today,
                      days.tomorrow,
                      days.weekend,
                      days.nextMonday,
                      days.inAWeek,
                    ].any(same)
                ? null
                : dayOf(date),
            onTap: pickDate,
          ),
          const Divider(indent: 16, endIndent: 16),
          TodoSheetOption(
            icon: FontAwesomeIcons.clock,
            label: l10n.todoDueSetTime,
            detail: minute == null
                ? null
                : TodoLabels.formatTodoTime(sheetContext, minute),
            onTap: pickTime,
          ),
          if (date != null && minute != null)
            TodoSheetOption(
              icon: FontAwesomeIcons.solidCalendar,
              label: l10n.todoDueAllDay,
              onTap: () =>
                  Navigator.of(sheetContext).pop(TodoDueChoice(date: date)),
            ),
          if (date != null)
            TodoSheetOption(
              icon: FontAwesomeIcons.xmark,
              label: l10n.todoDueRemove,
              destructive: true,
              onTap: () =>
                  Navigator.of(sheetContext).pop(const TodoDueChoice.remove()),
            ),
        ],
      );
    },
  );
}
