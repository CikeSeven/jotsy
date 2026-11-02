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

  test('a bare time keeps the locale\'s Hm format', () {
    final day = DateTime(2026, 10, 18);
    final evening = DateTime(2026, 10, 18, 20, 5, 9);
    final zhValues = compute(day, now: evening);
    expect(zhValues.resolve('{{时间}} {{time}} {{ 时间 }}'), '20:05 20:05 20:05');
    expect(
      compute(day, now: evening, english: true).resolve('{{time}}'),
      '20:05',
    );
  });

  test('a time format after the colon formats now in that pattern', () {
    final day = DateTime(2026, 10, 17);
    final evening = DateTime(2026, 10, 18, 20, 5, 9);
    final zhValues = compute(day, now: evening);
    expect(zhValues.resolve('{{时间:HH:mm:ss}}'), '20:05:09');
    expect(zhValues.resolve('{{时间:ah:mm}}'), '下午8:05');
    expect(zhValues.resolve('{{时间：H点mm分}}'), '20点05分');
    // 补写的日记：日期仍是那一天，时间是当下。
    expect(zhValues.resolve('{{日期}} {{时间:HH:mm}}'), '2026年10月17日 20:05');
    final enValues = compute(day, now: evening, english: true);
    expect(enValues.resolve('{{time:h:mm a}}'), '8:05 PM');
    expect(enValues.resolve("{{time:h 'o''clock'}}"), "8 o'clock");
    // 与骨架同名的写法按 intl 换成这个语言的本地图案（CLDR 在英文时间与
    // AM/PM 之间用窄不换行空格 U+202F）。
    expect(enValues.resolve('{{time:jm}}'), '8:05\u202fPM');
    // 中英别名在任一界面语言里都认，格式按界面语言。
    expect(enValues.resolve('{{时间:ah:mm}}'), 'PM8:05');
    expect(zhValues.resolve('{{time:h:mm a}}'), '8:05 下午');
  });

  test('a time format that cannot be used stays as written', () {
    final values = compute(
      DateTime(2026, 10, 18),
      now: DateTime(2026, 10, 18, 20, 5, 9),
    );
    for (final token in <String>[
      '{{时间:}}', // 空格式
      '{{时间:hh:mm A}}', // A 不是 intl 的字段字母
      '{{时间:foo}}',
      "{{时间:HH 'o}}", // 单引号没有闭合
      '{{时间:zzzz}}', // intl 没有实现时区，会输出空串
      '{{time:jmz}}', // 骨架换成的本地图案里有时区
      '{{时间:下午}}', // 没有任何字段
      "{{时间:'now'}}",
      '{{时间:EEEEEE}}', // intl 格式化时抛 UnsupportedError
    ]) {
      expect(values.resolve('写于 $token'), '写于 $token', reason: token);
    }
    // 其他变量不收格式，原样保留。
    expect(values.resolve('{{日期:yyyy}}'), '{{日期:yyyy}}');
  });

  test('every accepted field letter formats without throwing', () {
    final moment = DateTime(2026, 10, 18, 20, 5, 9, 123);
    for (final locale in <String>['zh', 'en']) {
      for (final letter in 'GyMkSEahKHcLQdDms'.split('')) {
        for (var width = 1; width <= 5; width++) {
          final pattern = letter * width;
          expect(
            formatDiaryTemplateMoment(moment, pattern, locale),
            isNotNull,
            reason: '$locale $pattern',
          );
        }
      }
    }
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
