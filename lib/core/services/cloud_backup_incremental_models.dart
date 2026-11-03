// 增量备份编排对外的结果与回调类型（界面与服务共用）。

enum CloudIncrementalPhase { scanning, checking, uploading, pruning }

typedef CloudIncrementalPhaseCallback =
    void Function(CloudIncrementalPhase phase);

enum CloudIncrementalBackupOutcome {
  uploaded,
  unchanged,
  needsManual,
  cancelled,
}

class CloudIncrementalBackupResult {
  const CloudIncrementalBackupResult.uploaded(this.bytes)
    : outcome = CloudIncrementalBackupOutcome.uploaded;
  const CloudIncrementalBackupResult.unchanged()
    : outcome = CloudIncrementalBackupOutcome.unchanged,
      bytes = 0;
  const CloudIncrementalBackupResult.needsManual(this.bytes)
    : outcome = CloudIncrementalBackupOutcome.needsManual;
  const CloudIncrementalBackupResult.cancelled()
    : outcome = CloudIncrementalBackupOutcome.cancelled,
      bytes = 0;

  final CloudIncrementalBackupOutcome outcome;

  /// [CloudIncrementalBackupOutcome.uploaded]：实际上传的字节数；
  /// [CloudIncrementalBackupOutcome.needsManual]：需要上传的新媒体字节数。
  final int bytes;
}

/// 本机还没有增量链时，由界面决定接上已有的链还是开始新链。
typedef CloudIncrementalChainResolver =
    Future<CloudIncrementalChainChoice?> Function(
      CloudIncrementalChainContext context,
    );

class CloudIncrementalChainContext {
  const CloudIncrementalChainContext({
    required this.existingChain,
    required this.isExistingEncrypted,
    required this.verify,
    required this.newChainId,
  });

  /// 网盘上最新一份增量备份所在的链；没有增量备份时为 null。
  final String? existingChain;

  /// [existingChain] 是否加密（会下载它最新的索引看一眼，不需要密码）。
  final Future<bool> Function() isExistingEncrypted;

  /// 用户输入的密码能否打开 [existingChain]；空串表示不加密。
  final Future<bool> Function(String password) verify;

  /// 新链的 id。
  final String Function() newChainId;
}

class CloudIncrementalChainChoice {
  const CloudIncrementalChainChoice({
    required this.chain,
    required this.password,
  });

  final String chain;

  /// 空串表示不加密。
  final String password;
}
