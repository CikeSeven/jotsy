part of 'calendar_display_options.dart';

// CalendarDisplayOptions 的 JSON 编解码。逐字段容错：缺失、类型不符或未知
// 枚举名只让该字段回退到默认值（见 [CalendarDisplayOptions] 的兼容策略）。

CalendarDisplayOptions _optionsFromJson(Map<String, dynamic> json) {
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
    holidayMode: _enumByName(
      CalendarLunarMode.values,
      json['holidayMode'],
      defaults.holidayMode,
    ),
    showAnniversaries: _bool(
      json['showAnniversaries'],
      defaults.showAnniversaries,
    ),
  );
}

Map<String, Object> _optionsToJson(CalendarDisplayOptions o) =>
    <String, Object>{
      'cellStyle': o.cellStyle.name,
      'heatBasis': o.heatBasis.name,
      'moodAggregation': o.moodAggregation.name,
      'showCountBadge': o.showCountBadge,
      'showCapsuleBadge': o.showCapsuleBadge,
      'showWeatherBadge': o.showWeatherBadge,
      'weekStart': o.weekStart.name,
      'highlightWeekends': o.highlightWeekends,
      'showWeekNumbers': o.showWeekNumbers,
      'fixedSixWeeks': o.fixedSixWeeks,
      'defaultFormat': o.defaultFormat.name,
      'rememberedFormat': o.rememberedFormat.name,
      'showMonthSummary': o.showMonthSummary,
      'dayContentStyle': o.dayContentStyle.name,
      'showOnThisDay': o.showOnThisDay,
      'yearBasis': o.yearBasis.name,
      'lunarMode': o.lunarMode.name,
      'holidayMode': o.holidayMode.name,
      'showAnniversaries': o.showAnniversaries,
    };

T _enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) {
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

bool _bool(Object? raw, bool fallback) => raw is bool ? raw : fallback;
