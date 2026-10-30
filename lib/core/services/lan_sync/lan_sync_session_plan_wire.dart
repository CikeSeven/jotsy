// 写入计划的线上形态（发起方 → 响应方，docs/lan_sync.md §5.3 的
// `sync.apply.part` / `sync.apply`）。
//
// 职责边界：纯数据变换，无 I/O。写入列表按 `{k: 键, e: 规划时的分面哈希或
// null, r: 最终分面或 null（删除）}` 分段送达，收尾消息带原地改名、历史时间
// 继承与统计；对端来的每个字段都校验，不合格抛 FormatException。
import 'lan_sync_messages.dart';
import 'sync/sync_model.dart';
import 'sync/sync_plan.dart';

Map<String, Object?> lanSyncWriteToJson(SyncWrite write) => <String, Object?>{
  'k': write.key.toString(),
  'e': write.expected,
  'r': write.record?.facets,
};

SyncWrite lanSyncWriteFromJson(Object? json) {
  if (json is! Map || json['k'] is! String) {
    throw const FormatException('invalid write');
  }
  final key = SyncKey.parse(json['k'] as String);
  final record = json['r'];
  if (record != null && record is! Map) {
    throw const FormatException('invalid write record');
  }
  return SyncWrite(
    key: key,
    expected: _hashes(json['e']),
    record: record == null
        ? null
        : SyncRecord(key, (record as Map).cast<String, Object?>()),
  );
}

/// `sync.apply` 的收尾字段（写入列表经 `sync.apply.part` 先行送达）。
Map<String, Object?> lanSyncPlanTailToJson(
  SyncSidePlan plan,
) => <String, Object?>{
  'renames': [
    for (final op in plan.renames)
      {'from': op.from, 'to': op.to, 'e': op.expected, 'r': op.record.facets},
  ],
  'seenAt': {
    for (final entry in plan.historySeenAt.entries)
      entry.key.toString(): entry.value,
  },
  'stats': {
    for (final entry in plan.stats.entries)
      entry.key.name: [
        entry.value.added,
        entry.value.updated,
        entry.value.deleted,
      ],
  },
};

/// 由送达的写入与收尾字段还原响应方的计划（媒体候选由发起方处理，这里为空）。
SyncSidePlan lanSyncPlanFromWire(List<SyncWrite> writes, LanSyncMessage tail) {
  final rawRenames = tail.fields['renames'];
  final rawSeenAt = tail.fields['seenAt'];
  final rawStats = tail.fields['stats'];
  if (rawRenames is! List || rawSeenAt is! Map || rawStats is! Map) {
    throw const FormatException('invalid sync.apply');
  }
  final renames = <SyncTagRenameOp>[];
  for (final item in rawRenames) {
    if (item is! Map ||
        item['from'] is! String ||
        item['to'] is! String ||
        item['r'] is! Map) {
      throw const FormatException('invalid rename');
    }
    final to = item['to'] as String;
    renames.add(
      SyncTagRenameOp(
        from: item['from'] as String,
        to: to,
        expected: _hashes(item['e']) ?? const <String, String>{},
        record: SyncRecord(
          SyncKey(SyncEntity.tag, to),
          (item['r'] as Map).cast<String, Object?>(),
        ),
      ),
    );
  }
  final seenAt = <SyncKey, Map<String, int>>{};
  for (final entry in rawSeenAt.entries) {
    final facets = entry.value;
    if (facets is! Map) throw const FormatException('invalid seenAt');
    seenAt[SyncKey.parse('${entry.key}')] = <String, int>{
      for (final facet in facets.entries)
        if (facet.key is String && facet.value is int)
          facet.key as String: facet.value as int,
    };
  }
  final stats = <SyncEntity, SyncEntityCounts>{};
  for (final entry in rawStats.entries) {
    final entity = SyncEntity.tryParse('${entry.key}');
    final value = entry.value;
    if (entity == null || value is! List || value.length != 3) continue;
    final ints = [for (final n in value) n is int ? n : 0];
    stats[entity] = SyncEntityCounts(
      added: ints[0],
      updated: ints[1],
      deleted: ints[2],
    );
  }
  return SyncSidePlan(
    writes: writes,
    renames: renames,
    mediaNeeded: const <String>[],
    stats: stats,
    historySeenAt: seenAt,
  );
}

Map<String, String>? _hashes(Object? json) {
  if (json == null) return null;
  if (json is! Map) throw const FormatException('invalid hashes');
  final hashes = <String, String>{};
  for (final entry in json.entries) {
    if (entry.key is! String || entry.value is! String) {
      throw const FormatException('invalid hash entry');
    }
    hashes[entry.key as String] = entry.value as String;
  }
  return hashes;
}
