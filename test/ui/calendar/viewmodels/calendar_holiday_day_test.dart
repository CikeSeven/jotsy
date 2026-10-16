import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/calendar/viewmodels/calendar_holiday_day.dart';
import 'package:node_diary/ui/calendar/viewmodels/calendar_lunar_day.dart';

void main() {
  // 期望值取自国务院办公厅 2026 年放假安排（tyme 1.5.0 内置数据）。
  CalendarHolidayDay? on(int month, int day) =>
      CalendarHolidayDay.of(DateTime(2026, month, day));

  test('the National Day week is off and its make-up days are workdays', () {
    for (var day = 1; day <= 7; day++) {
      expect(
        on(10, day),
        const CalendarHolidayDay(name: '国庆节', isWork: false),
        reason: '10-$day',
      );
    }
    expect(on(10, 8), isNull);
    expect(on(9, 20), const CalendarHolidayDay(name: '国庆节', isWork: true));
    expect(on(10, 10), const CalendarHolidayDay(name: '国庆节', isWork: true));
  });

  test('other 2026 holidays and make-up workdays', () {
    expect(on(1, 1)?.isWork, isFalse);
    expect(on(1, 4), const CalendarHolidayDay(name: '元旦', isWork: true));
    expect(on(2, 14), const CalendarHolidayDay(name: '春节', isWork: true));
    expect(on(2, 28), const CalendarHolidayDay(name: '春节', isWork: true));
    expect(on(2, 17), const CalendarHolidayDay(name: '春节', isWork: false));
    expect(on(5, 9), const CalendarHolidayDay(name: '劳动节', isWork: true));
    expect(on(9, 25), const CalendarHolidayDay(name: '中秋节', isWork: false));
    expect(on(3, 12), isNull);
  });

  test('UTC midnights from table_calendar resolve to the same day', () {
    expect(
      CalendarHolidayDay.of(DateTime.utc(2026, 10, 1)),
      CalendarHolidayDay.of(DateTime(2026, 10, 1)),
    );
  });

  test('years without published schedules have no marks', () {
    expect(CalendarHolidayDay.of(DateTime(2027, 1, 1)), isNull);
    expect(CalendarHolidayDay.of(DateTime(2027, 10, 1)), isNull);
    expect(
      CalendarHolidayDay.lastCoveredYear(now: DateTime(2026, 10, 16)),
      2026,
    );
    expect(
      CalendarHolidayDay.lastCoveredYear(now: DateTime(2040, 1, 1)),
      isNull,
    );
  });

  group('heading name', () {
    String? heading(int month, int day) {
      final date = DateTime(2026, month, day);
      return CalendarHolidayDay.of(
        date,
      )!.headingName(CalendarLunarDay.of(date));
    }

    test('is left out when the festival of the same name is shown', () {
      expect(heading(10, 1), isNull); // 国庆节
      expect(heading(1, 1), isNull); // 元旦
      expect(heading(5, 1), isNull); // 劳动节
      expect(heading(9, 25), isNull); // 中秋节（农历节日）
      expect(heading(4, 5), isNull); // 节气“清明”
    });

    test('is written on the other days of the break', () {
      expect(heading(10, 2), '国庆节');
      expect(heading(4, 4), '清明节');
      expect(heading(5, 4), '劳动节'); // 与青年节并列
    });

    test('is left out on make-up workdays and merged breaks dedupe', () {
      expect(heading(9, 20), isNull);
      const merged = CalendarHolidayDay(name: '国庆中秋', isWork: false);
      expect(
        merged.headingName(CalendarLunarDay.of(DateTime(2020, 10, 1))),
        isNull,
      );
      expect(merged.headingName(null), '国庆中秋');
    });
  });
}
