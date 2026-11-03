import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import 'backup_archive_io.dart';
import 'cloud_backup_incremental_cleanup.dart';
import 'cloud_backup_incremental_format.dart';
import 'cloud_backup_incremental_models.dart';
import 'cloud_backup_incremental_io.dart';
import 'cloud_backup_incremental_packs.dart';
import 'cloud_backup_incremental_prune.dart';
import 'cloud_backup_incremental_scan.dart';
import 'cloud_backup_incremental_state.dart';
import 'cloud_backup_models.dart';
import 'cloud_backup_options.dart';
import 'cloud_backup_target.dart';
import 'settings_service.dart';

export 'cloud_backup_incremental_models.dart';

/// 网盘增量备份的上传编排（docs/cloud_backup.md「增量备份」）。
///
/// 一次备份：
/// 1. 扫描本机（[IncrementalLocalScan]）：载荷与全部媒体的哈希；
/// 2. 自动备份且指纹与上次成功时相同 → 记为“没有变化”，不联网；
/// 3. 列出网盘文件一次；本机还没有增量链时经 [CloudIncrementalChainResolver]
///    让用户接上已有的链或开始新链（自动备份从不走到这一步）；
/// 4. 读这条链最新的索引（本机缓存优先），指纹相同 → “没有变化”；
/// 5. 网盘已有的内容 = 最新索引里、所在包仍在的哈希 + 续传日志里、包仍在的
///    哈希；其余内容打包上传，每传完一个包写一次续传日志；
/// 6. 上传快照，再上传索引（提交）；记住链与密码、更新本机状态；
/// 7. 按保留份数清理（失败只记日志，不影响这次备份的结果）。
///
/// 职责边界：不持有 BuildContext、不决定文案；同一备份位置的并发由
/// `CloudBackupService` 的锁保证。
class CloudIncrementalBackup {
  CloudIncrementalBackup({
    required this.database,
    required this.settingsService,
    required this.state,
    required this.dataRoot,
    required this.temporary,
    required this.saveOptions,
    required this.sleep,
    required this.clock,
    this.autoUploadLimit = defaultAutoUploadLimit,
    Random? random,
  }) : _random = random ?? Random.secure();

  /// 自动备份一次最多上传的新媒体；超过时留给用户手动备份（没有判断网络
  /// 类型的依赖，用大小兜住移动数据）。
  static const int defaultAutoUploadLimit = 50 * 1024 * 1024;
  final int autoUploadLimit;

  final AppDatabase database;
  final SettingsService settingsService;
  final CloudBackupLocalState state;
  final Directory dataRoot;
  final Future<Directory> Function() temporary;
  final Future<void> Function(
    String targetId,
    CloudBackupOptions Function(CloudBackupOptions) update,
  )
  saveOptions;
  final CloudSleep sleep;
  final DateTime Function() clock;
  final Random _random;

