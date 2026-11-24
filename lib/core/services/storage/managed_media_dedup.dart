import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../app_data_directory.dart';
import '../diary_media_cleanup_service.dart';
import '../diary_media_references.dart';
import '../lan_sync/sync/sync_media_index.dart';
import '../managed_media_write_gate.dart';
import 'managed_media_content_index.dart';
import 'storage_duplicates.dart';

/// 导入时复用同内容的托管文件（docs/rules/media.md「重复的图片与视频」）。
///
/// - 输入：刚复制进托管目录（并完成 HEIC 转码）的新文件；
/// - 输出：同一可共用范围（[managedMediaAdoptableDirectories]）里已有逐字节
///   相同的文件时返回它的路径、删掉新副本，否则原样返回新文件；
/// - 尽力而为：任何一步失败都退回用新文件，不让导入因此失败。
///
/// 安全性（复用的文件此刻可能没有任何已保存的引用，例如删掉的日记留下的、
/// 等着回收的文件）：
/// - 先把它的修改时间设为现在，自动回收的 24 小时宽限期重新计时，覆盖还没
///   保存的编辑会话（与同步把来件就位时的做法一致）；再等正在进行的那一轮
///   回收结束（它可能在改时间之前就判定了要删），确认文件还在才复用；
/// - 有压缩、HEIC 修复、同步这类写入者在进行时不复用：压缩提交后会删掉
///   不再被引用的原文件，还没保存的编辑看不见；
/// - 自己作为写入者经 [ManagedMediaWriteGate.write]，存储管理的删除、合并与
///   清理（独占）不会夹在中间；它们本身又要求没有编辑页开着。
///
/// 被复用的文件从“刚导入、可随手删掉”的登记里去掉（[FreshManagedFiles]），
/// 导入失败、取消或移除未保存的图片时，回滚就不会删掉别处在用的文件。
abstract final class ManagedMediaDedup {
  /// 复用 [freshPath] 的同内容文件；[cover] 为日记 / 日记本封面。
  static Future<String> adopt(String freshPath, {bool cover = false}) async {
    try {
      if (ManagedMediaWriteGate.hasWriters) return freshPath;
      return await ManagedMediaWriteGate.write(() => _adopt(freshPath, cover));
    } catch (error, stackTrace) {
      debugPrint('Managed media dedup skipped: $error\n$stackTrace');
      return freshPath;
    }
  }

  static Future<String> _adopt(String freshPath, bool cover) async {
    final freshKey = diaryMediaKeyOf(freshPath);
    if (freshKey == null) return freshPath;
    final fresh = File(freshPath);
    final size = await fresh.length();
    if (size <= 0) return freshPath;
    final root = await appDataRootDirectory();
    final candidates = <String>[];
    for (final directory in managedMediaAdoptableDirectories(
      managedMediaDirectoryOf(freshKey),
      cover: cover,
    )) {
      final keys = await _ManagedMediaSizes.keysWithSize(root, directory, size);
      candidates.addAll(keys.where((key) => key != freshKey).toList()..sort());
    }
    if (candidates.isEmpty) return freshPath;

    final hash = await syncSha256OfFile(fresh);
    final known = await ManagedMediaContentIndex.forRoot(
      root,
    ).describeAll(candidates);
    for (final key in candidates) {
      if (known[key]?.sha256 != hash) continue;
      final existing = File(p.joinAll(<String>[root.path, ...key.split('/')]));
      // 索引按大小 + 修改时间缓存，复用前按内容再核对一次。
      if (await syncSha256OfFile(existing) != hash) continue;
      await existing.setLastModified(DateTime.now());
      await DiaryMediaCleanupService.whenSweepsIdle();
      if (!await existing.exists()) continue;
      FreshManagedFiles.share(existing.path);
      FreshManagedFiles.release(freshPath);
      await _discard(fresh, root, managedMediaDirectoryOf(freshKey));
      return existing.path;
    }
    return freshPath;
  }

  /// 删掉没用上的新副本，以及因此变空的导入批次目录（托管目录本身保留）。
  static Future<void> _discard(
    File fresh,
    Directory root,
    String directory,
  ) async {
    try {
      await fresh.delete();
      final managed = p.normalize(p.join(root.path, directory));
      final parent = fresh.parent;
      if (p.isWithin(managed, parent.path) && await parent.list().isEmpty) {
        await parent.delete();
      }
    } on FileSystemException catch (error) {
      // 只是多留一份没人引用的副本，媒体回收会处理。
      debugPrint('Duplicate import cleanup failed: $error');
    }
  }

