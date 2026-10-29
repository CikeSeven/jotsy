import 'package:meta/meta.dart';

import 'sync_model.dart';

/// 本机同步状态的数据模型（规格 §3）：一次观测、分面历史、墓碑、标签改名。
///
/// 纯 Dart：规划器读取这些类型（经会话消息交换对方的历史与墓碑时也用同一套
/// JSON），它的测试不牵进 Flutter。文件读写与折叠规则分别在
/// `sync_local_state.dart` 与 `sync_state_fold.dart`。

/// 一次对本机数据的观测：当前清单、需要记录值的分面的当前值、标签名 → 本地
/// id（检测改名用），以及这次观测覆盖了哪些实体。
///
/// 检查点（`checkpoint.json.gz`）就是上一次的观测。[observed] 不含某个实体
/// （如本次没有请求 settings）时，比较时跳过该实体，检查点里它的旧条目原样
/// 保留：没观测不等于删除。
@immutable
class SyncObservation {
  SyncObservation({
    required this.manifest,
    required Map<SyncKey, Map<String, Object?>> trackedValues,
    required Map<String, int> tagLocalIds,
    required Set<SyncEntity> observed,
  }) : trackedValues = Map<SyncKey, Map<String, Object?>>.unmodifiable(
         trackedValues,
       ),
       tagLocalIds = Map<String, int>.unmodifiable(tagLocalIds),
       observed = Set<SyncEntity>.unmodifiable(observed);

  factory SyncObservation.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('无效的检查点');
    final values = <SyncKey, Map<String, Object?>>{};
    final rawValues = json['values'];
    if (rawValues is Map) {
      for (final entry in rawValues.entries) {
        final key = SyncKey.tryParse('${entry.key}');
        if (key == null || entry.value is! Map) continue;
        values[key] = (entry.value as Map).cast<String, Object?>();
      }
    }
    final tags = <String, int>{};
    final rawTags = json['tags'];
    if (rawTags is Map) {
      for (final entry in rawTags.entries) {
        if (entry.key is String && entry.value is int) {
          tags[entry.key as String] = entry.value as int;
        }
      }
    }
    final observed = <SyncEntity>{};
    final rawObserved = json['observed'];
    if (rawObserved is List) {
      for (final name in rawObserved) {
        final entity = name is String ? SyncEntity.tryParse(name) : null;
        if (entity != null) observed.add(entity);
      }
    }
    return SyncObservation(
      manifest: SyncManifest.fromJson(json['manifest']),
      trackedValues: values,
      tagLocalIds: tags,
      observed: observed,
    );
  }

  final SyncManifest manifest;

  /// 键 → 分面 → 当前值，只含 [SyncFacet.tracksValue] 的分面。
  final Map<SyncKey, Map<String, Object?>> trackedValues;

  final Map<String, int> tagLocalIds;
  final Set<SyncEntity> observed;

  Map<String, Object?> toJson() {
    final keys = trackedValues.keys.toList()..sort();
    return <String, Object?>{
      'manifest': manifest.toJson(),
      'values': <String, Object?>{
        for (final key in keys) key.toString(): trackedValues[key],
      },
      'tags': tagLocalIds,
      'observed': <String>[
        for (final entity in SyncEntity.values)
          if (observed.contains(entity)) entity.name,
      ],
    };
  }
}

/// 分面历史里的一条：这个分面曾经的哈希、发现它被换掉的时间（UTC 毫秒），
/// 以及需要记录值的分面的旧值。
@immutable
class SyncHistoryEntry {
  const SyncHistoryEntry({
    required this.hash,
    required this.seenAt,
    this.hasValue = false,
    this.value,
  });

  factory SyncHistoryEntry.fromJson(Object? json) {
    if (json is! Map || json['h'] is! String || json['t'] is! int) {
      throw const FormatException('无效的分面历史');
    }
    return SyncHistoryEntry(
      hash: json['h'] as String,
      seenAt: json['t'] as int,
      hasValue: json.containsKey('v'),
      value: json['v'],
    );
  }

  final String hash;
  final int seenAt;

  /// 是否带值（只有 diary.tags 与 orderList.items 带值）。值本身可以是任何
  /// JSON，单看 [value] 是否为 null 分不清“没记录”和“值就是 null”。
  final bool hasValue;
  final Object? value;

  Map<String, Object?> toJson() => <String, Object?>{
    'h': hash,
    't': seenAt,
    if (hasValue) 'v': value,
  };
}

/// 墓碑：本机删除一条记录的时间（UTC 毫秒）与删除前已知的各分面哈希（删除
/// 时的当前哈希 + 历史）。规划器据此判断对方的记录是不是“删除之后没改过”。
@immutable
class SyncTombstone {
  SyncTombstone({
    required this.deletedAt,
    required Map<String, List<String>> known,
  }) : known = Map<String, List<String>>.unmodifiable(
         known.map(
           (facet, hashes) =>
               MapEntry(facet, List<String>.unmodifiable(hashes)),
         ),
       );

  factory SyncTombstone.fromJson(Object? json) {
    if (json is! Map || json['t'] is! int || json['known'] is! Map) {
      throw const FormatException('无效的墓碑');
    }
    return SyncTombstone(
      deletedAt: json['t'] as int,
      known: <String, List<String>>{
        for (final entry in (json['known'] as Map).entries)
          if (entry.key is String && entry.value is List)
            entry.key as String: <String>[
              for (final hash in entry.value as List)
                if (hash is String) hash,
            ],
      },
    );
  }

  final int deletedAt;
  final Map<String, List<String>> known;

  /// [facet] 的哈希 [hash] 是否在删除前就已知。
  bool knows(String facet, String hash) =>
      known[facet]?.contains(hash) ?? false;

  Map<String, Object?> toJson() => <String, Object?>{
    't': deletedAt,
    'known': known,
  };
}

/// 标签改名：本机把名为 [from] 的标签改名为 [to]（同一个本地 id）。
@immutable
class SyncTagRename {
  const SyncTagRename({required this.from, required this.to, required this.at});

  factory SyncTagRename.fromJson(String from, Object? json) {
    if (json is! Map || json['to'] is! String || json['t'] is! int) {
      throw const FormatException('无效的改名记录');
    }
    return SyncTagRename(
      from: from,
      to: json['to'] as String,
      at: json['t'] as int,
    );
  }

  final String from;
  final String to;
  final int at;

  Map<String, Object?> toJson() => <String, Object?>{'to': to, 't': at};
}
