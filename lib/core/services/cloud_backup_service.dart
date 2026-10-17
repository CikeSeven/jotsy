import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import 'backup_import_models.dart';
import 'cloud_backup_drive.dart';
import 'cloud_backup_drives.dart';
import 'cloud_backup_http.dart';
import 'cloud_backup_models.dart';
import 'cloud_backup_oauth.dart';
import 'cloud_backup_s3.dart';
import 'cloud_backup_settings_service.dart';
import 'cloud_backup_target.dart';
import 'cloud_backup_webdav.dart';
import 'data_archive_service.dart';
import 'settings_service.dart';
import 'webdav_client.dart';
import 'webdav_models.dart';

/// 网盘备份编排服务。
///
/// 职责边界：
/// - 复用 [DataArchiveService] 生成/预检/恢复完整备份 ZIP，不直接操作数据库；
/// - 按备份位置的类型创建网盘客户端（[openRemote]），每次操作用完即关闭；
/// - 授权类网盘：发起授权、授权完成后校验并保存备份位置，令牌刷新后经
///   [CloudBackupSettingsService.updateConfig] 落盘；
/// - 不持有 BuildContext，不展示提示，不决定文案。
class CloudBackupService {
  CloudBackupService({
    required this._database,
    required this._settingsService,
    required this._targets,
    Map<CloudBackupKind, CloudDriveProvider>? drives,
    CloudBackupHttp Function()? httpFactory,
    this._webDavClientFactory,
    Future<Directory> Function()? temporaryDirectory,
  }) : _drives = drives ?? defaultCloudDriveProviders(),
       _httpFactory = httpFactory ?? CloudBackupHttp.new,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final AppDatabase _database;
  final SettingsService _settingsService;
  final CloudBackupSettingsService _targets;
  final Map<CloudBackupKind, CloudDriveProvider> _drives;
  final CloudBackupHttp Function() _httpFactory;
  final WebDavClient Function(WebDavConfig config)? _webDavClientFactory;
  final Future<Directory> Function() _temporaryDirectory;

  CloudBackupSettingsService get targets => _targets;

  /// 此安装包配置了应用密钥、可以添加的授权类网盘。
  bool isDriveAvailable(CloudBackupKind kind) =>
      _drives[kind]?.isAvailable ?? false;

  /// 按备份位置创建客户端；调用方负责 [CloudBackupRemote.close]。
  CloudBackupRemote openRemote(CloudBackupTarget target) {
    switch (target.kind) {
      case CloudBackupKind.webDav:
        return WebDavBackupRemote(
          config: WebDavConfig.fromJson(target.config),
          clientFactory: _webDavClientFactory,
        );
      case CloudBackupKind.s3:
        return S3BackupRemote(
          config: S3BackupConfig.fromJson(target.config),
          http: _httpFactory(),
        );
      default:
        final provider = _requireDrive(target.kind);
        final credentials = CloudDriveCredentials.fromConfig(target.config);
        final http = _httpFactory();
        final session = CloudOAuthSession(
          token: credentials.token,
          refresh: (token) => provider.refresh(http, token),
          // 刷新令牌可能已轮换，必须立刻落盘，否则下次启动拿旧令牌会失效。
          onRefreshed: (token) => _targets.updateConfig(
            target.id,
            (config) => <String, Object?>{...config, 'token': token.toJson()},
          ),
        );
        return provider.createRemote(http, session);
    }
  }

  Future<void> testConnection(CloudBackupTarget target) =>
      _withRemote(target, (remote) => remote.prepare());

  Future<List<CloudBackupEntry>> listBackups(CloudBackupTarget target) =>
      _withRemote(target, (remote) => remote.list());

  /// 导出当前数据为 ZIP 并上传；无论成败都删除本地临时 ZIP。
  Future<CloudBackupEntry> uploadCurrentBackup(
    CloudBackupTarget target, {
    String? zipPassword,
    DateTime? now,
    CloudBackupProgress? onProgress,
  }) async {
    final zipFile = await DataArchiveService.exportToZip(
      database: _database,
      settingsService: _settingsService,
      zipPassword: zipPassword,
    );
    try {
      return await _withRemote(
        target,
        (remote) => remote.upload(
          file: zipFile,
          fileName: buildCloudBackupFileName(now ?? DateTime.now()),
          onProgress: onProgress,
        ),
      );
    } finally {
      if (await zipFile.exists()) await zipFile.delete();
    }
  }

