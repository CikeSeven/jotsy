part of 'sync_planner.dart';

/// 最终状态的表示与读取规范值的小工具（纯函数）。规范值里的对象一律写时
/// 复制：记录里的值可能被别处共用（哈希是惰性缓存的），从不原地修改。

enum _Kind { same, value, absent, unknown }

/// 一条记录的最终状态。
/// - same：两侧本来就相同、规划不改（值即本机记录）；
/// - value：给定的最终值；
/// - absent：最终不存在；
/// - unknown：最终存在，但值所在的记录还没取到（只在 [planSyncFetch] 中出现）。
@immutable
class _Final {
  const _Final._(this.kind, [this.facets]);

  factory _Final.value(Map<String, Object?> facets) =>
      _Final._(_Kind.value, Map<String, Object?>.unmodifiable(facets));

  static const _Final same = _Final._(_Kind.same);
  static const _Final absent = _Final._(_Kind.absent);
  static const _Final unknown = _Final._(_Kind.unknown);

  final _Kind kind;
  final Map<String, Object?>? facets;

  bool get present => kind != _Kind.absent;
}

bool _sameHashes(Map<String, String>? a, Map<String, String>? b) {
  if (a == null || b == null || a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

int? _intOf(Object? value) => switch (value) {
  final int v => v,
  final double v when v == v.truncateToDouble() => v.toInt(),
  _ => null,
};

Map<String, Object?>? _mapOf(Object? value) =>
    value is Map ? value.cast<String, Object?>() : null;

/// 分面 [facet] 里对象值的 [field]。
Object? _field(Map<String, Object?>? facets, String facet, String field) =>
    _mapOf(facets?[facet])?[field];

/// 把 [facets] 的 [facet] 对象里的 [field] 换成 [value]（写时复制）。
Map<String, Object?> _withField(
  Map<String, Object?> facets,
  String facet,
  String field,
  Object? value,
) => <String, Object?>{
  ...facets,
  facet: <String, Object?>{...?_mapOf(facets[facet]), field: value},
};

/// 字符串列表（规范值里的 `names` / `ids`）；不是列表时为空。
List<String> _stringList(Object? value) => <String>[
  if (value is List)
    for (final item in value)
      if (item is String) item,
];
