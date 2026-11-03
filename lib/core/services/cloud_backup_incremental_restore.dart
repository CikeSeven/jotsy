import 'dart:io';

import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import 'backup_constants.dart';
import 'backup_import_models.dart';
import 'backup_payload.dart';
import 'cloud_backup_incremental_format.dart';
import 'cloud_backup_incremental_io.dart';
import 'cloud_backup_incremental_packs.dart';
import 'cloud_backup_incremental_prune.dart';
import 'cloud_backup_incremental_scan.dart';
import 'cloud_backup_incremental_state.dart';
import 'cloud_backup_models.dart';
import 'cloud_backup_target.dart';
import 'data_archive_service.dart';
import 'settings_service.dart';

/// 网盘增量备份的恢复编排。
///
/// 1. [open]：下载索引（多半已有缓存）与快照，解出载荷供预检；
/// 2. 界面经 `chooseBackupImportMode` 选好合并或覆盖（与完整备份同一套）；
/// 3. [restore]：按索引规划媒体——本机已有同样内容的直接复制，只下载缺少
///    内容所在的媒体包——再交给 [DataArchiveService.importFromPreparedStaging]，
///    之后的合并 / 覆盖、回滚与通知与恢复完整备份完全相同。
///
/// 本机文件一律复制、不移动：覆盖恢复失败时，回滚依赖本机原目录完好。
/// 需要的包在网盘上找不到、包里内容与哈希不符时整次恢复放弃（本机数据
/// 不动），不恢复出缺了照片的数据。
class CloudIncrementalRestore {
  CloudIncrementalRestore({
    required this.database,
    required this.settingsService,
    required this.state,
    required this.dataRoot,
    required this.temporary,
    required this.sleep,
  });

  final AppDatabase database;
  final SettingsService settingsService;
  final CloudBackupLocalState state;
  final Directory dataRoot;
  final Future<Directory> Function() temporary;
  final CloudSleep sleep;

  /// 下载并解开一份增量备份；调用方用完必须 [IncrementalSnapshotOpened.dispose]。
  /// [password] 为 null 表示这条链不加密；不对时抛
  /// [CloudIncrementalPasswordException]。
  Future<IncrementalSnapshotOpened> open({
    required CloudBackupTarget target,
    required CloudBackupRemote remote,
    required IncrementalSnapshotRef snapshot,
    required String? password,
    CloudBackupProgress? onProgress,
  }) async {
    final snap = snapshot.snapshot;
    if (snap == null) {
      throw CloudBackupException(CloudBackupFailure.notFound, snapshot.stem);
    }
    final scratch = await (await temporary()).createTemp('cloud_inc_restore_');
    try {
      final io = _io(target, remote, scratch);
      final index = await io.readIndex(snapshot.index, password: password);
      final payloadJson = await io.readSnapshotPayload(
        snap,
        password: password,
        onProgress: onProgress,
      );
      return IncrementalSnapshotOpened._(
        snapshot: snapshot,
        index: index,
        payloadJson: payloadJson,
        payload: BackupPayload.decode(payloadJson),
        password: password,
        scratch: scratch,
      );
    } catch (_) {
      await scratch.delete(recursive: true);
      rethrow;
    }
  }

