import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../diaries/models/style_library/style_json.dart';
import 'explore_module_id.dart';
import 'explore_module_spec.dart';
import 'explore_option_spec.dart';

/// 布局里的一项：认得的卡片（[ExploreModuleConfig]），或新版本写入、本版本
/// 认不出的卡片（[ExploreUnknownModule]，原样保留、位置不变）。
sealed class ExploreLayoutEntry {
  const ExploreLayoutEntry();

  Map<String, Object?> toJson();
}

/// 一张卡片在布局里的设置：是否显示、宽窗口下的宽度与它的选项。
///
/// 选项只存与默认不同的项（规整后的存储值，见 [ExploreOptionSpec]）；读取时
/// 认不出的选项键原样保留，新版本加的选项导回旧版本再导出不会丢。值相等按
/// 选项的规范写法比较（[exploreCanonicalJson]）。
@immutable
final class ExploreModuleConfig extends ExploreLayoutEntry {
  ExploreModuleConfig(
    this.id, {
    required this.visible,
    this.span = ExploreModuleSpan.auto,
    Map<String, Object> options = const <String, Object>{},
  }) : options = Map<String, Object>.unmodifiable(options),
       _signature = exploreCanonicalJson(options);

  /// 这张卡的默认设置（默认显隐、自动宽度、无自定义选项）。
  factory ExploreModuleConfig.initial(ExploreModuleSpec spec) =>
      ExploreModuleConfig(spec.id, visible: spec.visibleByDefault);

  /// 解析一项；[json] 的 `id` 已确认是 [id]。逐字段容错。
  factory ExploreModuleConfig.fromJson(
    ExploreModuleId id,
    Map<String, dynamic> json,
  ) {
    final spec = ExploreModuleSpec.of(id);
    final rawOptions = StyleJson.map(json['o']) ?? const <String, dynamic>{};
    final options = <String, Object>{};
    for (final MapEntry(:key, :value) in rawOptions.entries) {
      ExploreOptionSpec? option;
      for (final candidate in spec.options) {
        if (candidate.key == key) option = candidate;
      }
      if (option == null) {
        // 认不出的键：新版本的选项，原样保留。
        if (value != null) options[key] = value;
        continue;
      }
      final normalized = option.normalize(value);
      if (normalized != null && !option.isDefaultRaw(normalized)) {
        options[key] = normalized;
      }
    }
    return ExploreModuleConfig(
      id,
      visible: StyleJson.boolean(json['on'], spec.visibleByDefault),
      span: StyleJson.enumByName(
        ExploreModuleSpan.values,
        json['span'],
        ExploreModuleSpan.auto,
      ),
      options: options,
    );
  }

  final ExploreModuleId id;
  final bool visible;
  final ExploreModuleSpan span;
  final Map<String, Object> options;
  final String _signature;

  ExploreModuleSpec get spec => ExploreModuleSpec.of(id);

  /// 宽窗口下实际占的宽度（自动时取默认）。
  ExploreModuleSpan get resolvedSpan => spec.resolveSpan(span);

  /// 是否与这张卡的默认设置相同。
  bool get isInitial =>
      visible == spec.visibleByDefault &&
      span == ExploreModuleSpan.auto &&
      options.isEmpty;

  T choice<T extends Enum>(ExploreChoiceOption<T> option) =>
      option.read(options);

  bool toggle(ExploreToggleOption option) => option.read(options);

  int count(ExploreCountOption option) => option.read(options);

  List<T> multi<T extends Enum>(ExploreMultiOption<T> option) =>
      option.read(options);

  /// 选项的当前存储值（没有自定义时为默认值），编辑页用。
  Object rawOption(ExploreOptionSpec option) =>
      option.normalize(options[option.key]) ?? option.defaultRaw;

  /// 改一项选项；值不合法时不变，等于默认时移除该键。
  ExploreModuleConfig withOption(ExploreOptionSpec option, Object value) {
    final normalized = option.normalize(value);
    if (normalized == null) return this;
    final next = Map<String, Object>.of(options);
    if (option.isDefaultRaw(normalized)) {
      next.remove(option.key);
    } else {
      next[option.key] = normalized;
    }
    return ExploreModuleConfig(id, visible: visible, span: span, options: next);
  }

  ExploreModuleConfig copyWith({bool? visible, ExploreModuleSpan? span}) =>
      ExploreModuleConfig(
        id,
        visible: visible ?? this.visible,
        span: span ?? this.span,
        options: options,
      );

  /// 显隐总是写入：保存的布局保留用户看到的状态，即使以后改了默认显隐。
  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id.name,
    'on': visible,
    if (span != ExploreModuleSpan.auto) 'span': span.name,
    if (options.isNotEmpty) 'o': options,
  };

  @override
  bool operator ==(Object other) =>
      other is ExploreModuleConfig &&
      other.id == id &&
      other.visible == visible &&
      other.span == span &&
      other._signature == _signature;

  @override
  int get hashCode => Object.hash(id, visible, span, _signature);
}

/// 认不出的卡片：原样保留它的 JSON，读写时位置不变；编辑页与探索页都不显示。
@immutable
final class ExploreUnknownModule extends ExploreLayoutEntry {
  ExploreUnknownModule(this.id, Map<String, dynamic> json)
    : _json = exploreCanonicalJson(json);

  final String id;
  final String _json;

  @override
  Map<String, Object?> toJson() =>
      Map<String, Object?>.from(jsonDecode(_json) as Map);

  @override
  bool operator ==(Object other) =>
      other is ExploreUnknownModule && other._json == _json;

  @override
  int get hashCode => _json.hashCode;
}
