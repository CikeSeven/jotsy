import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/storage/storage_compress_plan.dart';
import 'package:node_diary/core/services/storage/storage_usage_models.dart';

Uint8List png({required int colorType, bool trns = false}) =>
    Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
      0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52, // IHDR
      0, 0, 0x0F, 0xA0, 0, 0, 0x0B, 0xB8, // 4000 × 3000
      8, colorType, 0, 0, 0, 0, 0, 0, 0, //
      if (trns) ...[0, 0, 0, 2, 0x74, 0x52, 0x4E, 0x53, 0, 0, 0, 0, 0, 0],
      0, 0, 0, 0, 0x49, 0x44, 0x41, 0x54, // IDAT
    ]);

/// 带 EXIF 方向 6（顺时针转 90°）的 4000 × 3000 JPEG 文件头。
final Uint8List rotatedJpeg = Uint8List.fromList([
  0xFF, 0xD8, //
  0xFF, 0xE1, 0x00, 0x22, 0x45, 0x78, 0x69, 0x66, 0, 0, // APP1 "Exif"
  0x4D, 0x4D, 0x00, 0x2A, 0, 0, 0, 8, // TIFF, big endian, IFD0 at 8
  0x00, 0x01, 0x01, 0x12, 0x00, 0x03, 0, 0, 0, 1, 0x00, 0x06, 0, 0, //
  0, 0, 0, 0, //
  0xFF, 0xC0, 0x00, 0x11, 0x08, 0x0B, 0xB8, 0x0F, 0xA0, 0x03, //
  1, 0x22, 0, 2, 0x11, 1, 3, 0x11, 1,
]);

StorageMediaEntry imageEntry(ImageHeaderInfo info, int bytes) =>
    StorageMediaEntry(
      key: 'diary_images/m/a.jpg',
      path: '/x/diary_images/m/a.jpg',
      kind: DiaryBlockMediaKind.image,
      category: StorageCategory.images,
      bytes: bytes,
      modifiedAt: DateTime(2026),
      refs: const [],
      image: info,
    );

void main() {
  group('image headers', () {
    test('reads JPEG size with EXIF rotation applied', () {
      final info = parseImageHeader(rotatedJpeg);
      expect(info.format, StorageImageFormat.jpeg);
      expect(info.width, 3000);
      expect(info.height, 4000);
    });

    test('detects PNG transparency from the color type and tRNS', () {
      expect(parseImageHeader(png(colorType: 2)).hasAlpha, isFalse);
      expect(parseImageHeader(png(colorType: 6)).hasAlpha, isTrue);
      expect(parseImageHeader(png(colorType: 3, trns: true)).hasAlpha, isTrue);
      expect(parseImageHeader(png(colorType: 2)).longestSide, 4000);
    });

    test('unknown or truncated bytes never throw', () {
      expect(parseImageHeader(Uint8List(0)).format, StorageImageFormat.other);
      expect(
        parseImageHeader(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47])).width,
        isNull,
      );
    });
  });

  group('estimates', () {
    test('large opaque photos are worth compressing', () {
      final entry = imageEntry(
        const ImageHeaderInfo(
          format: StorageImageFormat.jpeg,
          width: 4000,
          height: 3000,
        ),
        6 * 1024 * 1024,
      );
      final balanced = estimateImageCompression(
        entry,
        StorageImagePreset.balanced,
      );
      final compact = estimateImageCompression(
        entry,
        StorageImagePreset.compact,
      );
      expect(balanced, isNotNull);
      expect(compact, lessThan(balanced!));
    });

    test('animated, transparent and small images are skipped', () {
      ImageHeaderInfo info({bool alpha = false, bool animated = false}) =>
          ImageHeaderInfo(
            format: StorageImageFormat.png,
            width: 4000,
            height: 3000,
            hasAlpha: alpha,
            animated: animated,
          );
      const preset = StorageImagePreset.balanced;
      const big = 8 * 1024 * 1024;
      expect(
        estimateImageCompression(imageEntry(info(alpha: true), big), preset),
        isNull,
      );
      expect(
        estimateImageCompression(imageEntry(info(animated: true), big), preset),
        isNull,
      );
      expect(
        estimateImageCompression(imageEntry(info(), 100 * 1024), preset),
        isNull,
      );
    });

    test('videos already below the preset are skipped', () {
      final entry = StorageMediaEntry(
        key: 'diary_videos/m/v.mp4',
        path: '/x/diary_videos/m/v.mp4',
        kind: DiaryBlockMediaKind.video,
        category: StorageCategory.videos,
        bytes: 200 * 1024 * 1024,
        modifiedAt: DateTime(2026),
        refs: const [],
      );
      const fourK = StorageVideoInfo(
        width: 3840,
        height: 2160,
        durationMs: 60000,
        bitrate: 40000000,
      );
      const small = StorageVideoInfo(
        width: 854,
        height: 480,
        durationMs: 60000,
        bitrate: 1000000,
      );
      expect(
        estimateVideoCompression(entry, fourK, StorageVideoPreset.p720),
        isNotNull,
      );
      expect(
        estimateVideoCompression(entry, small, StorageVideoPreset.p720),
        isNull,
      );
      expect(storageCompressionWorthKeeping(1000, 950), isFalse);
      expect(storageCompressionWorthKeeping(1000, 500), isTrue);
    });
  });
}
