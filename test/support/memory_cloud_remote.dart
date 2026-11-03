import 'dart:io';

import 'package:node_diary/core/services/cloud_backup_drive.dart';
import 'package:node_diary/core/services/cloud_backup_http.dart';
import 'package:node_diary/core/services/cloud_backup_models.dart';
import 'package:node_diary/core/services/cloud_backup_oauth.dart';
import 'package:node_diary/core/services/cloud_backup_target.dart';

/// 内存里的网盘：一个平铺目录，记录每次上传 / 下载 / 删除，可注入失败。
/// 经 [MemoryCloudDrive] 挂成授权类网盘，`CloudBackupService.openRemote`
/// 每次都拿到同一个实例（close 不清空内容）。
class MemoryCloudRemote implements CloudBackupRemote {
  final Map<String, List<int>> files = <String, List<int>>{};
  final List<String> uploads = <String>[];
  final List<String> downloads = <String>[];
  final List<String> deletes = <String>[];
  int listCalls = 0;

  /// 每次上传前调用，抛错即这次上传失败（文件不落地）。
  void Function(String fileName)? beforeUpload;

  Iterable<String> namesEndingWith(String suffix) =>
      files.keys.where((name) => name.endsWith(suffix));

  @override
  Future<void> prepare() async {}

  @override
  Future<List<CloudBackupEntry>> list() async =>
      cloudZipBackupsOf(await listFiles());

  @override
  Future<List<CloudBackupEntry>> listFiles() async {
    listCalls++;
    return [
      for (final entry in files.entries)
        CloudBackupEntry(
          fileName: entry.key,
          remoteId: entry.key,
          size: entry.value.length,
          createdAt: cloudBackupCreatedAtFromFileName(entry.key),
        ),
    ];
  }

  @override
  Future<CloudBackupEntry> upload({
    required File file,
    required String fileName,
    CloudBackupProgress? onProgress,
  }) async {
    beforeUpload?.call(fileName);
    final bytes = await file.readAsBytes();
    files[fileName] = bytes;
    uploads.add(fileName);
    onProgress?.call(bytes.length, bytes.length);
    return CloudBackupEntry(
      fileName: fileName,
      remoteId: fileName,
      size: bytes.length,
    );
  }

  @override
  Future<void> download({
    required CloudBackupEntry entry,
    required File target,
    CloudBackupProgress? onProgress,
  }) async {
    final bytes = files[entry.remoteId];
    if (bytes == null) {
      throw CloudBackupException(CloudBackupFailure.notFound, entry.fileName);
    }
    downloads.add(entry.fileName);
    await target.writeAsBytes(bytes, flush: true);
    onProgress?.call(bytes.length, bytes.length);
  }

  @override
  Future<void> delete(CloudBackupEntry entry) async {
    files.remove(entry.remoteId);
    deletes.add(entry.fileName);
  }

  @override
  void close() {}
}

/// 把 [MemoryCloudRemote] 挂成一个“已授权”的网盘（借用 Google Drive 的
/// 类型，令牌永不过期）。
class MemoryCloudDrive implements CloudDriveProvider {
  MemoryCloudDrive(this.remote);

  final MemoryCloudRemote remote;

  static CloudBackupTarget target() => CloudBackupTarget.create(
    kind: CloudBackupKind.googleDrive,
    config: const CloudDriveCredentials(
      token: CloudOAuthToken(accessToken: 'memory'),
    ).toConfig(),
  );

  @override
  CloudBackupKind get kind => CloudBackupKind.googleDrive;

  @override
  bool get isAvailable => true;

  @override
  CloudDriveAuthorization beginAuthorization(CloudBackupHttp http) =>
      throw UnimplementedError();

  @override
  Future<CloudOAuthToken> refresh(
    CloudBackupHttp http,
    CloudOAuthToken token,
  ) async => token;

  @override
  Future<String?> fetchAccount(
    CloudBackupHttp http,
    CloudOAuthSession session,
  ) async => null;

  @override
  CloudBackupRemote createRemote(
    CloudBackupHttp http,
    CloudOAuthSession session,
  ) => remote;
}