  /// 按 [mode] 恢复已打开的增量备份。
  Future<BackupImportResult> restore({
    required CloudBackupTarget target,
    required CloudBackupRemote remote,
    required IncrementalSnapshotOpened opened,
    required BackupImportMode mode,
    CloudBackupProgress? onDownloadProgress,
  }) async {
    final (_, localFiles) = await scanIncrementalMedia(
      dataRoot: dataRoot,
      mediaIndex: state.mediaIndex,
    );
    final plan = await _plan(opened.index, localFiles);
    final io = _io(target, remote, opened._scratch);

    final downloads = <String, File>{};
    if (plan.packs.isNotEmpty) {
      final remoteFiles = {
        for (final file in await io.listFiles()) file.fileName: file,
      };
      final entries = <CloudBackupEntry>[];
      for (final name in plan.packs.keys) {
        final entry = remoteFiles[name];
        if (entry == null) {
          throw CloudBackupException(CloudBackupFailure.notFound, name);
        }
        entries.add(entry);
      }
      final total = entries.every((entry) => entry.size != null)
          ? entries.fold<int>(0, (sum, entry) => sum + entry.size!)
          : null;
      var done = 0;
      for (final entry in entries) {
        downloads[entry.fileName] = await io.download(
          entry,
          onProgress: (transferred, _) =>
              onDownloadProgress?.call(done + transferred, total),
        );
        done += entry.size ?? 0;
      }
    }

    return DataArchiveService.importFromPreparedStaging(
      database: database,
      settingsService: settingsService,
      mode: mode,
      fill: (staging) async {
        await File(
          p.join(staging.path, backupPayloadFileName),
        ).writeAsString(opened.payloadJson, flush: true);
        for (final (key, source) in plan.copies) {
          final stat = await File(source.path).stat();
          if (stat.type != FileSystemEntityType.file ||
              stat.modified.millisecondsSinceEpoch != source.modifiedAt) {
            throw IncrementalMediaChangedException(source.path);
          }
          final destination = File(stagingPathOf(staging, key));
          await destination.parent.create(recursive: true);
          await File(source.path).copy(destination.path);
        }
        final scratch = Directory(p.join(staging.path, '.pack_scratch'));
        await scratch.create();
        try {
          for (final MapEntry(key: name, value: targets)
              in plan.packs.entries) {
            final missing = await placeIncrementalPackContents(
              pack: downloads[name]!,
              targets: targets,
              staging: staging,
              scratch: scratch,
              password: opened.password,
            );
            if (missing.isNotEmpty) {
              throw FormatException('增量备份的媒体包已损坏：$name');
            }
          }
        } finally {
          await scratch.delete(recursive: true);
        }
      },
    );
  }

  /// 每个媒体键的来源：本机同一路径同一内容 → 复制它；本机别处有同一内容
  /// → 复制那一份；都没有 → 从索引记录的媒体包里取。
  Future<IncrementalRestorePlan> _plan(
    IncrementalIndex index,
    Map<String, IncrementalLocalFile> localFiles,
  ) async {
    final local = await state.mediaIndex.describeAll(localFiles.keys);
    final byHash = <String, IncrementalLocalFile>{};
    for (final MapEntry(key: key, value: info) in local.entries) {
      byHash.putIfAbsent(info.sha256, () => localFiles[key]!);
    }
    final copies = <(String, IncrementalLocalFile)>[];
    final packs = <String, Map<String, List<String>>>{};
    final keys = index.media.keys.toList()..sort();
    for (final key in keys) {
      if (!isValidIncrementalMediaKey(key)) {
        throw FormatException('增量备份索引的媒体路径不合法：$key');
      }
      final ref = index.media[key]!;
      final same = local[key];
      if (same != null && same.sha256 == ref.sha256) {
        copies.add((key, localFiles[key]!));
        continue;
      }
      final elsewhere = byHash[ref.sha256];
      if (elsewhere != null) {
        copies.add((key, elsewhere));
        continue;
      }
      packs
          .putIfAbsent(index.packs[ref.sha256]!, () => {})
          .putIfAbsent(ref.sha256, () => [])
          .add(key);
    }
    return IncrementalRestorePlan(copies, packs);
  }

  IncrementalRemoteIO _io(
    CloudBackupTarget target,
    CloudBackupRemote remote,
    Directory scratch,
  ) => IncrementalRemoteIO(
    remote: remote,
    state: state,
    targetId: target.id,
    scratch: scratch,
    sleep: sleep,
  );
}

/// 恢复时每个媒体的来源。
class IncrementalRestorePlan {
  const IncrementalRestorePlan(this.copies, this.packs);

  /// 从本机复制：（媒体键, 本机文件）。
  final List<(String, IncrementalLocalFile)> copies;

  /// 要下载的包：包名 → 哈希 → 要放到的媒体键。
  final Map<String, Map<String, List<String>>> packs;
}

/// 已下载并解开的一份增量备份。
class IncrementalSnapshotOpened {
  IncrementalSnapshotOpened._({
    required this.snapshot,
    required this.index,
    required this.payloadJson,
    required this.payload,
    required this.password,
    required this._scratch,
  });

  final IncrementalSnapshotRef snapshot;
  final IncrementalIndex index;
  final String payloadJson;
  final BackupPayload payload;
  final String? password;
  final Directory _scratch;

  Future<void> dispose() async {
    try {
      if (await _scratch.exists()) await _scratch.delete(recursive: true);
    } on FileSystemException {
      // 临时目录清理失败不影响恢复结果。
    }
  }
}
