import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../calendar/viewmodels/calendar_lunar_day.dart';
import '../viewmodels/anniversary_calendar.dart';
import '../viewmodels/anniversary_calendar_index.dart';
import '../viewmodels/anniversary_rule.dart';

/// 纪念日的展示文案与图标（日历卡片、列表、详情共用），保证各处说法一致。
abstract final class AnniversaryLabels {
  /// 重复的用心形，只记一天的用旗子。
  static FaIconData iconFor(AnniversaryRule rule) =>
      rule.repeats ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.solidFlag;

  /// 选中日卡片的副标题：这一次是什么（第几周年 / 开始那天 / 倒数），农历
  /// 规则再附上这一年实际的农历日期（顺延后的那天）。
  static String dayLine(
    AppLocalizations l10n,
    AnniversaryDayMark mark,
    DateTime today,
  ) {
    final occurrence = mark.occurrence;
    final rule = mark.rule;
    final String main;
    if (!rule.repeats) {
      final days = AnniversaryCalendar.daysBetween(today, occurrence.date);
      main = days > 0
          ? l10n.anniversaryCountdownLabel
          : days == 0
          ? l10n.anniversaryIsToday
          : l10n.anniversaryDaysSince(-days);
    } else if (occurrence.ordinal == 0) {
      main = l10n.anniversaryBaseDay;
    } else if (DateUtils.isSameDay(occurrence.date, today)) {
      main = l10n.anniversaryTodayOrdinal(occurrence.ordinal);
    } else {
      main = l10n.anniversaryOrdinal(occurrence.ordinal);
    }
    if (rule.recurrence != AnniversaryRecurrence.lunarYearly) {
      return main;
    }
    final lunar = CalendarLunarDay.of(occurrence.date);
    return '$main · ${l10n.calendarLunarDate(lunar.date)}';
  }

  /// 重复规则的名称（每年 / 农历每年 / 不重复）。
  static String ruleName(
    AppLocalizations l10n,
    AnniversaryRecurrence recurrence,
  ) {
    return switch (recurrence) {
      AnniversaryRecurrence.solarYearly => l10n.anniversaryRepeatSolar,
      AnniversaryRecurrence.lunarYearly => l10n.anniversaryRepeatLunar,
      AnniversaryRecurrence.once => l10n.anniversaryRepeatOnce,
    };
  }
}
