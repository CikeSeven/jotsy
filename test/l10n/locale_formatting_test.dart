import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/energy_battery_indicator.dart';

void main() {
  final zh = lookupAppLocalizations(const Locale('zh'));
  final en = lookupAppLocalizations(const Locale('en'));

  setUpAll(() async {
    await initializeDateFormatting('zh');
    await initializeDateFormatting('en');
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
}
