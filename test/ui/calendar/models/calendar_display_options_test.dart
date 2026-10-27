import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/calendar/models/calendar_display_options.dart';

void main() {
  test('missing or corrupt json falls back to the defaults', () {
    const defaults = CalendarDisplayOptions();
    expect(CalendarDisplayOptions.decode(null), defaults);
    expect(CalendarDisplayOptions.decode('  '), defaults);
    expect(CalendarDisplayOptions.decode('{not json'), defaults);
    expect(CalendarDisplayOptions.decode('[1, 2]'), defaults);
    expect(defaults.cellStyle, CalendarCellStyle.mood);
    expect(defaults.weekStart, CalendarWeekStart.locale);
    expect(defaults.showMonthSummary, isTrue);
    expect(defaults.lunarMode, CalendarLunarMode.locale);
    expect(defaults.holidayMode, CalendarLunarMode.locale);
    expect(defaults.showAnniversaries, isTrue);
    expect(defaults.showDayMoods, isTrue);
  });

  test('every field survives an encode/decode round trip', () {
    const options = CalendarDisplayOptions(
      cellStyle: CalendarCellStyle.heat,
      heatBasis: CalendarHeatBasis.words,
      moodAggregation: CalendarMoodAggregation.each,
      showCountBadge: false,
      showCapsuleBadge: false,
      showWeatherBadge: true,
      weekStart: CalendarWeekStart.sunday,
      highlightWeekends: true,
      showWeekNumbers: true,
      fixedSixWeeks: true,
      defaultFormat: CalendarDefaultFormat.remember,
      rememberedFormat: CalendarGridFormat.week,
      showMonthSummary: false,
      dayContentStyle: CalendarDayContentStyle.cards,
      showOnThisDay: false,
      yearBasis: CalendarYearBasis.words,
      lunarMode: CalendarLunarMode.always,
      holidayMode: CalendarLunarMode.never,
      showAnniversaries: false,
      showDayMoods: false,
    );

    expect(CalendarDisplayOptions.decode(options.encode()), options);
  });

  test('a bad field falls back alone and keeps the other choices', () {
    final options = CalendarDisplayOptions.decode(
      '{"cellStyle":"hologram","heatBasis":"words","showCountBadge":"yes",'
      '"weekStart":"monday","lunarMode":"sometimes","holidayMode":"always"}',
    );

    expect(options.cellStyle, CalendarCellStyle.mood);
    expect(options.heatBasis, CalendarHeatBasis.words);
    expect(options.showCountBadge, isTrue);
    expect(options.weekStart, CalendarWeekStart.monday);
    expect(options.lunarMode, CalendarLunarMode.locale);
    expect(options.holidayMode, CalendarLunarMode.always);
  });

  test('options saved before holidays existed keep holidays on locale', () {
    final options = CalendarDisplayOptions.decode('{"lunarMode":"never"}');
    expect(options.lunarMode, CalendarLunarMode.never);
    expect(options.holidayMode, CalendarLunarMode.locale);
  });

  test('initial format follows the default format choice', () {
    const remembered = CalendarDisplayOptions(
      defaultFormat: CalendarDefaultFormat.remember,
      rememberedFormat: CalendarGridFormat.week,
    );
    expect(remembered.initialFormat, CalendarGridFormat.week);
    expect(
      remembered
          .copyWith(defaultFormat: CalendarDefaultFormat.month)
          .initialFormat,
      CalendarGridFormat.month,
    );
    expect(
      const CalendarDisplayOptions(
        defaultFormat: CalendarDefaultFormat.week,
      ).initialFormat,
      CalendarGridFormat.week,
    );
  });
}
