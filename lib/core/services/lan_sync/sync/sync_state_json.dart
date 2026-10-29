/// 分面历史、墓碑与改名记录的文件 JSON 形态（`SyncLocalState` 读写）。
///
/// history:    {"v":1,"keys":{"<键>":{"<分面>":[{"h":哈希,"t":毫秒,"v":值?},…]}}}
/// tombstones: {"v":1,"keys":{"<键>":{"t":毫秒,"known":{"<分面>":[哈希,…]}}}}
/// renames:    {"v":1,"renames":{"<旧名>":{"to":新名,"t":毫秒}}}
///
/// 逐条容错：单条坏数据只丢这一条，不连累整个文件。
library;

import 'sync_model.dart';
import 'sync_state_fold.dart';
import 'sync_state_model.dart';

const int _kStateFileVersion = 1;

Map<String, Object?> syncEncodeHistory(
  Map<SyncKey, Map<String, List<SyncHistoryEntry>>> history,
) => <String, Object?>{
  'v': _kStateFileVersion,
  'keys': <String, Object?>{
    for (final entry in history.entries)
      entry.key.toString(): <String, Object?>{
        for (final facet in entry.value.entries)
          facet.key: <Object?>[for (final item in facet.value) item.toJson()],
      },
  },
};

Map<SyncKey, Map<String, List<SyncHistoryEntry>>> syncDecodeHistory(
  Object? json,
) {
  final result = <SyncKey, Map<String, List<SyncHistoryEntry>>>{};
  final keys = _versionedMap(json, 'keys');
  if (keys == null) return result;
  for (final entry in keys.entries) {
    final key = SyncKey.tryParse('${entry.key}');
    final facets = entry.value;
    if (key == null || facets is! Map) continue;
    final decoded = <String, List<SyncHistoryEntry>>{};
    for (final facet in facets.entries) {
      final items = facet.value;
      if (facet.key is! String || items is! List) continue;
      final list = <SyncHistoryEntry>[];
      for (final item in items) {
        try {
          list.add(SyncHistoryEntry.fromJson(item));
        } on FormatException {
          // 跳过这一条。
        }
      }
      if (list.isNotEmpty) {
        decoded[facet.key as String] = List<SyncHistoryEntry>.unmodifiable(
          list.take(kSyncHistoryLimit),
        );
      }
    }
    if (decoded.isNotEmpty) result[key] = decoded;
  }
  return result;
}

Map<String, Object?> syncEncodeTombstones(
  Map<SyncKey, SyncTombstone> tombstones,
) => <String, Object?>{
  'v': _kStateFileVersion,
  'keys': <String, Object?>{
    for (final entry in tombstones.entries)
      entry.key.toString(): entry.value.toJson(),
  },
};

Map<SyncKey, SyncTombstone> syncDecodeTombstones(Object? json) {
  final result = <SyncKey, SyncTombstone>{};
  final keys = _versionedMap(json, 'keys');
  if (keys == null) return result;
  for (final entry in keys.entries) {
    final key = SyncKey.tryParse('${entry.key}');
    if (key == null) continue;
    try {
      result[key] = SyncTombstone.fromJson(entry.value);
    } on FormatException {
      // 跳过这一条。
    }
  }
  return result;
}

Map<String, Object?> syncEncodeRenames(Map<String, SyncTagRename> renames) =>
    <String, Object?>{
      'v': _kStateFileVersion,
      'renames': <String, Object?>{
        for (final entry in renames.entries) entry.key: entry.value.toJson(),
      },
    };

Map<String, SyncTagRename> syncDecodeRenames(Object? json) {
  final result = <String, SyncTagRename>{};
  final renames = _versionedMap(json, 'renames');
  if (renames == null) return result;
  for (final entry in renames.entries) {
    if (entry.key is! String) continue;
    try {
      result[entry.key as String] = SyncTagRename.fromJson(
        entry.key as String,
        entry.value,
      );
    } on FormatException {
      // 跳过这一条。
    }
  }
  return result;
}

Map<dynamic, dynamic>? _versionedMap(Object? json, String field) {
  if (json is! Map || json['v'] != _kStateFileVersion) return null;
  final value = json[field];
  return value is Map ? value : null;
}
