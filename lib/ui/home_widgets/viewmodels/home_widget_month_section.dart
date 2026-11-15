// 快照的「心情月历」一节：这个月与前 [kHomeWidgetMonthsBack] 个月，每天的心情段、
// 是否写过、法定节假日；外加一周从哪天开始与星期的窄写法。
//
// 心情的口径与日历年视图一致（`CalendarYearPalette`）：长按日期记下的“这天的
// 心情”优先（五档即五段），否则取当天日记心情的平均折成五段；写了日记但没选
// 心情记为 -1。私密日记不在打点查询里，连“这天写过”都不会透露。
//
// 网格本身由原生按本机日期排（哪天是今天、这个月从星期几开始），跨月零点后
// 新的一个月不在快照里时，原生只画日期、不画心情与打点，等应用下次同步。

import 'package:flutter/material.dart' show DateUtils;
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../calendar/models/calendar_display_options.dart';
import '../../calendar/viewmodels/calendar_day_summary.dart';
import '../../calendar/viewmodels/calendar_holiday_day.dart';
import '../../widgets/mood_band_palette.dart';

/// 除了这个月，再往前带几个月（小组件上可以往回翻）。
const int kHomeWidgetMonthsBack = 2;

/// 心情月历要读的日期范围：往前 [kHomeWidgetMonthsBack] 个月的月初，到下个月
/// 月初。
(DateTime, DateTime) homeWidgetMonthRange(DateTime now) => (
  DateTime(now.year, now.month - kHomeWidgetMonthsBack),
  DateTime(now.year, now.month + 1),
);

/// 一周的第一天（[DateTime.weekday]）：日历设置里选了周一 / 周日就照它，跟随
/// 语言时取该语言的习惯（与 MaterialLocalizations 同一份 intl 数据）。
int homeWidgetFirstWeekday(CalendarWeekStart weekStart, String localeName) =>
    switch (weekStart) {
      CalendarWeekStart.monday => DateTime.monday,
      CalendarWeekStart.sunday => DateTime.sunday,
      // intl 的 FIRSTDAYOFWEEK：0 为周一 … 6 为周日。
      CalendarWeekStart.locale =>
        DateFormat.E(localeName).dateSymbols.FIRSTDAYOFWEEK + 1,
    };

Map<String, Object?> buildHomeWidgetMonthSection({
  required DateTime now,
  required AppLocalizations l10n,
  required List<DiaryCalendarMarker> markers,
  required Map<String, DayMood> dayMoods,
  required List<String> moodOptions,
  required CalendarWeekStart weekStart,
}) {
  final summaries = CalendarDaySummary.groupByDay(
    markers,
    now: now,
    moodOptions: moodOptions,
  );
  final months = <String, Object?>{};
  for (var back = kHomeWidgetMonthsBack; back >= 0; back--) {
    final month = DateTime(now.year, now.month - back);
    months[_monthKey(month)] = _month(month, l10n, summaries, dayMoods);
  }
  final narrow = DateFormat('ccccc', l10n.localeName);
  return <String, Object?>{
    'firstWeekday': homeWidgetFirstWeekday(weekStart, l10n.localeName),
    // 周一到周日的窄写法（2024-01-01 是周一）。
    'weekdays': <String>[
      for (var i = 0; i < 7; i++) narrow.format(DateTime(2024, 1, 1 + i)),
    ],
    'months': months,
  };
}

String _monthKey(DateTime month) =>
    '${month.year.toString().padLeft(4, '0')}-'
    '${month.month.toString().padLeft(2, '0')}';

Map<String, Object?> _month(
  DateTime month,
  AppLocalizations l10n,
  Map<DateTime, CalendarDaySummary> summaries,
  Map<String, DayMood> dayMoods,
) {
  final days = <String, Object?>{};
  var written = 0;
  final count = DateUtils.getDaysInMonth(month.year, month.month);
  for (var d = 1; d <= count; d++) {
    final day = DateTime(month.year, month.month, d);
    final summary = summaries[day];
    final dayMood =
        dayMoods['${_monthKey(month)}-${d.toString().padLeft(2, '0')}'];
    final hasEntries = summary != null && summary.hasEntries;
    if (hasEntries) written++;
    final band = switch ((dayMood, summary?.averageMoodWeight)) {
      (final DayMood mood, _) => mood.index,
      (null, final int weight) => MoodBandPalette.bandForWeight(weight),
      _ => hasEntries ? -1 : null,
    };
    final holiday = CalendarHolidayDay.of(day);
    if (band == null && !hasEntries && holiday == null) continue;
    days['$d'] = <String, Object?>{
      'b': ?band,
      if (hasEntries) 'w': 1,
      if (holiday != null) ...<String, Object?>{
        'h': holiday.isWork
            ? l10n.calendarHolidayWorkMark
            : l10n.calendarHolidayRestMark,
        'hw': holiday.isWork,
      },
    };
  }
  return <String, Object?>{
    'title': l10n.isZh
        ? '${month.year}年${month.month}月'
        : DateFormat.yMMMM(l10n.localeName).format(month),
    'writtenLabel': l10n.homeWidgetMonthWrittenDays(written),
    'days': days,
  };
}
