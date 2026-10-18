import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../models/diary_template.dart';
import '../models/diary_template_auto_rule.dart';
import '../models/diary_template_prefs.dart';
import 'diary_template_library.dart';

// 自动套用的显示文案：星期简称、时间、时间段标题与副标题、设置项摘要。
// 只做格式化，不读写偏好。

/// 当前语言的星期简称（1 = 周一 … 7 = 周日）。2026-10-19 是周一，按它依次
/// 往后取，交给 intl 的本地化格式，不在 ARB 里另写七个词。
String diaryTemplateWeekdayLabel(String localeName, int weekday) =>
    DateFormat.E(localeName).format(DateTime(2026, 10, 18 + weekday));

/// 一天中的分钟数按系统的 12/24 小时制显示。
String formatDiaryTemplateAutoMinute(BuildContext context, int minute) {
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}

/// 时间段标题：“07:00 – 10:00”，跨夜为“22:00 – 次日 02:00”。
String diaryTemplateAutoRangeLabel(
  BuildContext context,
  DiaryTemplateAutoRule rule,
) {
  final l10n = context.l10n;
  final start = formatDiaryTemplateAutoMinute(context, rule.startMinute);
  final end = formatDiaryTemplateAutoMinute(context, rule.endMinute);
  return rule.crossesMidnight
      ? l10n.diaryTemplatesAutoApplyRangeOvernight(start, end)
      : l10n.diaryTemplatesAutoApplyRange(start, end);
}

/// 星期说明：不限为“每天”，正好周一到周五为“工作日”，正好周六周日为
/// “周末”，其余按周一在前列出简称。
String diaryTemplateAutoDaysLabel(AppLocalizations l10n, Set<int> weekdays) {
  if (weekdays.isEmpty) return l10n.diaryTemplatesAutoApplyEveryDay;
  if (weekdays.length == 5 && weekdays.every((day) => day <= 5)) {
    return l10n.diaryTemplatesAutoApplyWorkdays;
  }
  if (weekdays.length == 2 && weekdays.containsAll(const <int>{6, 7})) {
    return l10n.diaryTemplatesAutoApplyWeekend;
  }
  return (weekdays.toList()..sort())
      .map((day) => diaryTemplateWeekdayLabel(l10n.localeName, day))
      .join(l10n.diaryTemplatesAutoApplyDaySeparator);
}

String diaryTemplateDisplayName(
  AppLocalizations l10n,
  DiaryTemplate template,
) => template.name.isEmpty ? l10n.diaryTemplateUntitled : template.name;

/// 管理页“自动套用”一行的副标题：什么都没设、只有默认模板、只有时间段、
/// 两者都有四种情况。默认模板已被删除时按没设处理。
String diaryTemplateAutoSummary(
  AppLocalizations l10n,
  DiaryTemplateLibrary library,
) {
  final DiaryTemplatePrefs prefs = library.prefs;
  final auto = library.autoTemplate;
  final count = prefs.autoRules.length;
  final name = auto == null ? null : diaryTemplateDisplayName(l10n, auto);
  if (count == 0) return name ?? l10n.diaryTemplatesAutoApplyNone;
  if (name == null) return l10n.diaryTemplatesAutoApplyRulesSummary(count);
  return l10n.diaryTemplatesAutoApplyRulesAndDefault(count, name);
}
