part of 'calendar_page.dart';

/// 范围统计区块：替换日历卡片底部的月度概览，标题行写起止日期与天数。
///
/// 统计口径与月度概览一致（[CalendarMonthStats.computeRange]，未解封胶囊
/// 不计，筛选同样生效）；范围可跨月跨年，打点经 [calendarRangeMarkersProvider] 按区间单独
/// 查询。改选终点时新区间的数据到达前沿用上一份打点，统计不会先清零再
/// 出现。
extension _CalendarPageRangeSection on _CalendarPageState {
  Widget _buildRangeSummary(
    CalendarRangeSelection range, {
    required CalendarMarkerFilter filter,
    required List<String> moodOptions,
    required DateTime now,
  }) {
    final markers = ref
        .watch(calendarRangeMarkersProvider((range.first, range.endExclusive)))
        .asData
        ?.value;
    if (markers != null) {
      _cachedRangeMarkers = markers;
    }
    final stats = CalendarMonthStats.computeRange(
      CalendarDaySummary.groupByDay(
        filter.apply(_cachedRangeMarkers, now: now),
        now: now,
        moodOptions: moodOptions,
      ),
      start: range.first,
      end: range.endExclusive,
      now: now,
      moodOptions: moodOptions,
    );
    return CalendarMonthSummary(
      stats: stats,
      isFuture: range.first.isAfter(DateUtils.dateOnly(now)),
      period: CalendarSummaryPeriod.range,
      header: CalendarRangeHeader(
        range: range,
        now: now,
        onExit: _controller.exitRange,
      ),
    );
  }
}
