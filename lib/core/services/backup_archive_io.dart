import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import 'backup_zip_reader.dart';
import 'backup_zip_writer.dart';
import 'diary_media_storage_service.dart';

/// 文件归档 IO：后台编码/流式解压，及导出时复制托管目录。
/// 不修改当前数据库或设置，不把整个 ZIP 的字节跨 isolate 传递。
class BackupArchiveIO {
  const BackupArchiveIO._();

  static Future<void> encodeDirectory(
    Directory root, {
    required String outputZipPath,
    String? password,
  }) => Isolate.run<void>(
    () => _encodeSync(
      root.path,
      outputZipPath: outputZipPath,
      password: password,
    ),
  );

  static Future<void> extract(
    String zipPath,
    Directory directory, {
    String? password,
    Set<String>? only,
    bool keepModifiedTimes = false,
  }) => Isolate.run<void>(
    () => BackupZipReader.extract(
      zipPath,
      directory.path,
      password: password,
      only: only,
      keepModifiedTimes: keepModifiedTimes,
    ),
  );

  static Future<bool> isPasswordProtected(String zipPath) =>
      Isolate.run<bool>(() => BackupZipReader.isPasswordProtected(zipPath));

  /// 按托管媒体键（如 `diary_images/media_x/a.jpg`）把文件复制到 [target] 下的
  /// 同一相对位置，日记包因此只携带被引用的媒体。键已由 `diaryMediaKeyOf`
  /// 排除 `..`；文件已不存在或不是普通文件（如符号链接）时跳过，正文里残留
  /// 的失效引用不应阻断导出。
  static Future<void> copyMediaFiles(
    Directory documents,
    Directory target,
    Iterable<String> mediaKeys,
  ) async {
    for (final key in mediaKeys) {
      final segments = key.split('/');
      final source = p.joinAll([documents.path, ...segments]);
      final type = await FileSystemEntity.type(source, followLinks: false);
      if (type != FileSystemEntityType.file) continue;
      final destination = File(p.joinAll([target.path, ...segments]));
      await destination.parent.create(recursive: true);
      await File(source).copy(destination.path);
    }
  }

  static Future<void> copyDirectory(Directory source, Directory target) async {
    if (!await target.exists()) {
      await target.create(recursive: true);
    }

    await for (final entity in source.list(
      recursive: false,
      followLinks: false,
    )) {
      final targetPath = p.join(target.path, p.basename(entity.path));
      if (entity is Directory) {
        await copyDirectory(entity, Directory(targetPath));
        continue;
      }
      if (entity is File) {
        await File(entity.path).copy(targetPath);
      }
    }
  }

  static void _encodeSync(
    String rootPath, {
    required String outputZipPath,
    String? password,
  }) {
    if (password != null) {
      BackupZipWriter.writeEncryptedDirectory(
        rootPath,
        outputZipPath,
        password,
      );
      return;
    }
    final normalizedRootPath = p.normalize(rootPath);
    final output = OutputFileStream(outputZipPath);
    final encoder = ZipEncoder()..startEncode(output);
    try {
      for (final entity in Directory(
        rootPath,
      ).listSync(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final relativePath = p
            .relative(p.normalize(entity.path), from: normalizedRootPath)
            .replaceAll('\\', '/');
        final input = InputFileStream(entity.path);
        try {
          final entry =
              ArchiveFile.stream(relativePath, entity.lengthSync(), input)
                ..lastModTime =
                    entity.lastModifiedSync().millisecondsSinceEpoch ~/ 1000;
          // 视频和常见附件多已压缩，STORE 可保持文件流，避免 Deflate 整条目
          // 缓冲。加密包走独立的流式 AES 编码，不保留整条目的加密缓存。
          if (relativePath.startsWith(
                '${DiaryMediaStorageService.videosDirectoryName}/',
              ) ||
              relativePath.startsWith(
                '${DiaryMediaStorageService.attachmentsDirectoryName}/',
              )) {
            entry.compress = false;
          }
          encoder.addFile(entry);
        } finally {
          input.closeSync();
        }
      }
      encoder.endEncode();
    } catch (_) {
      output.closeSync();
      File(outputZipPath).deleteSync();
      rethrow;
    } finally {
      output.closeSync();
    }
  }
}
