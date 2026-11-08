import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../models/todo_settings.dart';
import '../models/todo_view.dart';

/// 待办的展示文案（列表行、详情页、选择面板、提示共用），保证各处说法一致。
///
/// 时刻统一经 [formatTodoTime] 按系统的 12 / 24 小时制格式化；星期与月日
/// 经 intl 按界面语言格式化，不手写图案。
abstract final class TodoLabels {
  static String smartView(AppLocalizations l10n, TodoSmartView view) =>
      switch (view) {
        TodoSmartView.today => l10n.todoViewToday,
        TodoSmartView.planned => l10n.todoViewPlanned,
        TodoSmartView.important => l10n.todoViewImportant,
        TodoSmartView.all => l10n.todoViewAll,
        TodoSmartView.inbox => l10n.todoViewInbox,
        TodoSmartView.completed => l10n.todoViewCompleted,
      };

  static FaIconData smartViewIcon(TodoSmartView view) => switch (view) {
    TodoSmartView.today => FontAwesomeIcons.solidSun,
    TodoSmartView.planned => FontAwesomeIcons.solidCalendar,
    TodoSmartView.important => FontAwesomeIcons.solidStar,
    TodoSmartView.all => FontAwesomeIcons.layerGroup,
    TodoSmartView.inbox => FontAwesomeIcons.inbox,
    TodoSmartView.completed => FontAwesomeIcons.circleCheck,
  };

  static String sortMode(AppLocalizations l10n, TodoSortMode mode) =>
      switch (mode) {
        TodoSortMode.manual => l10n.todoSortManual,
        TodoSortMode.due => l10n.todoSortDue,
        TodoSortMode.priority => l10n.todoSortPriority,
        TodoSortMode.created => l10n.todoSortCreated,
      };

  static String priority(AppLocalizations l10n, TodoPriority priority) =>
      switch (priority) {
        TodoPriority.none => l10n.todoPriorityNone,
        TodoPriority.low => l10n.todoPriorityLow,
        TodoPriority.medium => l10n.todoPriorityMedium,
        TodoPriority.high => l10n.todoPriorityHigh,
      };

  /// 优先级的强调色：高为 error、中为 tertiary、低为 primary；无优先级为 null
  /// （用默认描边）。
  static Color? priorityColor(ColorScheme scheme, TodoPriority priority) =>
      switch (priority) {
        TodoPriority.none => null,
        TodoPriority.low => scheme.primary,
        TodoPriority.medium => scheme.tertiary,
        TodoPriority.high => scheme.error,
      };

  /// 一天中的分钟数 → 按系统 12 / 24 小时制的时刻文字。
  static String formatTodoTime(BuildContext context, int minute) {
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
  }

  /// 日期的相对说法：昨天 / 今天 / 明天；一周内写星期；同年写月日；跨年
  /// 写完整日期。
  static String relativeDay(
    AppLocalizations l10n,
    DateTime day,
    DateTime today,
  ) {
    final diff = DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
    if (diff == 0) return l10n.todoDueToday;
    if (diff == 1) return l10n.todoDueTomorrow;
    if (diff == -1) return l10n.todoDueYesterday;
    if (diff > 1 && diff < 7) {
      return DateFormat.EEEE(l10n.localeName).format(day);
    }
    if (day.year == today.year) return l10n.formatMonthDay(day);
    return l10n.formatFullDate(day);
  }

  /// 截止日（与时刻）的说法，如“明天 15:00”“11月20日”。
  static String due(
    BuildContext context,
    DateTime day,
    int? minute,
    DateTime today,
  ) {
    final l10n = context.l10n;
    final date = relativeDay(l10n, day, today);
    if (minute == null) return date;
    return l10n.todoDueWithTime(date, formatTodoTime(context, minute));
  }

  /// 一行待办的截止日说法；没有日期或日期坏了时为 null。
  static String? dueOfRow(BuildContext context, TodoRow row, DateTime today) {
    final text = row.dueDate;
    final day = text == null ? null : parseAnniversaryDate(text);
    if (day == null) return null;
    return due(context, day, row.dueMinute, today);
  }

