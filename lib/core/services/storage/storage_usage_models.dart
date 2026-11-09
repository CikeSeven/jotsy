import 'dart:math' as math;

import '../../database/diary_blocks/diary_blocks_media.dart';
import 'image_header_info.dart';

export '../../database/diary_blocks/diary_blocks_media.dart'
    show DiaryBlockMediaKind;
export 'image_header_info.dart';

/// 存储管理的数据模型（docs/rules/storage.md）。全部是只含基本类型的不可变
/// 对象：扫描在后台 isolate 里得出，整份送回主 isolate。

/// 总览分段的类别；顺序即分段条与图例的顺序。
enum StorageCategory {
  images,
  videos,
  audio,
  attachments,
  covers,
  backgrounds,
  fonts,
  database,
  cache,

  /// 应用本体（安装包与运行时生成的代码），只有系统统计读得到时才有。
  app,

  /// 托管媒体目录里没有任何引用的文件。
  unused,

  /// 数据根目录下的其他数据（同步与备份状态、导入暂存等）。
  other,
}

/// 引用来源的可见程度；按声明顺序越来越私密。一个文件取它全部引用里最
/// 公开的一档：在普通日记里出现过，就没有必要再藏。
enum StorageRefVisibility {
  visible,

  /// 只在隐藏的日记本里：揭示不必验证。
  private,

  /// 在上锁的日记本里：揭示前验证身份。
  locked,

  /// 只在未解封的时间胶囊里：不预览、不显示标题。
  capsule,
}

/// 媒体被谁引用。
sealed class StorageMediaRef {
  const StorageMediaRef();

  StorageRefVisibility get visibility;
}

/// 日记正文（[isCover] 为 false）或日记封面里的引用。
final class StorageDiaryRef extends StorageMediaRef {
  const StorageDiaryRef({
    required this.diaryLocalId,
    required this.diaryId,
    required this.title,
    required this.createdAt,
    required this.isCover,
    required this.isDeleted,
    required this.visibility,
  });

  final int diaryLocalId;
  final String diaryId;
  final String title;
  final DateTime createdAt;
  final bool isCover;

  /// 日记在回收站里。
  final bool isDeleted;

  @override
  final StorageRefVisibility visibility;
}

/// 日记本封面。
final class StorageNotebookCoverRef extends StorageMediaRef {
  const StorageNotebookCoverRef({
    required this.notebookLocalId,
    required this.notebookId,
    required this.name,
    required this.visibility,
  });

  final int notebookLocalId;
  final String notebookId;
  final String name;

  @override
  final StorageRefVisibility visibility;
}

/// 留言图片；标题、日期与可见程度取自所属日记。
final class StorageCommentRef extends StorageMediaRef {
  const StorageCommentRef({
    required this.commentLocalId,
    required this.diaryId,
    required this.diaryTitle,
    required this.diaryCreatedAt,
    required this.diaryIsDeleted,
    required this.visibility,
  });

  final int commentLocalId;
  final String diaryId;
  final String diaryTitle;
  final DateTime? diaryCreatedAt;
  final bool diaryIsDeleted;

  @override
  final StorageRefVisibility visibility;
}

/// AI 对话里用户附带的一张图片。对话不分私密，一律可见。
final class StorageAiMessageRef extends StorageMediaRef {
  const StorageAiMessageRef({
    required this.messageLocalId,
    required this.conversationId,
    required this.conversationTitle,
    required this.createdAt,
  });

  final int messageLocalId;
  final String conversationId;

  /// 所属对话的标题；空为“新对话”。
  final String conversationTitle;

  /// 消息发送的时间。
  final DateTime createdAt;

  @override
  StorageRefVisibility get visibility => StorageRefVisibility.visible;
}

/// 草稿箱里的一份草稿（正文或封面）。
final class StorageDraftRef extends StorageMediaRef {
  const StorageDraftRef({required this.draftLocalId, required this.title});

  final int draftLocalId;
  final String title;

  @override
  StorageRefVisibility get visibility => StorageRefVisibility.visible;
}

/// 认得出被提到、但不知道怎么改写的引用（如日记 metadata、旧版单份草稿）：
/// 文件算作在用、计入占用，但不能从存储管理里删除或压缩。
final class StorageOtherRef extends StorageMediaRef {
  const StorageOtherRef();

  @override
  StorageRefVisibility get visibility => StorageRefVisibility.visible;
}

