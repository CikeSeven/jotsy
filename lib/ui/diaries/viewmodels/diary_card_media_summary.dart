import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/database/audio_embed_codec.dart';
import '../../../core/database/file_embed_codec.dart';

/// 正文中的媒体概况：前几张图片的来源与各类嵌入的数量。
///
/// 输入为正文 JSON（Quill Delta，或旧版 AppFlowy 文档）；输出供卡片的多图
/// 拼贴与媒体角标使用。只在样式需要时由 `DiaryCardViewData.media` 惰性扫描
/// 一次并随卡片数据缓存，滚动中不重复解析。正文损坏时按“没有媒体”处理。
@immutable
class DiaryCardMediaSummary {
  const DiaryCardMediaSummary({
    this.images = const <String>[],
    this.imageCount = 0,
    this.audioCount = 0,
    this.videoCount = 0,
    this.attachmentCount = 0,
  });

  /// 拼贴最多用到的图片数。
  static const int maxImages = 4;

  static const DiaryCardMediaSummary empty = DiaryCardMediaSummary();

  /// 按出现顺序的前 [maxImages] 张图片（去重）。
  final List<String> images;
  final int imageCount;
  final int audioCount;
  final int videoCount;
  final int attachmentCount;

  bool get isEmpty =>
      imageCount == 0 &&
      audioCount == 0 &&
      videoCount == 0 &&
      attachmentCount == 0;

  static DiaryCardMediaSummary scan(String contentJson) {
    final normalized = contentJson.trim();
    if (normalized.isEmpty) {
      return empty;
    }
    Object? root;
    try {
      root = jsonDecode(normalized);
    } catch (_) {
      return empty;
    }
    final scanner = _MediaScanner()..visit(root);
    if (scanner.isEmpty) {
      return empty;
    }
    return DiaryCardMediaSummary(
      images: List<String>.unmodifiable(scanner.images),
      imageCount: scanner.imageCount,
      audioCount: scanner.audioCount,
      videoCount: scanner.videoCount,
      attachmentCount: scanner.attachmentCount,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DiaryCardMediaSummary &&
        listEquals(other.images, images) &&
        other.imageCount == imageCount &&
        other.audioCount == audioCount &&
        other.videoCount == videoCount &&
        other.attachmentCount == attachmentCount;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(images),
    imageCount,
    audioCount,
    videoCount,
    attachmentCount,
  );
}

/// 递归遍历 Delta / AppFlowy 节点并计数；与 `DiaryCardViewData` 取首图的
/// 规则一致（insert.image 与 type == image 两种写法）。
class _MediaScanner {
  final List<String> images = <String>[];
  int imageCount = 0;
  int audioCount = 0;
  int videoCount = 0;
  int attachmentCount = 0;

  bool get isEmpty =>
      imageCount == 0 &&
      audioCount == 0 &&
      videoCount == 0 &&
      attachmentCount == 0;

  void visit(Object? node) {
    if (node is List) {
      for (final item in node) {
        visit(item);
      }
      return;
    }
    if (node is! Map) {
      return;
    }
    final insert = node['insert'];
    if (insert is Map) {
      final image = insert['image'];
      if (image is String && image.trim().isNotEmpty) {
        _addImage(image.trim());
      }
      _countEmbed(insert.keys);
    }
    final type = node['type'];
    if (type is String) {
      if (type == 'image') {
        final attributes = node['attributes'];
        final url = attributes is Map ? attributes['url'] : null;
        if (url is String && url.trim().isNotEmpty) {
          _addImage(url.trim());
        }
      } else {
        _countEmbed(<Object?>[type]);
      }
    }
    for (final childKey in const <String>['root', 'children']) {
      final child = node[childKey];
      if (child != null) {
        visit(child);
      }
    }
  }

  void _addImage(String source) {
    imageCount += 1;
    if (images.length < DiaryCardMediaSummary.maxImages &&
        !images.contains(source)) {
      images.add(source);
    }
  }

  void _countEmbed(Iterable<Object?> keys) {
    for (final key in keys) {
      if (key == diaryAudioEmbedType) {
        audioCount += 1;
      } else if (key == 'video') {
        videoCount += 1;
      } else if (diaryFileEmbedTypes.contains(key)) {
        attachmentCount += 1;
      }
    }
  }
}
