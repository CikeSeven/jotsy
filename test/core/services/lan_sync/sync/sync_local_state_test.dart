import 'dart:io';

import 'package:drift/drift.dart'
    show BooleanExpressionOperators, Value, driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_local_state.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_state_fold.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_state_model.dart';
import 'package:path/path.dart' as p;

import 'sync_test_devices.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SyncTestDevice device;
  late DateTime now;
  late SyncLocalState state;

  SyncLocalState newState() => SyncLocalState(
    database: device.db,
    stateDir: device.stateDir,
    clock: () => now,
  );

  setUp(() async {
    device = await SyncTestDevice.create('state');
    now = DateTime.utc(2026, 10, 1);
    state = newState();
  });

  tearDown(() => device.dispose());

  const rich = SyncKey(SyncEntity.diary, 'diary-rich');

  Future<void> retitle(String diaryId, String title) =>
      (device.db.update(device.db.diaries)
            ..where((t) => t.diaryId.equals(diaryId)))
          .write(DiariesCompanion(title: Value(title)));

  test('first refresh has no history; an edit pushes the old hash', () async {
    await seedEveryEntity(device);
    final first = await state.refreshCheckpoint();
    expect(first.historyOf(rich), isEmpty);
    final before = first.manifest[rich]!;

    await retitle('diary-rich', 'Edited');
    now = now.add(const Duration(minutes: 5));
    final second = await state.refreshCheckpoint();
    final history = second.history(rich, SyncFacet.content);
    expect(history, hasLength(1));
    expect(history.single.hash, before[SyncFacet.content]);
    expect(history.single.seenAt, now.millisecondsSinceEpoch);
    expect(history.single.hasValue, isFalse);
    // 没变的分面没有历史。
    expect(second.history(rich, SyncFacet.stamp), isEmpty);
    // 早先给出的快照不受后来折叠的影响。
    expect(first.historyOf(rich), isEmpty);
  });

  test('tag set changes record the previous value', () async {
    await seedEveryEntity(device);
    await state.refreshCheckpoint();
    final rows = await device.db.readSyncRows();
    final travel = rows.tags.singleWhere((t) => t.name == 'travel').localId;
    final richLocal = rows.diaries
        .singleWhere((d) => d.diaryId == 'diary-rich')
        .localId;
    await (device.db.delete(
      device.db.diaryTags,
    )..where((t) => t.diaryId.equals(richLocal) & t.tagId.equals(travel))).go();
    final snapshot = await state.refreshCheckpoint();
    final entry = snapshot.history(rich, SyncFacet.tags).single;
    expect(entry.hasValue, isTrue);
    expect(entry.value, <String, Object?>{
      'names': <String>['travel', 'work'],
    });
    expect(
      snapshot.observation.trackedValues[rich]![SyncFacet.tags],
      <String, Object?>{
        'names': <String>['work'],
      },
    );
  });

  test(
    'a deletion writes a tombstone with current and historical hashes',
    () async {
      await seedEveryEntity(device);
      await state.refreshCheckpoint();
      await retitle('diary-rich', 'Edited');
      final edited = await state.refreshCheckpoint();
      final oldContent = edited.history(rich, SyncFacet.content).single.hash;
      final current = edited.manifest[rich]!;

      await device.db.hardDeleteDiary('diary-rich');
      final deleted = await state.refreshCheckpoint();
      final tombstone = deleted.tombstone(rich)!;
      expect(tombstone.deletedAt, now.millisecondsSinceEpoch);
      expect(
        tombstone.knows(SyncFacet.content, current[SyncFacet.content]!),
        isTrue,
      );
      expect(tombstone.knows(SyncFacet.content, oldContent), isTrue);
      expect(
        tombstone.knows(SyncFacet.trash, current[SyncFacet.trash]!),
        isTrue,
      );
      expect(deleted.historyOf(rich), isEmpty);
      // 成员关系与留言不是日记的分面，但它们的行也跟着没了。
      expect(
        deleted.tombstone(
          const SyncKey(SyncEntity.membership, 'nb-child|diary-rich'),
        ),
        isNotNull,
      );

      // 状态写进了文件：换一个实例读回来一样。
      final reloaded = await newState().snapshot();
      expect(reloaded.tombstone(rich)!.known, tombstone.known);
      expect(reloaded.manifest.containsKey(rich), isFalse);
    },
  );

  test(
    'a tag renamed in place is recorded as a rename plus a tombstone',
    () async {
      await seedEveryEntity(device);
      await state.refreshCheckpoint();
      final rows = await device.db.readSyncRows();
      final travel = rows.tags.singleWhere((t) => t.name == 'travel');
      await device.db.updateTag(
        tagId: travel.localId,
        name: 'trips',
        color: travel.color,
      );
      final snapshot = await state.refreshCheckpoint();
      final rename = snapshot.renameOf('travel')!;
      expect(rename.to, 'trips');
      expect(rename.at, now.millisecondsSinceEpoch);
      expect(
        snapshot.tombstone(const SyncKey(SyncEntity.tag, 'travel')),
        isNotNull,
      );

      // 再把旧名建回来：墓碑与改名都去掉。
      await device.db.createTag(name: 'travel', color: 1);
      final recreated = await state.refreshCheckpoint();
      expect(recreated.renameOf('travel'), isNull);
      expect(
        recreated.tombstone(const SyncKey(SyncEntity.tag, 'travel')),
        isNull,
      );
    },
  );

  test(
    'settings that were not observed are neither compared nor deleted',
    () async {
      final previous = SyncObservation(
        manifest: SyncManifest(<SyncKey, Map<String, String>>{
          const SyncKey(SyncEntity.settings, kSyncSettingsId): <String, String>{
            'themeMode': 'aaaa',
          },
          const SyncKey(SyncEntity.tag, 'x'): <String, String>{'color': 'bbbb'},
        }),
        trackedValues: const <SyncKey, Map<String, Object?>>{},
        tagLocalIds: const <String, int>{'x': 1},
        observed: SyncEntity.values.toSet(),
      );
      final current = SyncObservation(
        manifest: SyncManifest(const <SyncKey, Map<String, String>>{}),
        trackedValues: const <SyncKey, Map<String, Object?>>{},
        tagLocalIds: const <String, int>{},
        observed: SyncEntity.values.toSet()..remove(SyncEntity.settings),
      );
      final data = SyncStateData();
      final next = foldSyncObservation(
        previous: previous,
        current: current,
        state: data,
        now: 1000,
      );
      expect(data.tombstones.keys, <SyncKey>[
        const SyncKey(SyncEntity.tag, 'x'),
      ]);
      expect(
        next.manifest[const SyncKey(SyncEntity.settings, kSyncSettingsId)],
        <String, String>{'themeMode': 'aaaa'},
      );
    },
  );

  test('history keeps at most eight distinct hashes, newest first', () {
    final data = SyncStateData();
    const key = SyncKey(SyncEntity.tag, 'x');
    for (var i = 0; i < 12; i++) {
      data.pushHistory(key, 'color', SyncHistoryEntry(hash: 'h$i', seenAt: i));
    }
    data.pushHistory(
      key,
      'color',
      const SyncHistoryEntry(hash: 'h8', seenAt: 99),
    );
    final list = data.history[key]!['color']!;
    expect(list, hasLength(kSyncHistoryLimit));
    expect(list.first.hash, 'h8');
    expect(list.first.seenAt, 99);
    expect(list.where((e) => e.hash == 'h8'), hasLength(1));
  });

  test('tombstones and renames expire by age and by count', () {
    final day = const Duration(days: 1).inMilliseconds;
    final now = 1000 * day;
    final data = SyncStateData();
    data.tombstones[const SyncKey(SyncEntity.diary, 'old')] = SyncTombstone(
      deletedAt: now - 366 * day,
      known: const <String, List<String>>{},
    );
    data.tombstones[const SyncKey(SyncEntity.diary, 'fresh')] = SyncTombstone(
      deletedAt: now - 10 * day,
      known: const <String, List<String>>{},
    );
    data.renames['a'] = SyncTagRename(from: 'a', to: 'b', at: now - 400 * day);
    data.renames['c'] = SyncTagRename(from: 'c', to: 'd', at: now);
    data.prune(now);
    expect(data.tombstones.keys, <SyncKey>[
      const SyncKey(SyncEntity.diary, 'fresh'),
    ]);
    expect(data.renames.keys, <String>['c']);

    final many = SyncStateData();
    for (var i = 0; i < kSyncTombstoneMaxCount + 3; i++) {
      many.tombstones[SyncKey(SyncEntity.diary, 'd$i')] = SyncTombstone(
        deletedAt: now - i,
        known: const <String, List<String>>{},
      );
    }
    many.prune(now);
    expect(many.tombstones, hasLength(kSyncTombstoneMaxCount));
    // 淘汰的是最旧的三条。
    for (var i = kSyncTombstoneMaxCount; i < kSyncTombstoneMaxCount + 3; i++) {
      expect(
        many.tombstones.containsKey(SyncKey(SyncEntity.diary, 'd$i')),
        isFalse,
      );
    }
  });

  test('corrupt state files are discarded instead of crashing', () async {
    await seedEveryEntity(device);
    await state.refreshCheckpoint();
    await retitle('diary-rich', 'Edited');
    await state.refreshCheckpoint();
    for (final name in <String>[
      SyncLocalState.checkpointFile,
      SyncLocalState.historyFile,
      SyncLocalState.tombstonesFile,
      SyncLocalState.renamesFile,
      SyncLocalState.hashCacheFile,
    ]) {
      await File(p.join(device.stateDir.path, name)).writeAsString('garbage');
    }
    final fresh = newState();
    final snapshot = await fresh.refreshCheckpoint();
    // 检查点丢了就是“第一次”：没有历史，但清单完整。
    expect(snapshot.historyOf(rich), isEmpty);
    expect(snapshot.manifest.containsKey(rich), isTrue);
    // 之后照常工作。
    await retitle('diary-rich', 'Again');
    final next = await fresh.refreshCheckpoint();
    expect(next.history(rich, SyncFacet.content), hasLength(1));
  });

  test(
    'resetAfterRestore forgets checkpoint, history and tombstones',
    () async {
      await seedEveryEntity(device);
      await state.refreshCheckpoint();
      await device.db.hardDeleteDiary('diary-uri');
      await retitle('diary-rich', 'Edited');
      final before = await state.refreshCheckpoint();
      expect(
        before.tombstone(const SyncKey(SyncEntity.diary, 'diary-uri')),
        isNotNull,
      );

      await state.resetAfterRestore();
      for (final name in <String>[
        SyncLocalState.checkpointFile,
        SyncLocalState.historyFile,
        SyncLocalState.tombstonesFile,
        SyncLocalState.renamesFile,
        SyncLocalState.hashCacheFile,
      ]) {
        expect(File(p.join(device.stateDir.path, name)).existsSync(), isFalse);
      }
      await retitle('diary-rich', 'Restored');
      final after = await state.refreshCheckpoint();
      expect(after.historyOf(rich), isEmpty);
      expect(after.tombstoneKeys, isEmpty);
    },
  );

  test('recordAppliedState folds a written state like a refresh', () async {
    await seedEveryEntity(device);
    final before = await state.refreshCheckpoint();
    await device.db.hardDeleteDiary('diary-uri');
    final after = await state.observeRows(await device.db.readSyncRows());
    await state.recordAppliedState(after);
    final snapshot = await state.snapshot();
    expect(
      snapshot.tombstone(const SyncKey(SyncEntity.diary, 'diary-uri'))!.known,
      <String, List<String>>{
        for (final entry
            in before
                .manifest[const SyncKey(SyncEntity.diary, 'diary-uri')]!
                .entries)
          entry.key: <String>[entry.value],
      },
    );
    final book = const SyncKey(SyncEntity.orderList, 'book:nb-parent');
    expect(
      snapshot.history(book, SyncFacet.items).single.value,
      <String, Object?>{
        'ids': <String>['diary-delta', 'diary-uri', 'diary-rich'],
      },
    );
  });

  test(
    'buildRecords returns full records for the requested keys only',
    () async {
      await seedEveryEntity(device);
      final records = await state.buildRecords(<SyncKey>[
        rich,
        const SyncKey(SyncEntity.tag, 'work'),
        const SyncKey(SyncEntity.diary, 'missing'),
      ]);
      expect(records.map((r) => r.key).toSet(), <SyncKey>{
        rich,
        const SyncKey(SyncEntity.tag, 'work'),
      });
      final snapshot = await state.refreshCheckpoint();
      expect(
        records.singleWhere((r) => r.key == rich).hashes,
        snapshot.manifest[rich],
      );
    },
  );
}
