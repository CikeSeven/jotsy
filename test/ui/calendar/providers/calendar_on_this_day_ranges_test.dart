import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/calendar/providers/calendar_diary_providers.dart';

void main() {
  test('ranges cover the same date in other years up to this year', () {
    final ranges = calendarOnThisDayRanges(
      DateTime(2024, 3, 12),
      now: DateTime(2026, 10, 15),
    );
    final years = ranges.map((range) => range.$1.year).toList();

    expect(years, isNot(contains(2024)));
    expect(years.first, 2024 - calendarOnThisDayYearSpan);
    expect(years.last, 2026);
    expect(ranges.last, (DateTime(2026, 3, 12), DateTime(2026, 3, 13)));
  });

  test('February 29 only matches leap years', () {
    final ranges = calendarOnThisDayRanges(
      DateTime(2024, 2, 29),
      now: DateTime(2030, 1, 1),
    );
    final years = ranges.map((range) => range.$1.year).toSet();

    expect(years, containsAll(<int>[2020, 2028]));
    expect(years, isNot(contains(2025)));
    expect(ranges.every((range) => range.$1.month == 2), isTrue);
  });
}
