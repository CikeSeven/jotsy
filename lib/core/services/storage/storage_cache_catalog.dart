import 'dart:io';

import 'package:path/path.dart' as p;

import '../app_update_downloader.dart';
import '../diary_media_storage_service.dart';
import '../long_image_tile_service.dart';

/// 存储管理能清的缓存：应用临时目录下由本应用写入、删了也会按需重建的
/// 条目（docs/rules/storage.md）。
///
/// 只认清单里的名字，不整个清空临时目录：那里还有插件与引擎的缓存，录音中
/// 的暂存（`pending_recordings`）更不能动。清单里的条目一律只清“一小时内没
/// 改动过”的：选图、拍照、导出、分享、下载更新与网盘备份都会在这里写暂存，
/// 正在进行的不能被抽走；一小时足够覆盖这些操作，又不会让旧缓存一直留着。
abstract final class StorageCacheCatalog {
  /// 视频缩略图缓存（存储管理自己生成，见 `media_compressor.dart`）。
  static const String videoThumbnailDirectoryName = 'storage_video_thumbs';

  /// 整个目录都是缓存、逐个子项判断新旧的目录。
  static const List<String> directories = [
    ...DiaryMediaStorageService.pickerCacheDirectoryNames,
    LongImageTileService.directoryName,
    'diary_export',
    'diary_share',
    AppUpdateDownloader.directoryName,
    videoThumbnailDirectoryName,
  ];

  /// 直接放在临时目录下、按名字前缀认的暂存（导出的图片 / 长图 / 视频、
  /// 备份包与检查目录、网盘备份的打包与恢复目录）。
  static const List<String> prefixes = [
    'jotsy_',
    'node_note_backup_',
    'backup_export_',
    'backup_inspect_',
    'diary_export_',
    'cloud_inc_',
  ];

  /// 条目最后一次改动距今至少这么久才清。
  static const Duration idleThreshold = Duration(hours: 1);
}

/// 缓存里的一个可单独删除的条目（文件或整个子目录）。
class StorageCacheItem {
  const StorageCacheItem({
    required this.path,
    required this.bytes,
    required this.lastModified,
  });

  final String path;
  final int bytes;

  /// 条目（目录取其中最新的文件）最后一次改动的时间。
  final DateTime lastModified;

  bool isIdle(DateTime now) =>
      now.difference(lastModified) >= StorageCacheCatalog.idleThreshold;
}

/// 列出 [temporaryPath] 下清单里的缓存条目（同步，供后台 isolate 调用）。
List<StorageCacheItem> listStorageCacheItems(String temporaryPath) {
  final items = <StorageCacheItem>[];
  final root = Directory(temporaryPath);
  if (!root.existsSync()) return items;
  for (final name in StorageCacheCatalog.directories) {
    final directory = Directory(p.join(temporaryPath, name));
    if (!directory.existsSync()) continue;
    for (final child in _listQuietly(directory)) {
      final item = _describe(child);
      if (item != null) items.add(item);
    }
  }
  for (final entity in _listQuietly(root)) {
    final name = p.basename(entity.path);
    if (!StorageCacheCatalog.prefixes.any(name.startsWith)) continue;
    final item = _describe(entity);
    if (item != null) items.add(item);
  }
  return items;
}

/// 删除 [items] 里现在已闲置的条目，返回释放的字节；单个失败只跳过。
int deleteIdleStorageCacheItems(List<StorageCacheItem> items, DateTime now) {
  var freed = 0;
  for (final item in items) {
    if (!item.isIdle(now)) continue;
    try {
      final type = FileSystemEntity.typeSync(item.path, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        Directory(item.path).deleteSync(recursive: true);
      } else if (type != FileSystemEntityType.notFound) {
        File(item.path).deleteSync();
      }
      freed += item.bytes;
    } on FileSystemException {
      // 正被占用或已被系统清掉，下次再说。
    }
  }
  return freed;
}

List<FileSystemEntity> _listQuietly(Directory directory) {
  try {
    return directory.listSync(followLinks: false);
  } on FileSystemException {
    return const <FileSystemEntity>[];
  }
}

StorageCacheItem? _describe(FileSystemEntity entity) {
  try {
    if (entity is File) {
      final stat = entity.statSync();
      return StorageCacheItem(
        path: entity.path,
        bytes: stat.size,
        lastModified: stat.modified,
      );
    }
    if (entity is! Directory) return null;
    var bytes = 0;
    var latest = entity.statSync().modified;
    for (final file in entity.listSync(recursive: true, followLinks: false)) {
      if (file is! File) continue;
      final stat = file.statSync();
      bytes += stat.size;
      if (stat.modified.isAfter(latest)) latest = stat.modified;
    }
    return StorageCacheItem(
      path: entity.path,
      bytes: bytes,
      lastModified: latest,
    );
  } on FileSystemException {
    return null;
  }
}
