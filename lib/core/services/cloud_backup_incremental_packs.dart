import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import 'backup_archive_io.dart';
import 'backup_constants.dart';
import 'lan_sync/sync/sync_media_index.dart';

/// 增量备份的媒体包：把要上传的媒体按内容哈希打成 ZIP，以及把下载的包里
/// 需要的内容放进恢复暂存目录。
///
/// 为什么打包而不是一张图一个文件：坚果云免费账户每 30 分钟限 600 次请求，
/// 百度网盘上传一个文件要 5 次以上请求，几千张照片逐个上传会被限流好几个
/// 小时；打成约 32 MiB 一个的包，首次 1 GB 只需几十个文件。

/// 每个媒体包的目标大小。超过它的单个文件自己一个包。
const int incrementalPackTargetBytes = 32 * 1024 * 1024;

/// 要放进包里的一份内容（同一哈希只放一次）。
@immutable
class IncrementalPackItem {
  const IncrementalPackItem({
    required this.sha256,
    required this.path,
    required this.size,
    required this.modifiedAt,
  });

  final String sha256;

  /// 本机文件的绝对路径。
  final String path;
  final int size;

  /// 扫描时的修改时间（UTC 毫秒），打包后据此确认文件没被改动。
  final int modifiedAt;
}

/// 按 [target] 分组：依次装入，装不下就开新包；单个超大文件独占一个包。
/// 输入顺序决定分组，调用方按媒体键排序后传入，结果可复现。
List<List<IncrementalPackItem>> groupIncrementalPackItems(
  List<IncrementalPackItem> items, {
  int target = incrementalPackTargetBytes,
}) {
  final groups = <List<IncrementalPackItem>>[];
  var current = <IncrementalPackItem>[];
  var currentBytes = 0;
  for (final item in items) {
    if (current.isNotEmpty && currentBytes + item.size > target) {
      groups.add(current);
      current = <IncrementalPackItem>[];
      currentBytes = 0;
    }
    current.add(item);
    currentBytes += item.size;
  }
  if (current.isNotEmpty) groups.add(current);
  return groups;
}

/// 媒体在打包期间被改动（大小或修改时间变了）。这次备份放弃，下次重新
/// 扫描；不能把与哈希不符的内容存进以哈希命名的条目。
class IncrementalMediaChangedException implements Exception {
  const IncrementalMediaChangedException(this.path);

  final String path;

  @override
  String toString() => 'IncrementalMediaChangedException($path)';
}

/// 把 [items] 写成 [outputPath] 处的媒体包（条目名为哈希）。
Future<void> writeIncrementalPack(
  List<IncrementalPackItem> items, {
  required String outputPath,
  String? password,
}) async {
  await BackupArchiveIO.encodeEntries(
    [for (final item in items) (item.sha256, item.path)],
    outputZipPath: outputPath,
    password: password,
  );
  // 写完再核对一次：写入期间文件被改，包里的内容就与条目名的哈希对不上。
  for (final item in items) {
    final stat = await File(item.path).stat();
    if (stat.type != FileSystemEntityType.file ||
        stat.size != item.size ||
        stat.modified.millisecondsSinceEpoch != item.modifiedAt) {
      throw IncrementalMediaChangedException(item.path);
    }
  }
}

/// 从下载的包里取出 [targets]（哈希 → 要放到的媒体键）放进 [staging]。
///
/// 先解到 [scratch] 下的空目录（解包要求目标文件不存在），校验 sha256 后
/// 第一个键改名过去，其余键复制。包里缺少或内容不符的哈希返回给调用方，
/// 由它决定报错还是记为缺失。
Future<Set<String>> placeIncrementalPackContents({
  required File pack,
  required Map<String, List<String>> targets,
  required Directory staging,
  required Directory scratch,
  String? password,
}) async {
  final extractDir = await scratch.createTemp('pack_');
  final missing = <String>{};
  try {
    await BackupArchiveIO.extract(
      pack.path,
      extractDir,
      password: password,
      only: targets.keys.toSet(),
    );
    for (final MapEntry(key: hash, value: keys) in targets.entries) {
      final extracted = File(p.join(extractDir.path, hash));
      if (!await extracted.exists() ||
          await syncSha256OfFile(extracted) != hash) {
        missing.add(hash);
        continue;
      }
      for (var i = keys.length - 1; i >= 0; i--) {
        final destination = File(stagingPathOf(staging, keys[i]));
        await destination.parent.create(recursive: true);
        if (i == 0) {
          await extracted.rename(destination.path);
        } else {
          await extracted.copy(destination.path);
        }
      }
    }
  } finally {
    if (await extractDir.exists()) await extractDir.delete(recursive: true);
  }
  return missing;
}

/// 媒体键在暂存目录里的位置（布局与解开完整备份 ZIP 后一致）。键须已经
/// [isValidIncrementalMediaKey] 校验。
String stagingPathOf(Directory staging, String key) =>
    p.joinAll([staging.path, ...key.split('/')]);

/// 索引来自网盘，键可能被篡改：只认以托管目录开头、没有 `.` / `..` / 空段与
/// 反斜杠的相对路径，挡住目录穿越。
bool isValidIncrementalMediaKey(String key) {
  if (key.contains('\\') || key.contains('\u0000')) return false;
  final segments = key.split('/');
  if (segments.length < 2) return false;
  if (!incrementalMediaDirectories.contains(segments.first)) return false;
  for (final segment in segments) {
    if (segment.isEmpty || segment == '.' || segment == '..') return false;
  }
  return true;
}

/// 增量备份包含的托管目录：与完整备份相同（日记媒体 + 设置引用的背景图）。
const List<String> incrementalMediaDirectories = [
  ...backupMediaDirectories,
  ...backupSettingsMediaDirectories,
];
