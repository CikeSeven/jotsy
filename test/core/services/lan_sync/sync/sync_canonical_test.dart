import 'dart:convert';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_canonical_diary.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_hash_cache.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_manifest_builder.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';

import 'sync_test_devices.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SyncTestDevice a;
  late SyncTestDevice b;

  setUp(() async {
    a = await SyncTestDevice.create('a');
    b = await SyncTestDevice.create('b');
  });

  tearDown(() async {
    await a.dispose();
    await b.dispose();
  });

  SyncRecord recordOf(List<SyncRecord> records, SyncEntity entity, String id) =>
      records.singleWhere((r) => r.key == SyncKey(entity, id));

  group('cross-device determinism', () {
    test('records written into another device read back byte-for-byte equal '
        'with paths rebound to that device', () async {
      await seedEveryEntity(a);
      // 让 B 的本地 id 与 A 错开：自增 id 不会复用，插入再删掉一个标签即可。
      final dummy = await b.db
          .into(b.db.tags)
          .insert(const TagsCompanion(name: Value('dummy'), color: Value(1)));
      await (b.db.delete(b.db.tags)..where((t) => t.id.equals(dummy))).go();

      final fromA = await a.records();
      await writeRecordsForTest(b, fromA);
      final fromB = await b.records();

      expect(canonicalByKey(fromB), canonicalByKey(fromA));
      final manifestA = syncObserveRows(
        await a.db.readSyncRows(),
      ).observation.manifest;
      final manifestB = syncObserveRows(
        await b.db.readSyncRows(),
      ).observation.manifest;
      expect(manifestB.toJson(), manifestA.toJson());
      expect(manifestB.encodeGzip(), manifestA.encodeGzip());

      // B 库里的路径指向 B 自己的数据根，不残留 A 的路径。
      final stored = await b.db.readSyncRows();
      for (final diary in stored.diaries) {
        expect(diary.content, isNot(contains(a.dataRoot.path)));
        expect(diary.metadata, isNot(contains(a.dataRoot.path)));
      }
      final rich = stored.diaries.singleWhere((d) => d.diaryId == 'diary-rich');
      expect(rich.content, contains(b.media('diary_images/media_1/a.jpg')));
      expect(rich.cover, b.media('diary_covers/cover.jpg'));
      final uri = stored.diaries.singleWhere((d) => d.diaryId == 'diary-uri');
      // file: URI 写成本机绝对路径。
      expect(uri.content, contains(b.media('diary_images/c.jpg')));
      expect(uri.content, isNot(contains('file:')));
      expect(uri.metadata, contains(b.media('diary_attachments/imp.pdf')));
      final parent = stored.notebooks.singleWhere(
        (n) => n.notebookId == 'nb-parent',
      );
      expect(parent.payload, contains(b.media('diary_covers/nb.jpg')));
      // content_text 由正文重新生成，与写库口径一致。
      final written = await b.db.getDiaryWithTagsByDiaryId('diary-capsule');
      expect(written!.diary.contentText, 'plain line one\nline two');
    });

    test('canonical form strips local fields and keeps unknown data', () async {
      await seedEveryEntity(a);
      final records = await a.records();

      final rich = recordOf(records, SyncEntity.diary, 'diary-rich');
      final content = rich.facets[SyncFacet.content]! as Map;
      final metadata = content['metadata'] as Map;
      expect(metadata.containsKey('tagIds'), isFalse);
      expect(metadata['device'], <String, Object?>{'platform': 'android'});
      expect(content['cover'], 'jotsy-media:diary_covers/cover.jpg');
      expect(rich.facets[SyncFacet.tags], <String, Object?>{
        'names': <String>['travel', 'work'],
      });
      expect(rich.facets[SyncFacet.pin], <String, Object?>{'pinned': true});
      expect(rich.mediaKeys, <String>{
        'diary_covers/cover.jpg',
        'diary_images/media_1/a.jpg',
        'diary_recordings/r.m4a',
        'diary_videos/v.mp4',
        'diary_attachments/report.pdf',
      });
      // 看不见的子块已提到引用后面，远程图片不动。
      final encoded = syncCanonicalJson(content['content']);
      expect(encoded, contains('https://example.com/diary_images/remote.png'));
      expect(encoded, contains('hidden child'));
      expect(encoded, isNot(contains(a.dataRoot.path)));

      final capsule = recordOf(records, SyncEntity.diary, 'diary-capsule');
      final capsuleFacet = capsule.facets[SyncFacet.capsule]! as Map;
      expect(capsuleFacet['unlockAt'], 1900000000 * 1000);
      expect((capsuleFacet['meta'] as Map)['precision'], 'date');
      expect(
        ((capsule.facets[SyncFacet.content]! as Map)['metadata'] as Map)
            .containsKey('capsule'),
        isFalse,
      );

      final legacy = recordOf(records, SyncEntity.diary, 'diary-legacy');
      expect(
        (legacy.facets[SyncFacet.content]! as Map)['metadata'],
        'not a json object {',
      );
      expect(legacy.facets[SyncFacet.trash], <String, Object?>{
        'deleted': true,
        'deletedAt': 1700000300 * 1000,
      });
      expect(legacy.mediaKeys, <String>{'diary_images/legacy.jpg'});
      final delta = recordOf(records, SyncEntity.diary, 'diary-delta');
      expect(delta.mediaKeys, <String>{
        'diary_images/b.png',
        'diary_recordings/old.m4a',
      });
      final uri = recordOf(records, SyncEntity.diary, 'diary-uri');
      expect(uri.mediaKeys, <String>{
        'diary_images/c.jpg',
        'diary_attachments/imp.pdf',
      });

      final parent = recordOf(records, SyncEntity.notebook, 'nb-parent');
      final payload =
          (parent.facets[SyncFacet.definition]! as Map)['payload'] as Map;
      expect(payload['futureKey'], <String, Object?>{'x': 1});
      expect(payload['cover'], 'jotsy-media:diary_covers/nb.jpg');

      final memberships = records
          .where((r) => r.key.entity == SyncEntity.membership)
          .map((r) => r.key.id)
          .toSet();
      expect(memberships, <String>{
        'nb-parent|diary-rich',
        'nb-parent|diary-delta',
        'nb-parent|diary-uri',
        'nb-child|diary-rich',
      });
      List<Object?> ids(String listId) =>
          (recordOf(
                    records,
                    SyncEntity.orderList,
                    listId,
                  ).facets[SyncFacet.items]!
                  as Map)['ids']
              as List<Object?>;
      expect(ids('shelf'), <String>[
        'nb-child',
        'nb-parent',
        'nb-smart',
        'nb-empty',
      ]);
      expect(ids('templates'), <String>['tpl-2', 'tpl-1']);
      // 同位置按加入时间、再按本地 id。
      expect(ids('book:nb-parent'), <String>[
        'diary-delta',
        'diary-uri',
        'diary-rich',
      ]);
      expect(ids('book:nb-empty'), isEmpty);
      expect(
        records.any(
          (r) => r.key == const SyncKey(SyncEntity.orderList, 'book:nb-smart'),
        ),
        isFalse,
      );
      expect(
        recordOf(
          records,
          SyncEntity.dayMood,
          '2026-01-02',
        ).facets[SyncFacet.main],
        <String, Object?>{'mood': 'ecstatic', 'updatedAt': 1700005100 * 1000},
      );
      expect(
        (recordOf(
              records,
              SyncEntity.anniversary,
              'ann-1',
            ).facets[SyncFacet.main]!
            as Map)['metadata'],
        <String, Object?>{'icon': 'cake', 'color': 4283215696},
      );
      expect(
        records.any(
          (r) => r.key == const SyncKey(SyncEntity.template, 'builtin.daily'),
        ),
        isTrue,
      );
    });
  });

  group('canonicalization', () {
    test(
      'is idempotent for block, Delta, legacy node and plain text bodies',
      () async {
        await seedEveryEntity(a);
        final rows = await a.db.readSyncRows();
        for (final row in rows.diaries) {
          final first = syncDiaryRecord(row, const <String>['x']);
          final columns = SyncDiaryColumns.fromRecord(
            first,
            dataRoot: b.dataRoot.path,
          );
          final rewritten = SyncRawDiary(
            localId: 1,
            diaryId: columns.diaryId,
            title: columns.title,
            content: columns.content,
            cover: columns.cover,
            metadata: columns.metadata,
            createdAt: columns.createdAt.millisecondsSinceEpoch ~/ 1000,
            updatedAt: columns.updatedAt.millisecondsSinceEpoch ~/ 1000,
            isArchived: columns.archived,
            archivedAt: _seconds(columns.archivedAt),
            isPinned: columns.pinned,
            capsuleUnlockAt: _seconds(columns.capsuleUnlockAt),
            capsuleLockedAt: _seconds(columns.capsuleLockedAt),
            isDeleted: columns.deleted,
            deletedAt: _seconds(columns.deletedAt),
          );
          final second = syncDiaryRecord(rewritten, columns.tagNames);
          expect(
            syncCanonicalJson(second.facets),
            syncCanonicalJson(first.facets),
            reason: row.diaryId,
          );
          expect(second.hashes, first.hashes, reason: row.diaryId);
        }
      },
    );

    test(
      'hashes are stable and the cache path matches the cold path',
      () async {
        await seedEveryEntity(a);
        final rows = await a.db.readSyncRows();
        final cold = syncObserveRows(rows);
        final again = syncObserveRows(rows);
        expect(
          again.observation.manifest.toJson(),
          cold.observation.manifest.toJson(),
        );
        expect(cold.cacheHits, 0);

        // 经文件形态往返的缓存同样命中。
        final cache = syncHashCacheFromJson(
          jsonDecode(jsonEncode(syncHashCacheToJson(cold.cache))),
        );
        final warm = syncObserveRows(rows, cache: cache);
        expect(warm.cacheMisses, 0);
        expect(warm.cacheHits, cold.cacheMisses);
        expect(
          warm.observation.manifest.toJson(),
          cold.observation.manifest.toJson(),
        );
        expect(warm.observation.trackedValues, cold.observation.trackedValues);

        // 改一行只让这一行重算。
        await (a.db.update(a.db.diaries)
              ..where((t) => t.diaryId.equals('diary-rich')))
            .write(const DiariesCompanion(title: Value('Changed')));
        final changed = syncObserveRows(
          await a.db.readSyncRows(),
          cache: warm.cache,
        );
        expect(changed.cacheMisses, 1);
        expect(
          changed.observation.manifest[const SyncKey(
            SyncEntity.diary,
            'diary-rich',
          )]![SyncFacet.content],
          isNot(
            cold.observation.manifest[const SyncKey(
              SyncEntity.diary,
              'diary-rich',
            )]![SyncFacet.content],
          ),
        );
        // 没请求设置时观测里不含 settings 实体。
        expect(cold.observation.observed, isNot(contains(SyncEntity.settings)));
      },
    );

    test('record and manifest JSON round trips keep hashes', () async {
      await seedEveryEntity(a);
      final records = await a.records();
      for (final record in records) {
        final decoded = SyncRecord.fromJson(
          jsonDecode(jsonEncode(record.toJson())),
        );
        expect(decoded.key, record.key);
        expect(decoded.hashes, record.hashes);
      }
      final manifest = SyncManifest.fromRecords(records);
      final restored = SyncManifest.decodeGzip(manifest.encodeGzip());
      expect(restored.toJson(), manifest.toJson());
      expect(restored.formatVersion, kSyncFormatVersion);
      expect(
        () => SyncManifest.fromJson(<String, Object?>{
          'v': 1,
          'entries': <String, Object?>{'future:x': <String, Object?>{}},
        }),
        throwsFormatException,
      );
    });
  });

  group('canonical JSON and keys', () {
    test('sorts keys by UTF-16 code units without whitespace', () {
      expect(
        syncCanonicalJson(<String, Object?>{
          'b': 1,
          'a': <Object?>[
            true,
            null,
            1.5,
            <String, Object?>{'z': 'x', 'Z': 'y'},
          ],
          '\u{1F600}': 0,
          '￿': 0,
        }),
        '{"a":[true,null,1.5,{"Z":"y","z":"x"}],"b":1,"\u{1F600}":0,"￿":0}',
      );
      expect(syncHashValue(<String, Object?>{'a': 1}), hasLength(32));
    });

    test('keys parse on the first colon only', () {
      final key = SyncKey.parse('orderList:book:nb:1');
      expect(key.entity, SyncEntity.orderList);
      expect(key.id, 'book:nb:1');
      expect(key.toString(), 'orderList:book:nb:1');
      expect(SyncKey.tryParse('nope:1'), isNull);
      expect(
        SyncKey.parse('tag:a') == const SyncKey(SyncEntity.tag, 'a'),
        isTrue,
      );
      expect(parseSyncMembershipId('nb|d'), (notebookId: 'nb', diaryId: 'd'));
      expect(SyncOrderListId.notebookOf('book:nb'), 'nb');
    });
  });
}

int? _seconds(DateTime? time) =>
    time == null ? null : time.millisecondsSinceEpoch ~/ 1000;
