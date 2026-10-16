import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/calendar/viewmodels/calendar_lunar_day.dart';

// 期望的农历月日与节气取自香港天文台《公曆與農曆日期對照表》
// （https://www.hko.gov.hk/tc/gts/time/calendar/text/files/T{年}c.txt，
// 2020、2025、2026、2033 年），不是换算库自身的输出；节日按其农历定义
// （如中秋为八月十五）由对照表推出。
void main() {
  test('ordinary days show the lunar day and month starts show the month', () {
    final day = CalendarLunarDay.of(DateTime(2026, 10, 14));
    expect(day.date, '九月初五');
    expect(day.cellLabel, '初五');
    expect(day.kind, CalendarLunarKind.day);
    expect(day.festivals, isEmpty);
    expect(day.term, isNull);

    final monthStart = CalendarLunarDay.of(DateTime(2026, 10, 10));
    expect(monthStart.date, '九月初一');
    expect(monthStart.cellLabel, '九月');
    expect(monthStart.kind, CalendarLunarKind.monthStart);
  });

  test('leap months are named as leap months, including 2033', () {
    expect(CalendarLunarDay.of(DateTime(2025, 7, 25)).cellLabel, '闰六月');
    final leap = CalendarLunarDay.of(DateTime(2033, 12, 22));
    expect(leap.cellLabel, '闰十一月');
    expect(leap.date, '闰十一月初一');
  });

  test('solar terms replace the lunar day', () {
    final coldDew = CalendarLunarDay.of(DateTime(2026, 10, 8));
    expect(coldDew.date, '八月廿八');
    expect(coldDew.cellLabel, '寒露');
    expect(coldDew.kind, CalendarLunarKind.term);
    expect(coldDew.term, '寒露');
  });

  test('festivals win over solar terms and lunar days', () {
    final midAutumn = CalendarLunarDay.of(DateTime(2025, 10, 6));
    expect(midAutumn.date, '八月十五');
    expect(midAutumn.cellLabel, '中秋节');
    expect(midAutumn.kind, CalendarLunarKind.festival);

    final springFestival = CalendarLunarDay.of(DateTime(2026, 2, 17));
    expect(springFestival.date, '正月初一');
    expect(springFestival.cellLabel, '春节');

    // 2026 年腊月只有 29 天：除夕是春节前一天，而不是固定的“三十”。
    final eve = CalendarLunarDay.of(DateTime(2026, 2, 16));
    expect(eve.date, '十二月廿九');
    expect(eve.cellLabel, '除夕');

    expect(CalendarLunarDay.of(DateTime(2026, 1, 26)).cellLabel, '腊八节');
  });

  test('a traditional festival outranks a public holiday on the same day', () {
    // 2020-10-01 既是国庆节，也是八月十五。
    final both = CalendarLunarDay.of(DateTime(2020, 10, 1));
    expect(both.date, '八月十五');
    expect(both.cellLabel, '中秋节');
    expect(both.festivals, <String>['中秋节', '国庆节']);

    final nationalDay = CalendarLunarDay.of(DateTime(2026, 10, 1));
    expect(nationalDay.date, '八月廿一');
    expect(nationalDay.cellLabel, '国庆节');
    expect(nationalDay.kind, CalendarLunarKind.festival);
  });

  test('Qingming and the winter solstice are shown once, as solar terms', () {
    final qingming = CalendarLunarDay.of(DateTime(2026, 4, 5));
    expect(qingming.date, '二月十八');
    expect(qingming.cellLabel, '清明');
    expect(qingming.kind, CalendarLunarKind.term);
    expect(qingming.festivals, isEmpty);

    final solstice = CalendarLunarDay.of(DateTime(2033, 12, 21));
    expect(solstice.cellLabel, '冬至');
    expect(solstice.term, '冬至');
    expect(solstice.festivals, isEmpty);
  });

  test('table_calendar UTC days map to the same lunar date', () {
    expect(
      CalendarLunarDay.of(DateTime.utc(2026, 10, 8)).date,
      CalendarLunarDay.of(DateTime(2026, 10, 8, 23, 30)).date,
    );
  });
}
