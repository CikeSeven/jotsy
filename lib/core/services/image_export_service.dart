import 'dart:async';
import 'dart:io';

import 'package:gal/gal.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 图片导出失败的语义分类。
///
/// UI 层据此映射到对应的本地化提示，避免直接暴露底层异常字符串。
enum ImageExportErrorType {
  /// 源为空或无法识别。
  invalidSource,

  /// 相册写入权限被拒绝。
  permissionDenied,

  /// 网络图片下载失败（超时 / 网络不可用 / 非 200）。
  downloadFailed,

  /// 写入相册或调用分享时发生的其他失败。
  unknown,
}

/// 图片导出领域异常。
class ImageExportException implements Exception {
  const ImageExportException({
    required this.type,
    required this.message,
    this.cause,
  });

  final ImageExportErrorType type;
  final String message;
  final Object? cause;

  @override
  String toString() => 'ImageExportException($type, $message)';
}

/// 图片保存到相册 / 分享服务。
///
/// 职责边界：
/// - 输入：一个媒体 `source`，可能是应用私有目录下的本地文件路径，也可能是 http(s) URL；
/// - 输出：把该图片保存到系统相册，或交给系统分享面板；
/// - 副作用：网络图片会先流式下载到应用临时目录（[getTemporaryDirectory]）再处理，
///   短时间重复保存/分享同一 URL 会复用仍存在的临时文件；过期缓存会被清理；
/// - 不负责：UI 提示、loading 态、权限弹窗时机（仅触发 [Gal.requestAccess]）。
///
/// 失败一律抛出 [ImageExportException]，调用方转成本地化提示，禁止静默吞错。
class ImageExportService {
  const ImageExportService();

  static const Duration _downloadTimeout = Duration(seconds: 20);
  static const Duration _remoteImageCacheTtl = Duration(minutes: 15);
  static const int _maxRemoteImageBytes = 24 * 1024 * 1024;
  static const Set<String> _allowedImageMimeTypes = <String>{
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'image/bmp',
  };

  static final Map<String, _RemoteImageCacheEntry> _remoteImageCache =
      <String, _RemoteImageCacheEntry>{};
  static final Map<String, Future<File>> _remoteImageDownloads =
      <String, Future<File>>{};

  @visibleForTesting
  static void debugClearRemoteImageCache() {
    _remoteImageCache.clear();
    _remoteImageDownloads.clear();
  }

