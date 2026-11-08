import 'dart:io';
import 'dart:typed_data';

import '../heif_image_converter.dart';

/// 只读文件头得到图片的格式、像素尺寸与透明 / 动图标记（存储管理用）。
///
/// 为什么不用 `ImageDimensions`：它经 `dart:ui` 的 ImageDescriptor 解析，
/// 要在主 isolate 跑；存储扫描要一次看几千张图，放在后台 isolate，只能用
/// 纯 Dart 读字节。这里只认常见格式的固定字段，认不出时尺寸为 null、格式
/// 为 [StorageImageFormat.other]，绝不抛出。
///
/// JPEG 的 EXIF 方向为 5–8（转了 90°）时交换宽高，与看图时的方向一致。

enum StorageImageFormat { jpeg, png, webp, gif, heif, bmp, other }

class ImageHeaderInfo {
  const ImageHeaderInfo({
    required this.format,
    this.width,
    this.height,
    this.hasAlpha = false,
    this.animated = false,
  });

  static const ImageHeaderInfo unknown = ImageHeaderInfo(
    format: StorageImageFormat.other,
  );

  final StorageImageFormat format;
  final int? width;
  final int? height;

  /// 带透明通道（PNG 的 RGBA / 灰度透明 / tRNS、WebP 的 alpha、32 位 BMP）：
  /// 转成 JPEG 会丢透明，存储管理不压缩这类图。
  final bool hasAlpha;

  /// 动图（GIF 一律按动图、APNG、动态 WebP）：压缩会只剩一帧。
  final bool animated;

  int? get longestSide {
    final w = width;
    final h = height;
    if (w == null || h == null) return null;
    return w > h ? w : h;
  }
}

/// 读取文件头（最多 [headBytes] 字节）并解析；读不到时为 [ImageHeaderInfo.unknown]。
ImageHeaderInfo readImageHeaderInfoSync(String path, {int headBytes = 65536}) {
  try {
    final file = File(path).openSync();
    try {
      return parseImageHeader(file.readSync(headBytes));
    } finally {
      file.closeSync();
    }
  } on FileSystemException {
    return ImageHeaderInfo.unknown;
  }
}

ImageHeaderInfo parseImageHeader(Uint8List bytes) {
  try {
    if (_startsWith(bytes, const [0xFF, 0xD8])) return _jpeg(bytes);
    if (_startsWith(bytes, const [0x89, 0x50, 0x4E, 0x47])) return _png(bytes);
    if (_startsWith(bytes, const [0x47, 0x49, 0x46, 0x38])) {
      return ImageHeaderInfo(
        format: StorageImageFormat.gif,
        width: _u16le(bytes, 6),
        height: _u16le(bytes, 8),
        animated: true,
      );
    }
    if (_startsWith(bytes, const [0x52, 0x49, 0x46, 0x46]) &&
        bytes.length > 30 &&
        String.fromCharCodes(bytes, 8, 12) == 'WEBP') {
      return _webp(bytes);
    }
    if (_startsWith(bytes, const [0x42, 0x4D]) && bytes.length >= 30) {
      final height = _i32le(bytes, 22);
      return ImageHeaderInfo(
        format: StorageImageFormat.bmp,
        width: _i32le(bytes, 18).abs(),
        height: height.abs(),
        hasAlpha: _u16le(bytes, 28) == 32,
      );
    }
    if (HeifImageConverter.isHeifHeader(bytes)) {
      return const ImageHeaderInfo(format: StorageImageFormat.heif);
    }
  } on RangeError {
    // 文件头被截断：按认不出处理。
  }
  return ImageHeaderInfo.unknown;
}

ImageHeaderInfo _jpeg(Uint8List bytes) {
  var offset = 2;
  var orientation = 1;
  while (offset + 4 <= bytes.length) {
    if (bytes[offset] != 0xFF) {
      offset++;
      continue;
    }
    final marker = bytes[offset + 1];
    if (marker == 0xFF) {
      offset++;
      continue;
    }
    if (marker == 0xD9 || marker == 0xDA) break;
    final length = _u16be(bytes, offset + 2);
    if (marker == 0xE1) {
      orientation = _exifOrientation(bytes, offset + 4) ?? orientation;
    }
    final isFrame =
        marker >= 0xC0 &&
        marker <= 0xCF &&
        marker != 0xC4 &&
        marker != 0xC8 &&
        marker != 0xCC;
    if (isFrame && offset + 9 <= bytes.length) {
      final height = _u16be(bytes, offset + 5);
      final width = _u16be(bytes, offset + 7);
      final rotated = orientation >= 5 && orientation <= 8;
      return ImageHeaderInfo(
        format: StorageImageFormat.jpeg,
        width: rotated ? height : width,
        height: rotated ? width : height,
      );
    }
    offset += 2 + length;
  }
  return const ImageHeaderInfo(format: StorageImageFormat.jpeg);
}

