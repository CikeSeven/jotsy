import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/file_embed_codec.dart';

enum DiaryMediaKind { image, video, attachment }

/// 日记正文图片、视频和附件存储服务。
///
/// 约束：
/// - 外部路径/文件流复制到私有目录后才允许写入正文；
/// - 每次导入使用独立子目录，保留文件名及扩展名且不覆盖同名文件；
/// - 删除操作只针对托管文件，避免误删用户外部路径；
/// - 这里的删除只用于从未交给正文的文件（导入失败/取消）。已写入正文的文件
///   可能被撤销、放弃修改或其他日记复用，统一由 DiaryMediaCleanupService
///   按引用回收。
class DiaryMediaStorageService {
  const DiaryMediaStorageService._();

  static const String imagesDirectoryName = 'diary_images';
  static const String videosDirectoryName = 'diary_videos';
  static const String attachmentsDirectoryName = 'diary_attachments';

  /// 选择器在应用缓存里生成的中转副本目录：file_picker 的
  /// `cache/file_picker/<时间戳>/`，以及 Android 相册视频入口的
  /// `cache/diary_video_gallery/selection_*/<序号>/`。
  static const List<String> pickerCacheDirectoryNames = [
    'file_picker',
    'diary_video_gallery',
  ];

  static String directoryNameFor(DiaryMediaKind kind) => switch (kind) {
    DiaryMediaKind.image => imagesDirectoryName,
    DiaryMediaKind.video => videosDirectoryName,
    DiaryMediaKind.attachment => attachmentsDirectoryName,
  };

  static Future<DiaryFileAttachment> importFile({
    required DiaryMediaKind kind,
    required String fileName,
    String? sourcePath,
    Stream<List<int>>? readStream,
    List<int>? bytes,
  }) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, directoryNameFor(kind)));
    await directory.create(recursive: true);
    final importDirectory = await directory.createTemp('media_');
    final target = File(p.join(importDirectory.path, _safeFileName(fileName)));
    try {
      final source = sourcePath == null || sourcePath.trim().isEmpty
          ? null
          : sourcePath.startsWith('file:')
          ? File.fromUri(Uri.parse(sourcePath))
          : File(sourcePath);
      if (source != null && await source.exists()) {
        await source.copy(target.path);
      } else if (readStream != null) {
        // 视频可能很大，直接写入文件流，避免把全部内容留在 Dart 内存。
        final sink = target.openWrite();
        try {
          await sink.addStream(readStream);
          await sink.flush();
        } finally {
          await sink.close();
        }
      } else if (bytes != null) {
        await target.writeAsBytes(bytes, flush: true);
      } else {
        throw FileSystemException('Selected file is unavailable', sourcePath);
      }
      return DiaryFileAttachment(
        path: target.path,
        name: fileName,
        sizeBytes: await target.length(),
      );
    } catch (_) {
      // 复制失败不能留下可被备份打包的半成品。
      await importDirectory.delete(recursive: true);
      rethrow;
    }
  }

  static String _safeFileName(String name) {
    var safe = p.posix
        .basename(name.replaceAll('\\', '/'))
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .trim();
    if (safe.isEmpty || safe == '.' || safe == '..') return 'attachment';
    // 文件系统限制按字节计算，中文长文件名也要保留可识别的扩展名。
    final extension = p.extension(safe);
    var stem = p.basenameWithoutExtension(safe);
    while (utf8.encode('$stem$extension').length > 240 && stem.isNotEmpty) {
      stem = String.fromCharCodes(stem.runes.toList()..removeLast());
    }
    safe = '$stem$extension';
    return utf8.encode(safe).length <= 240 ? safe : 'attachment';
  }

  static Future<void> deleteManagedDiaryFile(String? rawPath) async {
    var path = rawPath?.trim();
    if (path == null || path.isEmpty) return;
    final uri = Uri.tryParse(path);
    if (uri?.scheme == 'file') {
      try {
        path = File.fromUri(uri!).path;
      } catch (_) {
        return;
      }
    }
    final root = await getApplicationDocumentsDirectory();
    final normalized = p.normalize(path);
    for (final kind in DiaryMediaKind.values) {
      final mediaRoot = p.normalize(p.join(root.path, directoryNameFor(kind)));
      if (!p.isWithin(mediaRoot, normalized)) continue;
      final file = File(normalized);
      if (await file.exists()) await file.delete();
      final parent = file.parent;
      if (p.isWithin(mediaRoot, parent.path) &&
          await parent.exists() &&
          await parent.list().isEmpty) {
        await parent.delete();
      }
      return;
    }
  }

  /// 导入结束后丢弃选择器留在缓存里的副本（成功或失败都不再需要）。
  ///
  /// 只处理位于 [pickerCacheDirectoryNames] 内的路径，桌面端等直接返回原文件
  /// 路径的平台不受影响；随后逐级移除变空的批次目录，缓存根目录保留。
  /// 清理是尽力而为：失败只会多占缓存，启动后的媒体回收会按宽限期兜底。
  static Future<void> discardPickerCopy(String? rawPath) async {
    final path = rawPath?.trim();
    if (path == null || path.isEmpty) return;
    try {
      final temporary = p.normalize((await getTemporaryDirectory()).path);
      final normalized = p.normalize(path);
      for (final name in pickerCacheDirectoryNames) {
        final cacheRoot = p.join(temporary, name);
        if (!p.isWithin(cacheRoot, normalized)) continue;
        final file = File(normalized);
        if (await file.exists()) await file.delete();
        var parent = file.parent;
        while (p.isWithin(cacheRoot, parent.path) &&
            await parent.exists() &&
            await parent.list().isEmpty) {
          await parent.delete();
          parent = parent.parent;
        }
        return;
      }
    } catch (_) {
      // 见上：缓存清理失败不影响导入结果。
    }
  }
}
