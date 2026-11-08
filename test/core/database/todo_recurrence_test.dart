import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/todo_recurrence.dart';
import 'package:node_diary/core/database/todo_rules.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day);

void main() {
  group('nextAfter', () {
    test('daily with an interval skips by the interval from the anchor', () {
      final rule = TodoRepeatRule(
        frequency: TodoRepeatFrequency.daily,
        interval: 3,
        anchor: d(2026, 11, 1),
      );
      expect(TodoRecurrence.nextAfter(rule, d(2026, 11, 1)), d(2026, 11, 4));
      expect(TodoRecurrence.nextAfter(rule, d(2026, 11, 5)), d(2026, 11, 7));
      expect(
        TodoRecurrence.nextAfter(rule, d(2026, 10, 1)),
        d(2026, 11, 1),
        reason: '起点之前没有任何一次',
      );
    });

    test('weekly picks the selected weekdays in aligned weeks', () {
      // 2026-11-02 是周一。
      final rule = TodoRepeatRule(
        frequency: TodoRepeatFrequency.weekly,
        interval: 2,
        weekdays: const <int>[DateTime.monday, DateTime.thursday],
        anchor: d(2026, 11, 2),
      );
      expect(TodoRecurrence.nextAfter(rule, d(2026, 11, 2)), d(2026, 11, 5));
      expect(
        TodoRecurrence.nextAfter(rule, d(2026, 11, 5)),
        d(2026, 11, 16),
        reason: '隔一周：跳过 11-09 那一周',
      );
    });

    test('weekly without weekdays repeats on the anchor weekday', () {
      final rule = TodoRepeatRule(
        frequency: TodoRepeatFrequency.weekly,
        anchor: d(2026, 11, 4),
      );
      expect(TodoRecurrence.nextAfter(rule, d(2026, 11, 4)), d(2026, 11, 11));
    });

    test('monthly on the 31st clamps short months and comes back', () {
      final rule = TodoRepeatRule(
        frequency: TodoRepeatFrequency.monthly,
        anchor: d(2026, 1, 31),
      );
      expect(TodoRecurrence.nextAfter(rule, d(2026, 1, 31)), d(2026, 2, 28));
      expect(TodoRecurrence.nextAfter(rule, d(2026, 2, 28)), d(2026, 3, 31));
      expect(TodoRecurrence.nextAfter(rule, d(2026, 3, 31)), d(2026, 4, 30));
    });

    test('monthly by weekday ordinal and last day', () {
      // 2026-11-11 是 11 月第二个周三。
      final ordinal = TodoRepeatRule(
        frequency: TodoRepeatFrequency.monthly,
        monthlyMode: TodoMonthlyMode.weekdayOrdinal,
        anchor: d(2026, 11, 11),
      );
      expect(
        TodoRecurrence.nextAfter(ordinal, d(2026, 11, 11)),
        d(2026, 12, 9),
      );
      final last = TodoRepeatRule(
        frequency: TodoRepeatFrequency.monthly,
        monthlyMode: TodoMonthlyMode.lastDay,
        anchor: d(2026, 1, 15),
      );
      expect(TodoRecurrence.nextAfter(last, d(2026, 1, 15)), d(2026, 1, 31));
      expect(TodoRecurrence.nextAfter(last, d(2026, 1, 31)), d(2026, 2, 28));
    });

    test('fifth weekday falls back to the last one of the month', () {
      // 2026-12-30 是 12 月第五个周三；2027 年 1 月只有四个周三（6、13、
      // 20、27 日），取最后一个。
      final rule = TodoRepeatRule(
        frequency: TodoRepeatFrequency.monthly,
        monthlyMode: TodoMonthlyMode.weekdayOrdinal,
        anchor: d(2026, 12, 30),
      );
      expect(TodoRecurrence.nextAfter(rule, d(2026, 12, 30)), d(2027, 1, 27));
    });

    test('yearly on Feb 29 uses Feb 28 in common years', () {
      final rule = TodoRepeatRule(
        frequency: TodoRepeatFrequency.yearly,
        anchor: d(2024, 2, 29),
      );
      expect(TodoRecurrence.nextAfter(rule, d(2024, 2, 29)), d(2025, 2, 28));
      expect(TodoRecurrence.nextAfter(rule, d(2027, 3, 1)), d(2028, 2, 29));
    });

    test('until ends the series', () {
      final rule = TodoRepeatRule(
        frequency: TodoRepeatFrequency.daily,
        anchor: d(2026, 11, 1),
        until: d(2026, 11, 3),
      );
      expect(TodoRecurrence.nextAfter(rule, d(2026, 11, 2)), d(2026, 11, 3));
      expect(TodoRecurrence.nextAfter(rule, d(2026, 11, 3)), isNull);
    });

    test('legal workdays skip holidays and include make-up workdays', () {
      final rule = TodoRepeatRule(
        frequency: TodoRepeatFrequency.legalWorkdays,
        anchor: d(2025, 9, 1),
      );
      // 2025 年国庆中秋：10-01～10-08 放假，9-28（周日）与 10-11（周六）上班。
      expect(TodoRecurrence.isLegalWorkday(d(2025, 9, 28)), isTrue);
      expect(TodoRecurrence.isLegalWorkday(d(2025, 10, 3)), isFalse);
      expect(TodoRecurrence.nextAfter(rule, d(2025, 9, 26)), d(2025, 9, 28));
      expect(TodoRecurrence.nextAfter(rule, d(2025, 9, 30)), d(2025, 10, 9));
    });

    test('occurrencesBetween lists every occurrence in range', () {
      final rule = TodoRepeatRule(
        frequency: TodoRepeatFrequency.weekly,
        weekdays: const <int>[DateTime.saturday, DateTime.sunday],
        anchor: d(2026, 11, 1),
      );
      expect(
        TodoRecurrence.occurrencesBetween(
          rule,
          d(2026, 11, 1),
          d(2026, 11, 15),
        ),
        <DateTime>[
          d(2026, 11, 1),
          d(2026, 11, 7),
          d(2026, 11, 8),
          d(2026, 11, 14),
          d(2026, 11, 15),
        ],
      );
      expect(TodoRecurrence.isOccurrence(rule, d(2026, 11, 7)), isTrue);
      expect(TodoRecurrence.isOccurrence(rule, d(2026, 11, 9)), isFalse);
    });
  });

  group('nextDueAfterCompletion', () {
    test('due basis jumps past today when completed late', () {
      final rule = TodoRepeatRule(
        frequency: TodoRepeatFrequency.weekly,
        anchor: d(2026, 10, 5),
      );
      expect(
        TodoRecurrence.nextDueAfterCompletion(
          rule,
          currentDue: d(2026, 10, 12),
          completedOn: d(2026, 11, 4),
          doneCount: 1,
        ),
        d(2026, 11, 9),
      );
    });

    test('due basis completed early moves to the following occurrence', () {
      final rule = TodoRepeatRule(
        frequency: TodoRepeatFrequency.weekly,
        anchor: d(2026, 11, 2),
      );
      expect(
        TodoRecurrence.nextDueAfterCompletion(
          rule,
          currentDue: d(2026, 11, 9),
          completedOn: d(2026, 11, 4),
          doneCount: 1,
        ),
        d(2026, 11, 16),
      );
    });

    test('completion basis counts from the completion day', () {
      final rule = TodoRepeatRule(
        frequency: TodoRepeatFrequency.daily,
        interval: 3,
        basis: TodoRepeatBasis.completion,
        anchor: d(2026, 11, 1),
      );
      expect(
        TodoRecurrence.nextDueAfterCompletion(
          rule,
          currentDue: d(2026, 11, 1),
          completedOn: d(2026, 11, 5),
          doneCount: 1,
        ),
        d(2026, 11, 8),
      );
    });

    test('count ends the series after the last completion', () {
      final rule = TodoRepeatRule(
        frequency: TodoRepeatFrequency.daily,
        anchor: d(2026, 11, 1),
        count: 2,
      );
      expect(
        TodoRecurrence.nextDueAfterCompletion(
          rule,
          currentDue: d(2026, 11, 1),
          completedOn: d(2026, 11, 1),
          doneCount: 1,
        ),
        d(2026, 11, 2),
      );
      expect(
        TodoRecurrence.nextDueAfterCompletion(
          rule,
          currentDue: d(2026, 11, 2),
          completedOn: d(2026, 11, 2),
          doneCount: 2,
        ),
        isNull,
      );
    });
  });
}
