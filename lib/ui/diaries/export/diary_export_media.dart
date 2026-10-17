import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../../core/services/image_export_service.dart';

/// 一个已找到的媒体：本地文件或内存字节（data URI 解码所得）。
@immutable
class DiaryExportMediaFile {
  const DiaryExportMediaFile._({
    required this.source,
    required this.extension,
    this.file,
    this.bytes,
  });

  final String source;

  /// 带点的小写扩展名，如 `.jpg`。
  final String extension;
  final File? file;
  final Uint8List? bytes;

  Future<Uint8List> readBytes() async => bytes ?? await file!.readAsBytes();
}

/// 导出用到的媒体：按来源解析一次并缓存，写出器只按来源取用。
///
/// 来源有三种：本地路径（应用私有目录或旧版导入留下的绝对路径）、http(s)
/// 地址（只下载图片，经 [ImageExportService] 复用缓存与大小限制）、data
/// URI。找不到的来源返回 null，由写出器跳过或写成名称，单个缺失不让整次
/// 导出失败。
class DiaryExportMediaLibrary {
  DiaryExportMediaLibrary({this._imageService = const ImageExportService()});

  final ImageExportService _imageService;
  final Map<String, Future<DiaryExportMediaFile?>> _cache =
      <String, Future<DiaryExportMediaFile?>>{};

  /// 解析 [source]；[allowDownload] 为 false 时不下载网络地址（录音、
  /// 视频、附件的远程地址只写成链接，不搬进导出包）。
  Future<DiaryExportMediaFile?> resolve(
    String source, {
    bool allowDownload = true,
  }) {
    final key = '$allowDownload|$source';
    return _cache[key] ??= _resolve(source.trim(), allowDownload);
  }

  /// 只读文件开头（默认 512KB），用于识别图片格式与尺寸而不读整张图；
  /// 读不到时返回 null。
  Future<Uint8List?> headOf(String source, {int length = 512 * 1024}) async {
    final media = await resolve(source);
    if (media == null) {
      return null;
    }
    final bytes = media.bytes;
    if (bytes != null) {
      return bytes.length <= length
          ? bytes
          : Uint8List.sublistView(bytes, 0, length);
    }
    RandomAccessFile? handle;
    try {
      handle = await media.file!.open();
      return await handle.read(length);
    } on FileSystemException {
      return null;
    } finally {
      await handle?.close();
    }
  }

  /// 图片格式与尺寸：先读文件头，头部不够（EXIF / ICC 段很大的 JPEG）
  /// 再读整个文件。无法识别时为 null。
  Future<ExportImageInfo?> imageInfoOf(String source) async {
    final head = await headOf(source);
    if (head == null) {
      return null;
    }
    return ExportImageInfo.read(head) ??
        switch (await bytesOf(source)) {
          final Uint8List bytes when bytes.length > head.length =>
            ExportImageInfo.read(bytes),
          _ => null,
        };
  }

  Future<Uint8List?> bytesOf(String source) async {
    final media = await resolve(source);
    if (media == null) {
      return null;
    }
    try {
      return await media.readBytes();
    } on FileSystemException {
      return null;
    }
  }

  Future<DiaryExportMediaFile?> _resolve(
    String source,
    bool allowDownload,
  ) async {
    if (source.isEmpty) {
      return null;
    }
    if (source.startsWith('data:')) {
      return _decodeDataUri(source);
    }
    if (ImageExportService.isRemoteSource(source)) {
      if (!allowDownload) {
        return null;
      }
      try {
        final file = await _imageService.downloadRemoteImage(source);
        return DiaryExportMediaFile._(
          source: source,
          extension: _extensionOf(file.path),
          file: file,
        );
      } on ImageExportException {
        return null;
      }
    }
    final file = source.startsWith('file:')
        ? File.fromUri(Uri.parse(source))
        : File(source);
    if (!await file.exists()) {
      return null;
    }
    return DiaryExportMediaFile._(
      source: source,
      extension: _extensionOf(file.path),
      file: file,
    );
  }

  static DiaryExportMediaFile? _decodeDataUri(String source) {
    const marker = ';base64,';
    final separator = source.indexOf(marker);
    if (separator < 0) {
      return null;
    }
    final mimeType = source.substring(5, separator).toLowerCase();
    try {
      return DiaryExportMediaFile._(
        source: source,
        extension: switch (mimeType) {
          'image/png' => '.png',
          'image/gif' => '.gif',
          'image/webp' => '.webp',
          'image/bmp' => '.bmp',
          _ => '.jpg',
        },
        bytes: base64Decode(source.substring(separator + marker.length)),
      );
    } on FormatException {
      return null;
    }
  }

  static String _extensionOf(String path) {
    final extension = p.extension(path).toLowerCase();
    return extension.isEmpty ? '.bin' : extension;
  }
}

/// 图片像素尺寸与格式；只读文件头，不解码像素。
@immutable
class ExportImageInfo {
  const ExportImageInfo(this.width, this.height, this.mimeType);

  final int width;
  final int height;
  final String mimeType;

