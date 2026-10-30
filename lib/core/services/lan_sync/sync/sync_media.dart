import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'sync_media_index.dart';
import 'sync_media_refs.dart';
import 'sync_media_rekey.dart';

export 'sync_media_library.dart';
export 'sync_media_rekey.dart';

/// 同步的媒体文件：收件暂存、校验、就位，以及发送与改键照做时读写本机文件
/// （规格 docs/lan_sync.md §2.3、§6 第 2 步）。
///
/// - 输入：数据根目录 `dataRoot`、会话 id、媒体索引（取本机文件的 sha256）；
/// - 输出：[SyncMediaPlacement]（就位的文件数 / 字节数与改键）、
///   [SyncOutgoingMedia]（发送用的流、大小与 sha256）；
/// - 副作用：只在 `<dataRoot>/.lan_sync_staging/<会话>/` 与托管媒体目录里
///   新建 / 改名 / 删除**暂存**文件；从不覆盖、删除或改写已有的托管媒体。
///
/// 暂存目录放在数据根目录下：与托管媒体同一个文件系统，就位用改名，原子且
/// 不必再拷贝一遍大视频。目录名以点开头、不在 `backupMediaDirectories` 里，
/// 媒体回收与备份都不会扫到它。

/// 暂存目录的名字（`<dataRoot>/.lan_sync_staging/`）。
const String kSyncStagingDirName = '.lan_sync_staging';

/// 暂存目录的最长保留时间：超过的由 [SyncMediaStaging.sweepStale] 清掉
/// （会话异常退出、进程被杀时留下的）。
const Duration kSyncStagingMaxAge = Duration(hours: 24);

/// 收到的文件与声明的大小或 sha256 不符：暂存文件已删除，这个键不会就位。
class SyncMediaVerificationException implements Exception {
  const SyncMediaVerificationException(this.key, this.message);

  final String key;
  final String message;

  @override
  String toString() => 'SyncMediaVerificationException($key): $message';
}

/// 一次就位的结果。
@immutable
class SyncMediaPlacement {
  const SyncMediaPlacement({
    this.rekeys = const <SyncMediaRekey>[],
    this.placedFiles = 0,
    this.placedBytes = 0,
    this.reusedFiles = 0,
  });

  /// 因同键不同文件而换了键的来件（按旧键排序）。
  final List<SyncMediaRekey> rekeys;

  /// 新放进托管目录的文件数与总字节数（界面摘要用）。
  final int placedFiles;
  final int placedBytes;

  /// 本机已有同样内容、直接复用的文件数。
  final int reusedFiles;

  Map<String, String> get rekeyMap => <String, String>{
    for (final rekey in rekeys) rekey.oldKey: rekey.newKey,
  };
}

/// 一次会话的收件暂存区：`<dataRoot>/.lan_sync_staging/<sessionId>/<键>`。
///
/// 用法（会话层）：每个来件 [openSink] 写入（或 [receive] 直接接一条流）、
/// 写完后 [verify]；写入层在开事务之前 [place]；会话结束（成功、失败或推迟）
/// 时 [dispose]（`SyncApplier.apply` 结束时会自己调用）。
class SyncMediaStaging {
  SyncMediaStaging({
    required this.dataRoot,
    required String sessionId,
    required this.index,
    DateTime Function()? clock,
  }) : directory = Directory(
         p.join(dataRoot.path, kSyncStagingDirName, _checkSessionId(sessionId)),
       ),
       _clock = clock ?? DateTime.now;

  final Directory dataRoot;
  final Directory directory;
  final SyncMediaIndex index;
  final DateTime Function() _clock;

  final Map<String, ({int size, String sha256})> _verified =
      <String, ({int size, String sha256})>{};

  /// 已经通过校验、等待就位的键。
  Iterable<String> get verifiedKeys => _verified.keys;

  /// 为 [key] 打开一个写入流（写到 `.part` 文件；同一个键重开即从头重写）。
  /// 调用方写完后关闭它，再调用 [verify]。键不合法时抛 [ArgumentError]。
  Future<IOSink> openSink(String key) async {
    final file = File('${_stagedPath(key)}.part');
    await file.parent.create(recursive: true);
    _verified.remove(key);
    return file.openWrite();
  }

  /// 核对已写完的 [key] 的大小与 sha256；不符时删除暂存文件并抛
  /// [SyncMediaVerificationException]。
  Future<void> verify(
    String key, {
    required int size,
    required String sha256,
  }) async {
    final part = File('${_stagedPath(key)}.part');
    if (!await part.exists()) {
      throw SyncMediaVerificationException(key, '没有收到文件');
    }
    final actualSize = await part.length();
    final actualHash = actualSize == size ? await syncSha256OfFile(part) : null;
    if (actualHash != sha256.toLowerCase()) {
      await part.delete();
      throw SyncMediaVerificationException(
        key,
        actualHash == null ? '大小不符：$actualSize ≠ $size' : 'sha256 不符',
      );
    }
    await part.rename(_stagedPath(key));
    _verified[key] = (size: actualSize, sha256: actualHash!);
  }

