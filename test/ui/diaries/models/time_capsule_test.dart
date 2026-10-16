import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/time_capsule.dart';

void main() {
  group('TimeCapsule', () {
    test('treats future unlock time as locked', () {
      final state = TimeCapsuleState.fromFields(
        lockedAt: DateTime(2026, 1, 1, 9),
        unlockAt: DateTime(2026, 1, 8, 9),
        now: DateTime(2026, 1, 2, 9),
      );

      expect(state.isCapsule, isTrue);
      expect(state.isLocked, isTrue);
      expect(state.remainingDays, 6);
    });

    test('treats reached unlock time as readable capsule', () {
      final state = TimeCapsuleState.fromFields(
        lockedAt: DateTime(2026, 1, 1, 9),
        unlockAt: DateTime(2026, 1, 8, 9),
        now: DateTime(2026, 1, 8, 9),
      );

      expect(state.isCapsule, isTrue);
      expect(state.isLocked, isFalse);
      expect(state.remainingDays, 0);
    });

    test('normalizes date precision to local day start', () {
      final normalized = TimeCapsuleSchedule.normalizeUnlockAt(
        DateTime(2026, 5, 20, 18, 45),
        precision: TimeCapsulePrecision.date,
      );

      expect(normalized, DateTime(2026, 5, 20));
    });

    test('uses unlock date as diary created date when sealed', () {
      final fallbackPublishAt = DateTime(2026, 1, 1, 9);
      final schedule = TimeCapsuleSchedule(
        unlockAt: DateTime(2027, 5, 20, 18, 45),
        precision: TimeCapsulePrecision.minute,
      );

      final createdAt = TimeCapsuleSchedule.resolveDiaryCreatedAt(
        schedule: schedule,
        fallbackPublishAt: fallbackPublishAt,
      );

      expect(createdAt, DateTime(2027, 5, 20, 18, 45));
    });
  });

  group('TimeCapsuleSchedule picker rules', () {
    final now = DateTime(2026, 10, 16, 14, 25, 30);

    test('presets count from the moment they are tapped', () {
      expect(
        TimeCapsuleSchedule.presetUnlockAt(TimeCapsulePreset.week, now),
        DateTime(2026, 10, 23, 14, 25, 30),
      );
      expect(
        TimeCapsuleSchedule.presetUnlockAt(TimeCapsulePreset.year, now),
        now.add(const Duration(days: 365)),
      );
    });

    test('date precision starts tomorrow, minute precision next minute', () {
      expect(
        TimeCapsuleSchedule.earliestUnlockAt(TimeCapsulePrecision.date, now),
        DateTime(2026, 10, 17),
      );
      expect(
        TimeCapsuleSchedule.earliestUnlockAt(TimeCapsulePrecision.minute, now),
        DateTime(2026, 10, 16, 14, 26),
      );
    });

    test('pending values are clamped into the selectable range', () {
      expect(
        TimeCapsuleSchedule.clampUnlockAt(
          DateTime(2026, 10, 16, 18),
          precision: TimeCapsulePrecision.date,
          now: now,
        ),
        DateTime(2026, 10, 17),
      );
      expect(
        TimeCapsuleSchedule.clampUnlockAt(
          DateTime(2040),
          precision: TimeCapsulePrecision.minute,
          now: now,
        ),
        DateTime(2036, 10, 16),
      );
      final inRange = DateTime(2026, 11, 2, 8, 15);
      expect(
        TimeCapsuleSchedule.clampUnlockAt(
          inRange,
          precision: TimeCapsulePrecision.minute,
          now: now,
        ),
        inRange,
      );
    });

    test('the picker opens on the current schedule or a week later', () {
      expect(
        TimeCapsuleSchedule.initialPendingUnlockAt(null, now),
        DateTime(2026, 10, 23, 14, 25, 30),
      );
      final expired = TimeCapsuleSchedule(
        unlockAt: DateTime(2026, 10, 1),
        precision: TimeCapsulePrecision.date,
      );
      expect(
        TimeCapsuleSchedule.initialPendingUnlockAt(expired, now),
        DateTime(2026, 10, 17),
      );
    });

    test('a date-only capsule for today is no longer in the future', () {
      TimeCapsuleSchedule dated(DateTime day) => TimeCapsuleSchedule(
        unlockAt: day,
        precision: TimeCapsulePrecision.date,
      );
      expect(dated(DateTime(2026, 10, 16, 20)).isUnlockInFuture(now), isFalse);
      expect(dated(DateTime(2026, 10, 17)).isUnlockInFuture(now), isTrue);
      expect(
        TimeCapsuleSchedule(
          unlockAt: DateTime(2026, 10, 16, 20),
          precision: TimeCapsulePrecision.minute,
        ).isUnlockInFuture(now),
        isTrue,
      );
    });

    test('schedules compare by value', () {
      final a = TimeCapsuleSchedule(
        unlockAt: DateTime(2027),
        precision: TimeCapsulePrecision.date,
      );
      final b = TimeCapsuleSchedule(
        unlockAt: DateTime(2027),
        precision: TimeCapsulePrecision.date,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
