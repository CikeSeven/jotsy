import 'package:flutter/foundation.dart';
import 'package:tyme/tyme.dart';

/// 日期格农历小字的类别，决定颜色：节日 tertiary、节气 primary、农历
/// 月首与普通农历日弱化显示。
enum CalendarLunarKind { festival, term, monthStart, day }

/// 一个公历日对应的农历信息（农历月日、节气、传统与公历节日）。
///
/// 输入：公历日期（只取年月日）；输出：日期格小字与选中日标题所需的文本。
/// 换算交给 tyme（6tail，依据 GB/T 33661-2017），本类只负责挑选显示内容。
/// 无副作用，结果按日期缓存。
///
/// 日期格只放得下一个词，按“传统节日 > 公历节日 > 节气 > 农历月首 > 农历日”
/// 取第一个；月首显示月名（“九月”“闰六月”），与纸质日历的习惯一致。
/// 清明节、冬至节以节气日为准、与节气同名，只按节气显示一次，避免标题里
/// 出现“清明节 · 清明”。
@immutable
class CalendarLunarDay {
  const CalendarLunarDay({
    required this.date,
    required this.cellLabel,
    required this.kind,
    this.festivals = const <String>[],
    this.term,
    required this.termPeriod,
  });

  /// 农历月日，如“九月廿四”“闰六月初一”。
  final String date;

  /// 日期格数字下方的小字。
  final String cellLabel;
  final CalendarLunarKind kind;

  /// 当天的节日（传统节日在前、公历节日在后），选中日标题用。
  final List<String> festivals;

  /// 当天恰逢的节气；非节气日为 null。
  final String? term;

  /// 当天所在的节气期（上一个节气到下一个节气之前都算），如霜降后到立冬前
  /// 都是“霜降”。日记模板的 `{{节气}}` 变量取它：只在节气当天才有值的
  /// [term] 一年里大多数日子都是空的。
  final String termPeriod;

  /// 缓存上限：月视图翻页与选中日切换会反复重建同一批日期格，单日换算约
  /// 几十微秒，一页 42 格累计可观；满了整体清空即可，不需要精确的 LRU。
  static const int _cacheLimit = 512;
  static final Map<int, CalendarLunarDay> _cache = <int, CalendarLunarDay>{};

  /// [day] 的农历信息；table_calendar 传入的是 UTC 零点，这里只取年月日，
  /// 本地与 UTC 日期一致。
  static CalendarLunarDay of(DateTime day) {
    final key = day.year * 10000 + day.month * 100 + day.day;
    final cached = _cache[key];
    if (cached != null) {
      return cached;
    }
    if (_cache.length >= _cacheLimit) {
      _cache.clear();
    }
    return _cache[key] = _compute(day.year, day.month, day.day);
  }

  static CalendarLunarDay _compute(int year, int month, int day) {
    final solar = SolarDay.fromYmd(year, month, day);
    final lunar = solar.getLunarDay();
    final lunarMonth = lunar.getLunarMonth();
    final termDay = solar.getTermDay();
    final termPeriod = termDay.getSolarTerm().getName();
    final term = termDay.getDayIndex() == 0 ? termPeriod : null;
    var traditional = lunar.getFestival()?.getName();
    if (term != null && traditional == '$term节') {
      traditional = null;
    }
    final modern = solar.getFestival()?.getName();

    final String cellLabel;
    final CalendarLunarKind kind;
    if ((traditional ?? modern) case final festival?) {
      cellLabel = festival;
      kind = CalendarLunarKind.festival;
    } else if (term != null) {
      cellLabel = term;
      kind = CalendarLunarKind.term;
    } else if (lunar.day == 1) {
      cellLabel = lunarMonth.getName();
      kind = CalendarLunarKind.monthStart;
    } else {
      cellLabel = lunar.getName();
      kind = CalendarLunarKind.day;
    }
    return CalendarLunarDay(
      date: '${lunarMonth.getName()}${lunar.getName()}',
      cellLabel: cellLabel,
      kind: kind,
      festivals: List<String>.unmodifiable(<String>[?traditional, ?modern]),
      term: term,
      termPeriod: termPeriod,
    );
  }
}