  /// [openSink] + 写完 [data] + [verify]。
  ///
  /// [data] 中途报错（断线、超时）时抛出**原来的**错误并删掉写了一半的
  /// `.part` 文件：IOSink 在 addStream 失败时已随之关闭，再 close 会抛
  /// FileSystemException，不能让它盖掉真正的原因（会话据此区分断线与超时）。
  Future<void> receive(
    String key,
    Stream<List<int>> data, {
    required int size,
    required String sha256,
  }) async {
    final sink = await openSink(key);
    try {
      await sink.addStream(data);
    } catch (error, stack) {
      try {
        await sink.close();
      } on Object {
        // 见上：sink 可能已经关闭。
      }
      await _deletePart(key);
      Error.throwWithStackTrace(error, stack);
    }
    await sink.close();
    await verify(key, size: size, sha256: sha256);
  }

  Future<void> _deletePart(String key) async {
    final part = File('${_stagedPath(key)}.part');
    try {
      if (await part.exists()) await part.delete();
    } on FileSystemException catch (error) {
      // 删不掉的随暂存目录在 [dispose] / [sweepStale] 时清掉。
      debugPrint('LAN sync staging part cleanup failed: $error');
    }
  }

  /// 把已校验的来件放进托管目录（规格 §6 第 2 步）：
  /// - 目标键不存在：改名就位，修改时间设为现在（不沿用发送方的时间，媒体
  ///   回收按修改时间留的宽限期才对新到的文件生效）；
  /// - 目标键已有同样 sha256 的文件：复用，丢掉暂存件；
  /// - 目标键已是另一份文件：**不覆盖**，放到派生键（[syncDerivedMediaKey]，
  ///   派生键上已有同样内容时复用），记入改键，由写入层改写本次要写的记录。
  ///
  /// 在写入事务之前调用：之后事务失败回滚时，已就位的文件留着、没有记录引用，
  /// 由媒体回收在宽限期之后收走。
  Future<SyncMediaPlacement> place() async {
    final rekeys = <SyncMediaRekey>[];
    var placedFiles = 0;
    var placedBytes = 0;
    var reused = 0;
    final keys = _verified.keys.toList()..sort();
    for (final key in keys) {
      final staged = _verified[key]!;
      final source = File(_stagedPath(key));
      String? target;
      for (final candidate in <String>[
        key,
        syncDerivedMediaKey(key, staged.sha256),
        syncDerivedMediaKey(key, staged.sha256, hexLength: 64),
      ]) {
        final path = syncMediaPathFor(dataRoot.path, candidate);
        if (path == null) continue;
        final existing = await index.describe(candidate);
        if (existing == null) {
          await _moveInto(source, File(path));
          placedFiles++;
          placedBytes += staged.size;
        } else if (existing.sha256 == staged.sha256) {
          await source.delete();
          reused++;
        } else {
          continue;
        }
        target = candidate;
        break;
      }
      if (target == null) {
        throw StateError('媒体 $key 的派生键都已被其他文件占用');
      }
      if (target != key) {
        rekeys.add(
          SyncMediaRekey(oldKey: key, newKey: target, sha256: staged.sha256),
        );
      }
    }
    _verified.clear();
    return SyncMediaPlacement(
      rekeys: rekeys,
      placedFiles: placedFiles,
      placedBytes: placedBytes,
      reusedFiles: reused,
    );
  }

  /// 删除本次会话的暂存目录（成功、失败或推迟都要调用；可重复调用）。
  Future<void> dispose() async {
    _verified.clear();
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } on FileSystemException catch (error) {
      // 删不掉只是多占空间，[sweepStale] 之后会再试。
      debugPrint('LAN sync staging cleanup failed: $error');
    }
  }

  /// 删除修改时间早于 [maxAge] 的暂存目录（服务启动时调用），返回删除的个数。
  static Future<int> sweepStale(
    Directory dataRoot, {
    Duration maxAge = kSyncStagingMaxAge,
    DateTime? now,
  }) async {
    final root = Directory(p.join(dataRoot.path, kSyncStagingDirName));
    if (!await root.exists()) return 0;
    final cutoff = (now ?? DateTime.now()).subtract(maxAge);
    var removed = 0;
    await for (final entity in root.list(followLinks: false)) {
      try {
        final stat = await entity.stat();
        if (!stat.modified.isBefore(cutoff)) continue;
        await entity.delete(recursive: true);
        removed++;
      } on FileSystemException catch (error) {
        debugPrint('LAN sync staging sweep skipped ${entity.path}: $error');
      }
    }
    return removed;
  }

  String _stagedPath(String key) {
    final path = syncMediaPathFor(directory.path, key);
    if (path == null) throw ArgumentError.value(key, 'key', '不是合法的媒体键');
    return path;
  }

  Future<void> _moveInto(File source, File target) async {
    await target.parent.create(recursive: true);
    try {
      await source.rename(target.path);
    } on FileSystemException {
      // 数据根目录被挂到别的文件系统等少见情形：退回拷贝后删除。
      await source.copy(target.path);
      await source.delete();
    }
    await target.setLastModified(_clock());
  }

  static String _checkSessionId(String id) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(id)) {
      throw ArgumentError.value(id, 'sessionId', '只能是字母、数字、- 与 _');
    }
    return id;
  }
}
