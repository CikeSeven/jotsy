import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/anniversaries/viewmodels/anniversary_calendar.dart';
import 'package:node_diary/ui/anniversaries/viewmodels/anniversary_rule.dart';
import 'package:tyme/tyme.dart';

/// 期望的农历换算结果都在测试里用 tyme 现算，不凭记忆手写公历日期。
DateTime solarOf(int lunarYear, int lunarMonth, int lunarDay) {
  final solar = LunarDay.fromYmd(lunarYear, lunarMonth, lunarDay).getSolarDay();
  return DateTime(solar.getYear(), solar.getMonth(), solar.getDay());
}

AnniversaryRule solar(DateTime base) =>
    AnniversaryRule.forDate(base, AnniversaryRecurrence.solarYearly);

AnniversaryRule lunar(DateTime base) =>
    AnniversaryRule.forDate(base, AnniversaryRecurrence.lunarYearly);

AnniversaryRule once(DateTime base) =>
    AnniversaryRule.forDate(base, AnniversaryRecurrence.once);

void main() {
  group('solar yearly', () {
    test('Feb 29 falls back to Feb 28 in common years', () {
      final rule = solar(DateTime(2024, 2, 29));
      expect(
        AnniversaryCalendar.inCycle(rule, 2025),
        AnniversaryOccurrence(
          date: DateTime(2025, 2, 28),
          ordinal: 1,
          adjusted: true,
        ),
      );
      expect(
        AnniversaryCalendar.inCycle(rule, 2028),
        AnniversaryOccurrence(date: DateTime(2028, 2, 29), ordinal: 4),
      );
      expect(AnniversaryCalendar.inCycle(rule, 2023), isNull);
    });

    test('next counts today as a hit', () {
      final rule = solar(DateTime(2020, 10, 16));
      expect(
        AnniversaryCalendar.next(rule, DateTime(2026, 10, 16)),
        AnniversaryOccurrence(date: DateTime(2026, 10, 16), ordinal: 6),
      );
      expect(
        AnniversaryCalendar.next(rule, DateTime(2026, 10, 17))?.date,
        DateTime(2027, 10, 16),
      );
    });

    test('nothing shows up before the first time', () {
      final rule = solar(DateTime(2026, 10, 1));
      expect(
        AnniversaryCalendar.inRange(
          rule,
          DateTime(2025, 10, 1),
          DateTime(2025, 11, 1),
        ),
        isEmpty,
      );
      expect(
        AnniversaryCalendar.next(rule, DateTime(2020, 1, 1))?.date,
        DateTime(2026, 10, 1),
      );
    });

    test('past lists earlier times newest first', () {
      final rule = solar(DateTime(2020, 3, 1));
      final past = AnniversaryCalendar.past(rule, DateTime(2026, 10, 16));
      expect(past.map((o) => o.date.year), <int>[
        2026,
        2025,
        2024,
        2023,
        2022,
        2021,
        2020,
      ]);
      expect(past.last.ordinal, 0);
      expect(
        AnniversaryCalendar.past(rule, DateTime(2026, 10, 16), limit: 3),
        hasLength(3),
      );
      // 今年这一次还没到，不算在“过去”里。
      expect(
        AnniversaryCalendar.past(rule, DateTime(2026, 2, 1)).first.date,
        DateTime(2025, 3, 1),
      );
    });
  });

  group('lunar yearly', () {
    test('the first time is exactly the date that was entered', () {
      final base = DateTime(2019, 11, 20);
      final rule = lunar(base);
      final snapshot = LunarYmd.of(base);
      expect(rule.lunar, snapshot);
      expect(
        AnniversaryCalendar.inCycle(rule, snapshot.year),
        AnniversaryOccurrence(date: base, ordinal: 0),
      );
      expect(
        AnniversaryCalendar.inCycle(rule, 2026)?.date,
        solarOf(2026, snapshot.month, snapshot.day),
      );
    });

    test('a leap-month date uses the plain month in years without it', () {
      // 2020-05-23 是农历闰四月初一。
      final rule = lunar(DateTime(2020, 5, 23));
      expect(rule.lunar, const LunarYmd(2020, -4, 1));
      expect(
        AnniversaryCalendar.inCycle(rule, 2021),
        AnniversaryOccurrence(
          date: solarOf(2021, 4, 1),
          ordinal: 1,
          adjusted: true,
        ),
      );
      // 下一个有闰四月的年份回到闰月本身。
      final leapYear = <int>[
        for (var y = 2021; y < 2100; y++)
          if (LunarYear.fromYear(y).getLeapMonth() == 4) y,
      ].first;
      expect(
        AnniversaryCalendar.inCycle(rule, leapYear),
        AnniversaryOccurrence(
          date: solarOf(leapYear, -4, 1),
          ordinal: leapYear - 2020,
        ),
      );
    });

    test('a plain-month date never repeats in the leap month', () {
      // 2023 年有闰二月：二月初一与闰二月初一各一天，只取二月初一。
      final rule = lunar(solarOf(2023, 2, 1));
      expect(rule.lunar, const LunarYmd(2023, 2, 1));
      final year = AnniversaryCalendar.inRange(
        rule,
        DateTime(2023, 1, 1),
        DateTime(2024, 1, 1),
      );
      expect(year.map((o) => o.date), <DateTime>[solarOf(2023, 2, 1)]);
      expect(
        AnniversaryCalendar.inCycle(rule, 2024)?.date,
        solarOf(2024, 2, 1),
      );
    });

    test('the 30th falls back to the 29th in a short month', () {
      // 2024-02-09 是农历癸卯年腊月三十（除夕）。
      final rule = lunar(DateTime(2024, 2, 9));
      expect(rule.lunar, const LunarYmd(2023, 12, 30));
      expect(LunarMonth.fromYm(2024, 12).getDayCount(), 29);
      expect(
        AnniversaryCalendar.inCycle(rule, 2024),
        AnniversaryOccurrence(
          date: solarOf(2024, 12, 29),
          ordinal: 1,
          adjusted: true,
        ),
      );
    });

    test('a twelfth-month date lands in the next solar year', () {
      // 腊八：农历 2025 年的腊八在公历 2026 年 1 月。
      final base = solarOf(2019, 12, 8);
      final rule = lunar(base);
      final january = AnniversaryCalendar.inRange(
        rule,
        DateTime(2026, 1, 1),
        DateTime(2026, 2, 1),
      );
      expect(january, <AnniversaryOccurrence>[
        AnniversaryOccurrence(date: solarOf(2025, 12, 8), ordinal: 6),
      ]);
      expect(january.single.date.year, 2026);
      expect(
        AnniversaryCalendar.next(rule, DateTime(2026, 1, 1))?.date,
        solarOf(2025, 12, 8),
      );
    });

    test('a stored snapshot wins over the base date', () {
      final row = Anniversary(
        id: 1,
        anniversaryId: 'a',
        title: 'x',
        baseDate: '2020-05-23',
        recurrence: AnniversaryRecurrence.lunarYearly.name,
        lunarYear: 2020,
        lunarMonth: -4,
        lunarDay: 1,
        note: '',
        isPinned: false,
        metadata: '{}',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(AnniversaryRule.fromRow(row)?.lunar, const LunarYmd(2020, -4, 1));
      // 快照不存在（2021 年没有闰四月）时按首次日期重算。
      final broken = row.copyWith(lunarYear: const Value(2021));
      expect(
        AnniversaryRule.fromRow(broken)?.lunar,
        const LunarYmd(2020, -4, 1),
      );
      expect(
        AnniversaryRule.fromRow(row.copyWith(baseDate: '2020-02-30')),
        isNull,
      );
    });
  });

  group('once', () {
    test('counts down before and has no next time after', () {
      final rule = once(DateTime(2026, 12, 31));
      final from = DateTime(2026, 10, 16);
      expect(
        AnniversaryCalendar.next(rule, from),
        AnniversaryOccurrence(date: DateTime(2026, 12, 31), ordinal: 0),
      );
      expect(AnniversaryCalendar.daysBetween(from, DateTime(2026, 12, 31)), 76);
      expect(AnniversaryCalendar.next(rule, DateTime(2027, 1, 2)), isNull);
      expect(AnniversaryCalendar.inCycle(rule, 2027), isNull);
      expect(
        AnniversaryCalendar.past(rule, DateTime(2027, 1, 2)).single.date,
        DateTime(2026, 12, 31),
      );
    });
  });

  test('daysBetween ignores the time of day and the direction', () {
    expect(
      AnniversaryCalendar.daysBetween(
        DateTime(2026, 3, 28, 23, 59),
        DateTime(2026, 3, 30, 0, 1),
      ),
      2,
    );
    expect(
      AnniversaryCalendar.daysBetween(DateTime(2026, 1, 2), DateTime(2026)),
      -1,
    );
    expect(
      AnniversaryCalendar.daysBetween(DateTime(2024), DateTime(2025)),
      366,
    );
  });
}
