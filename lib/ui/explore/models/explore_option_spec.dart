import 'dart:convert';

import 'package:flutter/foundation.dart';

/// 探索页卡片选项的声明。
///
/// 每张卡有哪些选项、取值范围与默认值都登记在 `ExploreOptions`，编辑页按
/// 声明统一画出控件，卡片按声明读出类型化的值——加选项不必改编辑页。
///
/// 存储：选项存为 `{key: 值}`（枚举存名字、开关存布尔、数量存整数、多选存
/// 名字列表），只写与默认不同的项。读取逐项容错：值不合法时只让这一项回到
/// 默认（[normalize] 返回 null），不连累同一张卡的其他选项。
sealed class ExploreOptionSpec {
  const ExploreOptionSpec(this.key);

  /// 存储键；同一张卡里唯一。编辑页按它取选项标题（同名键含义一致）。
  final String key;

  /// 默认值的存储形式。
  Object get defaultRaw;

  /// 原始值 → 规整后的存储值；不合法时为 null（读取时回到默认）。
  Object? normalize(Object? raw);

  /// 存储值是否等于默认（等于默认时不写入）。
  bool isDefaultRaw(Object raw) => exploreOptionRawEquals(raw, defaultRaw);
}

/// 单选：取值为枚举 [T] 的一部分（[values] 可以是子集，顺序即编辑页里的顺序）。
final class ExploreChoiceOption<T extends Enum> extends ExploreOptionSpec {
  const ExploreChoiceOption(
    super.key, {
    required this.values,
    required this.fallback,
  });

  final List<T> values;
  final T fallback;

  @override
  Object get defaultRaw => fallback.name;

  @override
  Object? normalize(Object? raw) {
    if (raw is! String) return null;
    for (final value in values) {
      if (value.name == raw) return raw;
    }
    return null;
  }

  T read(Map<String, Object> options) {
    final raw = options[key];
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return fallback;
  }
}

/// 开关。
final class ExploreToggleOption extends ExploreOptionSpec {
  const ExploreToggleOption(super.key, {required this.fallback});

  final bool fallback;

  @override
  Object get defaultRaw => fallback;

  @override
  Object? normalize(Object? raw) => raw is bool ? raw : null;

  bool read(Map<String, Object> options) {
    final raw = options[key];
    return raw is bool ? raw : fallback;
  }
}

/// 数量：只能取 [values] 之一；0 表示“全部”。
final class ExploreCountOption extends ExploreOptionSpec {
  const ExploreCountOption(
    super.key, {
    required this.values,
    required this.fallback,
  });

  final List<int> values;
  final int fallback;

  @override
  Object get defaultRaw => fallback;

  @override
  Object? normalize(Object? raw) {
    if (raw is! num || !raw.isFinite) return null;
    final value = raw.round();
    return values.contains(value) ? value : null;
  }

  int read(Map<String, Object> options) {
    final raw = options[key];
    return raw is int && values.contains(raw) ? raw : fallback;
  }
}

/// 有序多选：保留选择的先后顺序（数据看板按这个顺序排格子），最多
/// [maxSelected] 项，至少一项（全部取消时回到默认）。
final class ExploreMultiOption<T extends Enum> extends ExploreOptionSpec {
  const ExploreMultiOption(
    super.key, {
    required this.values,
    required this.fallback,
    required this.maxSelected,
  });

  final List<T> values;
  final List<T> fallback;
  final int maxSelected;

  @override
  Object get defaultRaw => <String>[for (final value in fallback) value.name];

  @override
  Object? normalize(Object? raw) {
    if (raw is! List) return null;
    final names = <String>[];
    for (final item in raw) {
      if (names.length >= maxSelected) break;
      if (item is String &&
          !names.contains(item) &&
          values.any((value) => value.name == item)) {
        names.add(item);
      }
    }
    return names.isEmpty ? null : List<String>.unmodifiable(names);
  }

  List<T> read(Map<String, Object> options) {
    final raw = options[key];
    if (raw is! List) return fallback;
    final result = <T>[
      for (final name in raw)
        for (final value in values)
          if (value.name == name) value,
    ];
    return result.isEmpty ? fallback : List<T>.unmodifiable(result);
  }
}

/// 两个存储值是否相同（列表按元素比较，其余按 `==`）。
bool exploreOptionRawEquals(Object? a, Object? b) {
  if (a is List && b is List) return listEquals<Object?>(a, b);
  return a == b;
}

/// 选项表的规范写法（键排序后的 JSON），用于值相等与哈希：选项里可能有
/// 新版本写入、本版本认不出的键，原样保留，比较时同样参与。
String exploreCanonicalJson(Object? value) => jsonEncode(_sorted(value));

Object? _sorted(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => '$key').toList()..sort();
    return <String, Object?>{for (final key in keys) key: _sorted(value[key])};
  }
  if (value is List) return <Object?>[for (final item in value) _sorted(item)];
  return value;
}