  Future<CloudIncrementalBackupResult> backup({
    required CloudBackupTarget target,
    required CloudBackupRemote remote,
    bool auto = false,
    CloudIncrementalChainResolver? resolveChain,
    CloudIncrementalPhaseCallback? onPhase,
    CloudBackupProgress? onProgress,
  }) async {
    onPhase?.call(CloudIncrementalPhase.scanning);
    final scan = await IncrementalLocalScan.capture(
      database: database,
      settingsService: settingsService,
      mediaIndex: state.mediaIndex,
      dataRoot: dataRoot,
      temporary: await temporary(),
    );
    final scratch = await scan.working.createTemp('io_');
    try {
      var local = await state.read(target.id);
      final options = target.options;
      if (auto &&
          options.hasChain &&
          local.lastIndexName != null &&
          local.lastFingerprint == scan.fingerprint) {
        // 记为一次成功：自动备份按间隔计算，没变化也算“已是最新”，不必在
        // 每次切到后台时重新扫描。
        await state.write(
          target.id,
          local.succeeded(
            indexName: local.lastIndexName!,
            fingerprint: scan.fingerprint,
            at: clock(),
          ),
        );
        return const CloudIncrementalBackupResult.unchanged();
      }
      onPhase?.call(CloudIncrementalPhase.checking);
      final io = IncrementalRemoteIO(
        remote: remote,
        state: state,
        targetId: target.id,
        scratch: scratch,
        sleep: sleep,
      );
      final files = await io.listFiles();
      final listing = IncrementalRemoteListing.of(files);

      final String chain;
      final String password;
      if (options.hasChain) {
        chain = options.chain!;
        password = options.password!;
      } else {
        if (resolveChain == null) {
          throw StateError('incremental backup needs a chain');
        }
        final choice = await resolveChain(_chainContext(listing, io));
        if (choice == null) {
          return const CloudIncrementalBackupResult.cancelled();
        }
        chain = choice.chain;
        password = choice.password;
        local = local.forgetChain();
        // 选定就记住，而不是等提交成功：第一次上传可能很大，中途断网后下次
        // 备份要接着同一条链，续传日志里已上传的包才能沿用（换一条新链就
        // 得全部重传）。
        await _remember(target, chain, password);
      }
      final zipPassword = password.isEmpty ? null : password;

      final latest = listing.latestOf(chain);
      final latestIndex = latest == null
          ? null
          : await io.readIndex(latest.index, password: zipPassword);
      if (latest != null && latestIndex!.fingerprint == scan.fingerprint) {
        await _remember(target, chain, password);
        await state.write(
          target.id,
          local.succeeded(
            indexName: latest.index.fileName,
            fingerprint: scan.fingerprint,
            at: clock(),
          ),
        );
        return const CloudIncrementalBackupResult.unchanged();
      }

      // 网盘上已经有的内容：哈希 → 所在的包。
      final known = <String, String>{};
      if (latestIndex != null) {
        for (final MapEntry(key: hash, value: pack)
            in latestIndex.packs.entries) {
          if (listing.packs.containsKey(pack)) known[hash] = pack;
        }
      }
      for (final MapEntry(key: pack, value: hashes)
          in local.pendingPacks.entries) {
        if (IncrementalFileName.parse(pack)?.chain != chain ||
            !listing.packs.containsKey(pack)) {
          continue;
        }
        for (final hash in hashes) {
          known.putIfAbsent(hash, () => pack);
        }
      }

      final items = _missingItems(scan, known);
      final missingBytes = items.fold<int>(0, (sum, item) => sum + item.size);
      if (auto && missingBytes > autoUploadLimit) {
        return CloudIncrementalBackupResult.needsManual(missingBytes);
      }

      onPhase?.call(CloudIncrementalPhase.uploading);
      final snapshotSize = await scan.payloadFile.length();
      final progress = _UploadProgress(missingBytes + snapshotSize, onProgress);
      final uploaded = <CloudBackupEntry>[];
      for (final group in groupIncrementalPackItems(items)) {
        final packFile = File(p.join(scratch.path, 'pack.tmp'));
        await writeIncrementalPack(
          group,
          outputPath: packFile.path,
          password: zipPassword,
        );
        final size = await packFile.length();
        final entry = await withCloudRetry((attempt) {
          progress.restart();
          return remote.upload(
            file: packFile,
            fileName: incrementalPackName(clock(), chain, _randomHex()),
            onProgress: progress.update,
          );
        }, sleep: sleep);
        progress.finish(size);
        await packFile.delete();
        uploaded.add(entry);
        final hashes = [for (final item in group) item.sha256];
        for (final hash in hashes) {
          known[hash] = entry.fileName;
        }
        local = local.withPendingPack(entry.fileName, hashes);
        await state.write(target.id, local);
      }

      final stem = incrementalSnapshotStem(clock(), chain);
      final snapFile = File(p.join(scratch.path, '$stem$snapshotExtension'));
      await BackupArchiveIO.encodeEntries(
        [(incrementalSnapshotEntryName, scan.payloadFile.path)],
        outputZipPath: snapFile.path,
        password: zipPassword,
      );
      final snapEntry = await withCloudRetry((_) {
        progress.restart();
        return remote.upload(
          file: snapFile,
          fileName: '$stem$snapshotExtension',
          onProgress: progress.update,
        );
      }, sleep: sleep);
      progress.finish(await snapFile.length());
      uploaded.add(snapEntry);

      final index = IncrementalIndex(
        chain: chain,
        createdAt: clock(),
        encrypted: zipPassword != null,
        payloadSha256: scan.payloadSha256,
        snapshotSize: await snapFile.length(),
        media: scan.media,
        packs: {
          for (final ref in scan.media.values) ref.sha256: known[ref.sha256]!,
        },
      );
      final indexJson = File(p.join(scratch.path, incrementalIndexEntryName));
      await indexJson.writeAsString(index.encode(), flush: true);
      final indexFile = File(p.join(scratch.path, '$stem$indexExtension'));
      await BackupArchiveIO.encodeEntries(
        [(incrementalIndexEntryName, indexJson.path)],
        outputZipPath: indexFile.path,
        password: zipPassword,
      );
      final indexEntry = await withCloudRetry(
        (_) => remote.upload(file: indexFile, fileName: '$stem$indexExtension'),
        sleep: sleep,
      );
      uploaded.add(indexEntry);
      await state.cacheIndex(
        target.id,
        indexEntry.fileName,
        index,
        password: zipPassword,
      );
      await _remember(target, chain, password);
      await state.write(
        target.id,
        local.succeeded(
          indexName: indexEntry.fileName,
          fingerprint: scan.fingerprint,
          at: clock(),
        ),
      );

      onPhase?.call(CloudIncrementalPhase.pruning);
      await pruneIncrementalQuietly(
        state: state,
        clock: clock,
        sleep: sleep,
        io: io,
        files: [...files, ...uploaded],
        keep: target.options.keepSnapshots,
        chain: chain,
        password: zipPassword,
      );
      return CloudIncrementalBackupResult.uploaded(progress.uploadedBytes);
    } finally {
      await scan.dispose();
    }
  }

