import 'package:flutter/foundation.dart';

/// 按时间段自动套用模板的一条规则：在 [startMinute]–[endMinute] 之间新建
/// 空白日记时套用 [templateId]。
///
/// 时间用一天中的分钟数（0–1439），区间左闭右开：07:00–10:00 覆盖 7:00 到
/// 9:59，10:00 整已经不算。[endMinute] 小于 [startMinute] 表示跨夜，例如
/// 22:00–02:00；两者相等没有意义（是“全天”还是“空”说不清），解码与保存时
/// 都会被拒绝。
///
/// 星期沿用 `DateTime.weekday`（1 = 周一 … 7 = 周日），空集合为每天。跨夜
/// 区间的星期看区间**开始**的那天：“周日 22:00–02:00”是周日晚上开始的那一段，
/// 因此周一凌晨 1 点命中，而“周一 22:00–02:00”在周一凌晨 1 点不命中——那时
/// 属于周日晚上开始的区间。
@immutable
class DiaryTemplateAutoRule {
  const DiaryTemplateAutoRule({
    required this.startMinute,
    required this.endMinute,
    this.weekdays = const <int>{},
    required this.templateId,
  });

  static const int minutesPerDay = 24 * 60;

  final int startMinute;
  final int endMinute;
  final Set<int> weekdays;
  final String templateId;

  /// 结束早于开始：区间跨过午夜，到次日结束。
  bool get crossesMidnight => endMinute < startMinute;

  /// 区间长度（分钟），跨夜时按到次日结束计算；排序“更具体的优先”用它。
  int get durationMinutes => crossesMidnight
      ? endMinute + minutesPerDay - startMinute
      : endMinute - startMinute;

  bool get isValid =>
      _isMinute(startMinute) &&
      _isMinute(endMinute) &&
      startMinute != endMinute &&
      templateId.isNotEmpty &&
      weekdays.every((day) => day >= 1 && day <= 7);

  /// [now] 是否落在这个时间段内（星期规则见类注释）。
  bool matches(DateTime now) {
    final minute = now.hour * 60 + now.minute;
    final int startDay;
    if (!crossesMidnight) {
      if (minute < startMinute || minute >= endMinute) return false;
      startDay = now.weekday;
    } else if (minute >= startMinute) {
      startDay = now.weekday;
    } else if (minute < endMinute) {
      // 午夜之后的那一段属于前一天开始的区间。
      startDay = now.weekday == DateTime.monday
          ? DateTime.sunday
          : now.weekday - 1;
    } else {
      return false;
    }
    return weekdays.isEmpty || weekdays.contains(startDay);
  }

  DiaryTemplateAutoRule copyWith({
    int? startMinute,
    int? endMinute,
    Set<int>? weekdays,
    String? templateId,
  }) {
    return DiaryTemplateAutoRule(
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      weekdays: weekdays ?? this.weekdays,
      templateId: templateId ?? this.templateId,
    );
  }

  /// 星期按从周一到周日排好，存储、比较与显示都用这个顺序。
  List<int> get sortedWeekdays => weekdays.toList()..sort();

  Map<String, Object> toJson() => <String, Object>{
    'from': startMinute,
    'to': endMinute,
    if (weekdays.isNotEmpty) 'days': sortedWeekdays,
    'id': templateId,
  };

  /// 逐项容错：不是对象、起止不是范围内的整数、起止相同或 id 为空时返回
  /// null（整条丢弃）；星期只保留 1–7 的整数并去重。
  static DiaryTemplateAutoRule? fromJson(Object? json) {
    if (json is! Map) return null;
    final from = json['from'];
    final to = json['to'];
    final id = json['id'];
    final days = json['days'];
    if (from is! int || to is! int || id is! String) return null;
    final rule = DiaryTemplateAutoRule(
      startMinute: from,
      endMinute: to,
      weekdays: Set<int>.unmodifiable(<int>{
        if (days is List)
          for (final day in days)
            if (day is int && day >= 1 && day <= 7) day,
      }),
      templateId: id.trim(),
    );
    return rule.isValid ? rule : null;
  }

  /// 存储与列表的顺序：按开始、结束、星期排，列表看起来就是一天的时间线。
  static int compareStored(DiaryTemplateAutoRule a, DiaryTemplateAutoRule b) {
    var result = a.startMinute.compareTo(b.startMinute);
    if (result != 0) return result;
    result = a.endMinute.compareTo(b.endMinute);
    if (result != 0) return result;
    final daysA = a.sortedWeekdays;
    final daysB = b.sortedWeekdays;
    for (var i = 0; i < daysA.length && i < daysB.length; i++) {
      result = daysA[i].compareTo(daysB[i]);
      if (result != 0) return result;
    }
    result = daysA.length.compareTo(daysB.length);
    if (result != 0) return result;
    return a.templateId.compareTo(b.templateId);
  }

  static bool _isMinute(int value) => value >= 0 && value < minutesPerDay;

  @override
  bool operator ==(Object other) =>
      other is DiaryTemplateAutoRule &&
      other.startMinute == startMinute &&
      other.endMinute == endMinute &&
      setEquals(other.weekdays, weekdays) &&
      other.templateId == templateId;

  @override
  int get hashCode => Object.hash(
    startMinute,
    endMinute,
    Object.hashAllUnordered(weekdays),
    templateId,
  );
}

/// 此刻新建空白日记时依次尝试的模板 id（调用方取第一个仍存在的）。
///
/// 时间段只在写今天的日记时生效：补写过去或写给未来某天时，“早上用晨间
/// 日记”没有意义，只用默认模板 [fallbackId]。同时命中多条时更具体的在前：
/// 1. 指定了星期的先于每天的；2. 时长更短的先于更长的；3. 开始更早的在前；
/// 4. 其余按存储顺序。默认模板总在最后，作为其他时间的兜底。
List<String> diaryTemplateAutoCandidates({
  required List<DiaryTemplateAutoRule> rules,
  required String? fallbackId,
  required DateTime now,
  required DateTime diaryDate,
}) {
  final isToday =
      diaryDate.year == now.year &&
      diaryDate.month == now.month &&
      diaryDate.day == now.day;
  final matched = <(DiaryTemplateAutoRule, int)>[
    if (isToday)
      for (var i = 0; i < rules.length; i++)
        if (rules[i].matches(now)) (rules[i], i),
  ];
  matched.sort((a, b) {
    final (ruleA, indexA) = a;
    final (ruleB, indexB) = b;
    final everyDayA = ruleA.weekdays.isEmpty ? 1 : 0;
    final everyDayB = ruleB.weekdays.isEmpty ? 1 : 0;
    if (everyDayA != everyDayB) return everyDayA.compareTo(everyDayB);
    var result = ruleA.durationMinutes.compareTo(ruleB.durationMinutes);
    if (result != 0) return result;
    result = ruleA.startMinute.compareTo(ruleB.startMinute);
    if (result != 0) return result;
    return indexA.compareTo(indexB);
  });
  return <String>{
    for (final (rule, _) in matched) rule.templateId,
    ?fallbackId,
  }.toList(growable: false);
}
