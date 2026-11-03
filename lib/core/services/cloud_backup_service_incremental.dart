part of 'cloud_backup_service.dart';

/// [CloudBackupService] 的增量备份、恢复与自动备份入口（拆出主文件，
/// 主文件只留连接、完整 ZIP 与授权）。每个会写网盘或本机状态的操作都经
/// [CloudBackupService._locked] 按备份位置排队。
extension CloudBackupIncrementalOps on CloudBackupService {
  /// 增量备份当前数据。本机还没有增量链时经 [resolveChain] 让用户接上已有
  /// 的链或开始新链。
  Future<CloudIncrementalBackupResult> backupIncremental(
    CloudBackupTarget target, {
    CloudIncrementalChainResolver? resolveChain,
    CloudIncrementalPhaseCallback? onPhase,
    CloudBackupProgress? onProgress,
  }) => _locked(target.id, () async {
    final current = _targets.targetById(target.id) ?? target;
    final backup = await _incrementalBackup();
    return _withRemote(
      current,
      (remote) => backup.backup(
        target: current,
        remote: remote,
        resolveChain: resolveChain,
        onPhase: onPhase,
        onProgress: onProgress,
      ),
    );
  });

  /// 自动备份一个位置：不该备份（见 [isCloudAutoBackupDue]）时返回 null；
  /// 否则静默执行并把结果记进本机状态，从不抛出。
  Future<CloudAutoBackupStatus?> runAutoBackup(String targetId) =>
      _locked(targetId, () async {
        final target = _targets.targetById(targetId);
        if (target == null) return null;
        final state = await localState();
        if (!isCloudAutoBackupDue(
          options: target.options,
          state: await state.read(targetId),
          now: _clock(),
        )) {
          return null;
        }
        final backup = await _incrementalBackup();
        CloudAutoBackupStatus status;
        var failed = false;
        try {
          final result = await _withRemote(
            target,
            (remote) =>
                backup.backup(target: target, remote: remote, auto: true),
          );
          status = CloudAutoBackupStatus(
            at: _clock(),
            outcome: switch (result.outcome) {
              CloudIncrementalBackupOutcome.uploaded =>
                CloudAutoBackupOutcome.uploaded,
              CloudIncrementalBackupOutcome.needsManual =>
                CloudAutoBackupOutcome.needsManual,
              _ => CloudAutoBackupOutcome.unchanged,
            },
            bytes: result.bytes == 0 ? null : result.bytes,
          );
        } on CloudBackupException catch (error) {
          failed = true;
          status = CloudAutoBackupStatus(
            at: _clock(),
            outcome: CloudAutoBackupOutcome.failed,
            failure: error.failure,
          );
        } on Object {
          // 本机文件读写失败、密码对不上等：同样只记一笔，不打扰用户。
          failed = true;
          status = CloudAutoBackupStatus(
            at: _clock(),
            outcome: CloudAutoBackupOutcome.failed,
          );
        }
        await state.update(
          targetId,
          (current) => current.withAuto(status, failed: failed),
        );
        return status;
      });

  /// 下载并解开一份增量备份供预检；调用方用完必须 dispose。
  Future<IncrementalSnapshotOpened> openIncrementalSnapshot(
    CloudBackupTarget target,
    IncrementalSnapshotRef snapshot, {
    required String? password,
    CloudBackupProgress? onProgress,
  }) async {
    final restore = await _incrementalRestore();
    return _withRemote(
      target,
      (remote) => restore.open(
        target: target,
        remote: remote,
        snapshot: snapshot,
        password: password,
        onProgress: onProgress,
      ),
    );
  }

  /// 已打开的增量备份与本机数据的关系，供选择导入方式。
  Future<BackupArchivePreview> previewIncrementalSnapshot(
    IncrementalSnapshotOpened opened,
  ) => DataArchiveService.previewPayload(
    database: _database,
    kind: BackupArchiveKind.fullBackup,
    payload: opened.payload,
  );

  /// 按 [mode] 恢复已打开的增量备份。本机还没有增量链时记住这条链与密码：
  /// 换新手机恢复之后接着备份，已在网盘上的媒体一份也不用重传。
  Future<BackupImportResult> restoreIncremental(
    CloudBackupTarget target,
    IncrementalSnapshotOpened opened, {
    required BackupImportMode mode,
    CloudBackupProgress? onDownloadProgress,
  }) => _locked(target.id, () async {
    final restore = await _incrementalRestore();
    final result = await _withRemote(
      target,
      (remote) => restore.restore(
        target: target,
        remote: remote,
        opened: opened,
        mode: mode,
        onDownloadProgress: onDownloadProgress,
      ),
    );
    final current = _targets.targetById(target.id);
    if (current != null && !current.options.hasChain) {
      await _targets.updateOptions(
        target.id,
        (options) =>
            options.withChain(opened.index.chain, opened.password ?? ''),
      );
    }
    return result;
  });

  /// 删除一份增量备份，并清理不再被引用的媒体包。
  Future<void> deleteIncrementalSnapshot(
    CloudBackupTarget target,
    IncrementalSnapshotRef snapshot,
  ) => _locked(target.id, () async {
    final current = _targets.targetById(target.id) ?? target;
    final backup = await _incrementalBackup();
    await _withRemote(
      current,
      (remote) => backup.deleteSnapshot(
        target: current,
        remote: remote,
        snapshot: snapshot,
      ),
    );
  });

  /// 读一个位置的增量备份状态（界面显示自动备份结果）。
  Future<CloudBackupTargetState> readTargetState(String targetId) async =>
      (await localState()).read(targetId);

  /// 忘记记住的增量链与密码；下次备份时重新选择接上已有的链或开始新链。
  Future<void> forgetIncrementalChain(
    String targetId,
  ) => _locked(targetId, () async {
    await _targets.updateOptions(targetId, (options) => options.withoutChain());
    await (await localState()).update(targetId, (state) => state.forgetChain());
  });

  Future<CloudIncrementalBackup> _incrementalBackup() async =>
      CloudIncrementalBackup(
        database: _database,
        settingsService: _settingsService,
        state: await localState(),
        dataRoot: await _dataRoot(),
        temporary: _temporaryDirectory,
        saveOptions: _targets.updateOptions,
        sleep: _sleep,
        clock: _clock,
        autoUploadLimit: _autoUploadLimit,
      );

  Future<CloudIncrementalRestore> _incrementalRestore() async =>
      CloudIncrementalRestore(
        database: _database,
        settingsService: _settingsService,
        state: await localState(),
        dataRoot: await _dataRoot(),
        temporary: _temporaryDirectory,
        sleep: _sleep,
      );
}
