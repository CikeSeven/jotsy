import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../notebooks/viewmodels/notebook_rule_labels.dart';

/// 搜索页的一个筛选槽位，对应一种智能日记本规则（选择器直接打开那种规则
/// 的编辑面板）。顺序即筛选胶囊的排列顺序。
enum DiarySearchFilterSlot {
  date(NotebookRuleType.date),
  mood(NotebookRuleType.mood),
  media(NotebookRuleType.media),
  weather(NotebookRuleType.weather),
  location(NotebookRuleType.location);

  const DiarySearchFilterSlot(this.ruleType);

  final NotebookRuleType ruleType;
}

/// 搜索页的筛选条件：时间、心情、媒体、天气、地点各至多一条，外加“含归档”。
///
/// 每一项都直接是智能日记本的一条规则（`notebook_rules.dart`），编译、口径
/// 与胶囊保密规则因此和智能日记本完全一致；“存为智能日记本”时原样带过去
/// （[rules]）。关键词与标签不在这里：它们由搜索页另行持有（标签按 id，
/// 入口从标签打开时就带着 id）。
///
/// 不可变、值相等：[predicate] 的结果是查询 provider key 的一部分。
@immutable
class DiarySearchFilters {
  const DiarySearchFilters({
    this.date,
    this.mood,
    this.media,
    this.weather,
    this.location,
    this.includeArchived = false,
  });

  static const DiarySearchFilters none = DiarySearchFilters();

  final NotebookDateRule? date;
  final NotebookMoodRule? mood;
  final NotebookMediaRule? media;

  /// 天气包含某段文字（`NotebookTextField.weather`）。
  final NotebookTextRule? weather;

  /// 地点包含某段文字（`NotebookTextField.location`）。
  final NotebookTextRule? location;

  /// 连归档的日记一起搜。智能日记本没有这一口径，存为日记本时不带。
  final bool includeArchived;

  /// 按胶囊排列顺序给出的规则（不含“含归档”）。
  List<NotebookRule> get rules => <NotebookRule>[
    ?date,
    ?mood,
    ?media,
    ?weather,
    ?location,
  ];

  /// 有没有任何一项筛选（含“含归档”）。
  bool get isActive => includeArchived || rules.isNotEmpty;

  /// 筛选谓词：没有规则时为 null（不筛选）。相对日期按 [now] 所在的那一天
  /// 编译，同一天里重复调用得到相等的谓词（见 [compileNotebookRules]）。
  DiaryScopePredicate? predicate({DateTime? now}) {
    final list = rules;
    if (list.isEmpty) {
      return null;
    }
    return compileNotebookRules(NotebookRuleSet(rules: list), now: now);
  }

  /// 某一槽位当前的规则；没有设置时为 null。
  NotebookRule? ruleOf(DiarySearchFilterSlot slot) => switch (slot) {
    DiarySearchFilterSlot.date => date,
    DiarySearchFilterSlot.mood => mood,
    DiarySearchFilterSlot.media => media,
    DiarySearchFilterSlot.weather => weather,
    DiarySearchFilterSlot.location => location,
  };

  /// 换掉某一槽位；[rule] 为 null 即清除。类型与槽位不符的规则（编辑面板
  /// 不会给出）按清除处理。
  DiarySearchFilters withSlot(DiarySearchFilterSlot slot, NotebookRule? rule) {
    NotebookTextRule? text(NotebookTextField field) =>
        rule is NotebookTextRule && rule.field == field ? rule : null;
    return DiarySearchFilters(
      date: slot == DiarySearchFilterSlot.date
          ? (rule is NotebookDateRule ? rule : null)
          : date,
      mood: slot == DiarySearchFilterSlot.mood
          ? (rule is NotebookMoodRule ? rule : null)
          : mood,
      media: slot == DiarySearchFilterSlot.media
          ? (rule is NotebookMediaRule ? rule : null)
          : media,
      weather: slot == DiarySearchFilterSlot.weather
          ? text(NotebookTextField.weather)
          : weather,
      location: slot == DiarySearchFilterSlot.location
          ? text(NotebookTextField.location)
          : location,
      includeArchived: includeArchived,
    );
  }

  DiarySearchFilters withIncludeArchived(bool value) => DiarySearchFilters(
    date: date,
    mood: mood,
    media: media,
    weather: weather,
    location: location,
    includeArchived: value,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiarySearchFilters &&
          other.date == date &&
          other.mood == mood &&
          other.media == media &&
          other.weather == weather &&
          other.location == location &&
          other.includeArchived == includeArchived;

  @override
  int get hashCode =>
      Object.hash(date, mood, media, weather, location, includeArchived);
}
