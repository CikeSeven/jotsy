import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/editing_session_registry.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_media.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_media_index.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_plan.dart';
import 'package:path/path.dart' as p;

import '../../../../support/lan_sync_two_devices.dart';

/// 媒体：暂存、校验、就位（复用 / 新放 / 同键不同文件换键）、改键照做与
/// 暂存目录清理（规格 §6 第 2 步）。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late LanSyncTestClock clock;
  late LanSyncTestDevice a;
  late LanSyncTestDevice b;

  setUp(() async {
    EditingSessionRegistry.instance.debugReset();
    clock = LanSyncTestClock();
    a = await LanSyncTestDevice.create('media-a', clock: clock);
    b = await LanSyncTestDevice.create('media-b', clock: clock);
  });

  tearDown(() async {
    await a.dispose();
    await b.dispose();
  });

  String sha(List<int> bytes) => sha256.convert(bytes).toString();

  SyncMediaStaging stagingOf(LanSyncTestDevice device, {DateTime? now}) =>
      SyncMediaStaging(
        dataRoot: device.dataRoot,
        sessionId: 's1',
        index: device.index,
        clock: now == null ? null : () => now,
      );

  Future<void> receive(SyncMediaStaging staging, String key, List<int> bytes) =>
      staging.receive(
        key,
        Stream.value(bytes),
        size: bytes.length,
        sha256: sha(bytes),
      );

  /// 一篇只有一张图片的日记。
  Future<void> imageDiary(LanSyncTestDevice device, String id, String key) =>
      device.db
          .into(device.db.diaries)
          .insert(
            DiariesCompanion.insert(
              diaryId: id,
              content: jsonEncode({
                'document': {
                  'type': 'page',
                  'children': [
                    {
                      'type': 'image',
                      'data': {'url': device.mediaPath(key)},
                    },
                  ],
                },
              }),
              contentText: '',
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
          );

  test('目标不存在：改名就位，修改时间为现在；目标已有同样内容：复用', () async {
    final now = DateTime(2026, 10, 2, 8, 30);
    final staging = stagingOf(a, now: now);
    await receive(staging, 'diary_images/media_n/new.jpg', [1, 2, 3]);
    await a.writeMedia('diary_images/media_n/same.jpg', [7, 7]);
    await receive(staging, 'diary_images/media_n/same.jpg', [7, 7]);
    final placement = await staging.place();

    expect(placement.rekeys, isEmpty);
    expect(placement.placedFiles, 1);
    expect(placement.placedBytes, 3);
    expect(placement.reusedFiles, 1);
    final placed = File(a.mediaPath('diary_images/media_n/new.jpg'));
    expect(await placed.readAsBytes(), [1, 2, 3]);
    expect((await placed.lastModified()).difference(now).inSeconds, 0);
    await staging.dispose();
    expect(await staging.directory.exists(), isFalse);
  });

  test('大小或 sha256 不符：拒收、删除暂存件，不会就位', () async {
    final staging = stagingOf(a);
    const key = 'diary_videos/v.mp4';
    final sink = await staging.openSink(key);
    sink.add([1, 2, 3]);
    await sink.close();
    await expectLater(
      staging.verify(key, size: 3, sha256: sha([9, 9, 9])),
      throwsA(isA<SyncMediaVerificationException>()),
    );
    expect(staging.verifiedKeys, isEmpty);
    expect((await staging.place()).placedFiles, 0);
    expect(await File(a.mediaPath(key)).exists(), isFalse);
    expect(() => staging.openSink('../escape.jpg'), throwsArgumentError);
  });

  test('来流中途报错：抛出原来的错误，删掉半截文件，不会就位', () async {
    final staging = stagingOf(a);
    const key = 'diary_images/media_n/broken.jpg';
    Stream<List<int>> failing() async* {
      yield [1, 2, 3];
      throw TimeoutException('peer silent');
    }

    await expectLater(
      staging.receive(key, failing(), size: 10, sha256: sha([1])),
      throwsA(isA<TimeoutException>()),
    );
    expect(staging.verifiedKeys, isEmpty);
    final leftovers = await staging.directory
        .list(recursive: true)
        .where((entry) => entry is File)
        .toList();
    expect(leftovers, isEmpty);
    expect((await staging.place()).placedFiles, 0);
  });

  test('同键不同文件：放到派生键，并改写本次写入记录里的引用', () async {
    const key = 'diary_images/media_x/p.jpg';
    await a.writeMedia(key, utf8.encode('AAA'));
    await imageDiary(b, 'd-b', key);
    await b.writeMedia(key, utf8.encode('BBB'));
    final record = (await b.records()).singleWhere(
      (r) => r.key.entity == SyncEntity.diary,
    );
    final staging = stagingOf(a);
    await receive(staging, key, utf8.encode('BBB'));
    final result = await a.applier.apply(
      SyncSidePlan(
        writes: [SyncWrite(key: record.key, expected: null, record: record)],
        renames: const [],
        mediaNeeded: const [key],
        stats: const {},
      ),
      staging: staging,
    );

    final derived = syncDerivedMediaKey(key, sha(utf8.encode('BBB')));
    expect(derived, startsWith('diary_images/media_x/p.'));
    expect(result.rekeys, [
      SyncMediaRekey(
        oldKey: key,
        newKey: derived,
        sha256: sha(utf8.encode('BBB')),
      ),
    ]);
    expect(result.mediaFiles, 1);
    expect(await File(a.mediaPath(key)).readAsString(), 'AAA');
    expect(await File(a.mediaPath(derived)).readAsString(), 'BBB');
    final stored = (await a.records()).singleWhere(
      (r) => r.key.entity == SyncEntity.diary,
    );
    expect(stored.mediaKeys, {derived});
    expect(await staging.directory.exists(), isFalse);
  });

  test('两台设备各有同键的不同文件：同步并照做改键后，两边规范记录一致', () async {
    const key = 'diary_images/media_x/p.jpg';
    await a.writeMedia(key, utf8.encode('from a'));
    await imageDiary(a, 'd-a', key);
    await b.writeMedia(key, utf8.encode('from b'));
    await imageDiary(b, 'd-b', key);

    final round = await runLanSyncRound(a, b);
    expect(round.initiatorResult!.rekeys, hasLength(1));
    expect(round.responderResult!.rekeys, hasLength(1));
    expect(round.initiatorAdopt!.diaries.updated, 1);
    expect(round.responderAdopt!.diaries.updated, 1);

    expect(await a.canonical(), await b.canonical());
    final keys = {for (final r in await a.records()) r.key.id: r.mediaKeys};
    expect(keys['d-a'], {syncDerivedMediaKey(key, sha(utf8.encode('from a')))});
    expect(keys['d-b'], {syncDerivedMediaKey(key, sha(utf8.encode('from b')))});
    for (final device in [a, b]) {
      for (final id in ['d-a', 'd-b']) {
        final file = File(device.mediaPath(keys[id]!.single));
        expect(await file.readAsString(), id == 'd-a' ? 'from a' : 'from b');
      }
    }
    expect((await planLanSyncRound(a, b)).isEmpty, isTrue);
  });

  test('照做改键：本机旧键已换成别的文件时跳过', () async {
    const key = 'diary_images/media_x/p.jpg';
    await a.writeMedia(key, utf8.encode('changed'));
    final adopted = await a.media.copyForAdoption([
      SyncMediaRekey(oldKey: key, newKey: '$key.x', sha256: sha([1])),
    ]);
    expect(adopted, isEmpty);
  });

  test('启动时清掉超过 24 小时的暂存目录', () async {
    final staging = stagingOf(a);
    await receive(staging, 'diary_covers/c.jpg', [1]);
    expect(await SyncMediaStaging.sweepStale(a.dataRoot), 0, reason: '刚建的不清');
    final removed = await SyncMediaStaging.sweepStale(
      a.dataRoot,
      now: DateTime.now().add(const Duration(hours: 25)),
    );
    expect(removed, 1);
    expect(await staging.directory.exists(), isFalse);
    expect(
      await Directory(p.join(a.dataRoot.path, kSyncStagingDirName)).exists(),
      isTrue,
    );
  });

  test('发送：按键给出流、大小与 sha256；没有的文件为 null', () async {
    await a.writeMedia('diary_attachments/r.pdf', [4, 5]);
    final library = SyncMediaLibrary(
      dataRoot: a.dataRoot,
      index: SyncMediaIndex(stateDir: a.stateDir, dataRoot: a.dataRoot),
    );
    final outgoing = (await library.open('diary_attachments/r.pdf'))!;
    expect(outgoing.size, 2);
    expect(outgoing.sha256, sha([4, 5]));
    expect(await outgoing.openRead().expand((chunk) => chunk).toList(), [4, 5]);
    expect(await library.open('diary_attachments/none.pdf'), isNull);
  });

  test('设置背景图同样按键就位（文件名合法才接受）', () async {
    final staging = stagingOf(b);
    await receive(staging, 'app_backgrounds/bg_1.jpg', [3]);
    await staging.place();
    expect(
      await File(
        p.join(b.dataRoot.path, 'app_backgrounds', 'bg_1.jpg'),
      ).exists(),
      isTrue,
    );
    expect(() => staging.openSink('app_backgrounds/a:b'), throwsArgumentError);
  });
}
