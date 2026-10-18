import 'package:flutter/foundation.dart';

/// 模板推荐规则与打分。
///
/// 一个模板可以声明三类条件：时段、星期、月初/月末。**类别之间取“且”、
/// 同一类别内取“或”**：工作日志写“周一至周五”且“午后或傍晚”，周六下午
/// 不推荐。没有声明任何条件的模板永远不算推荐，只按库内顺序出现。
///
/// 时段看当下（[now]），星期与月份看日记的日期（[diaryDate]）：补写昨天的
/// 日记时，“早上推荐晨间日记”已经没有意义，时段条件整类跳过；而“周日推荐
/// 周回顾”说的是那一天，应按补写的日期判断。只有时段条件的模板在补写时
/// 因此不推荐。
enum DiaryTemplateTimeSlot {
  /// 5:00–10:59
  morning,

  /// 11:00–16:59
  afternoon,

  /// 17:00–21:59
  evening,

  /// 22:00–4:59
  night;

  static DiaryTemplateTimeSlot of(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 11) return morning;
    if (hour >= 11 && hour < 17) return afternoon;
    if (hour >= 17 && hour < 22) return evening;
    return night;
  }
}

/// 月初（1–3 号）与月末（最后 3 天）。
enum DiaryTemplateMonthPhase {
  start,
  end;

  static const int span = 3;

  bool matches(DateTime day) {
    return switch (this) {
      start => day.day <= span,
      end => day.day > DateTime(day.year, day.month + 1, 0).day - span,
    };
  }
}

@immutable
class DiaryTemplateRecommendRules {
  const DiaryTemplateRecommendRules({
    this.slots = const <DiaryTemplateTimeSlot>{},
    this.weekdays = const <int>{},
    this.monthPhases = const <DiaryTemplateMonthPhase>{},
  });

  static const DiaryTemplateRecommendRules none = DiaryTemplateRecommendRules();

  final Set<DiaryTemplateTimeSlot> slots;

  /// [DateTime.weekday] 的取值：1 = 周一 … 7 = 周日。
  final Set<int> weekdays;
  final Set<DiaryTemplateMonthPhase> monthPhases;

  bool get isEmpty => slots.isEmpty && weekdays.isEmpty && monthPhases.isEmpty;

  DiaryTemplateRecommendRules copyWith({
    Set<DiaryTemplateTimeSlot>? slots,
    Set<int>? weekdays,
    Set<DiaryTemplateMonthPhase>? monthPhases,
  }) {
    return DiaryTemplateRecommendRules(
      slots: slots ?? this.slots,
      weekdays: weekdays ?? this.weekdays,
      monthPhases: monthPhases ?? this.monthPhases,
    );
  }

  /// 稀疏 JSON：没有条件的类别不写。
  Map<String, Object> toJson() => <String, Object>{
    if (slots.isNotEmpty)
      'slots': <String>[
        for (final slot in DiaryTemplateTimeSlot.values)
          if (slots.contains(slot)) slot.name,
      ],
    if (weekdays.isNotEmpty) 'weekdays': weekdays.toList()..sort(),
    if (monthPhases.isNotEmpty)
      'monthPhases': <String>[
        for (final phase in DiaryTemplateMonthPhase.values)
          if (monthPhases.contains(phase)) phase.name,
      ],
  };

  /// 逐项容错：认不出的时段名、越界的星期一律丢弃。
  factory DiaryTemplateRecommendRules.fromJson(Object? raw) {
    if (raw is! Map) return none;
    Set<T> names<T extends Enum>(Object? list, List<T> values) => <T>{
      if (list is List)
        for (final item in list)
          for (final value in values)
            if (value.name == item) value,
    };
    final weekdays = raw['weekdays'];
    return DiaryTemplateRecommendRules(
      slots: Set.unmodifiable(
        names(raw['slots'], DiaryTemplateTimeSlot.values),
      ),
      weekdays: Set.unmodifiable(<int>{
        if (weekdays is List)
          for (final day in weekdays)
            if (day is int && day >= 1 && day <= 7) day,
      }),
      monthPhases: Set.unmodifiable(
        names(raw['monthPhases'], DiaryTemplateMonthPhase.values),
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DiaryTemplateRecommendRules &&
      setEquals(other.slots, slots) &&
      setEquals(other.weekdays, weekdays) &&
      setEquals(other.monthPhases, monthPhases);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(slots),
    Object.hashAllUnordered(weekdays),
    Object.hashAllUnordered(monthPhases),
  );
}

/// 模板此刻是否推荐：不推荐返回 null，推荐时返回命中的条件类别数（条件越
/// 具体排得越前）。规则见 [DiaryTemplateRecommendRules] 的说明。
int? scoreDiaryTemplate(
  DiaryTemplateRecommendRules rules, {
  required DateTime now,
  required DateTime diaryDate,
}) {
  if (rules.isEmpty) return null;
  final writingToday =
      now.year == diaryDate.year &&
      now.month == diaryDate.month &&
      now.day == diaryDate.day;
  var score = 0;
  if (rules.slots.isNotEmpty && writingToday) {
    if (!rules.slots.contains(DiaryTemplateTimeSlot.of(now))) return null;
    score++;
  }
  if (rules.weekdays.isNotEmpty) {
    if (!rules.weekdays.contains(diaryDate.weekday)) return null;
    score++;
  }
  if (rules.monthPhases.isNotEmpty) {
    if (!rules.monthPhases.any((phase) => phase.matches(diaryDate))) {
      return null;
    }
    score++;
  }
  return score == 0 ? null : score;
}
