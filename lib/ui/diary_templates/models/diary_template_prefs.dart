import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart'
    show builtInDiaryTemplateIdPrefix;
import 'diary_template_auto_rule.dart';

/// 日记模板的行为偏好，存于单个 JSON 设置键 `app.settings.diary_template_prefs`
/// 并随完整备份导出（模板本身在数据库里）。
///
/// 格式：`{"v":1,"strip":false,"auto":"<模板 id>","hidden":["builtin.reading"],
/// "recent":["<id>", …],"rules":[{"from":420,"to":600,"days":[6,7],
/// "id":"builtin.weekly"}]}`，稀疏写入、逐字段容错：类型不符的字段回退默认值，
/// 不连累其他字段；`rules` 里坏掉的条目单独丢弃。没有 `rules` 的旧偏好（含
/// 旧备份）按“没有时间段”解码，其余字段不变。指向已删除模板的 id 留在这里
/// 无害，读取方按“不存在”处理。
@immutable
class DiaryTemplatePrefs {
  const DiaryTemplatePrefs({
    this.showStrip = true,
    this.autoTemplateId,
    this.hiddenBuiltIns = const <String>{},
    this.recent = const <String>[],
    this.autoRules = const <DiaryTemplateAutoRule>[],
  });

  static const DiaryTemplatePrefs defaults = DiaryTemplatePrefs();
  static const int maxRecent = 6;
  static const int maxAutoRules = 12;

  /// 新建日记时是否在标题下显示“从模板开始”建议条。
  final bool showStrip;

  /// 不在任何时间段内（或补写、写给未来的日子）时自动套用的默认模板；
  /// null 表示其他时间不自动套用。
  final String? autoTemplateId;

  /// 隐藏的内置模板 id（用户模板不隐藏，直接删除）。
  final Set<String> hiddenBuiltIns;

  /// 最近用过的模板 id，新的在前，最多 [maxRecent] 个。
  final List<String> recent;

  /// 按时间段自动套用的规则，按 [DiaryTemplateAutoRule.compareStored] 排好，
  /// 最多 [maxAutoRules] 条；列表显示顺序即存储顺序。
  final List<DiaryTemplateAutoRule> autoRules;

  factory DiaryTemplatePrefs.decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return defaults;
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return defaults;
    }
    if (json is! Map) return defaults;
    final strip = json['strip'];
    final auto = json['auto'];
    final hidden = json['hidden'];
    final recent = json['recent'];
    final rules = json['rules'];
    return DiaryTemplatePrefs(
      showStrip: strip is bool ? strip : true,
      autoTemplateId: auto is String && auto.trim().isNotEmpty
          ? auto.trim()
          : null,
      hiddenBuiltIns: Set<String>.unmodifiable(<String>{
        if (hidden is List)
          for (final id in hidden)
            if (id is String && id.startsWith(builtInDiaryTemplateIdPrefix)) id,
      }),
      recent: List<String>.unmodifiable(
        <String>{
          if (recent is List)
            for (final id in recent)
              if (id is String && id.isNotEmpty) id,
        }.take(maxRecent),
      ),
      autoRules: _normalizeRules(<DiaryTemplateAutoRule>[
        if (rules is List)
          for (final item in rules) ?DiaryTemplateAutoRule.fromJson(item),
      ]),
    );
  }

  /// 去重、截到上限（保留先出现的）并排好序。
  static List<DiaryTemplateAutoRule> _normalizeRules(
    Iterable<DiaryTemplateAutoRule> rules,
  ) {
    final kept = <DiaryTemplateAutoRule>[];
    for (final rule in rules) {
      if (kept.length >= maxAutoRules) break;
      if (rule.isValid && !kept.contains(rule)) kept.add(rule);
    }
    kept.sort(DiaryTemplateAutoRule.compareStored);
    return List<DiaryTemplateAutoRule>.unmodifiable(kept);
  }

  /// 全部为默认值时返回 null，调用方据此移除设置键。
  String? encode() {
    if (this == defaults) return null;
    return jsonEncode(<String, Object>{
      'v': 1,
      if (!showStrip) 'strip': false,
      'auto': ?autoTemplateId,
      if (hiddenBuiltIns.isNotEmpty) 'hidden': hiddenBuiltIns.toList()..sort(),
      if (recent.isNotEmpty) 'recent': recent,
      if (autoRules.isNotEmpty)
        'rules': <Map<String, Object>>[
          for (final rule in autoRules) rule.toJson(),
        ],
    });
  }

  DiaryTemplatePrefs withStrip(bool value) => _copy(showStrip: value);

  DiaryTemplatePrefs withAuto(String? templateId) =>
      _copy(autoTemplateId: () => templateId);

  DiaryTemplatePrefs withHidden(String templateId, bool hidden) {
    if (!templateId.startsWith(builtInDiaryTemplateIdPrefix)) return this;
    final next = Set<String>.of(hiddenBuiltIns);
    hidden ? next.add(templateId) : next.remove(templateId);
    return _copy(hiddenBuiltIns: Set<String>.unmodifiable(next));
  }

  /// 换掉全部时间段规则（去重、截到上限并排序）。
  DiaryTemplatePrefs withAutoRules(Iterable<DiaryTemplateAutoRule> rules) =>
      _copy(autoRules: _normalizeRules(rules));

  /// 指向 [templateId] 的时间段规则。
  List<DiaryTemplateAutoRule> autoRulesFor(String templateId) =>
      autoRules.where((rule) => rule.templateId == templateId).toList();

  /// 此刻新建空白日记时依次尝试的模板 id，见 [diaryTemplateAutoCandidates]。
  List<String> autoApplyCandidates({
    required DateTime now,
    required DateTime diaryDate,
  }) => diaryTemplateAutoCandidates(
    rules: autoRules,
    fallbackId: autoTemplateId,
    now: now,
    diaryDate: diaryDate,
  );

  /// 把 [templateId] 移到最近使用的最前面。
  DiaryTemplatePrefs recordUse(String templateId) {
    if (recent.isNotEmpty && recent.first == templateId) return this;
    return _copy(
      recent: List<String>.unmodifiable(
        <String>[
          templateId,
          ...recent.where((id) => id != templateId),
        ].take(maxRecent),
      ),
    );
  }

  DiaryTemplatePrefs _copy({
    bool? showStrip,
    String? Function()? autoTemplateId,
    Set<String>? hiddenBuiltIns,
    List<String>? recent,
    List<DiaryTemplateAutoRule>? autoRules,
  }) {
    return DiaryTemplatePrefs(
      showStrip: showStrip ?? this.showStrip,
      autoTemplateId: autoTemplateId == null
          ? this.autoTemplateId
          : autoTemplateId(),
      hiddenBuiltIns: hiddenBuiltIns ?? this.hiddenBuiltIns,
      recent: recent ?? this.recent,
      autoRules: autoRules ?? this.autoRules,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DiaryTemplatePrefs &&
      other.showStrip == showStrip &&
      other.autoTemplateId == autoTemplateId &&
      setEquals(other.hiddenBuiltIns, hiddenBuiltIns) &&
      listEquals(other.recent, recent) &&
      listEquals(other.autoRules, autoRules);

  @override
  int get hashCode => Object.hash(
    showStrip,
    autoTemplateId,
    Object.hashAllUnordered(hiddenBuiltIns),
    Object.hashAll(recent),
    Object.hashAll(autoRules),
  );
}