  static String reminder(BuildContext context, TodoReminder reminder) {
    final l10n = context.l10n;
    switch (reminder.kind) {
      case TodoReminderKind.beforeDue:
        final minutes = reminder.minutesBefore;
        if (minutes == 0) return l10n.todoReminderAtDue;
        if (minutes % (24 * 60) == 0) {
          return l10n.todoReminderDaysBefore(minutes ~/ (24 * 60));
        }
        if (minutes % 60 == 0) {
          return l10n.todoReminderHoursBefore(minutes ~/ 60);
        }
        return l10n.todoReminderMinutesBefore(minutes);
      case TodoReminderKind.onDay:
        final time = formatTodoTime(context, reminder.minuteOfDay);
        if (reminder.dayOffset == 0) return l10n.todoReminderOnDayAt(time);
        return l10n.todoReminderDaysBeforeAt(-reminder.dayOffset, time);
    }
  }

  /// 星期几的名称（[weekday] 为 `DateTime.monday`..`DateTime.sunday`）。
  static String weekdayName(
    AppLocalizations l10n,
    int weekday, {
    bool short = true,
  }) {
    // 2024-01-01 是周一。
    final day = DateTime(2024, 1, weekday);
    return (short
            ? DateFormat.E(l10n.localeName)
            : DateFormat.EEEE(l10n.localeName))
        .format(day);
  }

  /// 重复规则的一句话摘要，如“每 2 周 · 周一、周四”“每月第 2 个周三”。
  static String repeat(AppLocalizations l10n, TodoRepeatRule? rule) {
    if (rule == null) return l10n.todoRepeatNone;
    final interval = rule.interval;
    final String main;
    switch (rule.frequency) {
      case TodoRepeatFrequency.daily:
        main = interval == 1
            ? l10n.todoRepeatDaily
            : l10n.todoRepeatEveryDays(interval);
      case TodoRepeatFrequency.legalWorkdays:
        main = l10n.todoRepeatLegalWorkdays;
      case TodoRepeatFrequency.weekly:
        final days = rule.weekdays.isEmpty
            ? <int>[rule.anchor.weekday]
            : rule.weekdays;
        final names = days
            .map((d) => weekdayName(l10n, d))
            .join(l10n.isZh ? '、' : ', ');
        main = interval == 1 || rule.basis == TodoRepeatBasis.completion
            ? (rule.basis == TodoRepeatBasis.completion
                  ? l10n.todoRepeatEveryWeeks(interval)
                  : l10n.todoRepeatWeeklyOn(names))
            : l10n.todoRepeatSummaryJoin(
                l10n.todoRepeatEveryWeeks(interval),
                names,
              );
      case TodoRepeatFrequency.monthly:
        final String day = switch (rule.monthlyMode) {
          TodoMonthlyMode.dayOfMonth => l10n.todoRepeatMonthlyOnDay(
            rule.anchor.day,
          ),
          TodoMonthlyMode.weekdayOrdinal => l10n.todoRepeatMonthlyOrdinal(
            '${(rule.anchor.day - 1) ~/ 7 + 1}',
            weekdayName(l10n, rule.anchor.weekday, short: false),
          ),
          TodoMonthlyMode.lastDay => l10n.todoRepeatMonthlyLastDay,
        };
        main = rule.basis == TodoRepeatBasis.completion
            ? l10n.todoRepeatEveryMonths(interval)
            : interval == 1
            ? day
            : l10n.todoRepeatSummaryJoin(
                l10n.todoRepeatEveryMonths(interval),
                day,
              );
      case TodoRepeatFrequency.yearly:
        final date = l10n.formatMonthDay(rule.anchor);
        main = rule.basis == TodoRepeatBasis.completion
            ? l10n.todoRepeatEveryYears(interval)
            : interval == 1
            ? l10n.todoRepeatYearlyOn(date)
            : l10n.todoRepeatSummaryJoin(
                l10n.todoRepeatEveryYears(interval),
                date,
              );
    }
    final parts = <String>[main];
    if (rule.basis == TodoRepeatBasis.completion) {
      parts.add(l10n.todoRepeatFromCompletion);
    }
    final until = rule.until;
    if (until != null) {
      parts.add(l10n.todoRepeatEndsOn(l10n.formatFullDate(until)));
    } else if (rule.count != null) {
      parts.add(l10n.todoRepeatEndsAfter(rule.count!));
    }
    return parts.reduce(l10n.todoRepeatSummaryJoin);
  }
}
