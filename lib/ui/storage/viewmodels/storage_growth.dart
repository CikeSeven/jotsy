import 'dart:math' as math;

import '../../../core/services/storage/storage_usage_models.dart';

/// 媒体按日记日期（[StorageMediaEntry.displayDate]）新增多少的序列，总览页
/// “媒体增长”柱状图用（纯函数）。
///
/// 全部日期都在最近 12 个月里时按月（固定 12 根柱，没有的月份为 0，看得出
/// 节奏）；否则按年，最多最近 [maxYears] 年（年份连续，没有的年份为 0）。
/// 没有媒体时为 null。
class StorageGrowthSeries {
  const StorageGrowthSeries({required this.yearly, required this.points});

  static const int maxYears = 8;

  final bool yearly;

  /// 每段的起点（年初或月初）与这段新增的字节，按时间先后。
  final List<({DateTime start, int bytes})> points;

  /// 新增最多的一段；全为 0 时为 null。
  int? get peakIndex {
    int? index;
    var peak = 0;
    for (var i = 0; i < points.length; i++) {
      if (points[i].bytes > peak) {
        peak = points[i].bytes;
        index = i;
      }
    }
    return index;
  }

  static StorageGrowthSeries? of(List<StorageMediaEntry> media, DateTime now) {
    if (media.isEmpty) return null;
    final firstMonth = DateTime(now.year, now.month - 11);
    final monthly = media.every(
      (entry) => !entry.displayDate.isBefore(firstMonth),
    );
    if (monthly) {
      final bytes = List<int>.filled(12, 0);
      for (final entry in media) {
        final date = entry.displayDate;
        final index =
            (date.year - firstMonth.year) * 12 + date.month - firstMonth.month;
        if (index >= 0 && index < 12) bytes[index] += entry.bytes;
      }
      return StorageGrowthSeries(
        yearly: false,
        points: [
          for (var i = 0; i < 12; i++)
            (
              start: DateTime(firstMonth.year, firstMonth.month + i),
              bytes: bytes[i],
            ),
        ],
      );
    }
    final byYear = <int, int>{};
    for (final entry in media) {
      final year = entry.displayDate.year;
      byYear[year] = (byYear[year] ?? 0) + entry.bytes;
    }
    final last = byYear.keys.reduce(math.max);
    final first = math.max(byYear.keys.reduce(math.min), last - maxYears + 1);
    return StorageGrowthSeries(
      yearly: true,
      points: [
        for (var year = first; year <= last; year++)
          (start: DateTime(year), bytes: byYear[year] ?? 0),
      ],
    );
  }
}
