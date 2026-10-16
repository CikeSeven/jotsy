import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'calendar_display_enums.dart';

export 'calendar_display_enums.dart';

/// 日历页的显示选项。
///
/// 输入：设置服务中保存的 JSON 字符串；输出：不可变的选项对象。无副作用。
///
/// 兼容策略：整份选项存为一个 JSON 键（而不是十几个独立偏好），新增字段
/// 不必改动设置服务的构造参数；解析时逐字段容错——缺失、类型不符或未知的
/// 枚举名都回退到该字段默认值，而不是整份作废，旧版本写入或备份导入的
/// 局部损坏不会把用户其余的选择一起清掉。
@immutable
class CalendarDisplayOptions {
  const CalendarDisplayOptions({
    this.cellStyle = CalendarCellStyle.mood,
    this.heatBasis = CalendarHeatBasis.entries,
    this.moodAggregation = CalendarMoodAggregation.average,
    this.showCountBadge = true,
    this.showCapsuleBadge = true,
    this.showWeatherBadge = false,
    this.weekStart = CalendarWeekStart.locale,
    this.highlightWeekends = false,
    this.showWeekNumbers = false,
    this.fixedSixWeeks = false,
    this.defaultFormat = CalendarDefaultFormat.month,
    this.rememberedFormat = CalendarGridFormat.month,
    this.showMonthSummary = true,
    this.dayContentStyle = CalendarDayContentStyle.timeline,
    this.showOnThisDay = true,
    this.yearBasis = CalendarYearBasis.mood,
    this.lunarMode = CalendarLunarMode.locale,
  });

