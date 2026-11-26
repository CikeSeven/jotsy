import 'dart:convert';

import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import 'todo_reminder_planner.dart';

/// 待办提醒文案与通知偏好的纯核心辅助，供主调度器、后台 isolate 与界面共用。

/// 日期的相对说法：昨天 / 今天 / 明天；一周内写星期；同年写月日；跨年写完整日期。
String formatTodoRelativeDay(
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

/// “今天”“明天”以弹出通知那天为准，否则提前排好的通知会显示过期的相对日期。
String formatTodoReminderNotificationBody(
  AppLocalizations l10n,
  PlannedReminder reminder,
) {
  if (reminder.snooze) return l10n.todoNotificationSnoozedBody;
  final fireLocal = reminder.fireAt.toLocal();
  final fireDay = DateTime(fireLocal.year, fireLocal.month, fireLocal.day);
  final date = formatTodoRelativeDay(l10n, reminder.occurrence, fireDay);
  final minute = reminder.dueMinute;
  if (minute == null) return date;
  final time = DateFormat.jm(
    l10n.localeName,
  ).format(DateTime(2000, 1, 1, minute ~/ 60, minute % 60));
  return l10n.todoDueWithTime(date, time);
}

/// 从 `app.settings.todos` 原始 JSON 读取后台排程所需字段，避免 core 层反向依赖 ui 模型。
({int snoozeMinutes, bool hideContentOnLockScreen}) decodeTodoReminderPrefs(
  String? raw,
) {
  const defaultSnooze = 10;
  const snoozeChoices = <int>[5, 10, 15, 30, 60];
  if (raw == null || raw.trim().isEmpty) {
    return (snoozeMinutes: defaultSnooze, hideContentOnLockScreen: false);
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return (snoozeMinutes: defaultSnooze, hideContentOnLockScreen: false);
    }
    final snooze = decoded['snoozeMinutes'];
    return (
      snoozeMinutes: snooze is int && snoozeChoices.contains(snooze)
          ? snooze
          : defaultSnooze,
      hideContentOnLockScreen: decoded['hideContentOnLockScreen'] == true,
    );
  } on FormatException {
    return (snoozeMinutes: defaultSnooze, hideContentOnLockScreen: false);
  }
}