  @visibleForTesting
  static void debugReset() {
    _ManagedMediaSizes._byDirectory.clear();
    FreshManagedFiles._paths.clear();
  }
}

/// 本进程刚导入、还没被别处共用的托管文件。
///
/// 导入流程在失败、取消或用户移除还没保存的图片时会直接删掉自己刚导入的
/// 文件（`DiaryMediaStorageService.deleteManagedDiaryFile` 等）。导入时复用
/// 之后，同一个文件可能已被别的日记引用，所以删除前必须确认它是“自己刚
/// 导入的那份”：只有登记在这里、又没被复用过的才删，其余一律交给按引用的
/// 媒体回收。进程重启后登记清空，回滚删除自然只作用于本次导入。
abstract final class FreshManagedFiles {
  static final Set<String> _paths = <String>{};

  static String _normalize(String path) =>
      p.normalize(File(path).absolute.path);

  /// 登记一个刚导入的新文件。
  static void claim(String path) => _paths.add(_normalize(path));

  /// 被导入复用了：从此不再归任何一次导入所有。
  static void share(String path) => _paths.remove(_normalize(path));

  /// 取回所有权准备删除：登记过、没被复用时返回 true（并去掉登记）。
  static bool release(String path) => _paths.remove(_normalize(path));
}

/// 托管目录里“大小 → 定位键”的增量索引，导入时找同样大小的文件用。
///
/// 每次导入都完整遍历上万个文件太慢，这里按托管目录的直接子项（导入批次
/// 目录 `media_x/`，封面目录里则是文件本身）缓存：每次只列直接子项，新出现
/// 的才进去读大小，消失的丢掉。批次目录里后来多出的文件（压缩、HEIC 修复
/// 写在原文件旁的新文件）要到下次启动才会被看到，代价只是少复用一次。
/// 遍历在后台 isolate 里进行。
abstract final class _ManagedMediaSizes {
  static final Map<String, Map<String, List<(String, int)>>> _byDirectory =
      <String, Map<String, List<(String, int)>>>{};

  static Future<List<String>> keysWithSize(
    Directory root,
    String directory,
    int size,
  ) async {
    final path = p.normalize(p.join(root.absolute.path, directory));
    final children = _byDirectory.putIfAbsent(
      path,
      () => <String, List<(String, int)>>{},
    );
    final known = children.keys.toSet();
    final rootPath = root.absolute.path;
    final changes = await Isolate.run(
      () => _listChanges(rootPath, path, known),
    );
    children
      ..removeWhere((name, _) => changes.removed.contains(name))
      ..addAll(changes.added);
    return <String>[
      for (final files in children.values)
        for (final (key, bytes) in files)
          if (bytes == size) key,
    ];
  }
}

/// 列出 [directory] 的直接子项，与 [known] 比较：新子项连同其中文件的
/// 定位键与大小，以及已经不在的子项名。没有文件的子项（正在写入的导入
/// 批次）不记下，下次再看。
({Map<String, List<(String, int)>> added, Set<String> removed}) _listChanges(
  String root,
  String directory,
  Set<String> known,
) {
  final added = <String, List<(String, int)>>{};
  final present = <String>{};
  final folder = Directory(directory);
  if (!folder.existsSync()) return (added: added, removed: known);
  String keyOf(String path) =>
      p.relative(path, from: root).replaceAll('\\', '/');
  try {
    for (final entity in folder.listSync(followLinks: false)) {
      final name = p.basename(entity.path);
      present.add(name);
      if (known.contains(name)) continue;
      final files = <(String, int)>[];
      try {
        if (entity is File) {
          files.add((keyOf(entity.path), entity.lengthSync()));
        } else if (entity is Directory) {
          for (final file in entity.listSync(
            recursive: true,
            followLinks: false,
          )) {
            if (file is File) files.add((keyOf(file.path), file.lengthSync()));
          }
        }
      } on FileSystemException {
        // 并发删除或换走：当作没有这个子项。
      }
      if (files.isNotEmpty) added[name] = files;
    }
  } on FileSystemException {
    return (added: added, removed: <String>{});
  }
  return (added: added, removed: known.difference(present));
}
