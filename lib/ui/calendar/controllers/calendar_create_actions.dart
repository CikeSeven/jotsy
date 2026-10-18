part of 'package:node_diary/ui/calendar/pages/calendar_page.dart';

/// 从日历新建日记：经共用的新建流程（有草稿时先弹草稿选择面板）进入编辑页，
/// 发表日期取日历上的日期，未来日期可预设为时间胶囊。
extension _CalendarCreateActions on _CalendarPageController {
  /// 从日历进入新建流程：新建空白时以 [day]（默认选中日期）为发表日期；
  /// [capsuleUnlockAt] 非空时预设为在该日解封的时间胶囊（未来日期的“写给
  /// 这一天的时间胶囊”）。续写的草稿自带日期或胶囊设置时以草稿为准。
  Future<void> openCreateEditorWithDraftPrompt({
    DateTime? day,
    DateTime? capsuleUnlockAt,
  }) async {
    await runDiaryCreateEntryFlow(
      _state.context,
      _state.ref,
      day: DateUtils.dateOnly(day ?? _state._selectedDay),
      capsuleUnlockAt: capsuleUnlockAt,
    );
  }
}
