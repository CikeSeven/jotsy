import '../../../core/services/storage/storage_compress_plan.dart';
import '../../../core/services/storage/storage_usage_models.dart';
import '../models/storage_media_filter.dart';
import '../models/storage_preferences.dart';

/// 压缩档位与能否压缩（界面各处算“可压缩 / 预计节省”的同一组输入）。
class StorageCompressContext {
  const StorageCompressContext({
    required this.supported,
    required this.imagePreset,
    required this.videoPreset,
  });

  final bool supported;
  final StorageImagePreset imagePreset;
  final StorageVideoPreset videoPreset;

  /// [entry] 按当前档位压缩后的预计字节数；不支持、引用不可改写、不值得压
  /// 时为 null。
  int? estimate(StorageMediaEntry entry, StorageUsageReport report) {
    if (!supported || !entry.isEditable) return null;
    return switch (entry.kind) {
      DiaryBlockMediaKind.image => estimateImageCompression(entry, imagePreset),
      DiaryBlockMediaKind.video => estimateVideoCompression(
        entry,
        report.videoInfo[entry.key],
        videoPreset,
      ),
      _ => null,
    };
  }
}

/// 列表里的一项：要不要打码，以及按当前档位的压缩估算。
class StorageMediaItemView {
  const StorageMediaItemView({
    required this.entry,
    required this.masked,
    required this.estimatedBytes,
    this.video,
  });

  final StorageMediaEntry entry;

  /// 不显示预览与标题（私密日记未揭示，或未解封的时间胶囊）。
  final bool masked;

  /// 按当前档位压缩后的预计字节数；不可压缩时为 null。
  final int? estimatedBytes;
  final StorageVideoInfo? video;

  bool get compressible => estimatedBytes != null;
}

/// 媒体页的列表：按筛选与排序整理后的项与汇总。
class StorageMediaListView {
  const StorageMediaListView({
    required this.items,
    required this.totalBytes,
    required this.maskedPrivateCount,
    required this.maskedNeedsVerification,
  });

  final List<StorageMediaItemView> items;
  final int totalBytes;

  /// 因私密而打码、揭示后能看到的项数（胶囊不算：永不预览）。
  final int maskedPrivateCount;

  /// 打码的项里有在上锁日记本里的：揭示前要验证身份。
  final bool maskedNeedsVerification;

  /// 列表里最大的文件（行尾比例条的满格），与排序无关。
  int get largestBytes => items.fold<int>(
    0,
    (largest, item) => item.entry.bytes > largest ? item.entry.bytes : largest,
  );

  static StorageMediaListView of(
    StorageUsageReport report,
    StorageMediaFilter filter, {
    required StorageMediaSort sort,
    required StorageCompressContext compress,
    required bool revealPrivate,
  }) {
    final items = <StorageMediaItemView>[];
    var total = 0;
    var maskedPrivate = 0;
    var needsVerification = false;
    for (final entry in report.media) {
      if (filter.category != null && entry.category != filter.category) {
        continue;
      }
      if (filter.largeOnly && entry.bytes < StorageMediaFilter.largeFileBytes) {
        continue;
      }
      if (filter.trashOnly && !entry.onlyInTrash) continue;
      final estimate = compress.estimate(entry, report);
      if (filter.compressibleOnly && estimate == null) continue;
      final visibility = entry.visibility;
      final private =
          visibility == StorageRefVisibility.private ||
          visibility == StorageRefVisibility.locked;
      final masked =
          visibility == StorageRefVisibility.capsule ||
          (private && !revealPrivate);
      if (private && !revealPrivate) {
        maskedPrivate++;
        if (visibility == StorageRefVisibility.locked) needsVerification = true;
      }
      total += entry.bytes;
      items.add(
        StorageMediaItemView(
          entry: entry,
          masked: masked,
          estimatedBytes: estimate,
          video: report.videoInfo[entry.key],
        ),
      );
    }
    switch (sort) {
      case StorageMediaSort.largest:
        items.sort((a, b) => b.entry.bytes.compareTo(a.entry.bytes));
      case StorageMediaSort.newest:
        items.sort(
          (a, b) => b.entry.displayDate.compareTo(a.entry.displayDate),
        );
      case StorageMediaSort.oldest:
        items.sort(
          (a, b) => a.entry.displayDate.compareTo(b.entry.displayDate),
        );
    }
    return StorageMediaListView(
      items: items,
      totalBytes: total,
      maskedPrivateCount: maskedPrivate,
      maskedNeedsVerification: needsVerification,
    );
  }
}
