import 'dart:io';

import 'package:path/path.dart' as p;

import '../../database/app_database.dart';
import '../app_background_storage_service.dart';
import '../backup_constants.dart';
import '../diary_audio_storage_service.dart';
import '../diary_media_storage_service.dart';
import 'storage_cache_catalog.dart';
import 'storage_reference_index.dart';
import 'storage_usage_models.dart';

/// 一次占用扫描的输入：只含路径、时间与数据库读出的纯数据，可送进 isolate。
class StorageScanRequest {
  const StorageScanRequest({
    required this.dataRoot,
    required this.temporaryPath,
    required this.fontsPath,
    required this.sources,
    required this.now,
    this.legacyDraftRaw,
  });

  final String dataRoot;
  final String temporaryPath;

  /// 导入字体的目录（手机在应用支持目录，桌面恰好在数据根目录下）。
  final String? fontsPath;
  final StorageReferenceSources sources;
  final DateTime now;
  final String? legacyDraftRaw;
}

/// 扫描占用（同步、只读，在后台 isolate 里执行）。
///
/// - 托管媒体目录逐个文件按引用索引归类：被引用的进 [StorageUsageReport.media]，
///   没有引用的计入“未使用”（口径与媒体回收相同，见 [StorageReferenceIndex]）；
/// - 背景图、字体、数据库文件（含日志）各自求和；
/// - 缓存只算清单里的条目（[StorageCacheCatalog]）；
/// - 数据根目录下其余的一切（同步状态、备份状态、导入暂存）计入“其他”，
///   让总数接近系统设置里看到的应用数据大小。
///
/// 不跟随符号链接；读不到的文件只跳过，不让整次扫描失败。
StorageUsageReport scanStorageUsage(StorageScanRequest request) {
  final index = buildStorageReferenceIndex(
    request.sources,
    now: request.now,
    legacyDraftRaw: request.legacyDraftRaw,
  );
  final root = p.normalize(request.dataRoot);
  final bytes = <StorageCategory, int>{};
  void count(StorageCategory category, int size) {
    if (size > 0) bytes[category] = (bytes[category] ?? 0) + size;
  }

  final media = <StorageMediaEntry>[];
  var orphanFiles = 0;
  var clearableOrphanFiles = 0;
  var clearableOrphanBytes = 0;
  for (final directoryName in backupMediaDirectories) {
    final (kind, category) = _classify(directoryName);
    for (final (file, stat) in _files(Directory(p.join(root, directoryName)))) {
      final key = p.relative(file.path, from: root).replaceAll('\\', '/');
      if (!index.isReferenced(key)) {
        orphanFiles++;
        count(StorageCategory.unused, stat.size);
        if (request.now.difference(stat.modified) >= kStorageOrphanGrace) {
          clearableOrphanFiles++;
          clearableOrphanBytes += stat.size;
        }
        continue;
      }
      count(category, stat.size);
      media.add(
        StorageMediaEntry(
          key: key,
          path: file.path,
          kind: kind,
          category: category,
          bytes: stat.size,
          modifiedAt: stat.modified,
          refs: index.refsOf(key),
          image: kind == DiaryBlockMediaKind.image
              ? readImageHeaderInfoSync(file.path)
              : null,
        ),
      );
    }
  }

  final backgrounds = p.join(root, AppBackgroundStorageService.directoryName);
  count(StorageCategory.backgrounds, _directoryBytes(backgrounds));
  final fontsPath = request.fontsPath == null
      ? null
      : p.normalize(request.fontsPath!);
  if (fontsPath != null) {
    count(StorageCategory.fonts, _directoryBytes(fontsPath));
  }
  final databaseFiles = <String>{
    for (final suffix in const ['', '-journal', '-wal', '-shm'])
      p.join(root, '$appDatabaseFileName$suffix'),
  };
  for (final path in databaseFiles) {
    count(StorageCategory.database, _fileBytes(path));
  }

  final cacheItems = listStorageCacheItems(request.temporaryPath);
  var cacheBytes = 0;
  var clearable = 0;
  for (final item in cacheItems) {
    cacheBytes += item.bytes;
    if (item.isIdle(request.now)) clearable += item.bytes;
  }
  count(StorageCategory.cache, cacheBytes);

  final known = <String>{
    for (final name in backupMediaDirectories) p.join(root, name),
    backgrounds,
    ?fontsPath,
    ...databaseFiles,
  };
  for (final entity in _list(Directory(root))) {
    final path = p.normalize(entity.path);
    if (known.contains(path)) continue;
    count(
      StorageCategory.other,
      entity is Directory ? _directoryBytes(path) : _fileBytes(path),
    );
  }

  media.sort((a, b) => b.bytes.compareTo(a.bytes));
  return StorageUsageReport(
    categoryBytes: bytes,
    media: media,
    orphanFiles: orphanFiles,
    orphanBytes: bytes[StorageCategory.unused] ?? 0,
    clearableOrphanFiles: clearableOrphanFiles,
    clearableOrphanBytes: clearableOrphanBytes,
    cacheBytes: cacheBytes,
    clearableCacheBytes: clearable,
  );
}

(DiaryBlockMediaKind, StorageCategory) _classify(String directoryName) =>
    switch (directoryName) {
      DiaryMediaStorageService.imagesDirectoryName => (
        DiaryBlockMediaKind.image,
        StorageCategory.images,
      ),
      DiaryMediaStorageService.videosDirectoryName => (
        DiaryBlockMediaKind.video,
        StorageCategory.videos,
      ),
      DiaryAudioStorageService.directoryName => (
        DiaryBlockMediaKind.audio,
        StorageCategory.audio,
      ),
      DiaryMediaStorageService.attachmentsDirectoryName => (
        DiaryBlockMediaKind.attachment,
        StorageCategory.attachments,
      ),
      // 日记与日记本封面目录（`diary_covers`）。
      _ => (DiaryBlockMediaKind.image, StorageCategory.covers),
    };

Iterable<(File, FileStat)> _files(Directory directory) sync* {
  if (!directory.existsSync()) return;
  final List<FileSystemEntity> entities;
  try {
    entities = directory.listSync(recursive: true, followLinks: false);
  } on FileSystemException {
    return;
  }
  for (final entity in entities) {
    if (entity is! File) continue;
    try {
      yield (entity, entity.statSync());
    } on FileSystemException {
      // 并发删除：跳过。
    }
  }
}

List<FileSystemEntity> _list(Directory directory) {
  try {
    return directory.listSync(followLinks: false);
  } on FileSystemException {
    return const <FileSystemEntity>[];
  }
}

int _directoryBytes(String path) {
  var total = 0;
  for (final (_, stat) in _files(Directory(path))) {
    total += stat.size;
  }
  return total;
}

int _fileBytes(String path) {
  try {
    final stat = File(path).statSync();
    return stat.type == FileSystemEntityType.file ? stat.size : 0;
  } on FileSystemException {
    return 0;
  }
}
