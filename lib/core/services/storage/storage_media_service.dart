import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../database/app_database.dart';
import '../app_data_directory.dart';
import '../data_archive_service.dart';
import '../diary_font_storage_service.dart';
import '../diary_media_cleanup_service.dart';
import '../editing_session_registry.dart';
import '../managed_file_paths.dart';
import '../settings_service.dart';
import 'media_compressor.dart';
import 'storage_cache_catalog.dart';
import 'storage_compress_plan.dart';
import 'storage_media_edit_plan.dart';
import 'storage_reference_index.dart';
import 'storage_usage_models.dart';
import 'storage_usage_scanner.dart';

/// 存储管理的编排（docs/rules/storage.md）：扫描占用、删除与压缩媒体、清理。
///
/// 删除与压缩都遵守同一条链路，任何一步都不覆盖、不预先删除被引用的文件：
/// 1. 守卫：有编辑页这类握着整份内存副本的阻塞者时拒绝（它们之后整份写回
///    会把旧路径写回来）；等撤销窗口关闭（撤销会写回旧行）；
/// 2. 压缩时先把新文件写到原文件旁的新路径（[freshSiblingPath]），可取消；
/// 3. 在 [DataArchiveService.runSerialized] 里（与备份导入、局域网同步写入、
///    网盘备份扫描串行）重新读取全部引用来源、换算改写、一次事务按前置
///    条件写入；
/// 4. 重新扫描引用，只删除已经没有任何引用的文件（读取后被别人改过、写入
///    被跳过的行仍引用的文件自然留下；压缩写入被跳过时删掉的是新文件）；
/// 5. 写入过就发出 [EditingSessionRegistry.notifyDataReplaced]，打开着的
///    预览等一次性读取的界面重新读取，不会把旧正文写回。
class StorageMediaService {
  StorageMediaService({
    required this._database,
    required this._settings,
    required this._mediaCleanup,
    MediaCompressor? compressor,
    EditingSessionRegistry? registry,
    Future<Directory> Function()? dataRoot,
    Future<Directory> Function()? temporaryDirectory,
    Future<String?> Function()? fontsPath,
    DateTime Function()? clock,
  }) : compressor = compressor ?? createPlatformMediaCompressor(),
       _registry = registry ?? EditingSessionRegistry.instance,
       _dataRoot = dataRoot ?? appDataRootDirectory,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _fontsPath = fontsPath ?? _defaultFontsPath,
       _clock = clock ?? DateTime.now;

  final AppDatabase _database;
  final Future<SettingsService> Function() _settings;
  final DiaryMediaCleanupService _mediaCleanup;
  final MediaCompressor compressor;
  final EditingSessionRegistry _registry;
  final Future<Directory> Function() _dataRoot;
  final Future<Directory> Function() _temporaryDirectory;
  final Future<String?> Function() _fontsPath;
  final DateTime Function() _clock;

  /// 视频元数据缓存，键为“定位键|字节数|修改时间”：文件不变就不再读。
  final Map<String, StorageVideoInfo> _videoInfo = {};
  final Map<String, Future<String?>> _thumbnails = {};

  /// 等撤销窗口关闭的上限；超时视为忙，提示用户稍后再试。
  static const Duration undoWindowTimeout = Duration(seconds: 8);

  static Future<String?> _defaultFontsPath() async => p.join(
    (await getApplicationSupportDirectory()).path,
    DiaryFontStorageService.directoryName,
  );

  /// 扫描当前占用（文件遍历与正文解析在后台 isolate）。
  Future<StorageUsageReport> scan() async {
    final settings = await _settings();
    final request = StorageScanRequest(
      dataRoot: (await _dataRoot()).path,
      temporaryPath: (await _temporaryDirectory()).path,
      fontsPath: await _fontsPath(),
      sources: await _database.getStorageReferenceSources(),
      now: _clock(),
      legacyDraftRaw: settings.createDiaryDraftRaw,
    );
    final report = await _scanInBackground(request);
    final stats = await _database.getStorageDatabaseStats();
    return report.copyWith(
      databaseFreeBytes: stats.freeBytes,
      deviceSpace: await compressor.deviceSpace(),
      videoInfo: await _probeVideos(report.media),
    );
  }

