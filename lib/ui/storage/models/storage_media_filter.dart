import 'package:flutter/foundation.dart';

import '../../../core/services/storage/storage_usage_models.dart';

/// 媒体列表的筛选：一个类别（null 为全部媒体）加三个可叠加的条件。
@immutable
class StorageMediaFilter {
  const StorageMediaFilter({
    this.category,
    this.largeOnly = false,
    this.compressibleOnly = false,
    this.trashOnly = false,
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
  }) => StorageMediaFilter(
    category: category == null ? this.category : category(),
    largeOnly: largeOnly ?? this.largeOnly,
    compressibleOnly: compressibleOnly ?? this.compressibleOnly,
    trashOnly: trashOnly ?? this.trashOnly,
  );

  @override
  bool operator ==(Object other) =>
      other is StorageMediaFilter &&
      other.category == category &&
      other.largeOnly == largeOnly &&
      other.compressibleOnly == compressibleOnly &&
      other.trashOnly == trashOnly;

  @override
  int get hashCode =>
      Object.hash(category, largeOnly, compressibleOnly, trashOnly);
}
