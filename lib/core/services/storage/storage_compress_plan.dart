import 'dart:math' as math;

import 'storage_usage_models.dart';

/// 压缩预设与“值不值得压”的估算（纯函数，docs/rules/storage.md）。
///
/// 估算只用于界面上的“预计节省”与“可压缩”筛选，实际结果以编码器输出为准：
/// 输出没有明显变小时存储管理会丢掉它、保留原文件。

/// 图片压缩档位：最长边上限与 JPEG 画质。
enum StorageImagePreset {
  high(maxSide: 2560, quality: 85, bytesPerPixel: 0.30),
  balanced(maxSide: 1920, quality: 80, bytesPerPixel: 0.22),
  compact(maxSide: 1280, quality: 70, bytesPerPixel: 0.15);

  const StorageImagePreset({
    required this.maxSide,
    required this.quality,
    required this.bytesPerPixel,
  });

  final int maxSide;
  final int quality;

  /// 该画质下照片类内容每像素大约的 JPEG 字节数（估算用）。
  final double bytesPerPixel;

  static StorageImagePreset fromName(Object? name) =>
      values.asNameMap()[name] ?? balanced;
}

/// 视频压缩档位：短边像素与视频码率（H.264），音频固定 128 kbps AAC。
enum StorageVideoPreset {
  p1080(shortSide: 1080, videoBitrate: 5000000),
  p720(shortSide: 720, videoBitrate: 2500000),
  p480(shortSide: 480, videoBitrate: 1200000);

  const StorageVideoPreset({
    required this.shortSide,
    required this.videoBitrate,
  });

  final int shortSide;
  final int videoBitrate;

  static const int audioBitrate = 128000;

  static StorageVideoPreset fromName(Object? name) =>
      values.asNameMap()[name] ?? p720;
}

/// 小于这个大小的文件不值得压：省下的空间抵不上一次重编码的画质损失。
const int kStorageCompressMinBytes = 300 * 1024;

/// 预计输出不到原文件这个比例时才算“可压缩”。
const double kStorageCompressWorthRatio = 0.8;

/// 实际输出达到原文件这个比例就丢掉输出、保留原文件。
const double kStorageCompressKeepRatio = 0.9;

/// 图片按 [preset] 压缩后的预计字节数；不能或不值得压时为 null。
///
/// 不压：GIF 与其他动图（只会剩一帧）、带透明的图（JPEG 没有透明）、认不
/// 出格式或尺寸的图、太小的图。
int? estimateImageCompression(
  StorageMediaEntry entry,
  StorageImagePreset preset,
) {
  final image = entry.image;
  if (image == null || entry.bytes < kStorageCompressMinBytes) return null;
  if (image.animated || image.hasAlpha) return null;
  final supported = switch (image.format) {
    StorageImageFormat.jpeg ||
    StorageImageFormat.png ||
    StorageImageFormat.webp ||
    StorageImageFormat.bmp ||
    StorageImageFormat.heif => true,
    StorageImageFormat.gif || StorageImageFormat.other => false,
  };
  final width = image.width;
  final height = image.height;
  if (!supported || width == null || height == null) return null;
  final longest = math.max(width, height);
  final scale = longest > preset.maxSide ? preset.maxSide / longest : 1.0;
  final pixels = width * height * scale * scale;
  final estimate = math.min(
    entry.bytes,
    (pixels * preset.bytesPerPixel).round(),
  );
  return _worth(entry.bytes, estimate);
}

/// 视频按 [preset] 压缩后的预计字节数；不能或不值得压时为 null。
///
/// 已经不比档位清晰、码率也不高的视频不压（重编码只会更糊）。
int? estimateVideoCompression(
  StorageMediaEntry entry,
  StorageVideoInfo? info,
  StorageVideoPreset preset,
) {
  if (info == null || entry.bytes < kStorageCompressMinBytes) return null;
  if (info.durationMs <= 0 || info.width <= 0 || info.height <= 0) return null;
  final larger = info.shortSide > preset.shortSide;
  final heavier = info.bitrate > preset.videoBitrate * 1.3;
  if (!larger && !heavier) return null;
  final videoBitrate = info.bitrate > 0
      ? math.min(info.bitrate, preset.videoBitrate)
      : preset.videoBitrate;
  final bits =
      (videoBitrate + StorageVideoPreset.audioBitrate) * info.durationMs / 1000;
  return _worth(entry.bytes, math.min(entry.bytes, (bits / 8).round()));
}

int? _worth(int original, int estimate) {
  if (estimate > original * kStorageCompressWorthRatio) return null;
  if (original - estimate < 100 * 1024) return null;
  return estimate;
}

/// 输出 [output] 字节是否值得替换原来的 [original] 字节。
bool storageCompressionWorthKeeping(int original, int output) =>
    output > 0 && output < original * kStorageCompressKeepRatio;
