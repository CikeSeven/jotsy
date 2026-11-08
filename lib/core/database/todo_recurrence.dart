import 'dart:math' as math;

import 'package:tyme/tyme.dart';

import 'todo_rules.dart';

/// 待办重复规则的日期推算（纯函数，无 IO、不读时钟）。
///
/// 输入：[TodoRepeatRule]（起点、频率、间隔等）与参照日期；输出：本地零点的
/// `DateTime`。内部一律用 UTC 零点做日期加减——本地时间在夏令时切换的那天
/// 只有 23 或 25 小时，按 `Duration(days: 1)` 加减会落到前一天的 23 点；
/// 结果再按年月日转回本地零点。
///
/// 一串重复由起点 [TodoRepeatRule.anchor] 生成：起点之前没有任何一次；几号、
/// 第几个星期几、几月几日都以起点为准（见 [TodoRepeatRule] 的说明）。
abstract final class TodoRecurrence {
  /// [after] 之后（不含当天）按规则排定的第一次；串已过 [TodoRepeatRule.until]
  /// 时为 null。不考虑 [TodoRepeatRule.count]（次数由调用方按已完成次数判断）。
  static DateTime? nextAfter(TodoRepeatRule rule, DateTime after) {
    final start = _utcDay(rule.anchor);
    var target = _utcDay(after).add(const Duration(days: 1));
    if (target.isBefore(start)) target = start;
    final candidate = _firstOnOrAfter(rule, start, target);
    if (candidate == null) return null;
    final until = rule.until;
    if (until != null && candidate.isAfter(_utcDay(until))) return null;
    return _local(candidate);
  }

  /// [day] 是否恰好是这串里的一次。
  static bool isOccurrence(TodoRepeatRule rule, DateTime day) {
    final previous = DateTime(day.year, day.month, day.day - 1);
    final next = nextAfter(rule, previous);
    return next != null && _sameDay(next, day);
  }

  /// [from] 到 [to]（都含当天）之间的各次，至多 [limit] 次。
  static List<DateTime> occurrencesBetween(
    TodoRepeatRule rule,
    DateTime from,
    DateTime to, {
    int limit = 400,
  }) {
    final result = <DateTime>[];
    final end = _utcDay(to);
    var cursor = DateTime(from.year, from.month, from.day - 1);
    while (result.length < limit) {
      final next = nextAfter(rule, cursor);
      if (next == null || _utcDay(next).isAfter(end)) break;
      result.add(next);
      cursor = next;
    }
    return result;
  }

  /// 完成一次后的下一个截止日；这串已经结束（次数用完或超过截止日期）时
  /// 为 null。
  ///
  /// - 按截止日（[TodoRepeatBasis.due]）：取“当前截止日与完成当天两者中较晚
  ///   的那天”之后排定的第一次。逾期了几周才完成时直接跳到今天之后，不必
  ///   把错过的几次一次次勾掉；提前完成时跳到当前这次之后的那一次。
  /// - 按完成日（[TodoRepeatBasis.completion]）：从完成当天起加一个间隔；
  ///   每周重复不看选定的星期几，法定工作日取完成之后的第一个工作日。
  ///
  /// [doneCount] 是包括这一次在内已经完成的次数。
  static DateTime? nextDueAfterCompletion(
    TodoRepeatRule rule, {
    required DateTime currentDue,
    required DateTime completedOn,
    required int doneCount,
  }) {
    final count = rule.count;
    if (count != null && doneCount >= count) return null;
    final DateTime? next;
    switch (rule.basis) {
      case TodoRepeatBasis.due:
        final from = completedOn.isAfter(currentDue) ? completedOn : currentDue;
        next = nextAfter(rule, from);
      case TodoRepeatBasis.completion:
        next = _stepFromCompletion(rule, _utcDay(completedOn));
    }
    if (next == null) return null;
    final until = rule.until;
    if (until != null && _utcDay(next).isAfter(_utcDay(until))) return null;
    return next;
  }

  /// [day] 是否为法定工作日：有法定安排时以安排为准（放假日不上班、调休的
  /// 周末上班），否则周一到周五。tyme 只收录到依赖发布时已公布的年份，之后
  /// 的日子按普通周一到周五。
  static bool isLegalWorkday(DateTime day) {
    final holiday = LegalHoliday.fromYmd(day.year, day.month, day.day);
    if (holiday != null) return holiday.isWork();
    return day.weekday <= DateTime.friday;
  }

