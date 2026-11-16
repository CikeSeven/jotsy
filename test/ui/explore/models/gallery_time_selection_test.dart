import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/explore/models/gallery_time_selection.dart';

void main() {
  final now = DateTime(2026, 11, 16, 10);
  GalleryTimeSelection fresh([DateTimeRange? initial]) =>
      GalleryTimeSelection(initial: initial, now: now);

  test('tap selects a single light day; long press twice makes a range', () {
    final s = fresh()..tapDay(DateTime(2026, 11, 3));
    expect(s.dayMark(DateTime(2026, 11, 3)), GalleryDayMark.light);
    expect(
      s.result,
      DateTimeRange(start: DateTime(2026, 11, 3), end: DateTime(2026, 11, 3)),
    );

    s
      ..longPressDay(DateTime(2026, 11, 20))
      ..longPressDay(DateTime(2026, 11, 8));
    expect(s.dayMark(DateTime(2026, 11, 8)), GalleryDayMark.dark);
    expect(s.dayMark(DateTime(2026, 11, 20)), GalleryDayMark.dark);
    expect(s.dayMark(DateTime(2026, 11, 12)), GalleryDayMark.light);
    expect(s.dayMark(DateTime(2026, 11, 21)), GalleryDayMark.none);
    expect(
      s.result,
      DateTimeRange(start: DateTime(2026, 11, 8), end: DateTime(2026, 11, 20)),
    );
  });

  test('nothing picked yet means confirm stays disabled', () {
    expect(fresh().result, isNull);
  });

  test('long pressing two months selects the months in the visible year', () {
    final s = fresh()
      ..toggleMonthPicker()
      ..longPressMonth(6)
      ..longPressMonth(3);
    expect(s.monthRange, (3, 6));
    expect(s.monthMark(3), GalleryGridMark.endpoint);
    expect(s.monthMark(4), GalleryGridMark.middle);
    expect(
      s.result,
      DateTimeRange(start: DateTime(2026, 3), end: DateTime(2026, 6, 30)),
    );
    // 选月不让日期页跳月。
    expect(s.visibleMonth, DateTime(2026, 11));
  });

  test('cancelling the month layer restores what was there before', () {
    final s = fresh()..tapDay(DateTime(2026, 11, 5));
    s
      ..toggleMonthPicker()
      ..longPressMonth(2);
    expect(s.backToDays(), isTrue);
    expect(s.mode, GalleryTimePickerMode.day);
    expect(s.monthRange, isNull);
    expect(s.dayMark(DateTime(2026, 11, 5)), GalleryDayMark.light);
    // 已在日期页时交给菜单收起。
    expect(s.backToDays(), isFalse);
  });

  test('all months follows paging into the next year and keeps position '
      'when cancelled', () {
    final s = fresh()..longPressMonthHeader();
    expect(s.allMonthsSelected, isTrue);
    expect(
      s.result,
      DateTimeRange(start: DateTime(2026), end: DateTime(2026, 12, 31)),
    );

    s
      ..page(forward: true)
      ..page(forward: true);
    expect(s.visibleMonth, DateTime(2027, 1));
    expect(s.yearRange, (2027, 2027));
    expect(
      s.result,
      DateTimeRange(start: DateTime(2027), end: DateTime(2027, 12, 31)),
    );

    s.longPressMonthHeader();
    expect(s.allMonthsSelected, isFalse);
    expect(s.result, isNull);
    expect(s.visibleMonth, DateTime(2027, 1));
  });

  test('opening the year layer drops "all months"', () {
    final s = fresh()
      ..longPressMonthHeader()
      ..toggleYearPicker();
    expect(s.allMonthsSelected, isFalse);
    expect(s.result, isNull);
    expect(s.currentYearPageStart, 2021);
  });

  test('long pressing two years selects whole years', () {
    final s = fresh()
      ..toggleYearPicker()
      ..longPressYear(2024)
      ..longPressYear(2022);
    expect(s.yearRange, (2022, 2024));
    expect(s.allMonthsSelected, isTrue);
    expect(s.visibleMonth, DateTime(2022));
    expect(
      s.result,
      DateTimeRange(start: DateTime(2022), end: DateTime(2024, 12, 31)),
    );
    s.page(forward: true);
    expect(s.currentYearPageStart, 2033);
  });

  test('reopening restores month and year highlights from the range', () {
    final years = fresh(
      DateTimeRange(start: DateTime(2025), end: DateTime(2026, 12, 31)),
    );
    expect(years.yearRange, (2025, 2026));
    expect(years.allMonthsSelected, isTrue);
    // 今年在范围里：停在今天所在的月，“全部”里显示的是这个月。
    expect(years.visibleMonth, DateTime(2026, 11));

    final months = fresh(
      DateTimeRange(start: DateTime(2024, 2), end: DateTime(2024, 4, 30)),
    );
    expect(months.monthRange, (2, 4));
    expect(months.yearRange, (2024, 2024));
    expect(months.visibleMonth, DateTime(2024, 2));
  });
}