  /// 解析持久化的 JSON；null、空串或损坏时返回默认选项。
  factory CalendarDisplayOptions.decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const CalendarDisplayOptions();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return CalendarDisplayOptions.fromJson(decoded);
      }
    } catch (_) {
      // 损坏的配置按默认值展示，不阻断日历页。
    }
    return const CalendarDisplayOptions();
  }

  factory CalendarDisplayOptions.fromJson(Map<String, dynamic> json) {
    const defaults = CalendarDisplayOptions();
    return CalendarDisplayOptions(
      cellStyle: _enumByName(
        CalendarCellStyle.values,
        json['cellStyle'],
        defaults.cellStyle,
      ),
      heatBasis: _enumByName(
        CalendarHeatBasis.values,
        json['heatBasis'],
        defaults.heatBasis,
      ),
      moodAggregation: _enumByName(
        CalendarMoodAggregation.values,
        json['moodAggregation'],
        defaults.moodAggregation,
      ),
      showCountBadge: _bool(json['showCountBadge'], defaults.showCountBadge),
      showCapsuleBadge: _bool(
        json['showCapsuleBadge'],
        defaults.showCapsuleBadge,
      ),
      showWeatherBadge: _bool(
        json['showWeatherBadge'],
        defaults.showWeatherBadge,
      ),
      weekStart: _enumByName(
        CalendarWeekStart.values,
        json['weekStart'],
        defaults.weekStart,
      ),
      highlightWeekends: _bool(
        json['highlightWeekends'],
        defaults.highlightWeekends,
      ),
      showWeekNumbers: _bool(json['showWeekNumbers'], defaults.showWeekNumbers),
      fixedSixWeeks: _bool(json['fixedSixWeeks'], defaults.fixedSixWeeks),
      defaultFormat: _enumByName(
        CalendarDefaultFormat.values,
        json['defaultFormat'],
        defaults.defaultFormat,
      ),
      rememberedFormat: _enumByName(
        CalendarGridFormat.values,
        json['rememberedFormat'],
        defaults.rememberedFormat,
      ),
      showMonthSummary: _bool(
        json['showMonthSummary'],
        defaults.showMonthSummary,
      ),
      dayContentStyle: _enumByName(
        CalendarDayContentStyle.values,
        json['dayContentStyle'],
        defaults.dayContentStyle,
      ),
      showOnThisDay: _bool(json['showOnThisDay'], defaults.showOnThisDay),
      yearBasis: _enumByName(
        CalendarYearBasis.values,
        json['yearBasis'],
        defaults.yearBasis,
      ),
      lunarMode: _enumByName(
        CalendarLunarMode.values,
        json['lunarMode'],
        defaults.lunarMode,
      ),
    );
  }

  final CalendarCellStyle cellStyle;
  final CalendarHeatBasis heatBasis;
  final CalendarMoodAggregation moodAggregation;

  /// 一天两篇及以上时在右上角显示篇数。
  final bool showCountBadge;

  /// 有未解封时间胶囊的日子显示锁形角标。
  final bool showCapsuleBadge;

  /// 显示当天第一篇日记的天气图标。
  final bool showWeatherBadge;
  final CalendarWeekStart weekStart;

  /// 周末日期与星期栏改用 tertiary 色。
  final bool highlightWeekends;
  final bool showWeekNumbers;

  /// 月视图固定 6 行：翻月时网格高度不再在 5/6 行之间跳动。
  final bool fixedSixWeeks;
  final CalendarDefaultFormat defaultFormat;

  /// 上次切换到的格式，仅在 [defaultFormat] 为 remember 时生效。
  final CalendarGridFormat rememberedFormat;
  final bool showMonthSummary;
  final CalendarDayContentStyle dayContentStyle;

  /// 选中日下方显示其他年份同月同日的日记。
  final bool showOnThisDay;

  /// 年视图的着色依据，在年视图内切换。
  final CalendarYearBasis yearBasis;

  /// 日期数字下方是否显示农历、节气与节日。
  final CalendarLunarMode lunarMode;

  /// 打开日历页时应使用的网格格式。
  CalendarGridFormat get initialFormat => switch (defaultFormat) {
    CalendarDefaultFormat.month => CalendarGridFormat.month,
    CalendarDefaultFormat.week => CalendarGridFormat.week,
    CalendarDefaultFormat.remember => rememberedFormat,
  };

  Map<String, Object> toJson() => <String, Object>{
    'cellStyle': cellStyle.name,
    'heatBasis': heatBasis.name,
    'moodAggregation': moodAggregation.name,
    'showCountBadge': showCountBadge,
    'showCapsuleBadge': showCapsuleBadge,
    'showWeatherBadge': showWeatherBadge,
    'weekStart': weekStart.name,
    'highlightWeekends': highlightWeekends,
    'showWeekNumbers': showWeekNumbers,
    'fixedSixWeeks': fixedSixWeeks,
    'defaultFormat': defaultFormat.name,
    'rememberedFormat': rememberedFormat.name,
    'showMonthSummary': showMonthSummary,
    'dayContentStyle': dayContentStyle.name,
    'showOnThisDay': showOnThisDay,
    'yearBasis': yearBasis.name,
    'lunarMode': lunarMode.name,
  };

  String encode() => jsonEncode(toJson());

  CalendarDisplayOptions copyWith({
    CalendarCellStyle? cellStyle,
    CalendarHeatBasis? heatBasis,
    CalendarMoodAggregation? moodAggregation,
    bool? showCountBadge,
    bool? showCapsuleBadge,
    bool? showWeatherBadge,
    CalendarWeekStart? weekStart,
    bool? highlightWeekends,
    bool? showWeekNumbers,
    bool? fixedSixWeeks,
    CalendarDefaultFormat? defaultFormat,
    CalendarGridFormat? rememberedFormat,
    bool? showMonthSummary,
    CalendarDayContentStyle? dayContentStyle,
    bool? showOnThisDay,
    CalendarYearBasis? yearBasis,
    CalendarLunarMode? lunarMode,
  }) {
    return CalendarDisplayOptions(
      cellStyle: cellStyle ?? this.cellStyle,
      heatBasis: heatBasis ?? this.heatBasis,
      moodAggregation: moodAggregation ?? this.moodAggregation,
      showCountBadge: showCountBadge ?? this.showCountBadge,
      showCapsuleBadge: showCapsuleBadge ?? this.showCapsuleBadge,
      showWeatherBadge: showWeatherBadge ?? this.showWeatherBadge,
      weekStart: weekStart ?? this.weekStart,
      highlightWeekends: highlightWeekends ?? this.highlightWeekends,
      showWeekNumbers: showWeekNumbers ?? this.showWeekNumbers,
      fixedSixWeeks: fixedSixWeeks ?? this.fixedSixWeeks,
      defaultFormat: defaultFormat ?? this.defaultFormat,
      rememberedFormat: rememberedFormat ?? this.rememberedFormat,
      showMonthSummary: showMonthSummary ?? this.showMonthSummary,
      dayContentStyle: dayContentStyle ?? this.dayContentStyle,
      showOnThisDay: showOnThisDay ?? this.showOnThisDay,
      yearBasis: yearBasis ?? this.yearBasis,
      lunarMode: lunarMode ?? this.lunarMode,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CalendarDisplayOptions &&
        other.cellStyle == cellStyle &&
        other.heatBasis == heatBasis &&
        other.moodAggregation == moodAggregation &&
        other.showCountBadge == showCountBadge &&
        other.showCapsuleBadge == showCapsuleBadge &&
        other.showWeatherBadge == showWeatherBadge &&
        other.weekStart == weekStart &&
        other.highlightWeekends == highlightWeekends &&
        other.showWeekNumbers == showWeekNumbers &&
        other.fixedSixWeeks == fixedSixWeeks &&
        other.defaultFormat == defaultFormat &&
        other.rememberedFormat == rememberedFormat &&
        other.showMonthSummary == showMonthSummary &&
        other.dayContentStyle == dayContentStyle &&
        other.showOnThisDay == showOnThisDay &&
        other.yearBasis == yearBasis &&
        other.lunarMode == lunarMode;
  }

  @override
  int get hashCode => Object.hash(
    cellStyle,
    heatBasis,
    moodAggregation,
    showCountBadge,
    showCapsuleBadge,
    showWeatherBadge,
    weekStart,
    highlightWeekends,
    showWeekNumbers,
    fixedSixWeeks,
    defaultFormat,
    rememberedFormat,
    showMonthSummary,
    dayContentStyle,
    showOnThisDay,
    yearBasis,
    lunarMode,
  );

  static T _enumByName<T extends Enum>(
    List<T> values,
    Object? raw,
    T fallback,
  ) {
    if (raw is! String) {
      return fallback;
    }
    for (final value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    return fallback;
  }

  static bool _bool(Object? raw, bool fallback) => raw is bool ? raw : fallback;
}
