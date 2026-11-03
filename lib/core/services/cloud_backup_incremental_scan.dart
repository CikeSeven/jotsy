import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import 'backup_payload.dart';
import 'cloud_backup_incremental_format.dart';
import 'cloud_backup_incremental_packs.dart';
import 'data_archive_service.dart';
import 'lan_sync/sync/sync_media_index.dart';
import 'settings_service.dart';

/// 增量备份对本机数据的一次扫描：载荷（写成 gzip 临时文件）与全部托管
/// 媒体的哈希。
///
/// 职责边界：只读数据库、设置与媒体文件，写临时目录；不联网。
class IncrementalLocalScan {
  IncrementalLocalScan._({
    required this.working,
    required this.payloadFile,
    required this.payloadSha256,
    required this.media,
    required this.files,
  }) : fingerprint = incrementalFingerprint(payloadSha256, media);

  /// 本次扫描的临时目录（载荷文件在里面）；用完调用 [dispose]。
  final Directory working;

  /// 载荷 JSON 的 gzip（[incrementalSnapshotEntryName]）。
  final File payloadFile;
  final String payloadSha256;
  final Map<String, IncrementalMediaRef> media;

  /// 媒体键 → 本机文件与扫描时的修改时间。
  final Map<String, IncrementalLocalFile> files;
  final String fingerprint;

  Future<void> dispose() async {
    try {
      if (await working.exists()) await working.delete(recursive: true);
    } on FileSystemException {
      // 临时目录清理失败不影响备份结果。
    }
  }

  /// 在恢复的串行队列里扫描：不与正在进行的恢复 / 导入交错，读到的是同一
  /// 时刻的数据库与媒体。
  static Future<IncrementalLocalScan> capture({
    required AppDatabase database,
    required SettingsService settingsService,
    required SyncMediaIndex mediaIndex,
    required Directory dataRoot,
    required Directory temporary,
  }) => DataArchiveService.runSerialized(() async {
    final working = await temporary.createTemp('cloud_inc_');
    try {
      final payload = await BackupPayload.capture(
        database: database,
        settingsService: settingsService,
      );
      final payloadFile = File(
        p.join(working.path, incrementalSnapshotEntryName),
      );
      final sink = payloadFile.openWrite();
      try {
        await sink.addStream(
          Stream<List<int>>.value(
            utf8.encode(jsonEncode(payload)),
          ).transform(gzip.encoder),
        );
      } finally {
        await sink.close();
      }
      final (media, files) = await scanIncrementalMedia(
        dataRoot: dataRoot,
        mediaIndex: mediaIndex,
      );
      return IncrementalLocalScan._(
        working: working,
        payloadFile: payloadFile,
        payloadSha256: incrementalPayloadSha256(payload),
        media: media,
        files: files,
      );
    } catch (_) {
      await working.delete(recursive: true);
      rethrow;
    }
  });
}

/// 一个本机媒体文件。
class IncrementalLocalFile {
  const IncrementalLocalFile(this.path, this.modifiedAt);

  final String path;

  /// UTC 毫秒。
  final int modifiedAt;
}

/// 扫描全部托管媒体目录（与完整备份导出的目录相同），用 [mediaIndex] 的
/// 缓存取哈希：大小与修改时间没变的文件不再重新计算。
///
/// [SyncMediaIndex] 只认得局域网同步承认的键；个别它不认的文件名（例如含
/// 第二个托管目录名的路径）这里直接计算哈希，完整备份里有的文件增量备份
/// 也一个不少。
Future<(Map<String, IncrementalMediaRef>, Map<String, IncrementalLocalFile>)>
scanIncrementalMedia({
  required Directory dataRoot,
  required SyncMediaIndex mediaIndex,
}) async {
  final keys = <String, String>{};
  for (final name in incrementalMediaDirectories) {
    final directory = Directory(p.join(dataRoot.path, name));
    if (!await directory.exists()) continue;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final relative = p
          .relative(entity.path, from: dataRoot.path)
          .replaceAll('\\', '/');
      if (!isValidIncrementalMediaKey(relative)) {
        debugPrint('cloud backup skips unsupported media path: $relative');
        continue;
      }
      keys[relative] = entity.path;
    }
  }
  final described = await mediaIndex.describeAll(keys.keys);
  await mediaIndex.retainOnly(keys.keys.toSet());
  final media = <String, IncrementalMediaRef>{};
  final files = <String, IncrementalLocalFile>{};
  for (final MapEntry(key: key, value: path) in keys.entries) {
    final info = described[key];
    if (info != null) {
      media[key] = IncrementalMediaRef(info.sha256, info.size);
      files[key] = IncrementalLocalFile(path, info.modifiedAt);
      continue;
    }
    final file = File(path);
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file) continue;
    media[key] = IncrementalMediaRef(await syncSha256OfFile(file), stat.size);
    files[key] = IncrementalLocalFile(
      path,
      stat.modified.millisecondsSinceEpoch,
    );
  }
  return (media, files);
}
