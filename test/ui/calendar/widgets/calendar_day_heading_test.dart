import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/viewmodels/calendar_holiday_day.dart';
import 'package:node_diary/ui/calendar/viewmodels/calendar_lunar_day.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_day_heading.dart';

import '../../../support/expressive_test_theme.dart';

void main() {
  Future<void> pumpHeading(
    WidgetTester tester,
    DateTime day, {
    bool lunar = true,
    bool holiday = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        theme: expressiveTestTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: CalendarDayHeading(
              day: day,
              now: DateTime(2026, 10, 16),
              entryCount: 0,
              charCount: 0,
              lunar: lunar ? CalendarLunarDay.of(day) : null,
              holiday: holiday ? CalendarHolidayDay.of(day) : null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String detailLine(DateTime day) => '农历${CalendarLunarDay.of(day).date}';

  testWidgets('the lunar line ends with the holiday', (tester) async {
    final national = DateTime(2026, 10, 1);
    await pumpHeading(tester, national);
    expect(find.text('${detailLine(national)} · 国庆节 · 休'), findsOneWidget);

    final secondDay = DateTime(2026, 10, 2);
    await pumpHeading(tester, secondDay);
    expect(find.text('${detailLine(secondDay)} · 国庆节 · 休'), findsOneWidget);

    final qingming = DateTime(2026, 4, 5);
    await pumpHeading(tester, qingming);
    expect(find.text('${detailLine(qingming)} · 清明 · 休'), findsOneWidget);

    final makeUp = DateTime(2026, 9, 20);
    await pumpHeading(tester, makeUp);
    expect(find.text('${detailLine(makeUp)} · 调休上班'), findsOneWidget);
  });

  testWidgets('without lunar dates only the holiday is written', (
    tester,
  ) async {
    await pumpHeading(tester, DateTime(2026, 10, 1), lunar: false);
    expect(find.text('国庆节 · 休'), findsOneWidget);

    await pumpHeading(tester, DateTime(2026, 10, 10), lunar: false);
    expect(find.text('调休上班'), findsOneWidget);
  });

  testWidgets('the second line grows in instead of popping', (tester) async {
    await pumpHeading(tester, DateTime(2026, 10, 9), lunar: false);
    final plain = tester.getSize(find.byType(CalendarDayHeading)).height;

    await pumpHeading(tester, DateTime(2026, 10, 10), lunar: false);
    final settled = tester.getSize(find.byType(CalendarDayHeading)).height;
    expect(settled, greaterThan(plain));

    await pumpHeading(tester, DateTime(2026, 10, 9), lunar: false);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        theme: expressiveTestTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: CalendarDayHeading(
              day: DateTime(2026, 10, 10),
              now: DateTime(2026, 10, 16),
              entryCount: 0,
              charCount: 0,
              holiday: CalendarHolidayDay.of(DateTime(2026, 10, 10)),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));
    final midway = tester.getSize(find.byType(CalendarDayHeading)).height;
    expect(midway, greaterThan(plain));
    expect(midway, lessThan(settled));
    await tester.pumpAndSettle();
  });
}
