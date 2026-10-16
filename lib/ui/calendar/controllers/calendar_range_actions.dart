part of 'package:node_diary/ui/calendar/pages/calendar_page.dart';

/// 选一段日期做统计的流程：从长按菜单进入，点按定终点，关闭按钮退出。
///
/// 状态机（页面字段 `_range`）：
/// - null：普通选日；
/// - 只有起点：下一次点按定终点（点在起点之前自动交换）；
/// - 首尾俱全：再点按以该日为新起点重新选择。
///
/// 范围模式下每次点按同时更新选中日，下方仍显示最后点按那天的日记；
/// 回到今天、进入年视图（日期选择器只在年视图里打开）与长按“查看这一天”
/// 都视为离开范围选择，避免选中日落在范围之外却不高亮。
extension _CalendarRangeActions on _CalendarPageController {
  /// 以 [day] 为起点进入范围选择。
  void startRange(DateTime day) {
    final normalizedDay = DateUtils.dateOnly(day);
    _state.applyState(() {
      _state._range = CalendarRangeSelection(start: normalizedDay);
      _state._selectedDay = normalizedDay;
      _state._focusedMonth = normalizedDay;
    });
  }

  /// 退出范围选择，选中日保持不变。
  void exitRange() {
    if (_state._range == null) {
      return;
    }
    _state.applyState(() => _state._range = null);
  }

  /// 范围模式下的点按；不在范围模式时返回 false，交回普通选日处理。
  ///
  /// 点按起点本身作为终点时得到一天的范围，因此不能像普通选日那样在
  /// “选中日未变”时提前返回。
  bool tapInRange(DateTime day, DateTime focusedDay) {
    final range = _state._range;
    if (range == null) {
      return false;
    }
    _state.applyState(() {
      _state._range = range.tap(day);
      _state._selectedDay = DateUtils.dateOnly(day);
      _state._focusedMonth = DateUtils.dateOnly(focusedDay);
    });
    return true;
  }
}
