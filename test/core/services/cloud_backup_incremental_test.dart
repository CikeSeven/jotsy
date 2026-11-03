import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/backup_archive_io.dart';
import 'package:node_diary/core/services/backup_import_models.dart';
import 'package:node_diary/core/services/cloud_backup_incremental.dart';
import 'package:node_diary/core/services/cloud_backup_incremental_io.dart';
import 'package:node_diary/core/services/cloud_backup_incremental_prune.dart';
import 'package:node_diary/core/services/cloud_backup_incremental_state.dart';
import 'package:node_diary/core/services/cloud_backup_models.dart';
import 'package:node_diary/core/services/cloud_backup_service.dart';
import 'package:node_diary/core/services/cloud_backup_settings_service.dart';
import 'package:node_diary/core/services/cloud_backup_target.dart';
import 'package:path/path.dart' as p;

import '../../support/backup_test_fixture.dart';
import '../../support/memory_cloud_remote.dart';

/// 增量备份端到端（内存网盘）：去重上传、没有变化不上传、同机恢复不下载
/// 媒体、新装恢复、加密、续传、限流重试、清理与自动备份。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackupTestFixture fixture;
  late CloudBackupSettingsService targets;
  late MemoryCloudRemote remote;
  late CloudBackupTarget target;
  late DateTime now;
  late List<Duration> sleeps;

  CloudBackupService newService({int? autoUploadLimit}) => CloudBackupService(
    database: fixture.database,
    settingsService: fixture.settings,
    targets: targets,
    drives: {CloudBackupKind.googleDrive: MemoryCloudDrive(remote)},
    temporaryDirectory: () async => fixture.temporary,
    sleep: (duration) async => sleeps.add(duration),
    clock: () => now,
    autoUploadLimit:
        autoUploadLimit ?? CloudIncrementalBackup.defaultAutoUploadLimit,
  );

  CloudIncrementalChainResolver newChain([String password = '']) =>
      (context) async => CloudIncrementalChainChoice(
        chain: context.newChainId(),
        password: password,
      );

  Future<IncrementalSnapshotRef> latestSnapshot(
    CloudBackupService service,
  ) async => (await service.listBackups(target)).incremental.snapshots.first;

  Future<File> addImage(String name, List<int> bytes) async {
    final file = File(
      p.join(fixture.documents.path, 'diary_images', 'media_new', name),
    );
    await file.parent.create(recursive: true);
    return file.writeAsBytes(bytes, flush: true);
  }

  setUp(() async {
    fixture = await BackupTestFixture.create();
    targets = await CloudBackupSettingsService.create();
    remote = MemoryCloudRemote();
    target = MemoryCloudDrive.target();
    await targets.saveTarget(target);
    now = DateTime(2026, 11, 3, 10);
    sleeps = <Duration>[];
    await fixture.seedCurrentData();
  });

  tearDown(() async {
    targets.dispose();
    await fixture.dispose();
  });

  test('first backup packs every media once and remembers the chain', () async {
    final service = newService();
    final result = await service.backupIncremental(
      target,
      resolveChain: newChain(),
    );

    expect(result.outcome, CloudIncrementalBackupOutcome.uploaded);
    expect(remote.namesEndingWith('.pack'), hasLength(1));
    expect(remote.namesEndingWith('.snap'), hasLength(1));
    expect(remote.namesEndingWith('.idx'), hasLength(1));
    // 索引最后上传：它是提交标记。
    expect(remote.uploads.last, endsWith('.idx'));
    expect(targets.targetById(target.id)!.options.hasChain, isTrue);
    expect(remote.files.keys.where((name) => name.endsWith('.zip')), isEmpty);
  });

  test('a second backup without changes uploads nothing', () async {
    final service = newService();
    await service.backupIncremental(target, resolveChain: newChain());
    final uploads = remote.uploads.length;

    final result = await service.backupIncremental(target);

    expect(result.outcome, CloudIncrementalBackupOutcome.unchanged);
    expect(remote.uploads, hasLength(uploads));
  });

  test('new media uploads only a pack with the new content', () async {
    final service = newService();
    await service.backupIncremental(target, resolveChain: newChain());
    await addImage('new.jpg', List<int>.generate(64, (i) => i));
    final before = remote.uploads.length;

    final result = await service.backupIncremental(target);

    expect(result.outcome, CloudIncrementalBackupOutcome.uploaded);
    final added = remote.uploads.sublist(before);
    final packs = added.where((name) => name.endsWith('.pack')).toList();
    expect(packs, hasLength(1));
    final extracted = await fixture.temporary.createTemp('pack_check_');
    final packFile = File(p.join(fixture.temporary.path, 'check.pack'))
      ..writeAsBytesSync(remote.files[packs.single]!);
    await BackupArchiveIO.extract(packFile.path, extracted);
    expect(extracted.listSync(), hasLength(1));
  });

  test('restoring on the same device downloads no media packs', () async {
    final service = newService();
    await service.backupIncremental(target, resolveChain: newChain());
    await fixture.database.createDiary(
      title: 'written after the backup',
      contentDocJson: '[]',
      contentText: '',
      metadataJson: '{}',
    );
    remote.downloads.clear();

    final opened = await service.openIncrementalSnapshot(
      target,
      await latestSnapshot(service),
      password: null,
    );
    addTearDown(opened.dispose);
    await service.restoreIncremental(
      target,
      opened,
      mode: BackupImportMode.replaceAll,
    );

    expect(remote.downloads.where((name) => name.endsWith('.pack')), isEmpty);
    final titles =
        (await fixture.database.select(fixture.database.diaries).get()).map(
          (diary) => diary.title,
        );
    expect(titles, ['current diary']);
    for (final MapEntry(key: path, value: bytes)
        in fixture.originalMedia.entries) {
      expect(File(path).readAsBytesSync(), bytes, reason: path);
    }
  });

  test('a fresh install restores media from the packs', () async {
    await newService().backupIncremental(target, resolveChain: newChain());
    await targets.updateOptions(target.id, (options) => options.withoutChain());
    final relative = {
      for (final entry in fixture.originalMedia.entries)
        p.relative(entry.key, from: fixture.documents.path): entry.value,
    };
    fixture.documents = await Directory(
      p.join(fixture.root.path, 'fresh_install'),
    ).create();
    final service = newService();

    final opened = await service.openIncrementalSnapshot(
      target,
      await latestSnapshot(service),
      password: null,
    );
    addTearDown(opened.dispose);
    await service.restoreIncremental(
      target,
      opened,
      mode: BackupImportMode.replaceAll,
    );

    expect(
      remote.downloads.where((name) => name.endsWith('.pack')),
      isNotEmpty,
    );
    for (final MapEntry(key: path, value: bytes) in relative.entries) {
      expect(
        File(p.join(fixture.documents.path, path)).readAsBytesSync(),
        bytes,
        reason: path,
      );
    }
    // 恢复后接着这条链：再备份不重传任何媒体。
    expect(targets.targetById(target.id)!.options.hasChain, isTrue);
    final before = remote.uploads.length;
    await service.backupIncremental(target);
    expect(
      remote.uploads.sublist(before).where((name) => name.endsWith('.pack')),
      isEmpty,
    );
  });

  test(
    'merge restore brings back a deleted diary and keeps local ones',
    () async {
      final service = newService();
      await service.backupIncremental(target, resolveChain: newChain());
      final diary = await fixture.database
          .select(fixture.database.diaries)
          .getSingle();
      await fixture.database.hardDeleteDiary(diary.diaryId);
      await fixture.database.createDiary(
        title: 'local only',
        contentDocJson: '[]',
        contentText: '',
        metadataJson: '{}',
      );

      final opened = await service.openIncrementalSnapshot(
        target,
        await latestSnapshot(service),
        password: null,
      );
      addTearDown(opened.dispose);
      await service.restoreIncremental(
        target,
        opened,
        mode: BackupImportMode.merge,
      );

      final titles =
          (await fixture.database.select(fixture.database.diaries).get())
              .map((diary) => diary.title)
              .toSet();
      expect(titles, {'current diary', 'local only'});
    },
  );

  test('an encrypted chain needs its password to restore', () async {
    await newService().backupIncremental(
      target,
      resolveChain: newChain('secret'),
    );
    final pack = remote.namesEndingWith('.pack').single;
    final packFile = File(p.join(fixture.temporary.path, 'enc.pack'))
      ..writeAsBytesSync(remote.files[pack]!);
    expect(await BackupArchiveIO.isPasswordProtected(packFile.path), isTrue);

    // 另一台设备：没有缓存，也没有记住的密码。
    fixture.documents = await Directory(
      p.join(fixture.root.path, 'other_device'),
    ).create();
    final service = newService();
    final snapshot = await latestSnapshot(service);
    for (final password in [null, 'wrong']) {
      await expectLater(
        service.openIncrementalSnapshot(target, snapshot, password: password),
        throwsA(isA<CloudIncrementalPasswordException>()),
      );
    }
    final opened = await service.openIncrementalSnapshot(
      target,
      snapshot,
      password: 'secret',
    );
    await opened.dispose();
  });

  test(
    'an interrupted first backup reuses the packs it already uploaded',
    () async {
      final service = newService();
      remote.beforeUpload = (name) {
        if (name.endsWith('.snap')) {
          throw const CloudBackupException(CloudBackupFailure.storageFull);
        }
      };
      await expectLater(
        service.backupIncremental(target, resolveChain: newChain()),
        throwsA(isA<CloudBackupException>()),
      );
      expect(remote.namesEndingWith('.pack'), hasLength(1));
      expect(remote.namesEndingWith('.idx'), isEmpty);
      remote.beforeUpload = null;
      final before = remote.uploads.length;

      final result = await service.backupIncremental(target);

      expect(result.outcome, CloudIncrementalBackupOutcome.uploaded);
      expect(
        remote.uploads.sublist(before).where((name) => name.endsWith('.pack')),
        isEmpty,
      );
      expect(remote.namesEndingWith('.idx'), hasLength(1));
    },
  );

  test('rate limited uploads are retried with back-off', () async {
    var failures = 1;
    remote.beforeUpload = (name) {
      if (name.endsWith('.pack') && failures-- > 0) {
        throw const CloudBackupException(CloudBackupFailure.rateLimited);
      }
    };

    final result = await newService().backupIncremental(
      target,
      resolveChain: newChain(),
    );

    expect(result.outcome, CloudIncrementalBackupOutcome.uploaded);
    expect(sleeps, [cloudRetryDelays.first]);
    // 重试换了新文件名；失败的那次没有落地，网盘上只有一个包。
    expect(remote.namesEndingWith('.pack'), hasLength(1));
  });

  test(
    'deleting a backup removes packs only it used, after the grace period',
    () async {
      final service = newService();
      await service.backupIncremental(target, resolveChain: newChain());
      final firstPack = remote.namesEndingWith('.pack').single;
      now = now.add(const Duration(days: 1));
      await addImage('only_second.jpg', [9, 9, 9]);
      await service.backupIncremental(target);
      final secondPack = remote
          .namesEndingWith('.pack')
          .firstWhere((name) => name != firstPack);
      final second = await latestSnapshot(service);

      now = now.add(const Duration(days: 2));
      await service.deleteIncrementalSnapshot(target, second);

      expect(remote.files.containsKey(second.index.fileName), isFalse);
      expect(remote.files.containsKey(second.snapshot!.fileName), isFalse);
      expect(remote.files.containsKey(secondPack), isFalse);
      expect(remote.files.containsKey(firstPack), isTrue);
      expect(
        (await service.listBackups(target)).incremental.snapshots,
        hasLength(1),
      );
    },
  );

  test('automatic backup runs only when due and stays quiet', () async {
    final service = newService(autoUploadLimit: 16);
    expect(await service.runAutoBackup(target.id), isNull);
    await service.backupIncremental(target, resolveChain: newChain());
    await targets.updateOptions(
      target.id,
      (options) => options.copyWith(autoBackup: true),
    );

    now = now.add(const Duration(hours: 1));
    expect(await service.runAutoBackup(target.id), isNull);

    now = now.add(const Duration(days: 1));
    final listsBefore = remote.listCalls;
    final unchanged = await service.runAutoBackup(target.id);
    expect(unchanged!.outcome, CloudAutoBackupOutcome.unchanged);
    // 指纹没变：不联网。
    expect(remote.listCalls, listsBefore);

    now = now.add(const Duration(days: 1));
    await addImage('large.jpg', List<int>.filled(64, 7));
    final tooLarge = await service.runAutoBackup(target.id);
    expect(tooLarge!.outcome, CloudAutoBackupOutcome.needsManual);
    expect(tooLarge.bytes, 64);
    expect(remote.namesEndingWith('.idx'), hasLength(1));

    now = now.add(const Duration(hours: 2));
    expect(await service.runAutoBackup(target.id), isNull);
    final state = await service.readTargetState(target.id);
    expect(state.lastAuto!.outcome, CloudAutoBackupOutcome.needsManual);
  });

  test(
    'a failing automatic backup is recorded and retried after an hour',
    () async {
      final service = newService();
      await service.backupIncremental(target, resolveChain: newChain());
      await targets.updateOptions(
        target.id,
        (options) => options.copyWith(autoBackup: true),
      );
      await addImage('new.jpg', [1, 2, 3]);
      remote.beforeUpload = (_) =>
          throw const CloudBackupException(CloudBackupFailure.sessionExpired);

      now = now.add(const Duration(days: 2));
      final failed = await service.runAutoBackup(target.id);
      expect(failed!.outcome, CloudAutoBackupOutcome.failed);
      expect(failed.failure, CloudBackupFailure.sessionExpired);

      now = now.add(const Duration(minutes: 30));
      expect(await service.runAutoBackup(target.id), isNull);
      remote.beforeUpload = null;
      now = now.add(const Duration(minutes: 31));
      final retried = await service.runAutoBackup(target.id);
      expect(retried!.outcome, CloudAutoBackupOutcome.uploaded);
    },
  );

  test('a cancelled chain choice uploads nothing', () async {
    final result = await newService().backupIncremental(
      target,
      resolveChain: (_) async => null,
    );

    expect(result.outcome, CloudIncrementalBackupOutcome.cancelled);
    expect(remote.uploads, isEmpty);
    expect(targets.targetById(target.id)!.options.hasChain, isFalse);
  });

  test(
    'a second device can continue an encrypted chain after verifying',
    () async {
      await newService().backupIncremental(
        target,
        resolveChain: newChain('secret'),
      );
      await targets.updateOptions(
        target.id,
        (options) => options.withoutChain(),
      );
      final service = newService();
      final before = remote.uploads.length;
      bool? encrypted;
      final verified = <String, bool>{};

      final result = await service.backupIncremental(
        target,
        resolveChain: (context) async {
          encrypted = await context.isExistingEncrypted();
          for (final password in ['wrong', 'secret']) {
            verified[password] = await context.verify(password);
          }
          return CloudIncrementalChainChoice(
            chain: context.existingChain!,
            password: 'secret',
          );
        },
      );

      expect(encrypted, isTrue);
      expect(verified, {'wrong': false, 'secret': true});
      expect(result.outcome, CloudIncrementalBackupOutcome.unchanged);
      expect(remote.uploads, hasLength(before));
    },
  );
}
