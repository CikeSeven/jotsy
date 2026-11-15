// 快照「写作统计」一节怎么取数：从热力图起点（或今年 1 月 1 日）到今天的日历打点，
// 连续记录数到了查询起点时再往前补查，直到断开（最多再往前 [_maxExtraYears] 年）。
// 组装见 home_widget_stats_section.dart。

import 'home_widget_data_source.dart';
import 'home_widget_month_section.dart';
import 'home_widget_snapshot_input.dart';
import 'home_widget_stats_section.dart';

/// 连续记录最多再往前补查几年：连续写了十几年的人，小组件显示这个上限也无妨。
const int _maxExtraYears = 10;

Future<Map<String, Object?>> buildHomeWidgetStats(
  HomeWidgetDataSource data,
  HomeWidgetSnapshotInput input,
) async {
  final now = input.now;
  final firstWeekday = homeWidgetFirstWeekday(
    input.weekStart,
    input.l10n.localeName,
  );
  var start = homeWidgetStatsStart(now, firstWeekday);
  final markers = await data.markersBetween(
    start,
    DateTime(now.year, now.month, now.day + 1),
  );
  final written = homeWidgetWrittenDays(markers, now);
  var streak = homeWidgetStreak(written, now);
  for (var year = 0; year < _maxExtraYears && _reaches(streak, start); year++) {
    final earlier = DateTime(start.year - 1, start.month, start.day);
    written.addAll(
      homeWidgetWrittenDays(await data.markersBetween(earlier, start), now),
    );
    start = earlier;
    streak = homeWidgetStreak(written, now);
  }
  return buildHomeWidgetStatsSection(
    now: now,
    l10n: input.l10n,
    markers: markers,
    firstWeekday: firstWeekday,
    streak: streak,
  );
}

/// 连续记录是否一直数到了查询起点（再往前可能还连着）。
bool _reaches((int, DateTime?) streak, DateTime start) {
  final (days, end) = streak;
  if (end == null) return false;
  final first = DateTime(end.year, end.month, end.day - days + 1);
  return !first.isAfter(start);
}
