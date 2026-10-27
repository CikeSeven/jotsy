part of 'package:node_diary/ui/calendar/pages/calendar_page.dart';

/// 这天的心情：长按日期面板里选定或清除后写库。
///
/// 日期格与年视图订阅 [dayMoodsProvider]（drift watch），写入后自动换成新的
/// 样子，这里不改页面状态。清除带 4 秒撤销：先删行并拿到整行，撤销时原样
/// 写回；撤销期间又设了新心情的，以撤销写回的为准（与提示条上的承诺一致）。
/// 写库失败只提示，不改动任何状态。
extension _CalendarDayMoodActions on _CalendarPageController {
  Future<void> applyDayMood(DateTime day, DayMood? mood, {DayMood? current}) {
    if (mood == current) {
      return Future<void>.value();
    }
    return mood == null ? _clearDayMood(day) : _setDayMood(day, mood);
  }

  Future<void> _setDayMood(DateTime day, DayMood mood) async {
    final database = _state.ref.read(appDatabaseProvider);
    try {
      await database.setDayMood(day, mood);
    } catch (_) {
      if (_state.mounted) {
        await _showInfoSnackBar(_state.context.l10n.calendarDayMoodSaveFailed);
      }
    }
  }

  Future<void> _clearDayMood(DateTime day) async {
    final database = _state.ref.read(appDatabaseProvider);
    final DayMoodRow? removed;
    try {
      removed = await database.clearDayMood(day);
    } catch (_) {
      if (_state.mounted) {
        await _showInfoSnackBar(_state.context.l10n.calendarDayMoodSaveFailed);
      }
      return;
    }
    if (removed == null || !_state.mounted) {
      return;
    }
    final l10n = _state.context.l10n;
    final reason = await HomeHintVisibilityScope.showTrackedSnackBar(
      context: _state.context,
      snackBar: SnackBar(
        content: Text(l10n.calendarDayMoodCleared),
        duration: const Duration(seconds: 4),
        persist: false,
        action: SnackBarAction(label: l10n.commonUndo, onPressed: () {}),
      ),
    );
    if (reason != SnackBarClosedReason.action) {
      return;
    }
    // 撤销不依赖页面仍在：数据库连接是全局的，离开日历页后点撤销也要写回。
    try {
      await database.restoreDayMood(removed);
    } catch (_) {
      if (_state.mounted) {
        await _showInfoSnackBar(_state.context.l10n.calendarDayMoodSaveFailed);
      }
    }
  }
}
