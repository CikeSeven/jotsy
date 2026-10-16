import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import 'anniversary_calendar.dart';
import 'anniversary_rule.dart';

/// 相对今天的状态：还没到、就是今天、已经过去（只有不重复的会“过去”）。
enum AnniversaryPhase { upcoming, today, past }

/// 列表与详情页的倒数信息。
///
/// 输入：规则与今天；输出：下一次、距下一次的天数、距首次的天数。无副作用。
/// “已经 X 天”是今天减首次日期（首次当天为 0），与日历“N 天前”的口径一致。
@immutable
class AnniversaryCountdown {
  const AnniversaryCountdown._({
    required this.rule,
    required this.next,
    required this.daysUntilNext,
    required this.daysSinceBase,
  });

  factory AnniversaryCountdown.of(AnniversaryRule rule, DateTime today) {
    final next = AnniversaryCalendar.next(rule, today);
    return AnniversaryCountdown._(
      rule: rule,
      next: next,
      daysUntilNext: next == null
          ? null
          : AnniversaryCalendar.daysBetween(today, next.date),
      daysSinceBase: AnniversaryCalendar.daysBetween(rule.base, today),
    );
  }

  final AnniversaryRule rule;

  /// 今天或之后的下一次；不重复且已过去时为 null。
  final AnniversaryOccurrence? next;

  /// 距下一次的天数，今天为 0。
  final int? daysUntilNext;

  /// 距首次的天数：首次在过去为正，在未来为负。
  final int daysSinceBase;

  AnniversaryPhase get phase {
    final days = daysUntilNext;
    if (days == null) {
      return AnniversaryPhase.past;
    }
    return days == 0 ? AnniversaryPhase.today : AnniversaryPhase.upcoming;
  }

  /// 列表顺序：置顶在前；其余按下一次由近到远，已过去的倒数日排最后（最近
  /// 过去的在前）；同一天按名称，保证顺序稳定。
  static int compareForList(
    (Anniversary, AnniversaryCountdown) a,
    (Anniversary, AnniversaryCountdown) b,
  ) {
    final (rowA, countdownA) = a;
    final (rowB, countdownB) = b;
    if (rowA.isPinned != rowB.isPinned) {
      return rowA.isPinned ? -1 : 1;
    }
    final nextA = countdownA.next;
    final nextB = countdownB.next;
    if (nextA != null && nextB != null) {
      final byDate = nextA.date.compareTo(nextB.date);
      if (byDate != 0) return byDate;
    } else if (nextA != null || nextB != null) {
      return nextA != null ? -1 : 1;
    } else {
      final byBase = countdownB.rule.base.compareTo(countdownA.rule.base);
      if (byBase != 0) return byBase;
    }
    return rowA.title.compareTo(rowB.title);
  }
}
