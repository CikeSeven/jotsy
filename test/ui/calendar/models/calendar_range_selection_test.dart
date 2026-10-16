import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/calendar/models/calendar_range_selection.dart';

void main() {
  test('the second tap sets the end and the order does not matter', () {
    final picking = CalendarRangeSelection(start: DateTime(2026, 10, 12));
    expect(picking.isComplete, isFalse);
    expect(picking.first, DateTime(2026, 10, 12));
    expect(picking.last, DateTime(2026, 10, 12));
    expect(picking.dayCount, 1);

    final range = picking.tap(DateTime(2026, 10, 3));
    expect(range.isComplete, isTrue);
    expect(range.first, DateTime(2026, 10, 3));
    expect(range.last, DateTime(2026, 10, 12));
    expect(range.endExclusive, DateTime(2026, 10, 13));
    expect(range.dayCount, 10);
  });

  test('tapping after both ends are set starts a new range', () {
    final range = CalendarRangeSelection(
      start: DateTime(2026, 10, 3),
      end: DateTime(2026, 10, 12),
    );
    final restarted = range.tap(DateTime(2026, 11, 1));
    expect(restarted, CalendarRangeSelection(start: DateTime(2026, 11, 1)));
  });

  test('tapping the start again makes a one-day range', () {
    final range = CalendarRangeSelection(
      start: DateTime(2026, 10, 3),
    ).tap(DateTime.utc(2026, 10, 3));
    expect(range.isComplete, isTrue);
    expect(range.dayCount, 1);
    expect(range.roleOf(DateTime(2026, 10, 3)), CalendarRangeRole.endpoint);
  });

  test('each day knows whether it is an end, inside or outside', () {
    final range = CalendarRangeSelection(
      start: DateTime(2026, 10, 30),
      end: DateTime(2026, 11, 2, 15),
    );
    expect(
      range.roleOf(DateTime.utc(2026, 10, 30)),
      CalendarRangeRole.endpoint,
    );
    expect(range.roleOf(DateTime(2026, 10, 31, 23)), CalendarRangeRole.inside);
    expect(range.roleOf(DateTime(2026, 11, 1)), CalendarRangeRole.inside);
    expect(range.roleOf(DateTime(2026, 11, 2)), CalendarRangeRole.endpoint);
    expect(range.roleOf(DateTime(2026, 11, 3)), CalendarRangeRole.none);
    expect(range.roleOf(DateTime(2026, 10, 29)), CalendarRangeRole.none);
    expect(range.dayCount, 4);
  });

  test('day counts span years and leap days', () {
    final range = CalendarRangeSelection(
      start: DateTime(2027, 12, 31),
      end: DateTime(2028, 3, 1),
    );
    // 2027-12-31 起，1 月 31 + 2 月 29（2028 为闰年）+ 3 月 1 日。
    expect(range.dayCount, 1 + 31 + 29 + 1);
  });
}
