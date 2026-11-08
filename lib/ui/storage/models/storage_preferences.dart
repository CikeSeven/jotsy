import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/services/storage/storage_compress_plan.dart';

/// 媒体列表的排序。
enum StorageMediaSort {
  largest,
  newest,
  oldest;

  static StorageMediaSort fromName(Object? name) =>
      values.asNameMap()[name] ?? largest;
}

/// 媒体列表的显示方式（网格只在图片 / 视频 / 封面筛选下可选）。
enum StorageMediaView {
  list,
  grid;

  static StorageMediaView fromName(Object? name) =>
      values.asNameMap()[name] ?? list;
}

/// 存储管理页的本机偏好：排序、显示方式与上次用的压缩档位。
///
/// 存在单个设置键 `app.settings.storage_manager`（JSON）；逐字段容错，坏值
/// 只让那一项回到默认。本机偏好，不随备份导出、不参与同步。
@immutable
class StoragePreferences {
  const StoragePreferences({
    this.sort = StorageMediaSort.largest,
    this.view = StorageMediaView.list,
    this.imagePreset = StorageImagePreset.balanced,
    this.videoPreset = StorageVideoPreset.p720,
  });

  static const StoragePreferences defaults = StoragePreferences();

  final StorageMediaSort sort;
  final StorageMediaView view;
  final StorageImagePreset imagePreset;
  final StorageVideoPreset videoPreset;

  static StoragePreferences decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return defaults;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return defaults;
    }
    if (decoded is! Map) return defaults;
    return StoragePreferences(
      sort: StorageMediaSort.fromName(decoded['sort']),
      view: StorageMediaView.fromName(decoded['view']),
      imagePreset: StorageImagePreset.fromName(decoded['imagePreset']),
      videoPreset: StorageVideoPreset.fromName(decoded['videoPreset']),
    );
  }

  String encode() => jsonEncode(<String, Object?>{
    'sort': sort.name,
    'view': view.name,
    'imagePreset': imagePreset.name,
    'videoPreset': videoPreset.name,
  });

  StoragePreferences copyWith({
    StorageMediaSort? sort,
    StorageMediaView? view,
    StorageImagePreset? imagePreset,
    StorageVideoPreset? videoPreset,
  }) => StoragePreferences(
    sort: sort ?? this.sort,
    view: view ?? this.view,
    imagePreset: imagePreset ?? this.imagePreset,
    videoPreset: videoPreset ?? this.videoPreset,
  );

  @override
  bool operator ==(Object other) =>
      other is StoragePreferences &&
      other.sort == sort &&
      other.view == view &&
      other.imagePreset == imagePreset &&
      other.videoPreset == videoPreset;

  @override
  int get hashCode => Object.hash(sort, view, imagePreset, videoPreset);
}
