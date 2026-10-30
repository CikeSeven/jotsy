import 'sync_model.dart';
import 'sync_state_model.dart';

/// 检查点折叠规则（规格 §3）：把“上次观测 P → 本次观测 C”的差异记进分面历史、
/// 墓碑与标签改名。会话开始时刷新检查点、同步写入之后，用的都是这一套。
///
/// 纯数据、无 I/O；[SyncStateData] 由 `SyncLocalState` 负责读写文件。
///
/// 写时复制：被改动的键整块换成新的 Map / List，从不原地修改已有的内层
/// 集合。已经交给规划器的快照（外层浅拷贝）因此在之后的折叠中保持不变。

/// 每个分面最多保留的历史条数。
const int kSyncHistoryLimit = 8;

/// 墓碑与改名记录的保留时长与条数上限。
const Duration kSyncTombstoneMaxAge = Duration(days: 365);
const int kSyncTombstoneMaxCount = 50000;

/// 分面历史、墓碑与改名记录（内存形态）。
class SyncStateData {
  SyncStateData({
    Map<SyncKey, Map<String, List<SyncHistoryEntry>>>? history,
    Map<SyncKey, SyncTombstone>? tombstones,
    Map<String, SyncTagRename>? renames,
  }) : history = history ?? <SyncKey, Map<String, List<SyncHistoryEntry>>>{},
       tombstones = tombstones ?? <SyncKey, SyncTombstone>{},
       renames = renames ?? <String, SyncTagRename>{};

  /// 键 → 分面 → 历史（新的在前）。
  final Map<SyncKey, Map<String, List<SyncHistoryEntry>>> history;
  final Map<SyncKey, SyncTombstone> tombstones;

  /// 旧名 → 改名记录。
  final Map<String, SyncTagRename> renames;

  /// 把 [entry] 插到 [key] / [facet] 的历史最前；同一哈希只留最新的一条
  /// （A → B → A 这样改回去时不重复占位），超出 [kSyncHistoryLimit] 的丢掉。
  void pushHistory(SyncKey key, String facet, SyncHistoryEntry entry) {
    final facets = history[key];
    final previous = facets?[facet] ?? const <SyncHistoryEntry>[];
    final next = <SyncHistoryEntry>[
      entry,
      for (final old in previous)
        if (old.hash != entry.hash) old,
    ];
    history[key] = <String, List<SyncHistoryEntry>>{
      ...?facets,
      facet: List<SyncHistoryEntry>.unmodifiable(next.take(kSyncHistoryLimit)),
    };
  }

  /// 按时间与条数淘汰墓碑和改名记录（[now] 为 UTC 毫秒）。
  void prune(int now) {
    final cutoff = now - kSyncTombstoneMaxAge.inMilliseconds;
    tombstones.removeWhere((_, tombstone) => tombstone.deletedAt < cutoff);
    renames.removeWhere((_, rename) => rename.at < cutoff);
    if (tombstones.length > kSyncTombstoneMaxCount) {
      final oldest = tombstones.entries.toList()
        ..sort((a, b) {
          final byTime = a.value.deletedAt.compareTo(b.value.deletedAt);
          return byTime != 0 ? byTime : a.key.compareTo(b.key);
        });
      for (final entry in oldest.take(
        tombstones.length - kSyncTombstoneMaxCount,
      )) {
        tombstones.remove(entry.key);
      }
    }
    if (renames.length > kSyncTombstoneMaxCount) {
      final oldest = renames.values.toList()
        ..sort((a, b) {
          final byTime = a.at.compareTo(b.at);
          return byTime != 0 ? byTime : a.from.compareTo(b.from);
        });
      for (final rename in oldest.take(
        renames.length - kSyncTombstoneMaxCount,
      )) {
        renames.remove(rename.from);
      }
    }
  }
}

