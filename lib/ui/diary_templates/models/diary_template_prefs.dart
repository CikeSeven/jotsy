import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart'
    show builtInDiaryTemplateIdPrefix;

/// 日记模板的行为偏好，存于单个 JSON 设置键 `app.settings.diary_template_prefs`
/// 并随完整备份导出（模板本身在数据库里）。
///
/// 格式：`{"v":1,"strip":false,"auto":"<模板 id>","hidden":["builtin.weekly"],
/// "recent":["<id>", …]}`，稀疏写入、逐字段容错：类型不符的字段回退默认值，
/// 不连累其他字段。指向已删除模板的 id 留在这里无害，读取方按“不存在”处理。
@immutable
class DiaryTemplatePrefs {
  const DiaryTemplatePrefs({
    this.showStrip = true,
    this.autoTemplateId,
    this.hiddenBuiltIns = const <String>{},
    this.recent = const <String>[],
  });

  static const DiaryTemplatePrefs defaults = DiaryTemplatePrefs();
  static const int maxRecent = 6;

  /// 新建日记时是否在标题下显示“从模板开始”建议条。
  final bool showStrip;

  /// 新建空白日记时自动套用的模板；null 表示不自动套用。
  final String? autoTemplateId;

  /// 隐藏的内置模板 id（用户模板不隐藏，直接删除）。
  final Set<String> hiddenBuiltIns;

  /// 最近用过的模板 id，新的在前，最多 [maxRecent] 个。
  final List<String> recent;

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
    );
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
  }) {
    return DiaryTemplatePrefs(
      showStrip: showStrip ?? this.showStrip,
      autoTemplateId: autoTemplateId == null
          ? this.autoTemplateId
          : autoTemplateId(),
      hiddenBuiltIns: hiddenBuiltIns ?? this.hiddenBuiltIns,
      recent: recent ?? this.recent,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DiaryTemplatePrefs &&
      other.showStrip == showStrip &&
      other.autoTemplateId == autoTemplateId &&
      setEquals(other.hiddenBuiltIns, hiddenBuiltIns) &&
      listEquals(other.recent, recent);

  @override
  int get hashCode => Object.hash(
    showStrip,
    autoTemplateId,
    Object.hashAllUnordered(hiddenBuiltIns),
    Object.hashAll(recent),
  );
}
