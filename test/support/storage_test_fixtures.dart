import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/storage/media_compressor.dart';
import 'package:node_diary/core/services/storage/storage_media_service.dart';
import 'package:node_diary/core/services/storage/storage_usage_models.dart';

import 'fake_media_compressor.dart';

/// 存储管理界面测试用的假服务：扫描直接返回 [report]，删除 / 清理只记下
/// 参数（不碰数据库、文件与 isolate）。
class FakeStorageMediaService extends Fake implements StorageMediaService {
  FakeStorageMediaService(this.report, {bool supportsCompression = true})
    : compressor = FakeMediaCompressor(
        supportsCompression: supportsCompression,
      );

  StorageUsageReport report;

  @override
  final MediaCompressor compressor;

  final List<Set<String>> deleted = <Set<String>>[];
  final List<({bool cache, bool orphans, bool database})> cleanUps = [];

  /// 下一次删除 / 清理抛出的守卫拒绝。
  StorageBusyReason? busy;

  @override
  Future<StorageUsageReport> scan() async => report;

  @override
  Future<int> quickTotal() async => report.totalBytes;

  @override
  Future<String?> videoThumbnail(StorageMediaEntry entry) async => null;

  @override
  Future<StorageDeleteResult> deleteMedia(Set<String> keys) async {
    final reason = busy;
    if (reason != null) throw StorageBusyException(reason);
    deleted.add(keys);
    final freed = report.media
        .where((entry) => keys.contains(entry.key))
        .fold<int>(0, (sum, entry) => sum + entry.bytes);
    return StorageDeleteResult(
      deletedFiles: keys.length,
      freedBytes: freed,
      skippedRows: 0,
    );
  }

  @override
  Future<int> cleanUp({
    bool cache = true,
    bool orphans = true,
    bool database = true,
  }) async {
    final reason = busy;
    if (reason != null) throw StorageBusyException(reason);
    cleanUps.add((cache: cache, orphans: orphans, database: database));
    return (cache ? report.clearableCacheBytes : 0) +
        (orphans ? report.clearableOrphanBytes : 0);
  }
}

const int mb = 1024 * 1024;

/// 一篇日记引用的媒体。
StorageMediaEntry storageEntry(
  String key, {
  required int bytes,
  String title = '旅行',
  int diaryId = 1,
  DateTime? createdAt,
  StorageRefVisibility visibility = StorageRefVisibility.visible,
  bool deleted = false,
  ImageHeaderInfo? image,
  List<StorageMediaRef>? refs,
}) {
  final directory = key.split('/').first;
  final (kind, category) = switch (directory) {
    'diary_videos' => (DiaryBlockMediaKind.video, StorageCategory.videos),
    'diary_recordings' => (DiaryBlockMediaKind.audio, StorageCategory.audio),
    'diary_attachments' => (
      DiaryBlockMediaKind.attachment,
      StorageCategory.attachments,
    ),
    'diary_covers' => (DiaryBlockMediaKind.image, StorageCategory.covers),
    _ => (DiaryBlockMediaKind.image, StorageCategory.images),
  };
  return StorageMediaEntry(
    key: key,
    path: '/nonexistent/$key',
    kind: kind,
    category: category,
    bytes: bytes,
    modifiedAt: DateTime(2026, 5, 1),
    image:
        image ??
        (kind == DiaryBlockMediaKind.image
            ? const ImageHeaderInfo(
                format: StorageImageFormat.jpeg,
                width: 4032,
                height: 3024,
              )
            : null),
    refs:
        refs ??
        [
          StorageDiaryRef(
            diaryLocalId: diaryId,
            diaryId: 'diary-$diaryId',
            title: title,
            createdAt: createdAt ?? DateTime(2026, 5, 1),
            isCover: false,
            isDeleted: deleted,
            visibility: visibility,
          ),
        ],
  );
}

/// 有图片、视频、录音、私密与回收站项、缓存与未使用文件的一份报告。
StorageUsageReport sampleStorageReport({
  bool withReclaimable = true,
  StorageDeviceSpace? deviceSpace,
}) {
  final media = <StorageMediaEntry>[
    storageEntry(
      'diary_videos/m1/trip.mp4',
      bytes: 180 * mb,
      title: '海边',
      diaryId: 1,
    ),
    storageEntry(
      'diary_images/m2/sunset.jpg',
      bytes: 8 * mb,
      title: '日落',
      diaryId: 2,
      createdAt: DateTime(2026, 3, 1),
    ),
    storageEntry(
      'diary_images/m3/secret.jpg',
      bytes: 6 * mb,
      title: '私密标题',
      diaryId: 3,
      visibility: StorageRefVisibility.private,
    ),
    storageEntry(
      'diary_images/m4/old.jpg',
      bytes: 3 * mb,
      title: '旧日记',
      diaryId: 4,
      deleted: true,
    ),
    storageEntry(
      'diary_recordings/voice.m4a',
      bytes: 2 * mb,
      title: '语音',
      diaryId: 5,
    ),
  ];
  return StorageUsageReport(
    categoryBytes: {
      StorageCategory.images: 17 * mb,
      StorageCategory.videos: 180 * mb,
      StorageCategory.audio: 2 * mb,
      StorageCategory.database: 12 * mb,
      if (withReclaimable) StorageCategory.cache: 40 * mb,
      if (withReclaimable) StorageCategory.unused: 25 * mb,
    },
    media: media,
    orphanFiles: withReclaimable ? 4 : 0,
    orphanBytes: withReclaimable ? 25 * mb : 0,
    clearableOrphanFiles: withReclaimable ? 4 : 0,
    clearableOrphanBytes: withReclaimable ? 25 * mb : 0,
    cacheBytes: withReclaimable ? 40 * mb : 0,
    clearableCacheBytes: withReclaimable ? 40 * mb : 0,
    deviceSpace: deviceSpace,
    videoInfo: const {
      'diary_videos/m1/trip.mp4': StorageVideoInfo(
        width: 3840,
        height: 2160,
        durationMs: 75000,
        bitrate: 20000000,
      ),
    },
  );
}
