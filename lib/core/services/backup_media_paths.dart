import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../database/audio_embed_codec.dart';
import '../database/file_embed_codec.dart';
import 'diary_audio_storage_service.dart';
import 'diary_media_storage_service.dart';

/// 将正文、旧版文档和草稿中的托管引用映射到当前安装目录。
/// 只绑定暂存区里确实存在的文件，不能误用即将被替换的原媒体。
class BackupMediaPaths {
  BackupMediaPaths({
    required this.documentsDirectory,
    required this.stagingDirectory,
    this.targetSubdirectory,
  });

  final Directory documentsDirectory;
  final Directory stagingDirectory;

  /// 非空时引用重绑到 `<托管目录>/<targetSubdirectory>/<相对路径>`。覆盖恢复
  /// 整目录换入，相对路径保持不变；合并导入不能动本机已有文件，新文件统一
  /// 落进这个独立批次子目录，同名文件也不会互相覆盖。
  final String? targetSubdirectory;

  /// 已重绑的暂存文件 → 目标路径。合并导入据此只搬运实际写入的日记引用到
  /// 的文件；同一文件被多处引用时只记一次。
  final Map<String, String> boundFiles = <String, String>{};

  /// ZIP media files are restored into this installation's private documents
  /// directory, while their database references contain absolute paths from
  /// the exporting installation. Rebind only recognized managed-media paths
  /// whose extracted targets exist; remote URLs and external files stay intact.
  Future<String?> rewritePath(
    String? sourcePath, {
    required List<String> directoryNames,
  }) async {
    final source = sourcePath?.trim();
    if (source == null || source.isEmpty) {
      return sourcePath;
    }

    final uri = Uri.tryParse(source);
    if (uri != null &&
        uri.hasScheme &&
        uri.scheme != 'file' &&
        !RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(source)) {
      return sourcePath;
    }
    final localSource = uri?.scheme == 'file'
        ? Uri.decodeComponent(uri!.path)
        : source;

    final segments = p.posix
        .split(localSource.replaceAll('\\', '/'))
        .where((segment) => segment.isNotEmpty && segment != '.')
        .toList(growable: false);
    for (final directoryName in directoryNames) {
      final directoryIndex = segments.lastIndexOf(directoryName);
      if (directoryIndex < 0 || directoryIndex + 1 >= segments.length) {
        continue;
      }

      final relativePath = p.posix.normalize(
        p.posix.joinAll(segments.skip(directoryIndex + 1)),
      );
      if (p.posix.isAbsolute(relativePath) ||
          relativePath == '..' ||
          relativePath.startsWith('../')) {
        return sourcePath;
      }

      final candidate = p.joinAll([
        documentsDirectory.path,
        directoryName,
        ?targetSubdirectory,
        relativePath,
      ]);
      final extracted = p.join(
        stagingDirectory.path,
        directoryName,
        relativePath,
      );
      if (await File(extracted).exists()) {
        boundFiles[extracted] = candidate;
        return candidate;
      }
    }
    return sourcePath;
  }

  Future<String> rewriteContent(String content) async {
    Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException {
      return content;
    }

    await _rewriteNode(decoded);
    return jsonEncode(decoded);
  }

  /// 恢复 Quill 及旧版 AppFlowy 的媒体引用，保留文件 metadata 和远程 URL。
  Future<void> _rewriteNode(Object? node) async {
    if (node is List) {
      for (final child in node) {
        await _rewriteNode(child);
      }
      return;
    }
    if (node is! Map) {
      return;
    }

    final insert = node['insert'];
    if (insert is Map && insert['image'] is String) {
      insert['image'] = await rewritePath(
        insert['image'] as String,
        directoryNames: const <String>['diary_images'],
      );
    }
    if (insert is Map) {
      final audio = DiaryAudioAttachment.tryDecode(insert[diaryAudioEmbedType]);
      if (audio != null) {
        final restoredPath = await rewritePath(
          audio.path,
          directoryNames: const [DiaryAudioStorageService.directoryName],
        );
        insert[diaryAudioEmbedType] = audio
            .copyWith(path: restoredPath ?? audio.path)
            .encode();
      }
      for (final type in ['video', ...diaryFileEmbedTypes]) {
        final file = DiaryFileAttachment.tryDecode(insert[type]);
        if (file == null) continue;
        final path = await rewritePath(
          file.path,
          directoryNames: const [
            DiaryMediaStorageService.videosDirectoryName,
            DiaryMediaStorageService.attachmentsDirectoryName,
          ],
        );
        if (path != file.path) {
          insert[type] = replaceDiaryFilePath(insert[type], path!);
        }
      }
    }

    if (node['type'] == 'image') {
      final attributes = node['attributes'];
      if (attributes is Map && attributes['url'] is String) {
        attributes['url'] = await rewritePath(
          attributes['url'] as String,
          directoryNames: const <String>['diary_images'],
        );
      }
    }
    if (node['type'] == 'video' || diaryFileEmbedTypes.contains(node['type'])) {
      final file = DiaryFileAttachment.tryDecode(node['attributes']);
      if (file != null) {
        final path = await rewritePath(
          file.path,
          directoryNames: const [
            DiaryMediaStorageService.videosDirectoryName,
            DiaryMediaStorageService.attachmentsDirectoryName,
          ],
        );
        if (path != file.path) {
          node['attributes'] = replaceDiaryFilePath(node['attributes'], path!);
        }
      }
    }

    for (final child in node.values.toList(growable: false)) {
      await _rewriteNode(child);
    }
  }
}
