import 'package:flutter/foundation.dart';
import 'package:tyme/tyme.dart';

import '../../../core/database/app_database.dart';

/// 农历年月日；[month] 为负数表示闰月（与 tyme 的约定一致）。
@immutable
class LunarYmd {
  const LunarYmd(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  bool get isLeap => month < 0;

  /// 公历日对应的农历日。
  static LunarYmd of(DateTime solar) {
    final lunar = SolarDay.fromYmd(
      solar.year,
      solar.month,
      solar.day,
    ).getLunarDay();
    return LunarYmd(lunar.getYear(), lunar.getMonth(), lunar.getDay());
  }

  /// 是否是真实存在的农历日（闰月当年确有、日数不超过当月天数）。
  bool get isValid {
    try {
      LunarDay.fromYmd(year, month, day);
      return true;
    } on ArgumentError {
      return false;
    }
  }

  /// 农历月日的中文写法，如“四月初一”“闰六月三十”。
  String get monthDayName {
    final lunar = LunarDay.fromYmd(year, month, day);
    return '${lunar.getLunarMonth().getName()}${lunar.getName()}';
  }

  /// 干支纪年，如“己亥”。
  String get yearName => LunarYear.fromYear(year).getSixtyCycle().getName();

  @override
  bool operator ==(Object other) =>
      other is LunarYmd &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

/// 一条纪念日的日期规则：首次日期、重复方式与（农历重复时的）农历快照。
///
/// 从数据库行解析而来，与展示无关；作为 provider family 的键需要值相等。
@immutable
class AnniversaryRule {
  const AnniversaryRule({
    required this.base,
    required this.recurrence,
    this.lunar,
  });

  /// 首次日期（本地零点）：不重复时就是那一天，重复时是第一次，“已经 X 天”
  /// 从这里算起。
  final DateTime base;
  final AnniversaryRecurrence recurrence;

  /// 农历每年重复时的农历月日（年份为首次那年）；其他规则为 null。
  final LunarYmd? lunar;

  /// 解析一行纪念日；日期非法（只可能来自损坏的数据）时为 null，页面跳过
  /// 这一行而不是整页报错。农历快照缺失或不存在时按首次日期重新换算。
  static AnniversaryRule? fromRow(Anniversary row) {
    final base = parseAnniversaryDate(row.baseDate);
    if (base == null) {
      return null;
    }
    final recurrence = AnniversaryRecurrence.parse(row.recurrence);
    if (recurrence != AnniversaryRecurrence.lunarYearly) {
      return AnniversaryRule(base: base, recurrence: recurrence);
    }
    final year = row.lunarYear;
    final month = row.lunarMonth;
    final day = row.lunarDay;
    var lunar = year == null || month == null || day == null
        ? null
        : LunarYmd(year, month, day);
    if (lunar == null || !lunar.isValid) {
      lunar = LunarYmd.of(base);
    }
    return AnniversaryRule(base: base, recurrence: recurrence, lunar: lunar);
  }

  /// 给编辑器用：按首次日期生成规则（农历重复时现算快照）。
  factory AnniversaryRule.forDate(
    DateTime date,
    AnniversaryRecurrence recurrence,
  ) {
    final base = DateTime(date.year, date.month, date.day);
    return AnniversaryRule(
      base: base,
      recurrence: recurrence,
      lunar: recurrence == AnniversaryRecurrence.lunarYearly
          ? LunarYmd.of(base)
          : null,
    );
  }

  bool get repeats => recurrence != AnniversaryRecurrence.once;

  @override
  bool operator ==(Object other) =>
      other is AnniversaryRule &&
      other.base == base &&
      other.recurrence == recurrence &&
      other.lunar == lunar;

  @override
  int get hashCode => Object.hash(base, recurrence, lunar);
}

/// 纪念日的一次出现。
@immutable
class AnniversaryOccurrence {
  const AnniversaryOccurrence({
    required this.date,
    required this.ordinal,
    this.adjusted = false,
  });

  /// 这一次落在的公历日（本地零点）。
  final DateTime date;

  /// 第几次：首次为 0，之后每年加 1（“第 N 周年”）；不重复的规则恒为 0。
  final int ordinal;

  /// 这一年没有对应的日子而顺延到了相近的一天：公历 2 月 29 日在平年取
  /// 2 月 28 日；农历闰月在没有该闰月的年份取同名平月；农历三十在小月取
  /// 廿九。
  final bool adjusted;

  @override
  bool operator ==(Object other) =>
      other is AnniversaryOccurrence &&
      other.date == date &&
      other.ordinal == ordinal &&
      other.adjusted == adjusted;

  @override
  int get hashCode => Object.hash(date, ordinal, adjusted);
}
