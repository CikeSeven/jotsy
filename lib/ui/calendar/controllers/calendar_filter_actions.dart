part of 'package:node_diary/ui/calendar/pages/calendar_page.dart';

/// 按标签或心情筛选日历打点：打开筛选面板、更新与清除筛选。
///
/// 筛选只存在页面状态里（`_filter`），不写入设置；页面在聚合打点前过滤，
/// 日期格、月度概览、年视图与范围统计一起变化，那年今日与选中日的日记
/// 列表不受影响（见 [CalendarMarkerFilter]）。
extension _CalendarFilterActions on _CalendarPageController {
  /// 打开筛选面板；面板内每次点选即时生效，网格在浅遮罩后方同步重绘。
  Future<void> openFilter() {
    final moodOptions =
        _state.ref.read(moodOptionsProvider).asData?.value ??
        SettingsService.defaultMoodOptions;
    return showCalendarFilterSheet(
      _state.context,
      filter: _state._filter,
      moodOptions: moodOptions,
      onChanged: setFilter,
    );
  }

  void setFilter(CalendarMarkerFilter next) {
    if (next == _state._filter) {
      return;
    }
    _state.applyState(() => _state._filter = next);
  }

  void clearFilter() => setFilter(const CalendarMarkerFilter());
}
