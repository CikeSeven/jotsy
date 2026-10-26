import 'package:flutter/foundation.dart';

import '../../../core/database/diary_blocks/diary_blocks_media.dart';

/// 正文中的媒体概况：前几张图片的来源与各类嵌入的数量。
///
/// 输入为任一代正文 JSON；输出供卡片的多图
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
    final images = <String>[];
    var imageCount = 0;
    var audioCount = 0;
    var videoCount = 0;
    var attachmentCount = 0;
    for (final media in diaryContentMedia(contentJson)) {
      switch (media.kind) {
        case DiaryBlockMediaKind.image:
          imageCount++;
          if (images.length < maxImages && !images.contains(media.path)) {
            images.add(media.path!);
          }
        case DiaryBlockMediaKind.audio:
          audioCount++;
        case DiaryBlockMediaKind.video:
          videoCount++;
        case DiaryBlockMediaKind.attachment:
          attachmentCount++;
      }
    }
    if (imageCount + audioCount + videoCount + attachmentCount == 0) {
      return empty;
    }
    return DiaryCardMediaSummary(
      images: List<String>.unmodifiable(images),
      imageCount: imageCount,
      audioCount: audioCount,
      videoCount: videoCount,
      attachmentCount: attachmentCount,
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
