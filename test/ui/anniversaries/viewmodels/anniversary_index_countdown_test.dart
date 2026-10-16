import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/anniversaries/viewmodels/anniversary_calendar_index.dart';
import 'package:node_diary/ui/anniversaries/viewmodels/anniversary_countdown.dart';
import 'package:node_diary/ui/anniversaries/viewmodels/anniversary_rule.dart';

import '../../../support/anniversary_fixtures.dart';

void main() {
  group('calendar index', () {
    final rows = <Anniversary>[
      testAnniversary(id: 1, title: '纪念日', baseDate: '2020-10-31'),
      testAnniversary(id: 2, title: '生日', baseDate: '2000-11-01'),
      testAnniversary(id: 3, title: '同一天', baseDate: '2021-10-31'),
      testAnniversary(id: 4, title: '坏数据', baseDate: 'not a date'),
    ];

    test('days outside the focused month resolve from their own month', () {
      final index = AnniversaryCalendarIndex(rows);
      // 10 月的网格首尾带出 9 月底与 11 月初。
      expect(index.titleOn(DateTime.utc(2026, 11, 1)), '生日');
      expect(index.marksOn(DateTime(2026, 10, 31)).map((m) => m.row.id), <int>[
        1,
        3,
      ]);
      expect(index.titleOn(DateTime(2026, 10, 31)), '纪念日');
      expect(index.marksOn(DateTime(2026, 10, 31)).first.occurrence.ordinal, 6);
      expect(index.titleOn(DateTime(2026, 10, 30)), isNull);
    });

    test('unparsable rows are skipped and the empty index is cheap', () {
      final index = AnniversaryCalendarIndex(rows);
      expect(index.titleOn(DateTime(2026, 1, 1)), isNull);
      expect(AnniversaryCalendarIndex.empty.isEmpty, isTrue);
      expect(AnniversaryCalendarIndex.empty.marksOn(DateTime(2026)), isEmpty);
    });
  });

  group('countdown', () {
    final today = DateTime(2026, 10, 16);

    AnniversaryCountdown countdownOf(Anniversary row) =>
        AnniversaryCountdown.of(AnniversaryRule.fromRow(row)!, today);

    test('phases and day counts', () {
      final yearly = countdownOf(
        testAnniversary(id: 1, title: 'a', baseDate: '2020-10-16'),
      );
      expect(yearly.phase, AnniversaryPhase.today);
      expect(yearly.daysUntilNext, 0);
      expect(yearly.next?.ordinal, 6);
      expect(yearly.daysSinceBase, 2191);

      final countdown = countdownOf(
        testAnniversary(
          id: 2,
          title: 'b',
          baseDate: '2026-12-31',
          recurrence: AnniversaryRecurrence.once,
        ),
      );
      expect(countdown.phase, AnniversaryPhase.upcoming);
      expect(countdown.daysUntilNext, 76);
      expect(countdown.daysSinceBase, -76);

      final passed = countdownOf(
        testAnniversary(
          id: 3,
          title: 'c',
          baseDate: '2026-10-01',
          recurrence: AnniversaryRecurrence.once,
        ),
      );
      expect(passed.phase, AnniversaryPhase.past);
      expect(passed.next, isNull);
      expect(passed.daysSinceBase, 15);
    });

    test('list order: pinned, soonest next, then passed days newest first', () {
      final rows = <Anniversary>[
        testAnniversary(
          id: 1,
          title: 'old once',
          baseDate: '2020-01-01',
          recurrence: AnniversaryRecurrence.once,
        ),
        testAnniversary(id: 2, title: 'far', baseDate: '2020-09-01'),
        testAnniversary(id: 3, title: 'soon', baseDate: '2020-10-20'),
        testAnniversary(
          id: 4,
          title: 'pinned',
          baseDate: '2020-08-01',
          isPinned: true,
        ),
        testAnniversary(
          id: 5,
          title: 'recent once',
          baseDate: '2026-10-01',
          recurrence: AnniversaryRecurrence.once,
        ),
      ];
      final sorted = <(Anniversary, AnniversaryCountdown)>[
        for (final row in rows) (row, countdownOf(row)),
      ]..sort(AnniversaryCountdown.compareForList);
      expect(sorted.map((e) => e.$1.title), <String>[
        'pinned',
        'soon',
        'far',
        'recent once',
        'old once',
      ]);
    });
  });
}
