import 'package:flutter/foundation.dart';

import '../../../core/services/storage/storage_usage_models.dart';

/// 媒体列表的筛选：一个类别（null 为全部媒体）加几个条件。
///
/// [unusedOnly] 换一份列表（没有任何引用的文件），与只对在用的媒体有意义的
/// [compressibleOnly]、[trashOnly] 互斥：筛选条上选中一边会取消另一边。
@immutable
class StorageMediaFilter {
  const StorageMediaFilter({
    this.category,
    this.largeOnly = false,
    this.compressibleOnly = false,
    this.trashOnly = false,
    this.unusedOnly = false,
  });

  /// 媒体页能选的类别，顺序即筛选条的顺序。
  static const List<StorageCategory> categories = [
    StorageCategory.images,
    StorageCategory.videos,
    StorageCategory.audio,
    StorageCategory.attachments,
    StorageCategory.covers,
  ];

  /// “大文件”的门槛。
  static const int largeFileBytes = 10 * 1024 * 1024;

  final StorageCategory? category;
  final bool largeOnly;
  final bool compressibleOnly;

  /// 只看仅被回收站里的日记使用的文件。
  final bool trashOnly;

  /// 只看未使用的文件（[StorageUsageReport.unused]）。
  final bool unusedOnly;

  /// 网格只对有画面的类别有意义。
  bool get supportsGrid =>
      category == StorageCategory.images ||
      category == StorageCategory.videos ||
      category == StorageCategory.covers;

  StorageMediaFilter copyWith({
    StorageCategory? Function()? category,
    bool? largeOnly,
    bool? compressibleOnly,
    bool? trashOnly,
    bool? unusedOnly,
  }) => StorageMediaFilter(
    category: category == null ? this.category : category(),
    largeOnly: largeOnly ?? this.largeOnly,
    compressibleOnly: compressibleOnly ?? this.compressibleOnly,
    trashOnly: trashOnly ?? this.trashOnly,
    unusedOnly: unusedOnly ?? this.unusedOnly,
  );

  /// 筛选条上点按“未使用”：选中时取消只对在用媒体有意义的两个条件。
  StorageMediaFilter toggleUnused() => unusedOnly
      ? copyWith(unusedOnly: false)
      : copyWith(unusedOnly: true, compressibleOnly: false, trashOnly: false);

  /// 点按“可压缩”：选中时离开未使用的文件。
  StorageMediaFilter toggleCompressible() => compressibleOnly
      ? copyWith(compressibleOnly: false)
      : copyWith(compressibleOnly: true, unusedOnly: false);

  /// 点按“仅回收站”：选中时离开未使用的文件。
  StorageMediaFilter toggleTrash() => trashOnly
      ? copyWith(trashOnly: false)
      : copyWith(trashOnly: true, unusedOnly: false);

  @override
  bool operator ==(Object other) =>
      other is StorageMediaFilter &&
      other.category == category &&
      other.largeOnly == largeOnly &&
      other.compressibleOnly == compressibleOnly &&
      other.trashOnly == trashOnly &&
      other.unusedOnly == unusedOnly;

  @override
  int get hashCode =>
      Object.hash(category, largeOnly, compressibleOnly, trashOnly, unusedOnly);
}
