import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/utils/precise_time_formatter.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('zh');
  });

  group('PreciseTimeFormatter', () {
    test('同一天仅显示小时分钟', () {
      final now = DateTime(2026, 3, 11, 21, 30, 59);
      final target = DateTime(2026, 3, 11, 12, 22, 10);

      final result = PreciseTimeFormatter.format(
        target: target,
        now: now,
        l10n: lookupAppLocalizations(const Locale('zh')),
      );

      expect(result, '12:22');
    });

    test('同一年不同天显示月日和时间', () {
      final now = DateTime(2026, 3, 11, 21, 30);
      final target = DateTime(2026, 2, 9, 7, 5);

      final result = PreciseTimeFormatter.format(
        target: target,
        now: now,
        l10n: lookupAppLocalizations(const Locale('zh')),
      );

      expect(result, '2月9日 07:05');
    });

    test('跨年显示完整年月日和时间', () {
      final now = DateTime(2026, 3, 11, 21, 30);
      final target = DateTime(2013, 3, 23, 12, 13);

      final result = PreciseTimeFormatter.format(
        target: target,
        now: now,
        l10n: lookupAppLocalizations(const Locale('zh')),
      );

      expect(result, '2013年3月23日 12:13');
    });

    test('英文环境显示英文日期格式', () {
      final now = DateTime(2026, 3, 11, 21, 30);
      final target = DateTime(2026, 2, 9, 7, 5);

      final result = PreciseTimeFormatter.format(
        target: target,
        now: now,
        l10n: lookupAppLocalizations(const Locale('en')),
      );

      expect(result, 'Feb 9 07:05');
    });
  });
}
