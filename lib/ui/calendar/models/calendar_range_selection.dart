import 'package:flutter/foundation.dart';

/// 日期格在范围选择中的角色。
enum CalendarRangeRole { none, endpoint, inside }

/// 日历的日期范围选择（选一段日期做统计）。
///
/// 输入：起点与可选的终点（只取年月日）；输出有序的首尾日期、天数与每天
/// 的角色。不可变、无副作用，状态由页面持有。
///
/// 交互约定（与 table_calendar 自带的范围模式一致）：从长按菜单选定起点后，
/// 下一次点按定终点；点在起点之前时自动交换，不要求用户按顺序点；首尾都
/// 定下后再点按则以该日为新起点重新选择。
@immutable
class CalendarRangeSelection {
  CalendarRangeSelection({required DateTime start, DateTime? end})
    : start = _dateOnly(start),
      end = end == null ? null : _dateOnly(end);

  /// 用户最先选定的一天；终点可能在它之前，用 [first]/[last] 取有序日期。
  final DateTime start;

  /// 终点；尚未选定时为 null。
  final DateTime? end;

  bool get isComplete => end != null;

  /// 范围内较早的一天。
  DateTime get first {
    final end = this.end;
    return end != null && end.isBefore(start) ? end : start;
  }

  /// 范围内较晚的一天（尚未选定终点时与起点相同）。
  DateTime get last {
    final end = this.end;
    return end != null && end.isAfter(start) ? end : start;
  }

  /// 范围的结束边界（不含），供 `[first, endExclusive)` 区间查询与统计。
  DateTime get endExclusive => DateTime(last.year, last.month, last.day + 1);

  /// 包含首尾的天数；按日期差四舍五入，跨夏令时的 23/25 小时日不会算错。
  int get dayCount => (last.difference(first).inHours / 24).round() + 1;

  /// 点按 [day] 之后的选择：未选终点时定终点，否则以 [day] 重新起选。
  CalendarRangeSelection tap(DateTime day) {
    return isComplete
        ? CalendarRangeSelection(start: day)
        : CalendarRangeSelection(start: start, end: day);
  }

  CalendarRangeRole roleOf(DateTime day) {
    final date = _dateOnly(day);
    if (date == first || date == last) {
      return CalendarRangeRole.endpoint;
    }
    if (date.isAfter(first) && date.isBefore(last)) {
      return CalendarRangeRole.inside;
    }
    return CalendarRangeRole.none;
  }

  /// table_calendar 传入 UTC 零点，统一转成本地日期再比较。
  static DateTime _dateOnly(DateTime day) =>
      DateTime(day.year, day.month, day.day);

  @override
  bool operator ==(Object other) =>
      other is CalendarRangeSelection &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}