  String get extension => switch (mimeType) {
    'image/png' => '.png',
    'image/gif' => '.gif',
    'image/bmp' => '.bmp',
    'image/webp' => '.webp',
    _ => '.jpg',
  };

  /// 从 PNG / JPEG / GIF / BMP / WebP 文件头读取尺寸；其他格式（如 HEIC）
  /// 返回 null，写出器按“无法内嵌”处理。
  static ExportImageInfo? read(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    bool startsWith(List<int> magic) =>
        bytes.length >= magic.length &&
        Iterable<int>.generate(
          magic.length,
        ).every((int i) => bytes[i] == magic[i]);

    if (startsWith(const <int>[0x89, 0x50, 0x4E, 0x47]) && bytes.length > 24) {
      return ExportImageInfo(
        data.getUint32(16),
        data.getUint32(20),
        'image/png',
      );
    }
    if (startsWith(const <int>[0x47, 0x49, 0x46]) && bytes.length > 10) {
      return ExportImageInfo(
        data.getUint16(6, Endian.little),
        data.getUint16(8, Endian.little),
        'image/gif',
      );
    }
    if (startsWith(const <int>[0x42, 0x4D]) && bytes.length > 26) {
      return ExportImageInfo(
        data.getInt32(18, Endian.little).abs(),
        data.getInt32(22, Endian.little).abs(),
        'image/bmp',
      );
    }
    if (startsWith(const <int>[0xFF, 0xD8])) {
      return _readJpeg(bytes, data);
    }
    if (startsWith(const <int>[0x52, 0x49, 0x46, 0x46]) &&
        bytes.length > 30 &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return _readWebp(bytes, data);
    }
    return null;
  }

  /// 依次跳过 JPEG 段，直到 SOF 段（0xC0~0xCF，除去 DHT/JPG/DAC）。
  ///
  /// 手机竖拍的照片常以横向像素 + EXIF 方向（5~8 为旋转 90°）保存，Word、
  /// 浏览器按方向显示；这里返回显示时的宽高，否则竖图会被压扁成横图。
  static ExportImageInfo? _readJpeg(Uint8List bytes, ByteData data) {
    var offset = 2;
    var rotated = false;
    while (offset + 9 < bytes.length) {
      if (bytes[offset] != 0xFF) {
        return null;
      }
      final marker = bytes[offset + 1];
      if (marker == 0xFF) {
        offset++;
        continue;
      }
      final length = data.getUint16(offset + 2);
      if (marker == 0xE1) {
        rotated = _exifRotated(bytes, data, offset + 4, length - 2) || rotated;
      }
      final isFrame =
          marker >= 0xC0 &&
          marker <= 0xCF &&
          marker != 0xC4 &&
          marker != 0xC8 &&
          marker != 0xCC;
      if (isFrame) {
        final width = data.getUint16(offset + 7);
        final height = data.getUint16(offset + 5);
        return rotated
            ? ExportImageInfo(height, width, 'image/jpeg')
            : ExportImageInfo(width, height, 'image/jpeg');
      }
      offset += 2 + length;
    }
    return null;
  }

  /// APP1 段里的 EXIF 方向是否为 5~8（转置或旋转 90°/270°）。
  static bool _exifRotated(
    Uint8List bytes,
    ByteData data,
    int start,
    int length,
  ) {
    final end = start + length;
    if (length < 14 ||
        end > bytes.length ||
        String.fromCharCodes(bytes.sublist(start, start + 4)) != 'Exif') {
      return false;
    }
    final tiff = start + 6;
    final endian = bytes[tiff] == 0x49 ? Endian.little : Endian.big;
    final ifd = tiff + data.getUint32(tiff + 4, endian);
    if (ifd + 2 > end) {
      return false;
    }
    final count = data.getUint16(ifd, endian);
    for (var i = 0; i < count; i++) {
      final entry = ifd + 2 + i * 12;
      if (entry + 12 > end) {
        return false;
      }
      if (data.getUint16(entry, endian) == 0x0112) {
        final orientation = data.getUint16(entry + 8, endian);
        return orientation >= 5 && orientation <= 8;
      }
    }
    return false;
  }

  static ExportImageInfo? _readWebp(Uint8List bytes, ByteData data) {
    final chunk = String.fromCharCodes(bytes.sublist(12, 16));
    switch (chunk) {
      case 'VP8 ':
        return ExportImageInfo(
          data.getUint16(26, Endian.little) & 0x3FFF,
          data.getUint16(28, Endian.little) & 0x3FFF,
          'image/webp',
        );
      case 'VP8L':
        final b = data.getUint32(21, Endian.little);
        return ExportImageInfo(
          (b & 0x3FFF) + 1,
          ((b >> 14) & 0x3FFF) + 1,
          'image/webp',
        );
      case 'VP8X':
        int read24(int offset) =>
            bytes[offset] |
            (bytes[offset + 1] << 8) |
            (bytes[offset + 2] << 16);
        return ExportImageInfo(read24(24) + 1, read24(27) + 1, 'image/webp');
    }
    return null;
  }
}