  /// 设置首页的“已用”：只累加文件大小，不解析日记（[quickStorageTotal]）。
  Future<int> quickTotal() async => _quickTotalInBackground(
    (await _dataRoot()).path,
    (await _temporaryDirectory()).path,
    await _fontsPath(),
  );

  static Future<int> _quickTotalInBackground(
    String dataRoot,
    String temporaryPath,
    String? fontsPath,
  ) => Isolate.run(() => quickStorageTotal(dataRoot, temporaryPath, fontsPath));

  static Future<StorageUsageReport> _scanInBackground(
    StorageScanRequest request,
  ) => Isolate.run(() => scanStorageUsage(request));

  Future<Map<String, StorageVideoInfo>> _probeVideos(
    List<StorageMediaEntry> media,
  ) async {
    if (!compressor.supportsVideoInfo) return const {};
    String cacheKey(StorageMediaEntry entry) =>
        '${entry.key}|${entry.bytes}|${entry.modifiedAt.millisecondsSinceEpoch}';
    final videos = media
        .where((entry) => entry.kind == DiaryBlockMediaKind.video)
        .toList(growable: false);
    final missing = [
      for (final entry in videos)
        if (!_videoInfo.containsKey(cacheKey(entry))) entry,
    ];
    if (missing.isNotEmpty) {
      final probed = await compressor.probeVideos([
        for (final entry in missing) entry.path,
      ]);
      for (final entry in missing) {
        final info = probed[entry.path];
        if (info != null) _videoInfo[cacheKey(entry)] = info;
      }
    }
    return {
      for (final entry in videos)
        if (_videoInfo[cacheKey(entry)] case final info?) entry.key: info,
    };
  }

  /// 视频的缩略图路径（缓存在临时目录的 [StorageCacheCatalog.videoThumbnailDirectoryName]）；
  /// 不能生成时为 null。同一文件并发请求只生成一次。
  Future<String?> videoThumbnail(StorageMediaEntry entry) {
    if (!compressor.supportsVideoInfo) return Future.value();
    final name = sha1
        .convert(
          utf8.encode(
            '${entry.key}|${entry.bytes}|'
            '${entry.modifiedAt.millisecondsSinceEpoch}',
          ),
        )
        .toString();
    return _thumbnails[name] ??= () async {
      final target = p.join(
        (await _temporaryDirectory()).path,
        StorageCacheCatalog.videoThumbnailDirectoryName,
        '$name.jpg',
      );
      if (await File(target).exists()) return target;
      final ok = await compressor.videoThumbnail(entry.path, target: target);
      if (!ok) _thumbnails.remove(name);
      return ok ? target : null;
    }();
  }

  /// 删除 [keys] 指向的文件：先从全部引用里移除，再删已无引用的文件。
  Future<StorageDeleteResult> deleteMedia(Set<String> keys) async {
    await _guard();
    return DataArchiveService.runSerialized(() async {
      final sources = await _database.getStorageReferenceSources();
      final plan = await planStorageMediaRemoval(sources, keys);
      final written = await _database.applyStorageMediaEdits(plan.edits);
      final freed = await _deleteUnreferenced(keys);
      if (written.applied > 0) _registry.notifyDataReplaced();
      return StorageDeleteResult(
        deletedFiles: freed.files,
        freedBytes: freed.bytes,
        skippedRows: written.skipped,
      );
    });
  }

