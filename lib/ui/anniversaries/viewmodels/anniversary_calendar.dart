import 'dart:math' as math;

import 'package:tyme/tyme.dart';

import '../../../core/database/app_database.dart';
import 'anniversary_rule.dart';

/// 纪念日的日期推算：某一年落在哪天、某段日期里有哪几次、下一次是哪天。
///
/// 输入：[AnniversaryRule] 与日期（只取年月日，本地零点）；输出：
/// [AnniversaryOccurrence]。无副作用，农历换算结果按年月日缓存。所有页面
/// 都经这里推算，不各自换算（AGENTS.md）。
///
/// 顺延规则（这一年没有对应的日子时）：
/// - 公历 2 月 29 日：平年取 2 月 28 日——仍在二月，不跨到三月；
/// - 农历闰月：当年没有这个闰月时取同名平月（闰四月初一 → 四月初一）；
///   平月的纪念日不会在同名闰月再过一次；
/// - 农历三十：当月只有 29 天时取廿九。
///
/// 周期：公历规则按公历年，农历规则按农历年。农历年与公历年错开——腊月的
/// 日子落在下一个公历年的一二月，按日期段查询时要从前一个农历年找起。
abstract final class AnniversaryCalendar {
  /// 规则在第 [cycle] 年（公历或农历年）的那一次；早于首次或不重复规则的
  /// 其他年份为 null。
  static AnniversaryOccurrence? inCycle(AnniversaryRule rule, int cycle) {
    final base = rule.base;
    switch (rule.recurrence) {
      case AnniversaryRecurrence.once:
        return cycle == base.year
            ? AnniversaryOccurrence(date: base, ordinal: 0)
            : null;
      case AnniversaryRecurrence.solarYearly:
        if (cycle < base.year) {
          return null;
        }
        if (cycle == base.year) {
          return AnniversaryOccurrence(date: base, ordinal: 0);
        }
        final leapDay = base.month == 2 && base.day == 29;
        final adjusted = leapDay && !_isLeapYear(cycle);
        return AnniversaryOccurrence(
          date: DateTime(cycle, base.month, adjusted ? 28 : base.day),
          ordinal: cycle - base.year,
          adjusted: adjusted,
        );
      case AnniversaryRecurrence.lunarYearly:
        final lunar = rule.lunar ?? LunarYmd.of(base);
        if (cycle < lunar.year) {
          return null;
        }
        // 首次那年直接用记下的日期：用户填的是哪天就是哪天。
        if (cycle == lunar.year) {
          return AnniversaryOccurrence(date: base, ordinal: 0);
        }
        final solar = _lunarToSolar(cycle, lunar.month, lunar.day);
        if (solar == null) {
          return null;
        }
        return AnniversaryOccurrence(
          date: solar.date,
          ordinal: cycle - lunar.year,
          adjusted: solar.adjusted,
        );
    }
  }

  /// 落在 [[start], [endExclusive]) 内的各次，按日期先后。
  static List<AnniversaryOccurrence> inRange(
    AnniversaryRule rule,
    DateTime start,
    DateTime endExclusive,
  ) {
    final from = _dateOnly(start);
    final until = _dateOnly(endExclusive);
    final firstCycle = rule.recurrence == AnniversaryRecurrence.lunarYearly
        ? from.year - 1
        : from.year;
    final result = <AnniversaryOccurrence>[];
    for (var cycle = firstCycle; cycle <= until.year; cycle++) {
      final occurrence = inCycle(rule, cycle);
      if (occurrence != null &&
          !occurrence.date.isBefore(from) &&
          occurrence.date.isBefore(until)) {
        result.add(occurrence);
      }
    }
    return result;
  }

  /// [from] 当天或之后的第一次；不重复且已经过去时为 null。
  static AnniversaryOccurrence? next(AnniversaryRule rule, DateTime from) {
    final day = _dateOnly(from);
    if (!rule.repeats) {
      return day.isAfter(rule.base)
          ? null
          : AnniversaryOccurrence(date: rule.base, ordinal: 0);
    }
    // 农历年可能还没过完上一年的腊月，从前一年找起；三个周期内必有一次。
    final firstCycle = math.max(
      rule.recurrence == AnniversaryRecurrence.lunarYearly
          ? day.year - 1
          : day.year,
      _baseCycle(rule),
    );
    for (var cycle = firstCycle; cycle <= firstCycle + 3; cycle++) {
      final occurrence = inCycle(rule, cycle);
      if (occurrence != null && !occurrence.date.isBefore(day)) {
        return occurrence;
      }
    }
    return null;
  }

  /// [today] 当天及之前的各次，由近到远，最多 [limit] 次（“历年这一天”）。
  static List<AnniversaryOccurrence> past(
    AnniversaryRule rule,
    DateTime today, {
    int limit = 100,
  }) {
    final day = _dateOnly(today);
    final result = <AnniversaryOccurrence>[];
    final baseCycle = _baseCycle(rule);
    for (var cycle = day.year; cycle >= baseCycle; cycle--) {
      final occurrence = inCycle(rule, cycle);
      if (occurrence != null && !occurrence.date.isAfter(day)) {
        result.add(occurrence);
        if (result.length >= limit) {
          break;
        }
      }
    }
    return result;
  }

  /// [from] 到 [to] 相隔的天数（[to] 在后为正）。按 UTC 日期相减，夏令时
  /// 切换日的 23/25 小时不会让结果差一天。
  static int daysBetween(DateTime from, DateTime to) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  static int _baseCycle(AnniversaryRule rule) =>
      rule.recurrence == AnniversaryRecurrence.lunarYearly
      ? (rule.lunar ?? LunarYmd.of(rule.base)).year
      : rule.base.year;

  static bool _isLeapYear(int year) =>
      (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// 换算缓存：日历翻页、列表排序会反复换算同一批农历日；满了整体清空，
  /// 与 CalendarLunarDay 一致。
  static const int _cacheLimit = 1024;
  static final Map<int, ({DateTime date, bool adjusted})?> _cache =
      <int, ({DateTime date, bool adjusted})?>{};

  /// 农历 [year] 年 [month]（负为闰月）月 [day] 日对应的公历日，按顺延规则
  /// 落到当年真实存在的一天；超出 tyme 支持范围时为 null。
  static ({DateTime date, bool adjusted})? _lunarToSolar(
    int year,
    int month,
    int day,
  ) {
    final key = year * 10000 + (month + 12) * 100 + day;
    if (_cache.containsKey(key)) {
      return _cache[key];
    }
    if (_cache.length >= _cacheLimit) {
      _cache.clear();
    }
    return _cache[key] = _convert(year, month, day);
  }

  static ({DateTime date, bool adjusted})? _convert(
    int year,
    int month,
    int day,
  ) {
    try {
      var adjusted = false;
      var targetMonth = month;
      if (month < 0 && LunarYear.fromYear(year).getLeapMonth() != -month) {
        targetMonth = -month;
        adjusted = true;
      }
      final dayCount = LunarMonth.fromYm(year, targetMonth).getDayCount();
      var targetDay = day;
      if (targetDay > dayCount) {
        targetDay = dayCount;
        adjusted = true;
      }
      final solar = LunarDay.fromYmd(
        year,
        targetMonth,
        targetDay,
      ).getSolarDay();
      return (
        date: DateTime(solar.getYear(), solar.getMonth(), solar.getDay()),
        adjusted: adjusted,
      );
    } on ArgumentError {
      return null;
    }
  }
}
