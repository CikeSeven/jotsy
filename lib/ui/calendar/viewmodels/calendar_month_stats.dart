import 'package:flutter/material.dart';

import '../../../core/services/settings_service.dart';
import 'calendar_day_summary.dart';

/// 日历月度（年视图下为年度）概览数据。
///
/// 输入：当前翻到的月份的逐日汇总（[CalendarDaySummary]）、当前时刻与心情
/// 配置；输出概览条要显示的数字。纯计算，无副作用。
///
/// 与探索页的分工：探索页统计全部时间或近 30 天，这里只统计日历当前翻到的
/// 那个月，随翻月变化；未解封的时间胶囊已在逐日汇总中排除。
@immutable
class CalendarMonthStats {
  const CalendarMonthStats({
    required this.entryCount,
    required this.recordedDays,
    required this.elapsedDays,
    required this.charCount,
    required this.dominantMood,
    required this.longestStreak,
  });

  /// 统计 [month] 所在月份。
  factory CalendarMonthStats.compute(
    Map<DateTime, CalendarDaySummary> summaries, {
    required DateTime month,
    required DateTime now,
    required List<String> moodOptions,
  }) {
    return CalendarMonthStats.computeRange(
      summaries,
      start: DateTime(month.year, month.month),
      end: DateTime(month.year, month.month + 1),
      now: now,
      moodOptions: moodOptions,
    );
  }

  /// 统计 `[start, end)` 内的逐日汇总（年视图统计整年）。
  factory CalendarMonthStats.computeRange(
    Map<DateTime, CalendarDaySummary> summaries, {
    required DateTime start,
    required DateTime end,
    required DateTime now,
    required List<String> moodOptions,
  }) {
    final rangeStart = DateUtils.dateOnly(start);
    final today = DateUtils.dateOnly(now);

    var entryCount = 0;
    var charCount = 0;
    var recordedDays = 0;
    var longestStreak = 0;
    var currentStreak = 0;
    final moodCounts = <int, int>{};
    final moodLastSeen = <int, int>{};
    var moodOrder = 0;

    var totalDays = 0;
    // 逐日用日期构造而不是累加 24 小时，跨夏令时也不会漏日或重日。
    for (
      var day = rangeStart;
      day.isBefore(end);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      totalDays += 1;
      final summary = summaries[day];
      if (summary == null || !summary.hasEntries) {
        currentStreak = 0;
        continue;
      }
      entryCount += summary.entryCount;
      charCount += summary.charCount;
      recordedDays += 1;
      currentStreak += 1;
      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
      }
      for (final mood in summary.moods) {
        final weight = SettingsService.moodWeight(mood, moodOptions);
        if (weight == null) {
          continue;
        }
        moodCounts[weight] = (moodCounts[weight] ?? 0) + 1;
        moodLastSeen[weight] = moodOrder++;
      }
    }

    // 最常出现的心情；次数相同时取最近出现的那个，更贴近“这个月过得怎样”。
    int? dominantWeight;
    for (final entry in moodCounts.entries) {
      final best = dominantWeight;
      if (best == null ||
          entry.value > moodCounts[best]! ||
          (entry.value == moodCounts[best]! &&
              moodLastSeen[entry.key]! > moodLastSeen[best]!)) {
        dominantWeight = entry.key;
      }
    }

    final int? elapsedDays;
    if (rangeStart.isAfter(today)) {
      elapsedDays = null;
    } else if (today.isBefore(end)) {
      // 区间包含今天：从区间第一天数到今天（含）。
      // 本地零点相减再四舍五入：跨夏令时的 23/25 小时日不会少算一天。
      elapsedDays = (today.difference(rangeStart).inHours / 24).round() + 1;
    } else {
      elapsedDays = totalDays;
    }

    return CalendarMonthStats(
      entryCount: entryCount,
      recordedDays: recordedDays,
      elapsedDays: elapsedDays,
      charCount: charCount,
      dominantMood: dominantWeight == null
          ? null
          : SettingsService.moodForWeight(dominantWeight, moodOptions),
      longestStreak: longestStreak,
    );
  }

  final int entryCount;
  final int recordedDays;

  /// 区间内已经过去的天数（含今天）：包含今天的区间数到今天，过去的区间为
  /// 总天数，未来的区间为 null（不显示“已记录/已过去”的分母）。
  final int? elapsedDays;
  final int charCount;
  final String? dominantMood;

  /// 本月内最长的连续记录天数。
  final int longestStreak;

  bool get isEmpty => entryCount == 0;

  @override
  bool operator ==(Object other) {
    return other is CalendarMonthStats &&
        other.entryCount == entryCount &&
        other.recordedDays == recordedDays &&
        other.elapsedDays == elapsedDays &&
        other.charCount == charCount &&
        other.dominantMood == dominantMood &&
        other.longestStreak == longestStreak;
  }

  @override
  int get hashCode => Object.hash(
    entryCount,
    recordedDays,
    elapsedDays,
    charCount,
    dominantMood,
    longestStreak,
  );
}
