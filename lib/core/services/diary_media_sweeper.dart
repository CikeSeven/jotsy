import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'backup_constants.dart';
import 'diary_media_references.dart';
import 'diary_media_storage_service.dart';
import 'long_image_tile_service.dart';

/// 一次回收所需的全部输入；只含可跨 isolate 发送的值。
class DiaryMediaSweepRequest {
  const DiaryMediaSweepRequest({
    required this.documentsPath,
    required this.temporaryPath,
    required this.referenceSources,
    required this.now,
    required this.gracePeriod,
  });

  final String documentsPath;
  final String temporaryPath;
  final List<String?> referenceSources;
  final DateTime now;
  final Duration gracePeriod;
}

class DiaryMediaSweepReport {
  const DiaryMediaSweepReport({
    required this.deletedFiles,
    required this.freedBytes,
  });

  final int deletedFiles;
  final int freedBytes;
}

/// 在后台 isolate 中执行：删除未被引用且超过宽限期的托管媒体、过期的
/// 选择器缓存副本，以及原图已不存在的长图分片，再移除因此变空的批次目录。
///
/// - 只遍历托管目录与选择器缓存目录，不跟随符号链接，托管根目录本身保留；
/// - 修改时间在宽限期内的文件一律保留：覆盖刚导入、尚未保存的编辑会话，
///   以及与本次回收同时进行的导入/备份恢复；
/// - 单个条目失败（并发删除、目录被恢复流程换走）只跳过，不影响其余条目。
DiaryMediaSweepReport sweepDiaryMediaFiles(DiaryMediaSweepRequest request) {
  final references = DiaryMediaReferences(request.referenceSources);
  final sweep = _Sweep(request);
  for (final name in backupMediaDirectories) {
    sweep.run(
      Directory(p.join(request.documentsPath, name)),
      isReferenced: (file) => references.contains(
        p
            .relative(file.path, from: request.documentsPath)
            .replaceAll('\\', '/'),
      ),
    );
  }
  // 选择器缓存只是导入中转，没有任何正文会引用，过了宽限期即可回收。
  for (final name in DiaryMediaStorageService.pickerCacheDirectoryNames) {
    sweep.run(
      Directory(p.join(request.temporaryPath, name)),
      isReferenced: (_) => false,
    );
  }
  sweep.runLongImageTiles(
    Directory(
      p.join(request.temporaryPath, LongImageTileService.directoryName),
    ),
  );
  return DiaryMediaSweepReport(
    deletedFiles: sweep.deletedFiles,
    freedBytes: sweep.freedBytes,
  );
}

class _Sweep {
  _Sweep(this.request);

  final DiaryMediaSweepRequest request;
  int deletedFiles = 0;
  int freedBytes = 0;

  bool _isExpired(FileStat stat) =>
      request.now.difference(stat.modified) >= request.gracePeriod;

  void run(Directory root, {required bool Function(File) isReferenced}) {
    if (!root.existsSync()) return;
    final directories = <Directory>[];
    final emptied = <String>{};
    try {
      for (final entity in root.listSync(recursive: true, followLinks: false)) {
        if (entity is Directory) {
          directories.add(entity);
        } else if (entity is File && !isReferenced(entity)) {
          _deleteFile(entity, emptied);
        }
      }
    } on FileSystemException {
      // 目录在遍历中被换走（例如备份恢复），本轮保留剩余文件。
    }
    // 由深到浅处理目录：本轮删空的批次目录立即移除；原本就空的目录
    // （中断的导入）要等过了宽限期，避免抢在导入写入文件之前删掉。
    directories.sort((a, b) => b.path.length.compareTo(a.path.length));
    for (final directory in directories) {
      try {
        if (directory.listSync().isNotEmpty) continue;
        if (!emptied.contains(directory.path) &&
            !_isExpired(directory.statSync())) {
          continue;
        }
        directory.deleteSync();
        emptied.add(directory.parent.path);
      } on FileSystemException {
        // 并发写入或已被删除，留给下一轮。
      }
    }
  }

  /// 长图分片目录：原图已不存在（日记图被回收或删除）的整目录删除；没有
  /// 清单的目录是中断的切片暂存，同样在过了宽限期后删除。分片只是显示缓存，
  /// 原图还在的目录保留（删了下次显示时也会重切）。
  void runLongImageTiles(Directory root) {
    if (!root.existsSync()) return;
    final List<FileSystemEntity> entries;
    try {
      entries = root.listSync(followLinks: false);
    } on FileSystemException {
      return;
    }
    for (final entry in entries) {
      if (entry is! Directory) continue;
      try {
        if (!_isExpired(entry.statSync())) continue;
        final source = _tileSource(entry);
        if (source != null && File(source).existsSync()) continue;
        for (final file in entry.listSync(
          recursive: true,
          followLinks: false,
        )) {
          if (file is File) {
            freedBytes += file.lengthSync();
            deletedFiles++;
          }
        }
        entry.deleteSync(recursive: true);
      } on FileSystemException {
        // 正在切片或已被系统清理，留给下一轮。
      }
    }
  }

  static String? _tileSource(Directory dir) {
    final manifest = File(p.join(dir.path, LongImageTileService.manifestName));
    if (!manifest.existsSync()) return null;
    try {
      final decoded = jsonDecode(manifest.readAsStringSync());
      final source = decoded is Map ? decoded['source'] : null;
      return source is String ? source : null;
    } on FormatException {
      return null;
    }
  }

  void _deleteFile(File file, Set<String> emptied) {
    try {
      final stat = file.statSync();
      if (!_isExpired(stat)) return;
      file.deleteSync();
      deletedFiles++;
      freedBytes += stat.size;
      emptied.add(file.parent.path);
    } on FileSystemException {
      // 文件已被并发删除或无权限，跳过。
    }
  }
}