  static DateTime? _firstOnOrAfter(
    TodoRepeatRule rule,
    DateTime start,
    DateTime target,
  ) {
    final interval = math.max(1, rule.interval);
    switch (rule.frequency) {
      case TodoRepeatFrequency.daily:
        final diff = target.difference(start).inDays;
        final steps = (diff + interval - 1) ~/ interval;
        return start.add(Duration(days: steps * interval));
      case TodoRepeatFrequency.weekly:
        final days = rule.weekdays.isEmpty
            ? <int>[start.weekday]
            : rule.weekdays;
        final firstWeek = _weekStart(start);
        final weeksDiff = _weekStart(target).difference(firstWeek).inDays ~/ 7;
        var k = weeksDiff ~/ interval;
        // 目标所在的那一周可能已经过了所有选定的星期几，再往后看一个间隔；
        // 最多看三轮就一定命中（每轮都包含至少一个选定日）。
        for (var round = 0; round < 3; round++, k++) {
          final week = firstWeek.add(Duration(days: k * interval * 7));
          for (final weekday in days) {
            final candidate = week.add(Duration(days: weekday - 1));
            if (!candidate.isBefore(target) && !candidate.isBefore(start)) {
              return candidate;
            }
          }
        }
        return null;
      case TodoRepeatFrequency.monthly:
        final monthsDiff =
            (target.year - start.year) * 12 + target.month - start.month;
        var k = math.max(0, monthsDiff ~/ interval);
        for (var round = 0; round < 3; round++, k++) {
          final total = start.month - 1 + k * interval;
          final candidate = _monthlyIn(
            rule,
            start.year + total ~/ 12,
            total % 12 + 1,
          );
          if (!candidate.isBefore(target) && !candidate.isBefore(start)) {
            return candidate;
          }
        }
        return null;
      case TodoRepeatFrequency.yearly:
        var k = math.max(0, (target.year - start.year) ~/ interval);
        for (var round = 0; round < 3; round++, k++) {
          final year = start.year + k * interval;
          final candidate = DateTime.utc(
            year,
            start.month,
            math.min(start.day, _daysInMonth(year, start.month)),
          );
          if (!candidate.isBefore(target)) return candidate;
        }
        return null;
      case TodoRepeatFrequency.legalWorkdays:
        // 最长的假期加调休也不会连续超过两周没有工作日；留足余量。
        for (var i = 0; i < 60; i++) {
          final candidate = target.add(Duration(days: i));
          if (isLegalWorkday(candidate)) return candidate;
        }
        return null;
    }
  }

  static DateTime _monthlyIn(TodoRepeatRule rule, int year, int month) {
    final anchor = rule.anchor;
    final days = _daysInMonth(year, month);
    switch (rule.monthlyMode) {
      case TodoMonthlyMode.dayOfMonth:
        return DateTime.utc(year, month, math.min(anchor.day, days));
      case TodoMonthlyMode.lastDay:
        return DateTime.utc(year, month, days);
      case TodoMonthlyMode.weekdayOrdinal:
        final ordinal = (anchor.day - 1) ~/ 7 + 1;
        final first = DateTime.utc(year, month, 1);
        final offset = (anchor.weekday - first.weekday + 7) % 7;
        var day = 1 + offset + (ordinal - 1) * 7;
        // “第五个星期几”在这个月不存在时取最后一个。
        while (day > days) {
          day -= 7;
        }
        return DateTime.utc(year, month, day);
    }
  }

  static DateTime? _stepFromCompletion(TodoRepeatRule rule, DateTime done) {
    final interval = math.max(1, rule.interval);
    switch (rule.frequency) {
      case TodoRepeatFrequency.daily:
        return _local(done.add(Duration(days: interval)));
      case TodoRepeatFrequency.weekly:
        return _local(done.add(Duration(days: interval * 7)));
      case TodoRepeatFrequency.monthly:
        final total = done.month - 1 + interval;
        final year = done.year + total ~/ 12;
        final month = total % 12 + 1;
        return DateTime(
          year,
          month,
          math.min(done.day, _daysInMonth(year, month)),
        );
      case TodoRepeatFrequency.yearly:
        final year = done.year + interval;
        return DateTime(
          year,
          done.month,
          math.min(done.day, _daysInMonth(year, done.month)),
        );
      case TodoRepeatFrequency.legalWorkdays:
        for (var i = 1; i <= 60; i++) {
          final candidate = done.add(Duration(days: i));
          if (isLegalWorkday(candidate)) return _local(candidate);
        }
        return null;
    }
  }

  static DateTime _utcDay(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  static DateTime _local(DateTime utcDay) =>
      DateTime(utcDay.year, utcDay.month, utcDay.day);

  static DateTime _weekStart(DateTime utcDay) =>
      utcDay.subtract(Duration(days: utcDay.weekday - DateTime.monday));

  static int _daysInMonth(int year, int month) =>
      DateTime.utc(year, month + 1, 0).day;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
