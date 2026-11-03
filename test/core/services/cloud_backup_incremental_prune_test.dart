import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/cloud_backup_incremental_format.dart';
import 'package:node_diary/core/services/cloud_backup_incremental_prune.dart';
import 'package:node_diary/core/services/cloud_backup_models.dart';

/// 清理规划（纯函数）：保留份数、按链回收媒体包、宽限期、读不出的链与
/// 每次删除上限。
void main() {
  const chainA = 'aaaaaaaa';
  const chainB = 'bbbbbbbb';
  final now = DateTime(2026, 11, 10, 12);
  final hash1 = '1' * 64;
  final hash2 = '2' * 64;
  final hash3 = '3' * 64;

  DateTime daysAgo(int days) => now.subtract(Duration(days: days));

  CloudBackupEntry file(String name) =>
      CloudBackupEntry(fileName: name, remoteId: name);

  String stem(int days, String chain) =>
      incrementalSnapshotStem(daysAgo(days), chain);

  List<CloudBackupEntry> snapshot(int days, String chain) => [
    file('${stem(days, chain)}.snap'),
    file('${stem(days, chain)}.idx'),
  ];

  String pack(int days, String chain, String random) =>
      incrementalPackName(daysAgo(days), chain, random);

  IncrementalIndex index(String chain, Map<String, String> packs) =>
      IncrementalIndex(
        chain: chain,
        createdAt: now,
        encrypted: false,
        payloadSha256: hash1,
        snapshotSize: 1,
        media: {
          for (final (i, hash) in packs.keys.indexed)
            'diary_images/$i.jpg': IncrementalMediaRef(hash, 1),
        },
        packs: packs,
      );

  Set<String> deleted(IncrementalPrunePlan plan) => {
    for (final entry in plan.deletions) entry.fileName,
  };

  test('keeps the newest snapshots and deletes the rest index first', () {
    final listing = IncrementalRemoteListing.of([
      for (final days in [5, 4, 3, 2, 1]) ...snapshot(days, chainA),
    ]);
    expect(listing.snapshots.first.stem, stem(1, chainA));

    final plan = planIncrementalPrune(
      listing: listing,
      keep: 2,
      retainedIndexes: const {},
      now: now,
    );

    expect(plan.deletions.map((entry) => entry.fileName).toList(), [
      '${stem(3, chainA)}.idx',
      '${stem(3, chainA)}.snap',
      '${stem(4, chainA)}.idx',
      '${stem(4, chainA)}.snap',
      '${stem(5, chainA)}.idx',
      '${stem(5, chainA)}.snap',
    ]);
    expect(
      planIncrementalPrune(
        listing: listing,
        keep: 0,
        retainedIndexes: const {},
        now: now,
      ).isEmpty,
      isTrue,
    );
  });

  test('deletes old packs that no retained snapshot of the chain uses', () {
    final used = pack(5, chainA, '00000001');
    final unused = pack(5, chainA, '00000002');
    final fresh = pack(0, chainA, '00000003');
    final listing = IncrementalRemoteListing.of([
      ...snapshot(1, chainA),
      file(used),
      file(unused),
      file(fresh),
    ]);

    final plan = planIncrementalPrune(
      listing: listing,
      keep: 10,
      retainedIndexes: {
        stem(1, chainA): index(chainA, {hash1: used}),
      },
      now: now,
    );

    // 刚上传的包（不满 24 小时）可能属于另一台设备正在写的备份。
    expect(deleted(plan), {unused});
  });

  test('leaves a chain alone when one of its indexes is unreadable', () {
    final listing = IncrementalRemoteListing.of([
      ...snapshot(2, chainB),
      ...snapshot(1, chainA),
      file(pack(5, chainA, '00000001')),
      file(pack(5, chainB, '00000002')),
    ]);

    final plan = planIncrementalPrune(
      listing: listing,
      keep: 10,
      retainedIndexes: {
        stem(1, chainA): index(chainA, {hash1: pack(5, chainA, '00000001')}),
      },
      now: now,
    );

    expect(plan.isEmpty, isTrue);
  });

  test('a chain with no snapshot left loses all its old packs', () {
    final listing = IncrementalRemoteListing.of([
      ...snapshot(1, chainA),
      file(pack(5, chainB, '00000001')),
      file(pack(5, chainB, '00000002')),
      file(pack(0, chainB, '00000003')),
    ]);

    final plan = planIncrementalPrune(
      listing: listing,
      keep: 10,
      retainedIndexes: const {},
      now: now,
    );

    expect(deleted(plan), {
      pack(5, chainB, '00000001'),
      pack(5, chainB, '00000002'),
    });
  });

  test('removes snapshots that never got an index after the grace period', () {
    final listing = IncrementalRemoteListing.of([
      file('${stem(3, chainA)}.snap'),
      file('${stem(0, chainA)}.snap'),
    ]);
    expect(listing.snapshots, isEmpty);

    final plan = planIncrementalPrune(
      listing: listing,
      keep: 10,
      retainedIndexes: const {},
      now: now,
    );

    expect(deleted(plan), {'${stem(3, chainA)}.snap'});
  });

  test('does not delete packs when expired snapshots exceed the cap', () {
    final listing = IncrementalRemoteListing.of([
      for (final days in [4, 3, 2, 1]) ...snapshot(days, chainA),
      file(pack(5, chainA, '00000001')),
    ]);

    final plan = planIncrementalPrune(
      listing: listing,
      keep: 1,
      retainedIndexes: {
        stem(1, chainA): index(chainA, {hash2: 'x'}),
      },
      now: now,
      maxDeletions: 4,
    );

    // 过期的索引这次删不完，它们引用的包不能先被删掉。
    expect(plan.deletions, hasLength(4));
    expect(
      plan.deletions.every((entry) => !entry.fileName.endsWith('.pack')),
      isTrue,
    );
  });

  test('pack deletions fill the remaining room under the cap', () {
    final listing = IncrementalRemoteListing.of([
      ...snapshot(1, chainA),
      for (final random in ['00000001', '00000002', '00000003'])
        file(pack(5, chainA, random)),
    ]);

    final plan = planIncrementalPrune(
      listing: listing,
      keep: 10,
      retainedIndexes: {
        stem(1, chainA): index(chainA, {hash3: 'x'}),
      },
      now: now,
      maxDeletions: 2,
    );

    expect(plan.deletions, hasLength(2));
  });
}
