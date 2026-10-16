import 'package:flutter/foundation.dart';
import 'package:tyme/tyme.dart';

import 'calendar_lunar_day.dart';

/// 一个公历日的法定节假日安排：放假（休）或调休上班（班）。
///
/// 输入：公历日期（只取年月日）；输出：假日名与是否上班。数据来自 tyme 的
/// `LegalHoliday`（国务院办公厅每年公布的放假安排，自 2001-12-29 起），
/// 只收录到依赖版本发布时已公布的年份——之后的日期返回 null，日历照常按
/// 周末显示，升级 tyme 后自动补上。无副作用，结果按日期缓存。
@immutable
class CalendarHolidayDay {
  const CalendarHolidayDay({required this.name, required this.isWork});

  /// 所属假日名（元旦/春节/清明节/劳动节/端午节/中秋节/国庆节/国庆中秋/
  /// 抗战胜利日）；调休上班日同样记为它补的那个假日。
  final String name;

  /// true 为调休上班日（班），false 为放假日（休）。
  final bool isWork;

  /// 缓存上限与 [CalendarLunarDay] 一致。`LegalHoliday.fromYmd` 每次都要
  /// 现编一个正则去扫约 9.5KB 的数据串，一页 42 格每次重建都查一遍代价
  /// 可观；绝大多数日子不是假日，查不到的结果也要缓存。
  static const int _cacheLimit = 512;
  static final Map<int, CalendarHolidayDay?> _cache =
      <int, CalendarHolidayDay?>{};

  /// [day] 的放假安排，普通日子为 null。table_calendar 传入的是 UTC 零点，
  /// 这里只取年月日数字，不比较 DateTime 本身。
  static CalendarHolidayDay? of(DateTime day) {
    final key = day.year * 10000 + day.month * 100 + day.day;
    if (_cache.containsKey(key)) {
      return _cache[key];
    }
    if (_cache.length >= _cacheLimit) {
      _cache.clear();
    }
    final holiday = LegalHoliday.fromYmd(day.year, day.month, day.day);
    return _cache[key] = holiday == null
        ? null
        : CalendarHolidayDay(name: holiday.getName(), isWork: holiday.isWork());
  }

  static int? _lastCoveredYear;
  static bool _lastCoveredYearResolved = false;

  /// 数据收录到的最后一年（选项说明里告诉用户）；每年都有国庆假期，以
  /// 10 月 1 日是否有记录判断该年是否已收录。只走公开 API，不解析 tyme
  /// 的内部数据串。
  static int? lastCoveredYear({DateTime? now}) {
    if (_lastCoveredYearResolved && now == null) {
      return _lastCoveredYear;
    }
    final year = (now ?? DateTime.now()).year;
    int? covered;
    for (var y = year + 1; y >= year - 1; y--) {
      if (LegalHoliday.fromYmd(y, 10, 1) != null) {
        covered = y;
        break;
      }
    }
    if (now == null) {
      _lastCoveredYear = covered;
      _lastCoveredYearResolved = true;
    }
    return covered;
  }

  /// 选中日标题行要写出的假日名；会与已显示的内容重复时为 null：
  /// - 调休上班日只写“调休上班”，不写它补的假日名（那天并不过节）；
  /// - 当天的节日就是这个假日（tyme 的假日名与节日名同字，如“国庆节”；
  ///   合并假期“国庆中秋”含“中秋”），节日已经写在农历行里；
  /// - 清明节以节气日为准，节气“清明”已写出时不再写“清明节”。
  /// 不相干的节日照常并列（劳动节假期里的“青年节”、春节假期里的“除夕”）。
  String? headingName(CalendarLunarDay? lunar) {
    if (isWork) {
      return null;
    }
    if (lunar != null) {
      if (name == '${lunar.term}节') {
        return null;
      }
      for (final festival in lunar.festivals) {
        final stem = festival.endsWith('节')
            ? festival.substring(0, festival.length - 1)
            : festival;
        if (name.contains(stem)) {
          return null;
        }
      }
    }
    return name;
  }

  @override
  bool operator ==(Object other) =>
      other is CalendarHolidayDay &&
      other.name == name &&
      other.isWork == isWork;

  @override
  int get hashCode => Object.hash(name, isWork);
}
