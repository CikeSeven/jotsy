import '../../../core/services/storage/storage_usage_models.dart';
import '../models/storage_media_filter.dart';
import '../models/storage_preferences.dart';
import 'storage_growth.dart';
import 'storage_media_view.dart';

/// 某个类别的文件数与字节数。
class StorageCategoryStat {
  const StorageCategoryStat({required this.count, required this.bytes});

  static const StorageCategoryStat empty = StorageCategoryStat(
    count: 0,
    bytes: 0,
  );

  final int count;
  final int bytes;

  StorageCategoryStat add(int size) =>
      StorageCategoryStat(count: count + 1, bytes: bytes + size);
}

/// 总览页的派生数据：分段、各类媒体、可释放空间的几条建议。
class StorageOverviewView {
  const StorageOverviewView({
    required this.report,
    required this.segments,
    required this.media,
    required this.large,
    required this.trash,
    required this.compressible,
    required this.compressibleSaving,
    required this.top,
    required this.growth,
  });

  /// “占用最多”列出的条数。
  static const int topCount = 5;

  final StorageUsageReport report;

  /// 有内容的类别（按 [StorageCategory] 声明顺序）与字节数，分段条与图例用。
  final List<(StorageCategory, int)> segments;

  /// 媒体页能选的类别各自的数量与大小（[StorageMediaFilter.categories]）。
  final Map<StorageCategory, StorageCategoryStat> media;

  /// 大文件（≥ [StorageMediaFilter.largeFileBytes]）。
  final StorageCategoryStat large;

  /// 只被回收站里的日记使用的文件。
  final StorageCategoryStat trash;

  /// 按当前档位可压缩的文件与预计能省下的字节。
  final StorageCategoryStat compressible;
  final int compressibleSaving;

  /// 最大的几个媒体（私密的打码，同媒体页的默认状态）。
  final List<StorageMediaItemView> top;

  /// 媒体按日记日期的新增；没有媒体时为 null。
  final StorageGrowthSeries? growth;

  int get total => report.totalBytes;

  /// 全部媒体的数量与大小。
  StorageCategoryStat get allMedia => StorageCategoryStat(
    count: report.media.length,
    bytes: report.media.fold<int>(0, (sum, entry) => sum + entry.bytes),
  );

  /// 应用占手机存储的比例（0–1）；读不到设备空间时为 null。
  double? get deviceShare {
    final space = report.deviceSpace;
    if (space == null || space.totalBytes <= 0) return null;
    return total / space.totalBytes;
  }

  static StorageOverviewView of(
    StorageUsageReport report,
    StorageCompressContext compress, {
    DateTime? now,
  }) {
    final media = <StorageCategory, StorageCategoryStat>{
      for (final category in StorageMediaFilter.categories)
        category: StorageCategoryStat.empty,
    };
    var large = StorageCategoryStat.empty;
    var trash = StorageCategoryStat.empty;
    var compressible = StorageCategoryStat.empty;
    var saving = 0;
    for (final entry in report.media) {
      media[entry.category] =
          (media[entry.category] ?? StorageCategoryStat.empty).add(entry.bytes);
      if (entry.bytes >= StorageMediaFilter.largeFileBytes) {
        large = large.add(entry.bytes);
      }
      if (entry.onlyInTrash) trash = trash.add(entry.bytes);
      final estimate = compress.estimate(entry, report);
      if (estimate != null) {
        compressible = compressible.add(entry.bytes);
        saving += entry.bytes - estimate;
      }
    }
    return StorageOverviewView(
      report: report,
      segments: [
        for (final category in StorageCategory.values)
          if (report.bytesOf(category) > 0)
            (category, report.bytesOf(category)),
      ],
      media: media,
      large: large,
      trash: trash,
      compressible: compressible,
      compressibleSaving: saving,
      top: StorageMediaListView.of(
        report,
        const StorageMediaFilter(),
        sort: StorageMediaSort.largest,
        compress: compress,
        revealPrivate: false,
      ).items.take(topCount).toList(growable: false),
      growth: StorageGrowthSeries.of(report.media, now ?? DateTime.now()),
    );
  }
}
