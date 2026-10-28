import 'package:flutter/foundation.dart';

import '../../diaries/models/style_library/style_json.dart';
import 'explore_appearance.dart';
import 'explore_module_config.dart';
import 'explore_module_id.dart';
import 'explore_module_spec.dart';

/// 探索页布局：卡片的顺序与各自设置、是否显示统计范围条、探索页外观。
///
/// 这是预设、“我的布局”与布局码携带的整体（统计范围本身不在其中，见
/// `ExploreBehavior`）。
///
/// 读取的兼容规则（[ExploreLayout.fromJson]）：
/// - 认不出的卡片原样保留、位置不变（[ExploreUnknownModule]），新版本的布局
///   导回旧版本再保存不会丢；
/// - 重复出现的卡片只认第一次；
/// - 缺少的已知卡片（布局保存于这张卡加入之前）按默认顺序、默认显隐补到
///   末尾；
/// - 其余字段逐项容错，坏值只让这一项回到默认。
@immutable
class ExploreLayout {
  ExploreLayout({
    required List<ExploreLayoutEntry> entries,
    this.showPeriodBar = true,
    this.appearance = ExploreAppearance.defaults,
  }) : entries = List<ExploreLayoutEntry>.unmodifiable(entries);

  /// 默认布局：全部卡片按登记顺序、默认显隐。
  static final ExploreLayout defaults = ExploreLayout(
    entries: <ExploreLayoutEntry>[
      for (final spec in ExploreModuleSpec.all)
        ExploreModuleConfig.initial(spec),
    ],
  );

  factory ExploreLayout.fromJson(Object? raw) {
    final json = StyleJson.map(raw);
    if (json == null) return defaults;
    final rawModules = json['m'];
    final entries = <ExploreLayoutEntry>[];
    if (rawModules is List) {
      final seen = <String>{};
      for (final item in rawModules) {
        final map = StyleJson.map(item);
        final name = map?['id'];
        if (map == null || name is! String || name.isEmpty || !seen.add(name)) {
          continue;
        }
        final id = ExploreModuleId.byName(name);
        entries.add(
          id == null
              ? ExploreUnknownModule(name, map)
              : ExploreModuleConfig.fromJson(id, map),
        );
      }
      final present = <ExploreModuleId>{
        for (final entry in entries)
          if (entry is ExploreModuleConfig) entry.id,
      };
      for (final spec in ExploreModuleSpec.all) {
        if (!present.contains(spec.id)) {
          entries.add(ExploreModuleConfig.initial(spec));
        }
      }
    } else {
      entries.addAll(defaults.entries);
    }
    return ExploreLayout(
      entries: entries,
      showPeriodBar: StyleJson.boolean(json['bar'], true),
      appearance: ExploreAppearance.fromJson(json['look']),
    );
  }

  final List<ExploreLayoutEntry> entries;
  final bool showPeriodBar;
  final ExploreAppearance appearance;

  /// 认得的卡片，按布局顺序。
  List<ExploreModuleConfig> get modules => <ExploreModuleConfig>[
    for (final entry in entries)
      if (entry is ExploreModuleConfig) entry,
  ];

  /// [id] 的设置（[fromJson] 保证每张已知卡片都在）。
  ExploreModuleConfig module(ExploreModuleId id) {
    for (final entry in entries) {
      if (entry is ExploreModuleConfig && entry.id == id) return entry;
    }
    return ExploreModuleConfig.initial(ExploreModuleSpec.of(id));
  }

  bool get isDefault => this == defaults;

  Map<String, Object> toJson() {
    final json = <String, Object>{
      'm': <Object>[for (final entry in entries) entry.toJson()],
    };
    if (!showPeriodBar) json['bar'] = false;
    StyleJson.putObject(json, 'look', appearance.toJson());
    return json;
  }

  /// 替换一张卡的设置（同 id）。
  ExploreLayout withModule(ExploreModuleConfig config) => ExploreLayout(
    entries: <ExploreLayoutEntry>[
      for (final entry in entries)
        if (entry is ExploreModuleConfig && entry.id == config.id)
          config
        else
          entry,
    ],
    showPeriodBar: showPeriodBar,
    appearance: appearance,
  );

  /// 按新顺序排列已知卡片；认不出的卡片停在原来的位置（已知卡片依次填进
  /// 其余位置）。[ordered] 必须是 [modules] 的一个排列。
  ExploreLayout withModuleOrder(List<ExploreModuleConfig> ordered) {
    assert(ordered.length == modules.length);
    var next = 0;
    return ExploreLayout(
      entries: <ExploreLayoutEntry>[
        for (final entry in entries)
          if (entry is ExploreModuleConfig) ordered[next++] else entry,
      ],
      showPeriodBar: showPeriodBar,
      appearance: appearance,
    );
  }

  /// 把 [modules] 里第 [oldIndex] 张卡移到 [newIndex]（[newIndex] 为移除后
  /// 的位置）。
  ExploreLayout moveModule(int oldIndex, int newIndex) {
    final list = modules;
    if (oldIndex < 0 || oldIndex >= list.length) return this;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex.clamp(0, list.length), item);
    return withModuleOrder(list);
  }

  ExploreLayout copyWith({
    List<ExploreLayoutEntry>? entries,
    bool? showPeriodBar,
    ExploreAppearance? appearance,
  }) => ExploreLayout(
    entries: entries ?? this.entries,
    showPeriodBar: showPeriodBar ?? this.showPeriodBar,
    appearance: appearance ?? this.appearance,
  );

  @override
  bool operator ==(Object other) =>
      other is ExploreLayout &&
      other.showPeriodBar == showPeriodBar &&
      other.appearance == appearance &&
      listEquals(other.entries, entries);

  @override
  int get hashCode =>
      Object.hash(showPeriodBar, appearance, Object.hashAll(entries));
}
