import 'package:meta/meta.dart';

import 'cloud_backup_incremental_format.dart';
import 'cloud_backup_models.dart';

/// 增量备份的远端清单与清理规划（纯函数，不联网、不读写文件、不取时钟）。
///
/// 清理规则（docs/cloud_backup.md「增量备份」）：
/// 1. 按时间保留最近 N 份增量备份（所有链一起算，N 为 0 时全部保留），更早
///    的先删索引再删快照——索引是提交标记，先删它，删到一半中断也不会留下
///    “看得见却恢复不了”的备份；
/// 2. 没有索引的快照（上传中断）超过宽限期就删；
/// 3. 媒体包按链回收：这条链保留下来的索引全部读得出时，没被它们引用的包
///    删掉；这条链一份索引都不剩时整链的包删掉；有读不出的索引（别的设备用
///    另一个密码写的链）时整条链不动；
/// 4. 包名里的时间不满宽限期（默认 24 小时）的一律不删：另一台设备可能正在
///    上传、还没来得及写索引；
/// 5. 每次最多删 [maxDeletions] 个文件（坚果云每 30 分钟限 600 次请求），剩下
///    的下次再删。过期的快照这次删不完时，这次一个包也不删：它们的索引还在，
///    包被删掉就会留下恢复不了的备份。

/// 一份已提交（有索引）的增量备份。
@immutable
class IncrementalSnapshotRef {
  const IncrementalSnapshotRef({
    required this.stem,
    required this.chain,
    required this.time,
    required this.index,
    this.snapshot,
  });

  final String stem;
  final String chain;
  final DateTime time;
  final CloudBackupEntry index;

  /// `.snap` 文件；被手动删掉时为 null（这份备份无法恢复，只等清理）。
  final CloudBackupEntry? snapshot;
}

@immutable
class IncrementalRemotePack {
  const IncrementalRemotePack(this.name, this.entry);

  final IncrementalFileName name;
  final CloudBackupEntry entry;
}

/// 从 [CloudBackupRemote.listFiles] 的结果整理出的增量备份文件。
@immutable
class IncrementalRemoteListing {
  const IncrementalRemoteListing({
    required this.snapshots,
    required this.orphanSnapshots,
    required this.packs,
  });

  /// 已提交的增量备份，新的在前。
  final List<IncrementalSnapshotRef> snapshots;

  /// 没有索引的 `.snap`（上传中断留下的）。
  final List<(IncrementalFileName, CloudBackupEntry)> orphanSnapshots;

  /// 媒体包，按文件名索引。
  final Map<String, IncrementalRemotePack> packs;

  factory IncrementalRemoteListing.of(Iterable<CloudBackupEntry> files) {
    final snaps = <String, (IncrementalFileName, CloudBackupEntry)>{};
    final indexes = <String, (IncrementalFileName, CloudBackupEntry)>{};
    final packs = <String, IncrementalRemotePack>{};
    for (final file in files) {
      final name = IncrementalFileName.parse(file.fileName);
      if (name == null) continue;
      switch (name.kind) {
        case IncrementalFileKind.snapshot:
          snaps[name.stem] = (name, file);
        case IncrementalFileKind.indexFile:
          indexes[name.stem] = (name, file);
        case IncrementalFileKind.pack:
          packs[file.fileName] = IncrementalRemotePack(name, file);
      }
    }
    final snapshots = [
      for (final MapEntry(key: stem, value: (name, entry)) in indexes.entries)
        IncrementalSnapshotRef(
          stem: stem,
          chain: name.chain,
          time: name.time,
          index: entry,
          snapshot: snaps[stem]?.$2,
        ),
    ]..sort(_newestFirst);
    return IncrementalRemoteListing(
      snapshots: List.unmodifiable(snapshots),
      orphanSnapshots: [
        for (final entry in snaps.entries)
          if (!indexes.containsKey(entry.key)) entry.value,
      ],
      packs: Map.unmodifiable(packs),
    );
  }

  /// 某条链最新的一份（没有时为 null）。
  IncrementalSnapshotRef? latestOf(String chain) {
    for (final snapshot in snapshots) {
      if (snapshot.chain == chain) return snapshot;
    }
    return null;
  }

  static int _newestFirst(IncrementalSnapshotRef a, IncrementalSnapshotRef b) {
    final byTime = b.time.compareTo(a.time);
    return byTime != 0 ? byTime : b.stem.compareTo(a.stem);
  }
}

/// 按保留份数留下的增量备份（新的在前）。
List<IncrementalSnapshotRef> retainedIncrementalSnapshots(
  IncrementalRemoteListing listing,
  int keep,
) => keep <= 0 || listing.snapshots.length <= keep
    ? listing.snapshots
    : listing.snapshots.sublist(0, keep);

/// 本次要删除的文件，按删除顺序排列。
@immutable
class IncrementalPrunePlan {
  const IncrementalPrunePlan(this.deletions);

  final List<CloudBackupEntry> deletions;

  bool get isEmpty => deletions.isEmpty;
}

/// 规划一次清理。[retainedIndexes] 以主干为键，给出保留下来的备份中读得出
/// 的索引；没给出的视为读不出（这条链的包不动）。
IncrementalPrunePlan planIncrementalPrune({
  required IncrementalRemoteListing listing,
  required int keep,
  required Map<String, IncrementalIndex> retainedIndexes,
  required DateTime now,
  Duration grace = const Duration(hours: 24),
  int maxDeletions = 100,
}) {
  bool expired(DateTime time) => now.difference(time) >= grace;

  final retained = retainedIncrementalSnapshots(listing, keep);
  final retainedStems = {for (final snapshot in retained) snapshot.stem};

  final snapshotDeletions = <CloudBackupEntry>[
    for (final snapshot in listing.snapshots)
      if (!retainedStems.contains(snapshot.stem)) ...[
        snapshot.index,
        ?snapshot.snapshot,
      ],
    for (final (name, entry) in listing.orphanSnapshots)
      if (expired(name.time)) entry,
  ];
  if (snapshotDeletions.length >= maxDeletions) {
    return IncrementalPrunePlan(snapshotDeletions.sublist(0, maxDeletions));
  }

  final retainedByChain = <String, List<IncrementalSnapshotRef>>{};
  for (final snapshot in retained) {
    retainedByChain.putIfAbsent(snapshot.chain, () => []).add(snapshot);
  }
  final liveByChain = <String, Set<String>?>{};
  Set<String>? liveOf(String chain) => liveByChain.putIfAbsent(chain, () {
    final snapshots = retainedByChain[chain] ?? const [];
    final live = <String>{};
    for (final snapshot in snapshots) {
      final index = retainedIndexes[snapshot.stem];
      // 读不出的索引：不知道它引用了哪些包，整条链不动。
      if (index == null) return null;
      live.addAll(index.packNames);
    }
    return live;
  });

  final packDeletions = <CloudBackupEntry>[];
  final packs = listing.packs.values.toList()
    ..sort((a, b) => a.name.time.compareTo(b.name.time));
  for (final pack in packs) {
    if (!expired(pack.name.time)) continue;
    final live = liveOf(pack.name.chain);
    if (live == null || live.contains(pack.entry.fileName)) continue;
    packDeletions.add(pack.entry);
  }
  final room = maxDeletions - snapshotDeletions.length;
  return IncrementalPrunePlan([
    ...snapshotDeletions,
    ...packDeletions.take(room),
  ]);
}
