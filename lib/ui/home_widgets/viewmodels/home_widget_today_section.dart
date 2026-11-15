// 快照的「今日」一节：从今天起 [kHomeWidgetDayHorizon] 天，每天的日期文字、
// 农历、节气 / 节日、法定节假日与到这天为止还有几项待办。
//
// 为什么逐日算好而不是只给今天：应用不在运行时零点照样要翻页（原生按排好
// 的刷新时刻重画，见 `HomeWidgetSyncController`），原生只按本机日期挑出
// 这一天的一项，不做农历换算与复数。超出这段天数（应用很久没打开）时原生
// 只显示公历日期与星期，不显示过期的内容。
//
// 字数只给今天：之后的日子在应用打开之前不可能有新写的日记，原生找不到
// 就显示“还没写”。

import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart' show DayMood;
import '../../../l10n/app_localizations.dart';
import '../../calendar/viewmodels/calendar_holiday_day.dart';
import '../../calendar/viewmodels/calendar_lunar_day.dart';
import '../../todos/widgets/todo_labels.dart';

/// 逐日预算的天数（含今天）。两周足够覆盖一次长假不开应用。
const int kHomeWidgetDayHorizon = 14;

/// 快照里的日期键（`YYYY-MM-DD`，按本机日期）；原生 `WidgetDates.key` 同口径。
String homeWidgetDayKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// 构建「今日」一节。[todoDueDates] 为未完成待办的截止日（null 为没有
/// 截止日，不计入任何一天）；[todayWords] 为今天写下的字数；[dayMoods] 为
/// 这天的心情（只取预算范围内的日子，今日小组件的心情脸据此高亮）。
Map<String, Object?> buildHomeWidgetTodaySection({
  required DateTime now,
  required AppLocalizations l10n,
  required List<String?> todoDueDates,
  required int todayWords,
  Map<String, DayMood> dayMoods = const <String, DayMood>{},
}) {
  final today = DateTime(now.year, now.month, now.day);
  final dueKeys = <String>[
    for (final due in todoDueDates)
      if (due != null) due,
  ]..sort();
  final days = <String, Object?>{};
  for (var offset = 0; offset < kHomeWidgetDayHorizon; offset++) {
    final day = DateTime(today.year, today.month, today.day + offset);
    final key = homeWidgetDayKey(day);
    // 截到这天为止（含逾期）还没完成的待办数；日期键按字典序就是时间序。
    var todos = 0;
    for (final due in dueKeys) {
      if (due.compareTo(key) > 0) break;
      todos++;
    }
    days[key] = _day(day, l10n, todos);
  }
  return <String, Object?>{
    'days': days,
    'words': <String, Object?>{
      if (todayWords > 0) homeWidgetDayKey(today): todayWords,
    },
    'wordsLabel': <String, Object?>{
      if (todayWords > 0)
        homeWidgetDayKey(today): l10n.homeWidgetTodayWords(todayWords),
    },
    'moods': <String, Object?>{
      for (final key in days.keys)
        if (dayMoods[key] case final DayMood mood) key: mood.name,
    },
  };
}

Map<String, Object?> _day(DateTime day, AppLocalizations l10n, int todos) {
  final lunar = CalendarLunarDay.of(day);
  final holiday = CalendarHolidayDay.of(day);
  // 节日优先于节气：除夕、春节这样的日子比恰逢的节气更值得一眼看到。
  final almanac = lunar.festivals.isNotEmpty
      ? lunar.festivals.first
      : lunar.term;
  return <String, Object?>{
    'weekday': TodoLabels.weekdayName(l10n, day.weekday, short: false),
    'weekdayShort': TodoLabels.weekdayName(l10n, day.weekday),
    'monthDay': l10n.formatMonthDay(day),
    'month': l10n.isZh
        ? '${day.month}月'
        : DateFormat.MMMM(l10n.localeName).format(day),
    'lunar': lunar.date,
    'almanac': ?almanac,
    if (holiday != null)
      'holiday': <String, Object?>{
        'mark': holiday.isWork
            ? l10n.calendarHolidayWorkMark
            : l10n.calendarHolidayRestMark,
        'name': holiday.name,
        'work': holiday.isWork,
      },
    'todos': todos,
    'todosLabel': todos > 0
        ? l10n.homeWidgetTodayTodos(todos)
        : l10n.homeWidgetTodayNoTodos,
  };
}