  /// 压缩 [entries]：逐个写出新文件（可取消，已完成的照样提交），再一次
  /// 改写引用、删除原文件。输出没有明显变小的丢掉、保留原文件。
  Future<StorageCompressResult> compressMedia(
    List<StorageMediaEntry> entries, {
    required StorageImagePreset imagePreset,
    required StorageVideoPreset videoPreset,
    void Function(StorageCompressProgress progress)? onProgress,
    StorageCancelToken? cancel,
  }) async {
    await _guard();
    final outputs = <String, String>{};
    final outputBytes = <String, int>{};
    var unchanged = 0;
    var failed = 0;
    var cancelled = false;
    for (var index = 0; index < entries.length; index++) {
      if (cancel?.isCancelled ?? false) {
        cancelled = true;
        break;
      }
      final entry = entries[index];
      void report(double value) => onProgress?.call(
        StorageCompressProgress(
          index: index,
          total: entries.length,
          entry: entry,
          fileProgress: value,
        ),
      );
      report(0);
      final isVideo = entry.kind == DiaryBlockMediaKind.video;
      final target = freshSiblingPath(entry.path, isVideo ? 'mp4' : 'jpg');
      final ok = isVideo
          ? await compressor.compressVideo(
              entry.path,
              target,
              videoPreset,
              onProgress: report,
              cancel: cancel,
            )
          : await compressor.compressImage(entry.path, target, imagePreset);
      final size = ok ? await _lengthOf(target) : 0;
      if (!ok || !storageCompressionWorthKeeping(entry.bytes, size)) {
        await _deleteQuietly(target);
        if (cancel?.isCancelled ?? false) {
          cancelled = true;
          break;
        }
        if (ok) {
          unchanged++;
        } else {
          failed++;
        }
        continue;
      }
      outputs[entry.key] = target;
      outputBytes[entry.key] = size;
      report(1);
    }
    if (outputs.isEmpty) {
      return StorageCompressResult(
        compressed: 0,
        unchanged: unchanged,
        failed: failed,
        savedBytes: 0,
        skippedRows: 0,
        cancelled: cancelled,
      );
    }
    final root = (await _dataRoot()).path;
    return DataArchiveService.runSerialized(() async {
      final sources = await _database.getStorageReferenceSources();
      final plan = await planStorageMediaReplacement(sources, outputs);
      final written = await _database.applyStorageMediaEdits(plan.edits);
      final outputKeys = {
        for (final entry in outputs.entries)
          entry.key: p.relative(entry.value, from: root).replaceAll('\\', '/'),
      };
      // 原文件没人引用了就删；写入被跳过时新文件没人引用，删的是新文件。
      final candidates = {...outputs.keys, ...outputKeys.values};
      final referenced = await _referencedAmong(candidates);
      var compressed = 0;
      var saved = 0;
      for (final entry in entries) {
        final newKey = outputKeys[entry.key];
        if (newKey == null) continue;
        if (!referenced.contains(newKey)) {
          await _deleteQuietly(p.join(root, newKey));
          continue;
        }
        if (!referenced.contains(entry.key) &&
            await _deleteQuietly(entry.path)) {
          compressed++;
          saved += entry.bytes - outputBytes[entry.key]!;
        }
      }
      if (written.applied > 0) _registry.notifyDataReplaced();
      return StorageCompressResult(
        compressed: compressed,
        unchanged: unchanged,
        failed: failed,
        savedBytes: saved,
        skippedRows: written.skipped,
        cancelled: cancelled,
      );
    });
  }

  /// 一键清理：缓存（一小时内没动过的）、未使用的文件（[kStorageOrphanGrace]
  /// 之前写入的）与数据库空闲页。从不碰被引用的媒体。
  Future<int> cleanUp({
    bool cache = true,
    bool orphans = true,
    bool database = true,
  }) async {
    await _guard();
    return DataArchiveService.runSerialized(() async {
      var freed = 0;
      if (orphans) {
        final report = await _mediaCleanup.sweep(
          gracePeriod: kStorageOrphanGrace,
        );
        freed += report?.freedBytes ?? 0;
      }
      if (cache) {
        freed += await _clearCache(
          (await _temporaryDirectory()).path,
          _clock(),
        );
      }
      if (database) {
        final before = await _database.getStorageDatabaseStats();
        if (before.freeBytes >= StorageUsageReport.databaseCompactThreshold) {
          await _database.compactDatabase();
          final after = await _database.getStorageDatabaseStats();
          freed += before.freeBytes - after.freeBytes;
        }
      }
      return freed;
    });
  }

