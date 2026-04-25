import 'dart:math' as math;

enum TimeCapsulePrecision { date, minute }

class TimeCapsuleSchedule {
  const TimeCapsuleSchedule({required this.unlockAt, required this.precision});

  final DateTime unlockAt;
  final TimeCapsulePrecision precision;

  DateTime get normalizedUnlockAt {
    return normalizeUnlockAt(unlockAt, precision: precision);
  }

  static DateTime normalizeUnlockAt(
    DateTime value, {
    required TimeCapsulePrecision precision,
  }) {
    final local = value.toLocal();
    return switch (precision) {
      TimeCapsulePrecision.date => DateTime(local.year, local.month, local.day),
      TimeCapsulePrecision.minute => DateTime(
        local.year,
        local.month,
        local.day,
        local.hour,
        local.minute,
      ),
    };
  }

  static TimeCapsulePrecision parsePrecision(String? raw) {
    return switch (raw?.trim()) {
      'minute' => TimeCapsulePrecision.minute,
      _ => TimeCapsulePrecision.date,
    };
  }

  static String encodePrecision(TimeCapsulePrecision precision) {
    return switch (precision) {
      TimeCapsulePrecision.date => 'date',
      TimeCapsulePrecision.minute => 'minute',
    };
  }

  static DateTime resolveDiaryCreatedAt({
    required TimeCapsuleSchedule? schedule,
    required DateTime fallbackPublishAt,
  }) {
    return schedule?.normalizedUnlockAt ?? fallbackPublishAt;
  }
}

class TimeCapsuleState {
  const TimeCapsuleState({
    required this.lockedAt,
    required this.unlockAt,
    required this.now,
  });

  factory TimeCapsuleState.fromFields({
    required DateTime? lockedAt,
    required DateTime? unlockAt,
    required DateTime now,
  }) {
    return TimeCapsuleState(lockedAt: lockedAt, unlockAt: unlockAt, now: now);
  }

  final DateTime? lockedAt;
  final DateTime? unlockAt;
  final DateTime now;

  bool get isCapsule => lockedAt != null && unlockAt != null;

  bool get isLocked {
    final target = unlockAt;
    return target != null && now.isBefore(target);
  }

  int get remainingDays {
    final target = unlockAt;
    if (target == null || !isLocked) {
      return 0;
    }
    final remaining = target.difference(now);
    return math.max(1, (remaining.inHours / 24).ceil());
  }

  Duration get remainingDuration {
    final target = unlockAt;
    if (target == null || !isLocked) {
      return Duration.zero;
    }
    return target.difference(now);
  }
}