  /// 下载到临时目录；调用方负责删除返回的文件。
  Future<File> downloadBackup(
    CloudBackupTarget target,
    CloudBackupEntry entry, {
    CloudBackupProgress? onProgress,
  }) async {
    final temp = await _temporaryDirectory();
    final file = File(
      p.join(
        temp.path,
        'jotsy_cloud_${DateTime.now().microsecondsSinceEpoch}_'
        '${p.basename(entry.fileName)}',
      ),
    );
    await _withRemote(
      target,
      (remote) =>
          remote.download(entry: entry, target: file, onProgress: onProgress),
    );
    return file;
  }

  Future<void> deleteBackup(CloudBackupTarget target, CloudBackupEntry entry) =>
      _withRemote(target, (remote) => remote.delete(entry));

  /// 判断已下载的备份是否加密。
  Future<bool> isLocalBackupPasswordProtected(File zipFile) =>
      DataArchiveService.isZipPasswordProtected(zipPath: zipFile.path);

  /// 只读预检已下载的备份：识别类型并统计与本机重复的日记，供选择导入方式。
  Future<BackupArchivePreview> inspectLocalBackup({
    required File zipFile,
    String? zipPassword,
  }) {
    return DataArchiveService.inspectZip(
      database: _database,
      zipPath: zipFile.path,
      zipPassword: zipPassword,
    );
  }

  /// 基于已下载的备份按 [mode] 恢复，不再触发远程下载。调用方负责临时文件的
  /// 生命周期；用于“下载一次 → 判断加密 → 预检并选择导入方式 → 恢复”。
  Future<BackupImportResult> restoreFromLocalBackup({
    required File zipFile,
    String? zipPassword,
    required BackupImportMode mode,
  }) {
    return DataArchiveService.importFromZip(
      database: _database,
      settingsService: _settingsService,
      zipPath: zipFile.path,
      zipPassword: zipPassword,
      mode: mode,
    );
  }

  /// 开始授权；返回的会话用完（完成、取消或失败）必须 [CloudDriveAuthorizationSession.close]。
  CloudDriveAuthorizationSession beginAuthorization(CloudBackupKind kind) {
    final provider = _requireDrive(kind);
    final http = _httpFactory();
    return CloudDriveAuthorizationSession._(
      provider.beginAuthorization(http),
      http,
    );
  }

  /// 授权拿到令牌后：读取账号名、确认备份目录可用，再保存为备份位置。
  /// [existing] 不为空时是重新授权，保留原位置的 id。
  Future<CloudBackupTarget> completeAuthorization({
    required CloudBackupKind kind,
    required CloudOAuthToken token,
    CloudBackupTarget? existing,
  }) async {
    final provider = _requireDrive(kind);
    final http = _httpFactory();
    try {
      final session = CloudOAuthSession(
        token: token,
        refresh: (current) => provider.refresh(http, current),
      );
      String? account;
      try {
        account = await provider.fetchAccount(http, session);
      } on CloudBackupException {
        account = null;
      }
      final remote = provider.createRemote(http, session);
      await remote.prepare();
      final config = CloudDriveCredentials(
        token: session.token,
        account:
            account ??
            CloudDriveCredentials.accountOf(existing?.config ?? const {}),
      ).toConfig();
      final target =
          existing?.copyWith(config: config) ??
          CloudBackupTarget.create(kind: kind, config: config);
      await _targets.saveTarget(target);
      return target;
    } finally {
      http.close();
    }
  }

  CloudDriveProvider _requireDrive(CloudBackupKind kind) {
    final provider = _drives[kind];
    if (provider == null || !provider.isAvailable) {
      throw CloudBackupException(CloudBackupFailure.appKeyMissing, kind.id);
    }
    return provider;
  }

  Future<T> _withRemote<T>(
    CloudBackupTarget target,
    Future<T> Function(CloudBackupRemote remote) action,
  ) async {
    final remote = openRemote(target);
    try {
      return await action(remote);
    } finally {
      remote.close();
    }
  }
}

/// 一次进行中的授权；持有本次授权请求用的连接。
class CloudDriveAuthorizationSession {
  CloudDriveAuthorizationSession._(this.method, this._http);

  final CloudDriveAuthorization method;
  final CloudBackupHttp _http;

  void close() => _http.close();
}
