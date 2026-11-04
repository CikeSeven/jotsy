import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/energy_battery_indicator.dart';

void main() {
  final zh = lookupAppLocalizations(const Locale('zh'));
  final en = lookupAppLocalizations(const Locale('en'));
  final ja = lookupAppLocalizations(const Locale('ja'));
  final ru = lookupAppLocalizations(const Locale('ru'));

  setUpAll(() async {
    for (final code in const ['zh', 'en', 'ja', 'ru']) {
      await initializeDateFormatting(code);
    }
  });

  test('energy descriptions come from the active locale', () {
    expect(EnergyBatteryIndicator.descriptionForValue(1, zh), '疲惫不堪');
    expect(EnergyBatteryIndicator.descriptionForValue(3, zh), '状态一般');
    expect(EnergyBatteryIndicator.descriptionForValue(5, zh), '精力满满');
    expect(EnergyBatteryIndicator.descriptionForValue(2, en), 'A bit tired');
    expect(EnergyBatteryIndicator.descriptionForValue(4, en), 'Pretty good');
  });

  test('on-this-day label pluralizes per locale', () {
    expect(zh.exploreOnThisDayYearsAgo(1), '1年前的今天');
    expect(zh.exploreOnThisDayYearsAgo(3), '3年前的今天');
    expect(en.exploreOnThisDayYearsAgo(1), '1 year ago today');
    expect(en.exploreOnThisDayYearsAgo(3), '3 years ago today');
  });

  test('minute precision date time uses the locale pattern', () {
    final value = DateTime(2026, 3, 12, 9, 5);
    expect(zh.formatDateTimeMinute(value), '2026年03月12日 09:05');
    expect(en.formatDateTimeMinute(value), '2026-03-12 09:05');
  });

  test('Japanese and Russian dates follow their own field order', () {
    final value = DateTime(2026, 3, 12, 9, 5);
    expect(ja.formatDateTimeMinute(value), '2026/03/12 09:05');
    expect(ru.formatDateTimeMinute(value), '12.03.2026 09:05');
    expect(ja.formatMonthDay(value), '3月12日');
    expect(ru.formatMonthDay(value), '12 мар.');
    expect(ja.formatFullDate(value), '2026年3月12日');
    // intl 在年份与“г.”之间用窄不换行空格（U+202F）。
    expect(ru.formatFullDate(value), '12 мар. 2026\u202fг.');
  });

  test('English month and eyebrow dates keep their previous patterns', () {
    final now = DateTime.now();
    final sameYear = DateTime(now.year, 3, 12, 9, 5);
    final lastYear = DateTime(now.year - 1, 3, 12);
    String weekday(String locale, DateTime value) =>
        DateFormat.E(locale).format(value);

    expect(en.formatMonthDay(sameYear), 'Mar 12');
    expect(en.formatFullDate(lastYear), 'Mar 12, ${now.year - 1}');
    expect(
      en.formatEyebrowDate(sameYear),
      'Mar 12 · ${weekday('en', sameYear)}',
    );
    expect(
      en.formatEyebrowDate(lastYear),
      'Mar 12, ${now.year - 1} · ${weekday('en', lastYear)}',
    );
    expect(
      ja.formatEyebrowDate(sameYear),
      '3月12日 · ${weekday('ja', sameYear)}',
    );
    expect(zh.formatEyebrowDate(sameYear), startsWith('3月12日 · 周'));
  });

  test('Russian plurals pick one / few / many by the number', () {
    String shape(int count) =>
        ru.exploreOnThisDayYearsAgo(count).replaceAll('$count', '#');
    expect(shape(1), shape(21));
    expect(shape(2), shape(24));
    expect(shape(5), shape(11));
    expect(shape(1), isNot(shape(2)));
    expect(shape(2), isNot(shape(5)));
    expect(ja.exploreOnThisDayYearsAgo(3), contains('3'));
  });
}