  static Future<int> _clearCache(String temporaryPath, DateTime now) =>
      Isolate.run(
        () => deleteIdleStorageCacheItems(
          listStorageCacheItems(temporaryPath),
          now,
        ),
      );

  /// 守卫：编辑中直接拒绝；撤销窗口等到关闭，超时同样拒绝。
  Future<void> _guard() async {
    if (_registry.isEditing) {
      throw const StorageBusyException(StorageBusyReason.editing);
    }
    if (!await _registry.waitForUndoWindows(timeout: undoWindowTimeout)) {
      throw const StorageBusyException(StorageBusyReason.undoWindow);
    }
    if (_registry.isEditing) {
      throw const StorageBusyException(StorageBusyReason.editing);
    }
  }

  /// [keys] 里仍被引用的（口径同媒体回收，见 [StorageReferenceIndex]）。
  Future<Set<String>> _referencedAmong(Set<String> keys) async {
    final sources = await _database.getStorageReferenceSources();
    final legacy = (await _settings()).createDiaryDraftRaw;
    return _referencedInBackground(sources, legacy, _clock(), keys);
  }

  /// 静态方法保证闭包只捕获参数，不会把数据库等不可发送对象带进 isolate。
  static Future<Set<String>> _referencedInBackground(
    StorageReferenceSources sources,
    String? legacyDraftRaw,
    DateTime now,
    Set<String> keys,
  ) => Isolate.run(() {
    final index = buildStorageReferenceIndex(
      sources,
      now: now,
      legacyDraftRaw: legacyDraftRaw,
    );
    return keys.where(index.isReferenced).toSet();
  });

  Future<({int files, int bytes})> _deleteUnreferenced(Set<String> keys) async {
    final referenced = await _referencedAmong(keys);
    final root = (await _dataRoot()).path;
    var files = 0;
    var bytes = 0;
    for (final key in keys) {
      if (referenced.contains(key)) continue;
      final path = p.join(root, key);
      final size = await _lengthOf(path);
      if (await _deleteQuietly(path)) {
        files++;
        bytes += size;
      }
    }
    return (files: files, bytes: bytes);
  }

  static Future<int> _lengthOf(String path) async {
    try {
      return await File(path).length();
    } on FileSystemException {
      return 0;
    }
  }

  static Future<bool> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return false;
      await file.delete();
      return true;
    } on FileSystemException catch (error) {
      debugPrint('Storage cleanup skipped $path: $error');
      return false;
    }
  }
}

/// 为什么现在不能删除 / 压缩 / 清理。
enum StorageBusyReason { editing, undoWindow }

class StorageBusyException implements Exception {
  const StorageBusyException(this.reason);

  final StorageBusyReason reason;

  @override
  String toString() => 'StorageBusyException(${reason.name})';
}

class StorageDeleteResult {
  const StorageDeleteResult({
    required this.deletedFiles,
    required this.freedBytes,
    required this.skippedRows,
  });

  final int deletedFiles;
  final int freedBytes;

  /// 读取之后被改过、这次没有改写的行（它们引用的文件保留）。
  final int skippedRows;
}

class StorageCompressProgress {
  const StorageCompressProgress({
    required this.index,
    required this.total,
    required this.entry,
    required this.fileProgress,
  });

  /// 正在处理第几个（从 0 起）。
  final int index;
  final int total;
  final StorageMediaEntry entry;

  /// 当前文件的进度（0–1；图片没有中间进度）。
  final double fileProgress;

  double get overall =>
      total == 0 ? 1 : ((index + fileProgress.clamp(0, 1)) / total).clamp(0, 1);
}

class StorageCompressResult {
  const StorageCompressResult({
    required this.compressed,
    required this.unchanged,
    required this.failed,
    required this.savedBytes,
    required this.skippedRows,
    required this.cancelled,
  });

  /// 已替换为压缩版本的文件数。
  final int compressed;

  /// 压缩后没有明显变小、保留原文件的数量。
  final int unchanged;
  final int failed;
  final int savedBytes;
  final int skippedRows;
  final bool cancelled;
}
