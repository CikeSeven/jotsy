import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import 'anniversary_calendar.dart';
import 'anniversary_rule.dart';

/// 某一天的一条纪念日：哪一条、第几次。
@immutable
class AnniversaryDayMark {
  const AnniversaryDayMark({
    required this.row,
    required this.rule,
    required this.occurrence,
  });

  final Anniversary row;
  final AnniversaryRule rule;
  final AnniversaryOccurrence occurrence;
}

/// 日历网格用的“某天有哪些纪念日”索引。
///
/// 输入：全部纪念日（保持 `watchAnniversaries` 的顺序：置顶在前、再按创建
/// 先后，同一天有几条时日期格写第一条）；输出：按日查询的结果。
///
/// 按自然月懒建桶：一页月视图 42 格只需推算一两个月，每格是一次查表；格外
/// 日期与左右滑动时露出的相邻月份各自命中自己月份的桶，结果总是正确的。
/// 实例随纪念日列表变化整体重建，桶不需要失效逻辑。
class AnniversaryCalendarIndex {
  AnniversaryCalendarIndex(List<Anniversary> rows)
    : _entries = <(Anniversary, AnniversaryRule)>[
        for (final row in rows)
          if (AnniversaryRule.fromRow(row) case final rule?) (row, rule),
      ];

  static final AnniversaryCalendarIndex empty = AnniversaryCalendarIndex(
    const <Anniversary>[],
  );

  final List<(Anniversary, AnniversaryRule)> _entries;
  final Map<int, Map<int, List<AnniversaryDayMark>>> _months =
      <int, Map<int, List<AnniversaryDayMark>>>{};

  bool get isEmpty => _entries.isEmpty;

  /// [day] 当天的纪念日；table_calendar 传入的 UTC 零点同样按年月日取。
  List<AnniversaryDayMark> marksOn(DateTime day) {
    if (_entries.isEmpty) {
      return const <AnniversaryDayMark>[];
    }
    final bucket = _months[day.year * 100 + day.month] ??= _buildMonth(
      day.year,
      day.month,
    );
    return bucket[day.day] ?? const <AnniversaryDayMark>[];
  }

  /// 日期格小字行写的名称：当天第一条。
  String? titleOn(DateTime day) {
    final marks = marksOn(day);
    return marks.isEmpty ? null : marks.first.row.title;
  }

  Map<int, List<AnniversaryDayMark>> _buildMonth(int year, int month) {
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1);
    final bucket = <int, List<AnniversaryDayMark>>{};
    for (final (row, rule) in _entries) {
      for (final occurrence in AnniversaryCalendar.inRange(rule, start, end)) {
        (bucket[occurrence.date.day] ??= <AnniversaryDayMark>[]).add(
          AnniversaryDayMark(row: row, rule: rule, occurrence: occurrence),
        );
      }
    }
    return bucket;
  }
}
