import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/cloud_backup_incremental_format.dart';
import 'package:node_diary/core/services/cloud_backup_incremental_packs.dart';
import 'package:node_diary/core/services/cloud_backup_incremental_state.dart';
import 'package:node_diary/core/services/cloud_backup_models.dart';
import 'package:node_diary/core/services/cloud_backup_options.dart';
import 'package:node_diary/core/services/cloud_backup_target.dart';

/// 增量备份的远端格式、选项与自动备份时机（纯函数）。
void main() {
  final hashA = 'a' * 64;
  final hashB = 'b' * 64;
  final time = DateTime(2026, 11, 3, 9, 5, 7);

  group('file names', () {
    test('snapshot and index share a stem that parses back', () {
      final stem = incrementalSnapshotStem(time, '0a1b2c3d');
      expect(stem, 'jotsy_inc_20261103_090507_0a1b2c3d');
      final snap = IncrementalFileName.parse('$stem.snap')!;
      final index = IncrementalFileName.parse('$stem.idx')!;
      expect(snap.kind, IncrementalFileKind.snapshot);
      expect(index.kind, IncrementalFileKind.indexFile);
      expect(index.stem, snap.stem);
      expect(index.chain, '0a1b2c3d');
      expect(index.time, time);
    });

    test('pack names carry chain and time', () {
      final name = incrementalPackName(time, '0a1b2c3d', 'deadbeef');
      final parsed = IncrementalFileName.parse(name)!;
      expect(parsed.kind, IncrementalFileKind.pack);
      expect(parsed.chain, '0a1b2c3d');
      expect(parsed.time, time);
    });

    test('other files and renamed copies are not incremental files', () {
      for (final name in [
        'jotsy_backup_20261103_090507.zip',
        'manifest.json',
        'jotsy_inc_20261103_090507_0a1b2c3d(1).idx',
        'jotsy_pack_0a1b2c3d_20261103090507_deadbeef (1).pack',
        'jotsy_inc_20261103_090507_XYZ.snap',
      ]) {
        expect(IncrementalFileName.parse(name), isNull, reason: name);
      }
      // 旧版只把 .zip 当备份：增量文件不会出现在它的列表里。
      expect(
        isCloudBackupFileName('jotsy_inc_20261103_090507_0a1b2c3d.snap'),
        isFalse,
      );
    });
  });

  group('index', () {
    IncrementalIndex sample() => IncrementalIndex(
      chain: '0a1b2c3d',
      createdAt: time,
      encrypted: true,
      payloadSha256: hashA,
      snapshotSize: 120,
      media: {
        'diary_images/media_1/a.jpg': IncrementalMediaRef(hashA, 10),
        'diary_covers/cover_1.jpg': IncrementalMediaRef(hashA, 10),
        'app_backgrounds/bg_1.jpg': IncrementalMediaRef(hashB, 30),
      },
      packs: {
        hashA: 'jotsy_pack_0a1b2c3d_20261103090507_00000001.pack',
        hashB: 'jotsy_pack_0a1b2c3d_20261103090507_00000002.pack',
      },
    );

    test('round-trips and counts shared content once', () {
      final decoded = IncrementalIndex.decode(sample().encode());
      expect(decoded.media, sample().media);
      expect(decoded.packs, sample().packs);
      expect(decoded.encrypted, isTrue);
      expect(decoded.fingerprint, sample().fingerprint);
      expect(decoded.mediaBytes, 40);
      expect(decoded.packNames, hasLength(2));
    });

    test('rejects tampered hashes, pack names and missing packs', () {
      String tamper(String from, String to) =>
          sample().encode().replaceFirst(from, to);
      for (final raw in [
        tamper('"$hashB",30', '"../x",30'),
        tamper('_00000002.pack', '_00000002.zip'),
        tamper('"$hashB":"jotsy_pack', '"${'c' * 64}":"jotsy_pack'),
        '{"v":2}',
      ]) {
        expect(() => IncrementalIndex.decode(raw), throwsFormatException);
      }
    });

    test('payload hash ignores generatedAt only', () {
      final a = incrementalPayloadSha256({
        'formatVersion': 1,
        'generatedAt': '2026-11-03T09:00:00',
        'database': {'diaries': []},
      });
      final b = incrementalPayloadSha256({
        'formatVersion': 1,
        'generatedAt': '2026-11-04T09:00:00',
        'database': {'diaries': []},
      });
      final c = incrementalPayloadSha256({
        'formatVersion': 1,
        'generatedAt': '2026-11-03T09:00:00',
        'database': {
          'diaries': [1],
        },
      });
      expect(a, b);
      expect(a, isNot(c));
    });

    test('fingerprint does not depend on media order', () {
      final first = incrementalFingerprint(hashA, {
        'diary_images/a': IncrementalMediaRef(hashA, 1),
        'diary_images/b': IncrementalMediaRef(hashB, 2),
      });
      final second = incrementalFingerprint(hashA, {
        'diary_images/b': IncrementalMediaRef(hashB, 2),
        'diary_images/a': IncrementalMediaRef(hashA, 1),
      });
      expect(first, second);
    });
  });

  test('media keys from the index cannot escape the staging directory', () {
    for (final key in [
      'diary_images/media_1/a.jpg',
      'app_backgrounds/bg_1.jpg',
      'diary_recordings/recording_1.m4a',
    ]) {
      expect(isValidIncrementalMediaKey(key), isTrue, reason: key);
    }
    for (final key in [
      '../diary_images/a.jpg',
      'diary_images/../../etc/passwd',
      'diary_images/./a.jpg',
      'diary_images//a.jpg',
      'diary_images',
      'secrets/a.jpg',
      r'diary_images\a.jpg',
    ]) {
      expect(isValidIncrementalMediaKey(key), isFalse, reason: key);
    }
  });

  test('pack grouping keeps packs near the target size', () {
    IncrementalPackItem item(int size) => IncrementalPackItem(
      sha256: '$size',
      path: '/x/$size',
      size: size,
      modifiedAt: 0,
    );
    final groups = groupIncrementalPackItems([
      item(4),
      item(5),
      item(3),
      item(20),
      item(1),
    ], target: 10);
    expect(
      [
        for (final group in groups) [for (final i in group) i.size],
      ],
      [
        [4, 5],
        [3],
        [20],
        [1],
      ],
    );
  });

  group('options', () {
    test('parse tolerantly and write sparsely', () {
      expect(const CloudBackupOptions().toJson(), isEmpty);
      final parsed = CloudBackupOptions.fromJson({
        'keep': 7,
        'auto': true,
        'interval': 'monthly',
        'chain': 'NOT-HEX',
        'password': 'x',
      });
      expect(parsed.keepSnapshots, CloudBackupOptions.defaultKeepSnapshots);
      expect(parsed.autoBackup, isTrue);
      expect(parsed.autoInterval, CloudAutoBackupInterval.daily);
      expect(parsed.hasChain, isFalse);

      final chained = const CloudBackupOptions().withChain('0a1b2c3d', '');
      final again = CloudBackupOptions.fromJson(chained.toJson());
      expect(again.chain, '0a1b2c3d');
      expect(again.password, '');
      expect(again.zipPassword, isNull);
      expect(again.withoutChain().hasChain, isFalse);
    });

    test('live in the target JSON outside the connection config', () {
      final target =
          CloudBackupTarget.create(
            kind: CloudBackupKind.webDav,
            config: const {'serverUrl': 'https://dav.example'},
          ).copyWith(
            options: const CloudBackupOptions(
              keepSnapshots: 10,
              autoBackup: true,
            ).withChain('0a1b2c3d', 'pw'),
          );
      final decoded = CloudBackupTarget.decodeList(
        CloudBackupTarget.encodeList([target]),
      ).single;
      expect(decoded.config, {'serverUrl': 'https://dav.example'});
      expect(decoded.options.keepSnapshots, 10);
      expect(decoded.options.autoBackup, isTrue);
      expect(decoded.options.password, 'pw');
      // 表单保存会整份重建 config，选项不受影响。
      expect(decoded.copyWith(config: const {}).options.chain, '0a1b2c3d');
    });
  });

  group('isCloudAutoBackupDue', () {
    final now = DateTime(2026, 11, 3, 12);
    final on = const CloudBackupOptions(
      autoBackup: true,
    ).withChain('0a1b2c3d', '');
    CloudBackupTargetState state({
      String? index = 'jotsy_inc_20261101_120000_0a1b2c3d.idx',
      Duration? sinceSuccess,
      Duration? sinceFailure,
      CloudAutoBackupStatus? auto,
    }) => CloudBackupTargetState(
      lastIndexName: index,
      lastSuccessAt: sinceSuccess == null ? null : now.subtract(sinceSuccess),
      lastFailureAt: sinceFailure == null ? null : now.subtract(sinceFailure),
      lastAuto: auto,
    );

    test('needs the switch, a chain and a first manual backup', () {
      final due = state(sinceSuccess: const Duration(days: 2));
      expect(isCloudAutoBackupDue(options: on, state: due, now: now), isTrue);
      expect(
        isCloudAutoBackupDue(
          options: on.copyWith(autoBackup: false),
          state: due,
          now: now,
        ),
        isFalse,
      );
      expect(
        isCloudAutoBackupDue(options: on.withoutChain(), state: due, now: now),
        isFalse,
      );
      expect(
        isCloudAutoBackupDue(options: on, state: state(index: null), now: now),
        isFalse,
      );
    });

    test('waits for the interval and backs off after failures', () {
      expect(
        isCloudAutoBackupDue(
          options: on,
          state: state(sinceSuccess: const Duration(hours: 23)),
          now: now,
        ),
        isFalse,
      );
      expect(
        isCloudAutoBackupDue(
          options: on.copyWith(autoInterval: CloudAutoBackupInterval.weekly),
          state: state(sinceSuccess: const Duration(days: 3)),
          now: now,
        ),
        isFalse,
      );
      expect(
        isCloudAutoBackupDue(
          options: on,
          state: state(
            sinceSuccess: const Duration(days: 3),
            sinceFailure: const Duration(minutes: 20),
          ),
          now: now,
        ),
        isFalse,
      );
      expect(
        isCloudAutoBackupDue(
          options: on,
          state: state(
            sinceSuccess: const Duration(days: 3),
            auto: CloudAutoBackupStatus(
              at: now.subtract(const Duration(hours: 5)),
              outcome: CloudAutoBackupOutcome.needsManual,
              bytes: 1,
            ),
          ),
          now: now,
        ),
        isFalse,
      );
    });

    test('state survives a JSON round trip', () {
      final original = state(
        sinceSuccess: const Duration(days: 1),
        sinceFailure: const Duration(hours: 2),
        auto: CloudAutoBackupStatus(
          at: now,
          outcome: CloudAutoBackupOutcome.failed,
          failure: CloudBackupFailure.sessionExpired,
        ),
      ).withPendingPack('p.pack', [hashA]);
      final decoded = CloudBackupTargetState.fromJson(original.toJson());
      expect(decoded.lastIndexName, original.lastIndexName);
      expect(decoded.lastSuccessAt, original.lastSuccessAt);
      expect(decoded.lastFailureAt, original.lastFailureAt);
      expect(decoded.lastAuto!.failure, CloudBackupFailure.sessionExpired);
      expect(decoded.pendingPacks, {
        'p.pack': [hashA],
      });
      expect(CloudBackupTargetState.fromJson('garbage').lastIndexName, isNull);
    });
  });
}
