import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../diaries/models/style_library/saved_style.dart';
import '../../diaries/models/style_library/style_json.dart';
import 'explore_layout.dart';
import 'explore_period.dart';

/// 用户保存的一套探索页布局（“我的布局”）。
typedef ExploreSavedLayout = SavedStyle<ExploreLayout>;

/// 探索页的行为：不随预设、我的布局与布局码改变。
@immutable
class ExploreBehavior {
  const ExploreBehavior({this.period = ExplorePeriod.all});

  static const ExploreBehavior defaults = ExploreBehavior();

  factory ExploreBehavior.fromJson(Object? raw) {
    final json = StyleJson.map(raw);
    if (json == null) return defaults;
    return ExploreBehavior(
      period: StyleJson.enumByName(
        ExplorePeriod.values,
        json['period'],
        defaults.period,
      ),
    );
  }

  /// 统计范围：范围条上次选的（范围条关闭时在编辑页里设）。
  final ExplorePeriod period;

  bool get isDefault => this == defaults;

  Map<String, Object> toJson() {
    final json = <String, Object>{};
    StyleJson.putEnum(json, 'period', period, defaults.period);
    return json;
  }

  ExploreBehavior copyWith({ExplorePeriod? period}) =>
      ExploreBehavior(period: period ?? this.period);

  @override
  bool operator ==(Object other) =>
      other is ExploreBehavior && other.period == period;

  @override
  int get hashCode => period.hashCode;
}

/// 探索页设置的整体：当前布局、我的布局与行为。
///
/// 持久化为单个 JSON 设置键（`app.settings.explore_layout`，备份字段
/// `exploreLayoutRaw`）：`{"v":1,"current":{…},"saved":[…],"behavior":{…}}`。
/// 放在一个键里，备份恢复与失败回滚都是原子的；全为默认时编码为 null，由
/// 设置服务删除该键。保存项的增删改与上限见 [SavedStyles]；所有修改都原样
/// 保留 [behavior]。
@immutable
class ExploreSettings implements StyleLibrary<ExploreLayout, ExploreSettings> {
  ExploreSettings({
    ExploreLayout? current,
    this.saved = const <ExploreSavedLayout>[],
    this.behavior = ExploreBehavior.defaults,
  }) : current = current ?? ExploreLayout.defaults;

  static final ExploreSettings defaults = ExploreSettings();
  static const int schemaVersion = 1;

  /// 解析持久化的 JSON；null、空串或损坏时返回默认设置。各部分逐项容错。
  factory ExploreSettings.decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return defaults;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      // 损坏的配置按默认布局展示，不能让外观偏好阻断探索页。
      return defaults;
    }
    if (decoded is! Map) return defaults;
    return ExploreSettings(
      current: ExploreLayout.fromJson(decoded['current']),
      saved: SavedStyles.decode(decoded['saved'], ExploreLayout.fromJson),
      behavior: ExploreBehavior.fromJson(decoded['behavior']),
    );
  }

  @override
  final ExploreLayout current;
  @override
  final List<ExploreSavedLayout> saved;
  final ExploreBehavior behavior;

  bool get isDefault =>
      current.isDefault && saved.isEmpty && behavior.isDefault;

  @override
  bool get canSaveMore => saved.length < SavedStyles.maxItems;

  /// 默认设置编码为 null（删除键）。
  String? encode() {
    if (isDefault) return null;
    final behaviorJson = behavior.toJson();
    return jsonEncode(<String, Object>{
      'v': schemaVersion,
      'current': current.toJson(),
      if (saved.isNotEmpty)
        'saved': SavedStyles.encode(saved, (layout) => layout.toJson()),
      if (behaviorJson.isNotEmpty) 'behavior': behaviorJson,
    });
  }

  ExploreSettings withBehavior(ExploreBehavior value) =>
      ExploreSettings(current: current, saved: saved, behavior: value);

  @override
  ExploreSettings withCurrent(ExploreLayout style) =>
      ExploreSettings(current: style, saved: saved, behavior: behavior);

  @override
  ExploreSettings addSaved(String name, ExploreLayout style, {DateTime? now}) =>
      _withSaved(SavedStyles.add(saved, name, style, now: now));

  @override
  ExploreSettings renameSaved(String id, String name) =>
      _withSaved(SavedStyles.rename(saved, id, name));

  @override
  ExploreSettings removeSaved(String id) =>
      _withSaved(SavedStyles.remove(saved, id));

  @override
  ExploreSettings restoreSaved(ExploreSavedLayout item, int index) =>
      _withSaved(SavedStyles.restore(saved, item, index));

  ExploreSettings _withSaved(List<ExploreSavedLayout>? next) => next == null
      ? this
      : ExploreSettings(current: current, saved: next, behavior: behavior);

  @override
  bool operator ==(Object other) =>
      other is ExploreSettings &&
      other.current == current &&
      listEquals(other.saved, saved) &&
      other.behavior == behavior;

  @override
  int get hashCode => Object.hash(current, Object.hashAll(saved), behavior);
}
