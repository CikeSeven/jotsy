import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'backup_archive_io.dart';
import 'cloud_backup_incremental_format.dart';
import 'cloud_backup_incremental_state.dart';
import 'cloud_backup_models.dart';

/// 增量备份读写网盘的公共部分：限流重试、下载并解开索引 / 快照。
///
/// 职责边界：只经 [CloudBackupRemote] 访问网盘、只在 [scratch] 下写临时文件，
/// 不碰数据库与托管媒体；调用方负责 [scratch] 的生命周期。

/// 链密码打不开这条链的索引（或加密与否不一致）。
class CloudIncrementalPasswordException implements Exception {
  const CloudIncrementalPasswordException(this.chain);

  final String chain;

  @override
  String toString() => 'CloudIncrementalPasswordException($chain)';
}

/// 限流与网络错误的退避间隔：最多重试 3 次。坚果云等限流按 30 分钟窗口
/// 计算，短时间密集重试只会继续被拒，所以间隔逐次拉长。
const List<Duration> cloudRetryDelays = <Duration>[
  Duration(seconds: 2),
  Duration(seconds: 8),
  Duration(seconds: 30),
];

typedef CloudSleep = Future<void> Function(Duration duration);

/// 执行 [action]，遇到限流或网络错误时按 [cloudRetryDelays] 退避重试；
/// 其他错误（授权失效、空间不足……）重试也没用，直接抛出。[attempt] 从 0
/// 开始，供调用方在重试时换一个文件名。
Future<T> withCloudRetry<T>(
  Future<T> Function(int attempt) action, {
  required CloudSleep sleep,
}) async {
  for (var attempt = 0; ; attempt++) {
    try {
      return await action(attempt);
    } on CloudBackupException catch (error) {
      final retryable =
          error.failure == CloudBackupFailure.rateLimited ||
          error.failure == CloudBackupFailure.network;
      if (!retryable || attempt >= cloudRetryDelays.length) rethrow;
      await sleep(cloudRetryDelays[attempt]);
    }
  }
}

class IncrementalRemoteIO {
  IncrementalRemoteIO({
    required this.remote,
    required this.state,
    required this.targetId,
    required this.scratch,
    required this.sleep,
  });

  final CloudBackupRemote remote;
  final CloudBackupLocalState state;
  final String targetId;
  final Directory scratch;
  final CloudSleep sleep;
  var _counter = 0;

  Future<List<CloudBackupEntry>> listFiles() =>
      withCloudRetry((_) => remote.listFiles(), sleep: sleep);

  /// 下载 [entry] 到临时文件；调用方负责删除。
  Future<File> download(
    CloudBackupEntry entry, {
    CloudBackupProgress? onProgress,
  }) async {
    final file = File(
      p.join(scratch.path, 'dl_${_counter++}_${entry.fileName}'),
    );
    await withCloudRetry(
      (_) =>
          remote.download(entry: entry, target: file, onProgress: onProgress),
      sleep: sleep,
    );
    return file;
  }

  /// 读出一份索引并核对密码：优先用本机缓存，没有才下载解开并写入缓存。
  ///
  /// [password] 为 null 表示这条链不加密。打不开、或索引记录的加密与否与
  /// 密码不一致（用户以为加了密、其实没加）都抛
  /// [CloudIncrementalPasswordException]；索引本身损坏抛 [FormatException]。
  Future<IncrementalIndex> readIndex(
    CloudBackupEntry entry, {
    required String? password,
  }) async {
    final cached = await state.cachedIndex(
      targetId,
      entry.fileName,
      password: password,
    );
    final index = cached ?? await _downloadIndex(entry, password: password);
    if (index.encrypted != (password != null)) {
      throw CloudIncrementalPasswordException(index.chain);
    }
    if (cached == null) {
      await state.cacheIndex(
        targetId,
        entry.fileName,
        index,
        password: password,
      );
    }
    return index;
  }

  Future<IncrementalIndex> _downloadIndex(
    CloudBackupEntry entry, {
    required String? password,
  }) async {
    final file = await download(entry);
    try {
      final text = await _extractText(
        file,
        incrementalIndexEntryName,
        password: password,
        chain: IncrementalFileName.parse(entry.fileName)?.chain ?? '',
      );
      return IncrementalIndex.decode(text);
    } finally {
      await _deleteQuietly(file);
    }
  }

  /// 下载快照并解出载荷 JSON（gzip 解压后的文本）。
  Future<String> readSnapshotPayload(
    CloudBackupEntry entry, {
    required String? password,
    CloudBackupProgress? onProgress,
  }) async {
    final file = await download(entry, onProgress: onProgress);
    try {
      final directory = await scratch.createTemp('snap_');
      try {
        await _extract(
          file,
          directory,
          incrementalSnapshotEntryName,
          password: password,
          chain: IncrementalFileName.parse(entry.fileName)?.chain ?? '',
        );
        final gz = File(p.join(directory.path, incrementalSnapshotEntryName));
        if (!await gz.exists()) {
          throw const FormatException('增量备份快照缺少载荷');
        }
        return await gz
            .openRead()
            .transform(gzip.decoder)
            .transform(utf8.decoder)
            .join();
      } finally {
        await directory.delete(recursive: true);
      }
    } finally {
      await _deleteQuietly(file);
    }
  }

  /// 不用缓存、只核对 [password] 能否打开 [entry] 这份索引（第一次接上
  /// 别的设备写的加密链时验证用户输入的密码）。
  Future<bool> verifyPassword(CloudBackupEntry entry, String? password) async {
    try {
      final index = await _downloadIndex(entry, password: password);
      if (index.encrypted != (password != null)) return false;
      await state.cacheIndex(
        targetId,
        entry.fileName,
        index,
        password: password,
      );
      return true;
    } on CloudIncrementalPasswordException {
      return false;
    }
  }

  /// 这份索引是否加密（下载后看 ZIP 头，不需要密码）。
  Future<bool> isEncrypted(CloudBackupEntry entry) async {
    final cached = await state.cachedIndexEncrypted(targetId, entry.fileName);
    if (cached != null) return cached;
    final file = await download(entry);
    try {
      return await BackupArchiveIO.isPasswordProtected(file.path);
    } finally {
      await _deleteQuietly(file);
    }
  }

  Future<String> _extractText(
    File zip,
    String entryName, {
    required String? password,
    required String chain,
  }) async {
    final directory = await scratch.createTemp('idx_');
    try {
      await _extract(
        zip,
        directory,
        entryName,
        password: password,
        chain: chain,
      );
      final file = File(p.join(directory.path, entryName));
      if (!await file.exists()) {
        throw const FormatException('增量备份索引缺少内容');
      }
      return await file.readAsString();
    } finally {
      await directory.delete(recursive: true);
    }
  }

  /// 解出单个条目；密码错误统一换成 [CloudIncrementalPasswordException]。
  static Future<void> _extract(
    File zip,
    Directory directory,
    String entryName, {
    required String? password,
    required String chain,
  }) async {
    try {
      await BackupArchiveIO.extract(
        zip.path,
        directory,
        password: password,
        only: {entryName},
      );
    } on FormatException catch (error) {
      if (error.message.toLowerCase().contains('password')) {
        throw CloudIncrementalPasswordException(chain);
      }
      rethrow;
    }
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // 临时文件随 scratch 一起清理。
    }
  }
}