/// 一个被引用着的托管媒体文件。
class StorageMediaEntry {
  const StorageMediaEntry({
    required this.key,
    required this.path,
    required this.kind,
    required this.category,
    required this.bytes,
    required this.modifiedAt,
    required this.refs,
    this.image,
  });

  /// 相对数据根目录的定位键（`diary_images/media_x/a.jpg`），见 `diaryMediaKeyOf`。
  final String key;

  /// 本机绝对路径。
  final String path;
  final DiaryBlockMediaKind kind;

  /// [StorageCategory.images] / videos / audio / attachments / covers 之一。
  final StorageCategory category;
  final int bytes;
  final DateTime modifiedAt;
  final List<StorageMediaRef> refs;

  /// 图片的文件头信息；不是图片时为 null。
  final ImageHeaderInfo? image;

  String get fileName {
    final slash = key.lastIndexOf('/');
    return slash < 0 ? key : key.substring(slash + 1);
  }

  StorageRefVisibility get visibility {
    var result = StorageRefVisibility.capsule;
    for (final ref in refs) {
      if (ref.visibility.index < result.index) result = ref.visibility;
    }
    return refs.isEmpty ? StorageRefVisibility.visible : result;
  }

  /// 每个引用都知道怎么改写时才能删除或压缩。
  bool get isEditable => refs.every((ref) => ref is! StorageOtherRef);

  /// 只被回收站里的日记（正文、封面或它的留言）引用。
  bool get onlyInTrash =>
      refs.isNotEmpty &&
      refs.every(
        (ref) => switch (ref) {
          StorageDiaryRef(:final isDeleted) => isDeleted,
          StorageCommentRef(:final diaryIsDeleted) => diaryIsDeleted,
          _ => false,
        },
      );

  /// 最早引用它的日记（或 AI 对话消息）日期（列表副标题与“从旧到新”排序
  /// 用）；都没有时取文件修改时间。
  DateTime get displayDate {
    DateTime? earliest;
    for (final ref in refs) {
      final date = switch (ref) {
        StorageDiaryRef(:final createdAt) => createdAt,
        StorageCommentRef(:final diaryCreatedAt) => diaryCreatedAt,
        StorageAiMessageRef(:final createdAt) => createdAt,
        _ => null,
      };
      if (date != null && (earliest == null || date.isBefore(earliest))) {
        earliest = date;
      }
    }
    return earliest ?? modifiedAt;
  }
}

/// 视频的元数据（Android 原生读取，见 `media_compressor.dart`）。
class StorageVideoInfo {
  const StorageVideoInfo({
    required this.width,
    required this.height,
    required this.durationMs,
    required this.bitrate,
  });

  final int width;
  final int height;
  final int durationMs;

  /// 整个文件的平均码率（bit/s）；读不到时为 0。
  final int bitrate;

  int get shortSide => math.min(width, height);

  Duration get duration => Duration(milliseconds: durationMs);
}

/// 设备存储空间（只有 Android 读得到）。
///
/// [totalBytes] / [freeBytes] 为内部存储的总量与可用（Android 8+ 取系统的
/// 存储统计，总量是标称容量，与系统设置一致）；[appCodeBytes] /
/// [appDataBytes] 为本应用的安装包与数据（含缓存），与系统“应用信息 →
/// 存储”同一口径，读不到时为 null。
class StorageDeviceSpace {
  const StorageDeviceSpace({
    required this.totalBytes,
    required this.freeBytes,
    this.appCodeBytes,
    this.appDataBytes,
  });

  final int totalBytes;
  final int freeBytes;
  final int? appCodeBytes;
  final int? appDataBytes;

  int get usedBytes => math.max(0, totalBytes - freeBytes);

  /// 系统统计里本应用的总占用（安装包 + 数据）；读不到时为 null。
  int? get appTotalBytes {
    final code = appCodeBytes;
    final data = appDataBytes;
    return code == null || data == null ? null : code + data;
  }
}

/// 存储管理清理未使用文件时保留最近这么久写入的：局域网同步在写库前先把
/// 收到的文件放进媒体目录，导入也是先拷文件后写库，这段时间里文件还没有
/// 引用。比启动回收的 24 小时短得多，用户点了清理就能马上看到效果。
const Duration kStorageOrphanGrace = Duration(minutes: 10);

/// 应用总占用：系统统计读得到时为安装包 + 数据（不少于扫描到的），否则为
/// 扫描到的 [scanned]。总览与设置首页的“已用”同一口径。
int storageAppTotal(int scanned, StorageDeviceSpace? space) {
  final code = space?.appCodeBytes;
  final data = space?.appDataBytes;
  if (code == null || data == null) return scanned;
  return code + math.max(data, scanned);
}

