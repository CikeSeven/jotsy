import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/viewmodels/calendar_lunar_day.dart';
import 'package:node_diary/ui/diary_templates/models/built_in/diary_template_questions.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_variables.dart';
import 'package:node_diary/ui/diary_templates/viewmodels/diary_template_variable_values.dart';

void main() {
  final zh = lookupAppLocalizations(const Locale('zh'));
  final en = lookupAppLocalizations(const Locale('en'));

  setUpAll(() async {
    await initializeDateFormatting('zh');
    await initializeDateFormatting('en');
  });

  DiaryTemplateVariableValues compute(
    DateTime day, {
    DateTime? now,
    int shift = 0,
    bool english = false,
  }) => DiaryTemplateVariableValues.compute(
    l10n: english ? en : zh,
    diaryDate: day,
    now: now ?? DateTime(2026, 10, 18, 8, 5),
    questionShift: shift,
  );

  test('dates follow the interface language', () {
    final day = DateTime(2026, 10, 18);
    final values = compute(day);
    expect(values[DiaryTemplateVariable.date], '2026年10月18日');
    expect(values[DiaryTemplateVariable.weekday], '星期日');
    expect(values[DiaryTemplateVariable.time], '08:05');
    expect(values[DiaryTemplateVariable.month], '十月');
    final english = compute(day, english: true);
    expect(english[DiaryTemplateVariable.date], 'October 18, 2026');
    expect(english[DiaryTemplateVariable.weekday], 'Sunday');
  });

  test('a backfilled diary uses its own date, but the time is now', () {
    final values = compute(
      DateTime(2026, 10, 17),
      now: DateTime(2026, 10, 18, 21, 40),
    );
    expect(values.resolve('{{日期}} {{时间}}'), '2026年10月17日 21:40');
  });

  test('ISO week numbers across a year boundary', () {
    expect(isoWeekNumber(DateTime(2026, 1, 1)), 1); // 周四
    expect(isoWeekNumber(DateTime(2027, 1, 1)), 53); // 周五，属于 2026 第 53 周
    expect(isoWeekNumber(DateTime(2024, 12, 30)), 1); // 周一，属于 2025 第 1 周
    expect(isoWeekNumber(DateTime(2026, 10, 18)), 42);
  });

  test('day of year and year progress handle leap years', () {
    expect(
      compute(DateTime(2028, 12, 31))[DiaryTemplateVariable.dayOfYear],
      '366',
    );
    expect(
      compute(DateTime(2026, 3, 1))[DiaryTemplateVariable.dayOfYear],
      '60',
    );
    expect(
      compute(DateTime(2026, 12, 31))[DiaryTemplateVariable.yearProgress],
      '100%',
    );
    expect(
      compute(DateTime(2026, 7, 2))[DiaryTemplateVariable.yearProgress],
      '50%',
    );
  });

  test('lunar date and solar term come from the calendar', () {
    final day = DateTime(2026, 10, 18);
    final lunar = CalendarLunarDay.of(day);
    final values = compute(day);
    expect(values[DiaryTemplateVariable.lunar], lunar.date);
    // 10 月 18 日不是节气当天，仍有所在的节气期（寒露）。
    expect(lunar.term, isNull);
    expect(values[DiaryTemplateVariable.solarTerm], '寒露');
  });

  test('the question is fixed per day and moves with the shift', () {
    final questions = diaryTemplateQuestions(zh);
    final day = DateTime(2026, 10, 18);
    final first = compute(day)[DiaryTemplateVariable.question];
    expect(compute(day)[DiaryTemplateVariable.question], first);
    final next = compute(day, shift: 1)[DiaryTemplateVariable.question];
    expect(questions.indexOf(next!), (questions.indexOf(first!) + 1) % 30);
    expect(
      compute(DateTime(2026, 10, 19))[DiaryTemplateVariable.question],
      next,
    );
  });
}
