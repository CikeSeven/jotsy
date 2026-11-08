import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

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

/// 选截止日：今天 / 明天 / 下周一 / 选择日期…，已有日期时再给“设置时间”
/// （或“全天”）与“移除日期”。选日期时保留原来的时刻。关闭面板不改动时为
/// null。
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
      final tomorrow = DateTime(today.year, today.month, today.day + 1);
      final daysToMonday = (DateTime.monday - today.weekday + 7) % 7;
      final nextMonday = DateTime(
        today.year,
        today.month,
        today.day + (daysToMonday == 0 ? 7 : daysToMonday),
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
          TodoSheetOption(
            icon: FontAwesomeIcons.solidSun,
            label: l10n.todoDueToday,
            detail: TodoLabels.weekdayName(l10n, today.weekday),
            selected: same(today),
            onTap: () => pick(today),
          ),
          TodoSheetOption(
            icon: FontAwesomeIcons.arrowRight,
            label: l10n.todoDueTomorrow,
            detail: TodoLabels.weekdayName(l10n, tomorrow.weekday),
            selected: same(tomorrow),
            onTap: () => pick(tomorrow),
          ),
          TodoSheetOption(
            icon: FontAwesomeIcons.forward,
            label: l10n.todoDueNextWeek,
            detail: l10n.formatMonthDay(nextMonday),
            selected: same(nextMonday),
            onTap: () => pick(nextMonday),
          ),
          TodoSheetOption(
            icon: FontAwesomeIcons.calendarDays,
            label: l10n.todoDuePickDate,
            detail:
                date == null ||
                    same(today) ||
                    same(tomorrow) ||
                    same(nextMonday)
                ? null
                : TodoLabels.relativeDay(l10n, date, today),
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
