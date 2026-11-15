// 快照的「纪念日」一节：全部纪念日按列表顺序（置顶在前，再按下一次的远近，
// 与纪念日列表同一口径 `AnniversaryCountdown.compareForList`），每个带上接下来
// [kHomeWidgetAnniversaryOccurrences] 次的日子与文字。
//
// 为什么给日子而不是给天数：天数由原生按本机日期现算（应用不在运行时日子照样
// 过，零点重画后就对），农历换算、顺延规则与第几周年这些只有 Dart 会的部分
// 在这里算好。接下来几次都用完（应用两三年没打开）时原生改显示“已经 N 天”。
//
// 纪念日不是日记内容：应用锁开着也照常显示；关联的日记不进快照。

import 'package:flutter/material.dart' show DateUtils;

import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../anniversaries/viewmodels/anniversary_calendar.dart';
import '../../anniversaries/viewmodels/anniversary_countdown.dart';
import '../../anniversaries/viewmodels/anniversary_rule.dart';
import 'home_widget_today_section.dart';

/// 每个纪念日带上的未来次数：每年一次的纪念日覆盖两年以上。
const int kHomeWidgetAnniversaryOccurrences = 3;

List<Map<String, Object?>> buildHomeWidgetAnniversaries({
  required DateTime now,
  required AppLocalizations l10n,
  required List<Anniversary> rows,
}) {
  final today = DateUtils.dateOnly(now);
  final items = <(Anniversary, AnniversaryCountdown)>[
    for (final row in rows)
      if (AnniversaryRule.fromRow(row) case final AnniversaryRule rule)
        (row, AnniversaryCountdown.of(rule, today)),
  ]..sort(AnniversaryCountdown.compareForList);
  return <Map<String, Object?>>[
    for (final (row, countdown) in items)
      _item(row, countdown.rule, today, l10n),
  ];
}

Map<String, Object?> _item(
  Anniversary row,
  AnniversaryRule rule,
  DateTime today,
  AppLocalizations l10n,
) {
  final occurrences = <Map<String, Object?>>[];
  var from = today;
  for (var i = 0; i < kHomeWidgetAnniversaryOccurrences; i++) {
    final next = AnniversaryCalendar.next(rule, from);
    if (next == null) break;
    final ordinal = next.ordinal;
    occurrences.add(<String, Object?>{
      'date': homeWidgetDayKey(next.date),
      'dateLabel': l10n.formatEyebrowDate(next.date),
      if (ordinal > 0) 'ordinalLabel': l10n.anniversaryOrdinal(ordinal),
      'todayLabel': ordinal > 0
          ? l10n.anniversaryTodayOrdinal(ordinal)
          : l10n.anniversaryIsToday,
    });
    from = DateTime(next.date.year, next.date.month, next.date.day + 1);
  }
  final lunar = rule.lunar;
  return <String, Object?>{
    'id': row.anniversaryId,
    'title': row.title,
    'pinned': row.isPinned,
    'repeats': rule.repeats,
    'base': homeWidgetDayKey(rule.base),
    'baseLabel': l10n.formatFullDate(rule.base),
    if (lunar != null) 'lunar': l10n.calendarLunarDate(lunar.monthDayName),
    'occurrences': occurrences,
  };
}
