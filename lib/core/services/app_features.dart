// 功能管理开关（设置 → 功能管理）。
//
// 职责：描述用户可整体关闭的功能——日历 Tab、探索 Tab、日记本、纪念日、
// 日记模板、时间胶囊——是否开启；默认全部开启。关闭只是在各处隐藏入口与
// 展示，数据一律保留，重新开启即恢复原样。
//
// 存储：单个 JSON 设置键 `app.settings.app_features`（经
// `SettingsService.setAppFeaturesRaw`），逐字段容错解析，随完整备份导出，
// 导入失败时随设置快照回滚。全部为默认值时不落盘（[encode] 返回 null）。

import 'dart:convert';

/// 各功能是否开启。不可变；修改经 [copyWith] 得到新值后保存。
class AppFeatures {
  const AppFeatures({
    this.calendar = true,
    this.explore = true,
    this.notebooks = true,
    this.anniversaries = true,
    this.templates = true,
    this.timeCapsules = true,
  });

  /// 全部开启：从未设置、读不出或恢复默认时都是它。
  static const AppFeatures defaults = AppFeatures();

  /// 日历 Tab。
  final bool calendar;

  /// 探索 Tab。
  final bool explore;

  /// 日记本。
  final bool notebooks;

  /// 纪念日的用户开关值；界面判断是否可用请读 [anniversariesEnabled]。
  final bool anniversaries;

  /// 日记模板。
  final bool templates;

  /// 时间胶囊。
  final bool timeCapsules;

  /// 纪念日依附日历（列表只能从日历顶栏进入），日历关闭时一并关闭；界面一律
  /// 读这个 getter 判断纪念日是否可用，不直接读 [anniversaries]（它只是用户
  /// 自己的开关值，日历重新开启时恢复）。
  bool get anniversariesEnabled => calendar && anniversaries;

  static const _keyCalendar = 'calendar';
  static const _keyExplore = 'explore';
  static const _keyNotebooks = 'notebooks';
  static const _keyAnniversaries = 'anniversaries';
  static const _keyTemplates = 'templates';
  static const _keyTimeCapsules = 'timeCapsules';

  /// 解析设置原文。空值、坏 JSON 或不是对象时回到 [defaults]；每个字段
  /// 单独读取，类型不对只让这一项回到默认，认不出的键忽略——这样新旧版本
  /// 互相导入备份时，不会因为一项坏值把用户关掉的其他功能全部重新打开。
  static AppFeatures decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return defaults;
    final Object? node;
    try {
      node = jsonDecode(raw);
    } on FormatException {
      return defaults;
    }
    if (node is! Map) return defaults;
    final map = node;
    bool read(String key, bool fallback) {
      final value = map[key];
      return value is bool ? value : fallback;
    }

    return AppFeatures(
      calendar: read(_keyCalendar, defaults.calendar),
      explore: read(_keyExplore, defaults.explore),
      notebooks: read(_keyNotebooks, defaults.notebooks),
      anniversaries: read(_keyAnniversaries, defaults.anniversaries),
      templates: read(_keyTemplates, defaults.templates),
      timeCapsules: read(_keyTimeCapsules, defaults.timeCapsules),
    );
  }

  /// 编码为设置原文；等于默认值时返回 null，让设置层移除该键而不是存一份
  /// 与默认相同的 JSON。
  String? encode() {
    if (this == defaults) return null;
    return jsonEncode(<String, bool>{
      _keyCalendar: calendar,
      _keyExplore: explore,
      _keyNotebooks: notebooks,
      _keyAnniversaries: anniversaries,
      _keyTemplates: templates,
      _keyTimeCapsules: timeCapsules,
    });
  }

  AppFeatures copyWith({
    bool? calendar,
    bool? explore,
    bool? notebooks,
    bool? anniversaries,
    bool? templates,
    bool? timeCapsules,
  }) {
    return AppFeatures(
      calendar: calendar ?? this.calendar,
      explore: explore ?? this.explore,
      notebooks: notebooks ?? this.notebooks,
      anniversaries: anniversaries ?? this.anniversaries,
      templates: templates ?? this.templates,
      timeCapsules: timeCapsules ?? this.timeCapsules,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppFeatures &&
      other.calendar == calendar &&
      other.explore == explore &&
      other.notebooks == notebooks &&
      other.anniversaries == anniversaries &&
      other.templates == templates &&
      other.timeCapsules == timeCapsules;

  @override
  int get hashCode => Object.hash(
    calendar,
    explore,
    notebooks,
    anniversaries,
    templates,
    timeCapsules,
  );

  @override
  String toString() =>
      'AppFeatures(calendar: $calendar, explore: $explore, '
      'notebooks: $notebooks, anniversaries: $anniversaries, '
      'templates: $templates, timeCapsules: $timeCapsules)';
}