  /// 删除一份增量备份：先删索引（撤回提交）再删快照，然后清理不再被引用的
  /// 媒体包。
  Future<void> deleteSnapshot({
    required CloudBackupTarget target,
    required CloudBackupRemote remote,
    required IncrementalSnapshotRef snapshot,
  }) async {
    final scratch = await (await temporary()).createTemp('cloud_inc_del_');
    try {
      final io = IncrementalRemoteIO(
        remote: remote,
        state: state,
        targetId: target.id,
        scratch: scratch,
        sleep: sleep,
      );
      await withCloudRetry((_) => remote.delete(snapshot.index), sleep: sleep);
      final snap = snapshot.snapshot;
      if (snap != null) {
        await withCloudRetry((_) => remote.delete(snap), sleep: sleep);
      }
      final options = target.options;
      final files = await io.listFiles();
      await pruneIncrementalQuietly(
        state: state,
        clock: clock,
        sleep: sleep,
        io: io,
        files: files,
        keep: options.keepSnapshots,
        chain: options.hasChain ? options.chain : null,
        password: options.zipPassword,
      );
    } finally {
      await scratch.delete(recursive: true);
    }
  }

  CloudIncrementalChainContext _chainContext(
    IncrementalRemoteListing listing,
    IncrementalRemoteIO io,
  ) {
    final latest = listing.snapshots.isEmpty ? null : listing.snapshots.first;
    return CloudIncrementalChainContext(
      existingChain: latest?.chain,
      isExistingEncrypted: latest == null
          ? () async => false
          : () => io.isEncrypted(latest.index),
      verify: latest == null
          ? (_) async => false
          : (password) => io.verifyPassword(
              latest.index,
              password.isEmpty ? null : password,
            ),
      newChainId: _randomHex,
    );
  }

  /// 每个哈希挑一个本机文件（按媒体键排序取第一个），组成要上传的内容。
  List<IncrementalPackItem> _missingItems(
    IncrementalLocalScan scan,
    Map<String, String> known,
  ) {
    final keys = scan.media.keys.toList()..sort();
    final picked = <String>{};
    return [
      for (final key in keys)
        if (!known.containsKey(scan.media[key]!.sha256) &&
            picked.add(scan.media[key]!.sha256))
          IncrementalPackItem(
            sha256: scan.media[key]!.sha256,
            path: scan.files[key]!.path,
            size: scan.media[key]!.size,
            modifiedAt: scan.files[key]!.modifiedAt,
          ),
    ];
  }

  Future<void> _remember(
    CloudBackupTarget target,
    String chain,
    String password,
  ) async {
    final options = target.options;
    if (options.chain == chain && options.password == password) return;
    await saveOptions(
      target.id,
      (current) => current.withChain(chain, password),
    );
  }

  String _randomHex() => List<String>.generate(
    4,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// 上传进度：多个文件合成一条，按总字节换算。
class _UploadProgress {
  _UploadProgress(this.total, this.onProgress);

  final int total;
  final CloudBackupProgress? onProgress;
  int uploadedBytes = 0;
  int _current = 0;

  void restart() => _current = 0;

  void update(int transferred, int? _) {
    _current = transferred;
    onProgress?.call(uploadedBytes + _current, total);
  }

  void finish(int size) {
    uploadedBytes += size;
    _current = 0;
    onProgress?.call(uploadedBytes, total);
  }
}
