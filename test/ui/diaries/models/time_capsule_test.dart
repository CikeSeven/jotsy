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
}
