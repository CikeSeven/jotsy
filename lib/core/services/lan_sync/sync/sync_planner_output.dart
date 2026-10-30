part of 'sync_planner.dart';

/// 产出（规格 §4.5、§4.6）：对比每侧现状与最终状态，生成写入、原地改名、
/// 媒体候选、统计与待确认事项。
///
/// - 最终值与这一侧当前哈希全同：不写；
/// - 最终不存在、这一侧有：删除（expected 为当前哈希）；
/// - 其余：写入最终记录（这一侧没有时 expected 为 null，即新增）；
/// - 这一侧的原地改名占掉 `tag:旧名` 的删除与 `tag:新名` 的新增；
/// - 媒体候选：写入记录里、哈希有变化的分面引用到的媒体键（没变的分面引用
///   的文件这一侧本来就有）；
/// - 历史时间继承：直接采纳了另一侧原值的分面，写入后折叠时旧值的 seenAt
///   用那个值在另一侧的确立时间（[SyncSidePlan.historySeenAt]）。
extension _Output on _Planner {
  SyncPlan buildPlan() {
    final all = <SyncKey>{...keys, ...createdKeys}.toList()..sort();
    final plans = <_Side, SyncSidePlan>{
      for (final side in _sides) side: _sidePlan(side, all),
    };
    final guards = <SyncDeletionGuard>[
      for (final side in _sides) ?_deletionGuard(side, plans[side]!),
    ];
    final sorted = copies.toList()
      ..sort((a, b) {
        final byOriginal = a.originalId.compareTo(b.originalId);
        return byOriginal != 0 ? byOriginal : a.copyId.compareTo(b.copyId);
      });
    return SyncPlan(
      local: plans[_Side.local]!,
      remote: plans[_Side.remote]!,
      conflictCopies: sorted,
      confirmations: SyncPendingConfirmations(
        deletionGuards: guards,
        sideChoiceCounts: sideChoiceActive
            ? _countByEntity(ancestryLess)
            : const <SyncEntity, int>{},
      ),
    );
  }

  SyncSidePlan _sidePlan(_Side side, List<SyncKey> all) {
    final renames = inPlaceRenames[side]!;
    final renamedNames = <String>{...renames.keys, ...renames.values};
    final writes = <SyncWrite>[];
    final stats = <SyncEntity, SyncEntityCounts>{};
    final media = <String>{};
    final seenAt = <SyncKey, Map<String, int>>{};
    void count(SyncEntity entity, {int a = 0, int u = 0, int d = 0}) {
      stats[entity] = (stats[entity] ?? const SyncEntityCounts()).plus(
        added: a,
        updated: u,
        deleted: d,
      );
    }

    for (final key in all) {
      final state = finals[key]!;
      if (state.kind == _Kind.same) continue;
      if (key.entity == SyncEntity.tag && renamedNames.contains(key.id)) {
        continue;
      }
      final current = hashesOn(side, key);
      if (!state.present) {
        if (current == null) continue;
        writes.add(SyncWrite(key: key, expected: current, record: null));
        count(key.entity, d: 1);
        continue;
      }
      final facets = state.facets;
      if (facets == null) {
        throw StateError('同步规划没有 $key 的最终值');
      }
      final record = SyncRecord(key, facets);
      final hashes = record.hashes;
      if (_sameHashes(current, hashes)) continue;
      writes.add(SyncWrite(key: key, expected: current, record: record));
      count(key.entity, a: current == null ? 1 : 0, u: current == null ? 0 : 1);
      for (final facet in record.facets.entries) {
        if (current?[facet.key] == hashes[facet.key]) continue;
        media.addAll(syncMediaKeysIn(facet.value));
      }
      // 采纳的值若之后又被从属关系改掉（不再等于另一侧的原值），就不继承。
      final adopted = inherited[side]![key];
      if (current != null && adopted != null) {
        final source = hashesOn(side.other, key);
        final times = <String, int>{
          for (final entry in adopted.entries)
            if (hashes[entry.key] == source?[entry.key] &&
                hashes[entry.key] != current[entry.key])
              entry.key: entry.value,
        };
        if (times.isNotEmpty) seenAt[key] = times;
      }
    }

    final ops = <SyncTagRenameOp>[];
    final froms = renames.keys.toList()..sort();
    for (final from in froms) {
      final to = renames[from]!;
      final toKey = SyncKey(SyncEntity.tag, to);
      ops.add(
        SyncTagRenameOp(
          from: from,
          to: to,
          expected: hashesOn(side, SyncKey(SyncEntity.tag, from))!,
          record: SyncRecord(toKey, finalFacets(toKey)!),
        ),
      );
      count(SyncEntity.tag, u: 1);
    }
    return SyncSidePlan(
      writes: writes,
      renames: ops,
      mediaNeeded: media.toList()..sort(),
      stats: stats,
      historySeenAt: seenAt,
    );
  }

  /// 删除保护：彻底删除的日记数 > max(20, 该侧日记总数的 10%)。
  SyncDeletionGuard? _deletionGuard(_Side side, SyncSidePlan plan) {
    final count = plan.diaryDeletions;
    final total = sideOf(
      side,
    ).manifest.keys.where((key) => key.entity == SyncEntity.diary).length;
    if (count <= 20 || count * 10 <= total) return null;
    return SyncDeletionGuard(side: side.role, count: count, total: total);
  }
}

/// 按实体计数（“以哪边为准”的明细）。
Map<SyncEntity, int> _countByEntity(Iterable<SyncKey> keys) {
  final counts = <SyncEntity, int>{};
  for (final key in keys) {
    counts[key.entity] = (counts[key.entity] ?? 0) + 1;
  }
  return counts;
}
