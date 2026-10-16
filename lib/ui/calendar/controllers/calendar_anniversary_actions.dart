part of 'package:node_diary/ui/calendar/pages/calendar_page.dart';

/// 日历页的纪念日入口：长按日期“添加纪念日”与点按选中日的纪念日卡片。
/// 编辑页与提示经 anniversary_navigation.dart，页面只负责从哪一天打开。
extension _CalendarAnniversaryActions on _CalendarPageController {
  Future<void> addAnniversary(DateTime day) async {
    await openAnniversaryEditor(
      _state.context,
      database: _state.ref.read(appDatabaseProvider),
      draft: AnniversaryDraft.forDay(day, today: DateTime.now()),
    );
  }

  Future<void> openAnniversary(AnniversaryDayMark mark) async {
    await openAnniversaryEditor(
      _state.context,
      database: _state.ref.read(appDatabaseProvider),
      draft: AnniversaryDraft.fromRow(mark.row),
      editing: mark.row,
    );
  }
}