  /// 判断 [source] 是否为网络图片（http/https）。
  static bool isRemoteSource(String source) {
    final uri = Uri.tryParse(source.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  /// 将 [source] 指向的图片保存到系统相册。
  ///
  /// 流程：
  /// 1. 校验源非空；
  /// 2. 确认/申请相册写入权限（被拒则抛 [ImageExportErrorType.permissionDenied]）；
  /// 3. 本地图片直接保存；网络图片先下载到临时文件再保存。
  Future<void> saveToGallery(String source) async {
    final normalized = source.trim();
    if (normalized.isEmpty) {
      throw const ImageExportException(
        type: ImageExportErrorType.invalidSource,
        message: 'empty image source',
      );
    }

    await _ensureGalleryAccess();

    try {
      if (isRemoteSource(normalized)) {
        final file = await _downloadToTempFile(normalized);
        await Gal.putImage(file.path);
      } else {
        await Gal.putImage(normalized);
      }
    } on ImageExportException {
      rethrow;
    } on GalException catch (error) {
      // gal 在权限相关失败时也会抛 GalException，做一次细分映射。
      final isAccessDenied = error.type == GalExceptionType.accessDenied;
      throw ImageExportException(
        type:
            isAccessDenied
                ? ImageExportErrorType.permissionDenied
                : ImageExportErrorType.unknown,
        message: 'gal putImage failed: ${error.type}',
        cause: error,
      );
    } catch (error) {
      throw ImageExportException(
        type: ImageExportErrorType.unknown,
        message: 'save to gallery failed',
        cause: error,
      );
    }
  }

  /// 将 [source] 指向的图片交给系统分享面板。
  ///
  /// 本地图片直接分享其文件；网络图片先下载到临时文件再分享。
  Future<void> shareImage(String source) async {
    final normalized = source.trim();
    if (normalized.isEmpty) {
      throw const ImageExportException(
        type: ImageExportErrorType.invalidSource,
        message: 'empty image source',
      );
    }

    try {
      final String path;
      if (isRemoteSource(normalized)) {
        final file = await _downloadToTempFile(normalized);
        path = file.path;
      } else {
        path = normalized;
      }
      await Share.shareXFiles(<XFile>[XFile(path)]);
    } on ImageExportException {
      rethrow;
    } catch (error) {
      throw ImageExportException(
        type: ImageExportErrorType.unknown,
        message: 'share image failed',
        cause: error,
      );
    }
  }

  /// 确认相册写入权限；未授权时主动申请，仍被拒则抛出权限异常。
  Future<void> _ensureGalleryAccess() async {
    try {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (hasAccess) {
        return;
      }
      final granted = await Gal.requestAccess(toAlbum: true);
      if (!granted) {
        throw const ImageExportException(
          type: ImageExportErrorType.permissionDenied,
          message: 'gallery access denied',
        );
      }
    } on ImageExportException {
      rethrow;
    } on GalException catch (error) {
      throw ImageExportException(
        type: ImageExportErrorType.permissionDenied,
        message: 'gallery access check failed: ${error.type}',
        cause: error,
      );
    }
  }

  /// 下载网络图片到应用临时目录，返回落地文件。
  ///
  /// 失败（超时 / 网络不可用 / 非 200 / 空响应 / 超出大小 / 非图片响应）统一抛
  /// [ImageExportErrorType.downloadFailed]。
  Future<File> _downloadToTempFile(String url) async {
    await _evictExpiredRemoteImageCache();

    final cached = _remoteImageCache[url];
    if (cached != null && !cached.isExpired && await cached.file.exists()) {
      return cached.file;
    }
    _remoteImageCache.remove(url);

    final pending = _remoteImageDownloads[url];
    if (pending != null) {
      return pending;
    }

    final download = _downloadRemoteImageToTempFile(url);
    _remoteImageDownloads[url] = download;
    try {
      return await download;
    } finally {
      _remoteImageDownloads.remove(url);
    }
  }

  Future<File> _downloadRemoteImageToTempFile(String url) async {
    final client = HttpClient();
    File? file;
    IOSink? sink;
    try {
      final uri = Uri.parse(url);
      final request = await client.getUrl(uri).timeout(_downloadTimeout);
      final response = await request.close().timeout(_downloadTimeout);
      if (response.statusCode != HttpStatus.ok) {
        throw ImageExportException(
          type: ImageExportErrorType.downloadFailed,
          message: 'download failed with status ${response.statusCode}',
        );
      }

      final contentLength = response.contentLength;
      if (contentLength > _maxRemoteImageBytes) {
        throw const ImageExportException(
          type: ImageExportErrorType.downloadFailed,
          message: 'downloaded image is too large',
        );
      }

      final contentType = response.headers.contentType?.mimeType.toLowerCase();
      if (!_isAllowedRemoteImageType(contentType, uri.path)) {
        throw const ImageExportException(
          type: ImageExportErrorType.downloadFailed,
          message: 'downloaded file is not a supported image',
        );
      }

      final tempDir = await getTemporaryDirectory();
      final extension = _guessExtension(uri.path, contentType: contentType);
      final fileName =
          'jotsy_image_${DateTime.now().microsecondsSinceEpoch}$extension';
      file = File(p.join(tempDir.path, fileName));
      sink = file.openWrite();

      var totalBytes = 0;
      await for (final chunk in response.timeout(_downloadTimeout)) {
        totalBytes += chunk.length;
        if (totalBytes > _maxRemoteImageBytes) {
          throw const ImageExportException(
            type: ImageExportErrorType.downloadFailed,
            message: 'downloaded image is too large',
          );
        }
        sink.add(chunk);
      }

      if (totalBytes == 0) {
        throw const ImageExportException(
          type: ImageExportErrorType.downloadFailed,
          message: 'downloaded image is empty',
        );
      }

      await sink.flush();
      await sink.close();
      sink = null;

      _remoteImageCache[url] = _RemoteImageCacheEntry(
        file: file,
        expiresAt: DateTime.now().add(_remoteImageCacheTtl),
      );
      return file;
    } on ImageExportException {
      rethrow;
    } on TimeoutException catch (error) {
      throw ImageExportException(
        type: ImageExportErrorType.downloadFailed,
        message: 'download timeout',
        cause: error,
      );
    } on SocketException catch (error) {
      throw ImageExportException(
        type: ImageExportErrorType.downloadFailed,
        message: 'network unavailable',
        cause: error,
      );
    } finally {
      client.close(force: true);
      if (sink != null) {
        await sink.close();
      }
      if (file != null && !_isCachedRemoteImageFile(file)) {
        await _deleteIfExists(file);
      }
    }
  }

  bool _isAllowedRemoteImageType(String? mimeType, String urlPath) {
    if (mimeType != null && mimeType.isNotEmpty) {
      return _allowedImageMimeTypes.contains(mimeType);
    }
    return _hasAllowedImageExtension(urlPath);
  }

  bool _isCachedRemoteImageFile(File file) {
    for (final entry in _remoteImageCache.values) {
      if (entry.file.path == file.path) {
        return true;
      }
    }
    return false;
  }

  Future<void> _evictExpiredRemoteImageCache() async {
    final expiredFiles = <File>[];
    _remoteImageCache.removeWhere((_, entry) {
      final expired = entry.isExpired;
      if (expired) {
        expiredFiles.add(entry.file);
      }
      return expired;
    });
    for (final file in expiredFiles) {
      await _deleteIfExists(file);
    }
  }

  Future<void> _deleteIfExists(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      // 临时文件清理失败不应覆盖用户正在执行的保存/分享结果。
    }
  }

  bool _hasAllowedImageExtension(String urlPath) {
    final ext = p.extension(urlPath).toLowerCase();
    const allowed = <String>{'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'};
    return allowed.contains(ext);
  }

  /// 从 URL 路径或响应 MIME 推断图片后缀，识别不到时回退为 `.jpg`。
  String _guessExtension(String urlPath, {required String? contentType}) {
    switch (contentType) {
      case 'image/jpeg':
        return '.jpg';
      case 'image/png':
        return '.png';
      case 'image/gif':
        return '.gif';
      case 'image/webp':
        return '.webp';
      case 'image/bmp':
        return '.bmp';
    }

    final ext = p.extension(urlPath).toLowerCase();
    if (_hasAllowedImageExtension(urlPath)) {
      return ext;
    }
    return '.jpg';
  }
}

class _RemoteImageCacheEntry {
  const _RemoteImageCacheEntry({required this.file, required this.expiresAt});

  final File file;
  final DateTime expiresAt;

  bool get isExpired => !DateTime.now().isBefore(expiresAt);
}
