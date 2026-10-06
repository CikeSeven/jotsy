import 'dart:async';
import 'dart:io';

import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum VideoExportFailure {
  missingFile,
  permissionDenied,
  notEnoughSpace,
  unsupportedFormat,
  downloadFailed,
  failed,
}

class VideoExportException implements Exception {
  const VideoExportException(this.type);
  final VideoExportFailure type;
}

/// 将正文视频保存到系统相册；本地源只读，网络视频按流下载并在导出后清理。
/// 确认弹窗由 UI 负责；本服务只在确认之后执行权限检查和相册写入。
class VideoExportService {
  const VideoExportService();
  static const _timeout = Duration(seconds: 30);

  Future<void> saveToGallery(String source) async {
    Directory? downloaded;
    try {
      final value = source.trim();
      if (value.isEmpty) {
        throw const VideoExportException(VideoExportFailure.missingFile);
      }
      final uri = Uri.tryParse(value);
      final remote =
          uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
      File? file;
      if (!remote) {
        file = uri?.scheme == 'file' ? File.fromUri(uri!) : File(value);
        if (!await file.exists() || await file.length() == 0) {
          throw const VideoExportException(VideoExportFailure.missingFile);
        }
      }
      if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
        throw const VideoExportException(VideoExportFailure.permissionDenied);
      }
      if (remote) {
        downloaded = await Directory(
          (await getTemporaryDirectory()).path,
        ).createTemp('jotsy_video_export_');
        file = await _download(uri, downloaded);
      }
      await Gal.putVideo(file!.path);
    } on VideoExportException {
      rethrow;
    } on GalException catch (error) {
      throw VideoExportException(switch (error.type) {
        GalExceptionType.accessDenied => VideoExportFailure.permissionDenied,
        GalExceptionType.notEnoughSpace => VideoExportFailure.notEnoughSpace,
        GalExceptionType.notSupportedFormat =>
          VideoExportFailure.unsupportedFormat,
        GalExceptionType.unexpected => VideoExportFailure.failed,
      });
    } catch (_) {
      throw const VideoExportException(VideoExportFailure.failed);
    } finally {
      if (downloaded != null) {
        try {
          await downloaded.delete(recursive: true);
        } on FileSystemException {
          // 缓存清理失败不能覆盖已经完成的相册保存结果。
        }
      }
    }
  }

  Future<File> _download(Uri uri, Directory directory) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    IOSink? sink;
    try {
      final response = await (await client.getUrl(uri).timeout(_timeout))
          .close()
          .timeout(_timeout);
      if (response.statusCode != HttpStatus.ok) {
        throw const VideoExportException(VideoExportFailure.downloadFailed);
      }
      final mime = response.headers.contentType?.mimeType;
      if (mime != null &&
          !mime.startsWith('video/') &&
          mime != 'application/octet-stream') {
        throw const VideoExportException(VideoExportFailure.downloadFailed);
      }
      final extension = p.extension(uri.path).toLowerCase();
      const formats = ['.mp4', '.mov', '.m4v', '.3gp', '.avi', '.webm', '.mkv'];
      final suffix = formats.contains(extension)
          ? extension
          : switch (mime) {
              'video/quicktime' => '.mov',
              'video/webm' => '.webm',
              _ => '.mp4',
            };
      final file = File(p.join(directory.path, 'video$suffix'));
      sink = file.openWrite();
      var size = 0;
      await for (final chunk in response.timeout(_timeout)) {
        size += chunk.length;
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (size == 0) {
        throw const VideoExportException(VideoExportFailure.downloadFailed);
      }
      return file;
    } on FileSystemException {
      rethrow;
    } catch (_) {
      throw const VideoExportException(VideoExportFailure.downloadFailed);
    } finally {
      client.close(force: true);
      await sink?.close();
    }
  }
}