/// 把 [current] 相对 [previous] 的差异折进 [state]，返回新的检查点。
///
/// - P、C 都有、分面哈希不同：P 的旧哈希（及要记值的分面的旧值）进历史；
/// - P 有、C 没有：写墓碑（known = P 的各分面哈希 + 各分面历史），该键的
///   历史随之并进墓碑、不再单独保留；标签若同一本地 id 在 C 里换了名字，另记
///   改名（旧名照样写墓碑）；
/// - C 有、P 没有：新记录，没有历史；本机若有它的墓碑或改名记录（删了又建回
///   同名记录）一并去掉，墓碑只描述本机“现在没有”的记录；
/// - 只比较 [current] 观测到的实体；没观测的实体在新检查点里沿用 P 的条目。
///
/// [previous] 为 null（第一次、或状态被重置）时没有差异可记，C 直接成为检查点。
///
/// [seenAtOverrides]（键 → 分面 → 毫秒）只在同步写入之后传入（规划器的
/// `SyncSidePlan.historySeenAt`）：P、C 都有且哈希变了的分面，旧哈希进历史时
/// 有覆盖值就以它为 `seenAt`，没有才用 [now]。这些分面是直接采纳了另一侧的
/// 值，覆盖值是那个值在来源一侧的确立时间——若记成写入时刻，采纳者每次都会
/// 变成“最新确立者”，三台以上设备之间来回改过的值会按同步顺序无休止地翻转
/// （规格 §4.1.1）。墓碑、改名与新记录不受影响；覆盖了没变化或不存在的分面
/// 时忽略。
SyncObservation foldSyncObservation({
  required SyncObservation? previous,
  required SyncObservation current,
  required SyncStateData state,
  required int now,
  Map<SyncKey, Map<String, int>> seenAtOverrides =
      const <SyncKey, Map<String, int>>{},
}) {
  final observed = current.observed;
  if (previous != null) {
    final currentTagNames = <int, String>{
      for (final entry in current.tagLocalIds.entries) entry.value: entry.key,
    };
    for (final entry in previous.manifest.entries.entries) {
      final key = entry.key;
      if (!observed.contains(key.entity)) continue;
      final before = entry.value;
      final after = current.manifest[key];
      if (after != null) {
        final overrides = seenAtOverrides[key];
        for (final facet in before.entries) {
          if (after[facet.key] == facet.value) continue;
          final values = SyncFacet.tracksValue(key.entity, facet.key)
              ? previous.trackedValues[key]
              : null;
          final hasValue = values != null && values.containsKey(facet.key);
          state.pushHistory(
            key,
            facet.key,
            SyncHistoryEntry(
              hash: facet.value,
              seenAt: overrides?[facet.key] ?? now,
              hasValue: hasValue,
              value: hasValue ? values[facet.key] : null,
            ),
          );
        }
        continue;
      }
      state.tombstones[key] = _tombstoneOf(key, before, state, now);
      state.history.remove(key);
      if (key.entity == SyncEntity.tag) {
        _recordRename(key.id, previous, current, currentTagNames, state, now);
      }
    }
  }
  for (final key in current.manifest.keys) {
    state.tombstones.remove(key);
    if (key.entity == SyncEntity.tag) state.renames.remove(key.id);
  }
  state.prune(now);

  if (previous == null) return current;
  // 没观测的实体沿用上一次的条目与值（如这次没有请求 settings）。
  final entries = <SyncKey, Map<String, String>>{...current.manifest.entries};
  final values = <SyncKey, Map<String, Object?>>{...current.trackedValues};
  for (final entry in previous.manifest.entries.entries) {
    if (observed.contains(entry.key.entity)) continue;
    entries[entry.key] = entry.value;
    final value = previous.trackedValues[entry.key];
    if (value != null) values[entry.key] = value;
  }
  return SyncObservation(
    manifest: SyncManifest(entries),
    trackedValues: values,
    tagLocalIds: current.tagLocalIds,
    observed: <SyncEntity>{...previous.observed, ...observed},
  );
}

SyncTombstone _tombstoneOf(
  SyncKey key,
  Map<String, String> hashes,
  SyncStateData state,
  int now,
) {
  final known = <String, List<String>>{};
  void add(String facet, String hash) {
    final list = known.putIfAbsent(facet, () => <String>[]);
    if (!list.contains(hash)) list.add(hash);
  }

  for (final facet in hashes.entries) {
    add(facet.key, facet.value);
  }
  final history = state.history[key];
  if (history != null) {
    for (final facet in history.entries) {
      for (final entry in facet.value) {
        add(facet.key, entry.hash);
      }
    }
  }
  return SyncTombstone(deletedAt: now, known: known);
}

/// 旧名 [from] 在 P 里的本地 id，到 C 里叫了别的名字：记为改名。已有指向
/// [from] 的改名（更早的 x → from）顺带改成指向新名，规划器只需查一跳。
void _recordRename(
  String from,
  SyncObservation previous,
  SyncObservation current,
  Map<int, String> currentTagNames,
  SyncStateData state,
  int now,
) {
  final localId = previous.tagLocalIds[from];
  if (localId == null) return;
  final to = currentTagNames[localId];
  if (to == null || to == from) return;
  if (!current.manifest.containsKey(SyncKey(SyncEntity.tag, to))) return;
  for (final rename in state.renames.values.toList()) {
    if (rename.to == from) {
      state.renames[rename.from] = SyncTagRename(
        from: rename.from,
        to: to,
        at: rename.at,
      );
    }
  }
  state.renames[from] = SyncTagRename(from: from, to: to, at: now);
}
