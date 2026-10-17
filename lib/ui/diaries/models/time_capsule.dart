import 'dart:math' as math;

enum TimeCapsulePrecision { date, minute }

/// 胶囊选择页的快捷预设：从选择时刻起往后推一段固定时长。
enum TimeCapsulePreset {
  week(Duration(days: 7)),
  month(Duration(days: 30)),
  year(Duration(days: 365));

  const TimeCapsulePreset(this.offset);

  final Duration offset;
}

class TimeCapsuleSchedule {
  const TimeCapsuleSchedule({required this.unlockAt, required this.precision});

  final DateTime unlockAt;
  final TimeCapsulePrecision precision;

  DateTime get normalizedUnlockAt {
    return normalizeUnlockAt(unlockAt, precision: precision);
  }

  /// 按精度归一后的解封时刻是否仍晚于 [now]。
  ///
  /// “只按日期”会归一到当天零点：选今天、或草稿恢复时那天已过，都会得到
  /// 一个写入即解封的胶囊，发布前必须拦下。
  bool isUnlockInFuture(DateTime now) => normalizedUnlockAt.isAfter(now);

  @override
  bool operator ==(Object other) =>
      other is TimeCapsuleSchedule &&
      other.unlockAt == unlockAt &&
      other.precision == precision;

  @override
  int get hashCode => Object.hash(unlockAt, precision);

  /// 快捷预设对应的解封时刻。
  static DateTime presetUnlockAt(TimeCapsulePreset preset, DateTime now) =>
      now.add(preset.offset);

  /// 该精度下可选的最早解封时刻：按日期是明天零点（今天零点已过去），
  /// 按分钟是下一个整分钟。选择器的下限与发布前校验共用这一规则。
  static DateTime earliestUnlockAt(
    TimeCapsulePrecision precision,
    DateTime now,
  ) {
    final local = now.toLocal();
    return switch (precision) {
      TimeCapsulePrecision.date => DateTime(
        local.year,
        local.month,
        local.day + 1,
      ),
      TimeCapsulePrecision.minute => DateTime(
        local.year,
        local.month,
        local.day,
        local.hour,
        local.minute + 1,
      ),
    };
  }

  /// 可选的最晚解封时刻：十年后的同一天。
  static DateTime latestUnlockAt(DateTime now) {
    final local = now.toLocal();
    return DateTime(local.year + 10, local.month, local.day);
  }

  /// 把待选解封时刻限制在 [earliestUnlockAt]、[latestUnlockAt] 之间。
  ///
  /// 选择器要求初始值不早于下限：切换精度（分钟 → 日期会把下限推到明天）、
  /// 或已有设置在打开前过期时，都要先夹到可选范围内再交给选择器。
  static DateTime clampUnlockAt(
    DateTime value, {
    required TimeCapsulePrecision precision,
    required DateTime now,
  }) {
    final earliest = earliestUnlockAt(precision, now);
    if (value.isBefore(earliest)) {
      return earliest;
    }
    final latest = latestUnlockAt(now);
    return value.isAfter(latest) ? latest : value;
  }

  /// 打开胶囊选择页时的初始待选时刻：沿用已有设置，没有则默认一周后。
  static DateTime initialPendingUnlockAt(
    TimeCapsuleSchedule? schedule,
    DateTime now,
  ) {
    final precision = schedule?.precision ?? TimeCapsulePrecision.date;
    return clampUnlockAt(
      schedule?.unlockAt ?? presetUnlockAt(TimeCapsulePreset.week, now),
      precision: precision,
      now: now,
    );
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