/// 一次扫描的结果。
class StorageUsageReport {
  const StorageUsageReport({
    required this.categoryBytes,
    required this.media,
    required this.orphanFiles,
    required this.orphanBytes,
    required this.clearableOrphanFiles,
    required this.clearableOrphanBytes,
    required this.cacheBytes,
    required this.clearableCacheBytes,
    this.databaseFreeBytes = 0,
    this.deviceSpace,
    this.videoInfo = const <String, StorageVideoInfo>{},
  });

  /// 每个类别的字节数；没有内容的类别不在表里。
  final Map<StorageCategory, int> categoryBytes;

  /// 被引用着的媒体（未被引用的只计入 [orphanFiles] / [orphanBytes]）。
  final List<StorageMediaEntry> media;

  /// 托管媒体目录里没有任何引用的文件（含 HEIC 修复留下的原图、中断的导入）。
  final int orphanFiles;
  final int orphanBytes;

  /// 其中现在就能清的（修改时间早于 [kStorageOrphanGrace]）。
  final int clearableOrphanFiles;
  final int clearableOrphanBytes;

  /// 缓存清单里的全部字节与其中现在就能清的部分（见 `storage_cache_catalog.dart`）。
  final int cacheBytes;
  final int clearableCacheBytes;

  /// 数据库里空闲页的字节，整理后可还给系统。
  final int databaseFreeBytes;
  final StorageDeviceSpace? deviceSpace;

  /// 视频元数据，键为 [StorageMediaEntry.key]（只有能读的平台有）。
  final Map<String, StorageVideoInfo> videoInfo;

  /// 数据库空闲不到这么多时不提示整理：整理要重写整个文件，收益太小。
  static const int databaseCompactThreshold = 1024 * 1024;

  int get totalBytes =>
      categoryBytes.values.fold<int>(0, (sum, bytes) => sum + bytes);

  int bytesOf(StorageCategory category) => categoryBytes[category] ?? 0;

  int get compactableDatabaseBytes =>
      databaseFreeBytes >= databaseCompactThreshold ? databaseFreeBytes : 0;

  /// 一键清理能释放的字节：缓存、未使用的文件与数据库空闲页，从不包括被
  /// 引用的媒体。
  int get reclaimableBytes =>
      clearableCacheBytes + clearableOrphanBytes + compactableDatabaseBytes;

  /// 并入系统统计（[StorageDeviceSpace.appTotalBytes] 读得到时）：安装包计入
  /// “应用本体”，系统算的数据比扫描到的多出来的部分（引擎缓存、偏好、不随
  /// 备份的同步状态等扫描不到的目录）计入“其他”。之后的总数与系统“应用
  /// 信息 → 存储”一致，即 [storageAppTotal]。
  StorageUsageReport withDeviceSpace(StorageDeviceSpace? space) {
    final code = space?.appCodeBytes;
    final data = space?.appDataBytes;
    if (code == null || data == null) return copyWith(deviceSpace: space);
    final scanned = totalBytes;
    final bytes = Map<StorageCategory, int>.of(categoryBytes)
      ..remove(StorageCategory.app);
    if (code > 0) bytes[StorageCategory.app] = code;
    final unseen = data - scanned;
    if (unseen > 0) {
      bytes[StorageCategory.other] =
          (bytes[StorageCategory.other] ?? 0) + unseen;
    }
    return copyWith(categoryBytes: bytes, deviceSpace: space);
  }

  StorageUsageReport copyWith({
    Map<StorageCategory, int>? categoryBytes,
    int? databaseFreeBytes,
    StorageDeviceSpace? deviceSpace,
    Map<String, StorageVideoInfo>? videoInfo,
  }) => StorageUsageReport(
    categoryBytes: categoryBytes ?? this.categoryBytes,
    media: media,
    orphanFiles: orphanFiles,
    orphanBytes: orphanBytes,
    clearableOrphanFiles: clearableOrphanFiles,
    clearableOrphanBytes: clearableOrphanBytes,
    cacheBytes: cacheBytes,
    clearableCacheBytes: clearableCacheBytes,
    databaseFreeBytes: databaseFreeBytes ?? this.databaseFreeBytes,
    deviceSpace: deviceSpace ?? this.deviceSpace,
    videoInfo: videoInfo ?? this.videoInfo,
  );
}
