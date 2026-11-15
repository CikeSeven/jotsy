import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_languages.dart';
import 'package:node_diary/l10n/app_localizations_gen.dart';
import 'package:node_diary/ui/calendar/models/calendar_display_options.dart';
import 'package:node_diary/ui/home_widgets/viewmodels/home_widget_anniversary_section.dart';
import 'package:node_diary/ui/home_widgets/viewmodels/home_widget_month_section.dart';
import 'package:node_diary/ui/home_widgets/viewmodels/home_widget_plurals.dart';

import '../../support/anniversary_fixtures.dart';

void main() {
  final now = DateTime(2026, 11, 15, 9);
  AppLocalizations l10n(String code) => lookupAppLocalizations(Locale(code));

  setUpAll(() async {
    for (final language in appLanguages) {
      await initializeDateFormatting(language.code);
    }
  });

  group('plural forms', () {
    test('every interface language has plural samples', () {
      expect(
        homeWidgetPluralLanguages,
        containsAll(appLanguages.map((language) => language.code)),
      );
    });

    test('exports one form per category with the count as %d', () {
      expect(
        homeWidgetPluralForms(l10n('en'), l10n('en').anniversaryDaysLeft),
        <String, String>{'one': '%d day left', 'other': '%d days left'},
      );
      final ru = homeWidgetPluralForms(
        l10n('ru'),
        l10n('ru').anniversaryDaysLeft,
      );
      expect(ru.keys, containsAll(<String>['one', 'few', 'many', 'other']));
      expect(ru['many'], contains('%d'));
      expect(
        homeWidgetPluralForms(l10n('zh'), l10n('zh').anniversaryDaysToGo),
        <String, String>{'other': '天后'},
      );
    });
  });

  group('anniversaries', () {
    test('pinned first, then by the next date; a past one-off goes last', () {
      final items = buildHomeWidgetAnniversaries(
        now: now,
        l10n: l10n('zh'),
        rows: <Anniversary>[
          testAnniversary(
            id: 1,
            title: '搬家',
            baseDate: '2025-03-01',
            recurrence: AnniversaryRecurrence.once,
          ),
          testAnniversary(id: 2, title: '在一起', baseDate: '2021-12-03'),
          testAnniversary(
            id: 3,
            title: '生日',
            baseDate: '1990-01-20',
            isPinned: true,
          ),
        ],
      );
      expect(items.map((item) => item['title']), <String>['生日', '在一起', '搬家']);
      // 已经过去的不重复纪念日没有下一次。
      expect(items.last['occurrences'], isEmpty);
      final together = items[1]['occurrences']! as List;
      expect(together, hasLength(kHomeWidgetAnniversaryOccurrences));
      expect((together.first as Map)['date'], '2026-12-03');
      expect((together.first as Map)['ordinalLabel'], '第 5 周年');
    });

    test('an anniversary today says so', () {
      final items = buildHomeWidgetAnniversaries(
        now: now,
        l10n: l10n('zh'),
        rows: <Anniversary>[
          testAnniversary(id: 1, title: '妈妈生日', baseDate: '1968-11-15'),
        ],
      );
      final first = (items.single['occurrences']! as List).first as Map;
      expect(first['date'], '2026-11-15');
      expect(first['todayLabel'], '今天是第 58 周年');
    });
  });

  group('mood calendar', () {
    Map<String, Object?> dayOf(
      Map<String, Object?> section,
      String month,
      int day,
    ) =>
        (((section['months']! as Map)[month]! as Map)['days']! as Map)['$day']
            as Map<String, Object?>;

    test('the day mood wins over the average of the entries', () {
      final section = buildHomeWidgetMonthSection(
        now: now,
        l10n: l10n('zh'),
        markers: <DiaryCalendarMarker>[
          DiaryCalendarMarker(
            diaryId: 'a',
            createdAt: DateTime(2026, 11, 3, 20),
            moodEmoji: '😄',
          ),
          DiaryCalendarMarker(
            diaryId: 'b',
            createdAt: DateTime(2026, 11, 4, 20),
          ),
        ],
        dayMoods: <String, DayMood>{'2026-11-03': DayMood.awful},
        moodOptions: const <String>[
          '😭',
          '😢',
          '😞',
          '😕',
          '😐',
          '🙂',
          '😊',
          '😄',
          '😀',
          '🤩',
        ],
        weekStart: CalendarWeekStart.locale,
      );
      expect(dayOf(section, '2026-11', 3)['b'], DayMood.awful.index);
      expect(dayOf(section, '2026-11', 3)['w'], 1);
      // 写了但没选心情。
      expect(dayOf(section, '2026-11', 4)['b'], -1);
      final months = (section['months']! as Map).keys;
      expect(months, <String>['2026-09', '2026-10', '2026-11']);
      expect(
        ((section['months']! as Map)['2026-11']! as Map)['writtenLabel'],
        '写了 2 天',
      );
    });

    test('marks public holidays', () {
      final section = buildHomeWidgetMonthSection(
        now: DateTime(2026, 10, 2),
        l10n: l10n('zh'),
        markers: const <DiaryCalendarMarker>[],
        dayMoods: const <String, DayMood>{},
        moodOptions: const <String>[],
        weekStart: CalendarWeekStart.locale,
      );
      expect(dayOf(section, '2026-10', 1)['h'], '休');
    });

    test('the week starts where the calendar says', () {
      expect(
        homeWidgetFirstWeekday(CalendarWeekStart.locale, 'zh'),
        DateTime.monday,
      );
      expect(
        homeWidgetFirstWeekday(CalendarWeekStart.locale, 'en'),
        DateTime.sunday,
      );
      expect(
        homeWidgetFirstWeekday(CalendarWeekStart.sunday, 'zh'),
        DateTime.sunday,
      );
      expect(
        homeWidgetFirstWeekday(CalendarWeekStart.monday, 'en'),
        DateTime.monday,
      );
    });
  });
}
