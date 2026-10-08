import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:meta/meta.dart';

import 'backup_constants.dart';

/// 将已验证的暂存媒体换入私有目录；数据库/设置失败时按逆序恢复原目录。
/// 暂存区与目标都位于 documents，rename 不跨磁盘且不复制大视频。
class BackupMediaTransaction {
  BackupMediaTransaction({required this.documents, required this.staging})
    : renameDirectory = _moveDirectory;

  @visibleForTesting
  BackupMediaTransaction.withDirectoryMover({
    required this.documents,
    required this.staging,
    required this.renameDirectory,
  });

  final Directory documents;
  final Directory staging;
  final Future<Directory> Function(Directory, String) renameDirectory;
  final List<String> _saved = [];
  final List<String> _installed = [];

  Directory get _previous => Directory(p.join(staging.path, 'previous_media'));

  Future<void> install() async {
    await _previous.create();
    // 先确认所有目标类型，再进行换入，避免明显的目录错误造成半途替换。
    for (final name in backupMediaDirectories) {
      final type = await FileSystemEntity.type(
        p.join(documents.path, name),
        followLinks: false,
      );
      if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.directory) {
        throw FileSystemException('媒体目标不是普通目录', p.join(documents.path, name));
      }
      await Directory(p.join(staging.path, name)).create(recursive: true);
    }
    for (final name in backupMediaDirectories) {
      final target = Directory(p.join(documents.path, name));
      if (await target.exists()) {
        await renameDirectory(target, p.join(_previous.path, name));
        _saved.add(name);
      }
      await renameDirectory(Directory(p.join(staging.path, name)), target.path);
      _installed.add(name);
    }
  }

  Future<void> rollback() async {
    Object? firstError;
    StackTrace? firstStack;
    // 某一目录恢复失败仍继续恢复其他目录。失败的原文件留在暂存区，不能清理。
    for (final name in backupMediaDirectories.reversed) {
      try {
        final target = Directory(p.join(documents.path, name));
        if (_installed.contains(name) && await target.exists()) {
          await target.delete(recursive: true);
        }
        if (_saved.contains(name)) {
          await renameDirectory(
            Directory(p.join(_previous.path, name)),
            target.path,
          );
        }
      } catch (error, stack) {
        firstError ??= error;
        firstStack ??= stack;
      }
    }
    if (firstError != null) Error.throwWithStackTrace(firstError, firstStack!);
  }

  static Future<Directory> _moveDirectory(Directory source, String target) =>
      source.rename(target);
}
