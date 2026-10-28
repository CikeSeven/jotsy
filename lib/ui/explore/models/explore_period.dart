import 'package:flutter/foundation.dart';

/// 探索页的统计范围（页面顶部的范围条，及周期回顾的周期）。持久化存的是
/// 枚举名。
enum ExplorePeriod { week, month, year, all }

/// 一段本地日期：[start] 当天零点起（含），[end] 零点止（不含）。
///
/// 日界一律用日期构造（`DateTime(y, m, d + n)`），不加 24 小时，夏令时切换日
/// 仍按本地日期分界。
@immutable
class ExploreDateRange {
  const ExploreDateRange(this.start, this.end);

  final DateTime start;
  final DateTime end;

  /// [local] 为本地时间。
  bool contains(DateTime local) =>
      !local.isBefore(start) && local.isBefore(end);

  @override
  bool operator ==(Object other) =>
      other is ExploreDateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'ExploreDateRange($start, $end)';
}

/// [period] 在 [now]（本地）所在的那一段；[ExplorePeriod.all] 为 null（不限）。
/// [firstWeekday] 为每周第一天（`DateTime.monday` … `DateTime.sunday`），与
/// 日历的每周起始日一致。
ExploreDateRange? explorePeriodRange(
  ExplorePeriod period,
  DateTime now, {
  required int firstWeekday,
}) {
  final today = DateTime(now.year, now.month, now.day);
  return switch (period) {
    ExplorePeriod.week => () {
      final offset = (today.weekday - firstWeekday + 7) % 7;
      final start = DateTime(today.year, today.month, today.day - offset);
      return ExploreDateRange(
        start,
        DateTime(start.year, start.month, start.day + 7),
      );
    }(),
    ExplorePeriod.month => ExploreDateRange(
      DateTime(today.year, today.month),
      DateTime(today.year, today.month + 1),
    ),
    ExplorePeriod.year => ExploreDateRange(
      DateTime(today.year),
      DateTime(today.year + 1),
    ),
    ExplorePeriod.all => null,
  };
}

/// [range]（[period] 的一段）的上一段：上一周、上个月、去年。
ExploreDateRange explorePreviousRange(
  ExplorePeriod period,
  ExploreDateRange range,
) {
  final start = range.start;
  return switch (period) {
    ExplorePeriod.week => ExploreDateRange(
      DateTime(start.year, start.month, start.day - 7),
      start,
    ),
    ExplorePeriod.month => ExploreDateRange(
      DateTime(start.year, start.month - 1),
      start,
    ),
    ExplorePeriod.year ||
    ExplorePeriod.all => ExploreDateRange(DateTime(start.year - 1), start),
  };
}