/// APP1 段里 EXIF IFD0 的方向标签（0x0112）；不是 EXIF 或读不到时为 null。
int? _exifOrientation(Uint8List bytes, int start) {
  if (start + 14 > bytes.length ||
      String.fromCharCodes(bytes, start, start + 4) != 'Exif') {
    return null;
  }
  final tiff = start + 6;
  final little = bytes[tiff] == 0x49;
  int u16(int at) => little ? _u16le(bytes, at) : _u16be(bytes, at);
  int u32(int at) => little ? _u32le(bytes, at) : _u32be(bytes, at);
  final ifd = tiff + u32(tiff + 4);
  final count = u16(ifd);
  for (var index = 0; index < count; index++) {
    final entry = ifd + 2 + index * 12;
    if (u16(entry) == 0x0112) return u16(entry + 8);
  }
  return null;
}

ImageHeaderInfo _png(Uint8List bytes) {
  final width = _u32be(bytes, 16);
  final height = _u32be(bytes, 20);
  final colorType = bytes[25];
  var hasAlpha = colorType == 4 || colorType == 6;
  var animated = false;
  // IHDR 之后、IDAT 之前的块：tRNS 表示调色板 / 灰度透明，acTL 表示 APNG。
  var offset = 33;
  while (offset + 8 <= bytes.length) {
    final length = _u32be(bytes, offset);
    final type = String.fromCharCodes(bytes, offset + 4, offset + 8);
    if (type == 'IDAT' || type == 'IEND') break;
    if (type == 'tRNS') hasAlpha = true;
    if (type == 'acTL') animated = true;
    offset += 12 + length;
  }
  return ImageHeaderInfo(
    format: StorageImageFormat.png,
    width: width,
    height: height,
    hasAlpha: hasAlpha,
    animated: animated,
  );
}

ImageHeaderInfo _webp(Uint8List bytes) {
  final chunk = String.fromCharCodes(bytes, 12, 16);
  switch (chunk) {
    case 'VP8 ':
      return ImageHeaderInfo(
        format: StorageImageFormat.webp,
        width: _u16le(bytes, 26) & 0x3FFF,
        height: _u16le(bytes, 28) & 0x3FFF,
      );
    case 'VP8L':
      final b0 = bytes[21], b1 = bytes[22], b2 = bytes[23], b3 = bytes[24];
      return ImageHeaderInfo(
        format: StorageImageFormat.webp,
        width: 1 + (b0 | ((b1 & 0x3F) << 8)),
        height: 1 + ((b1 >> 6) | (b2 << 2) | ((b3 & 0x0F) << 10)),
        hasAlpha: (b3 >> 4) & 1 == 1,
      );
    case 'VP8X':
      final flags = bytes[20];
      return ImageHeaderInfo(
        format: StorageImageFormat.webp,
        width: 1 + _u24le(bytes, 24),
        height: 1 + _u24le(bytes, 27),
        hasAlpha: flags & 0x10 != 0,
        animated: flags & 0x02 != 0,
      );
  }
  return const ImageHeaderInfo(format: StorageImageFormat.webp);
}

bool _startsWith(Uint8List bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var index = 0; index < prefix.length; index++) {
    if (bytes[index] != prefix[index]) return false;
  }
  return true;
}

int _u16be(Uint8List b, int at) => (b[at] << 8) | b[at + 1];
int _u16le(Uint8List b, int at) => b[at] | (b[at + 1] << 8);
int _u24le(Uint8List b, int at) => b[at] | (b[at + 1] << 8) | (b[at + 2] << 16);
int _u32be(Uint8List b, int at) =>
    (b[at] << 24) | (b[at + 1] << 16) | (b[at + 2] << 8) | b[at + 3];
int _u32le(Uint8List b, int at) =>
    b[at] | (b[at + 1] << 8) | (b[at + 2] << 16) | (b[at + 3] << 24);
int _i32le(Uint8List b, int at) => _u32le(b, at).toSigned(32);
