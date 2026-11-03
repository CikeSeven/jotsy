/// 一个备份位置的增量备份与自动备份选项（存在 `CloudBackupTarget.options`）。
///
/// 职责边界：
/// - 只描述选项与本机记住的增量链（链 id + 密码），不读写偏好、不联网；
/// - 与连接配置 `config` 分开存放：表单保存与重新授权都会整份重建 `config`，
///   选项放进去会被冲掉；
/// - 逐字段容错、稀疏写入：认不出的值回到默认，默认值不写进 JSON。
///
/// 链密码与网盘密码、授权令牌同存于本机偏好 `app.cloud_backup.targets`，
/// 不随备份导出、不同步；换设备恢复时由用户重新输入。
class CloudBackupOptions {
  const CloudBackupOptions({
    this.keepSnapshots = defaultKeepSnapshots,
    this.autoBackup = false,
    this.autoInterval = CloudAutoBackupInterval.daily,
    this.chain,
    this.password,
  });

  static const int defaultKeepSnapshots = 30;

  /// 保留份数的可选值；0 表示全部保留。
  static const List<int> keepChoices = <int>[10, 30, 100, 0];

  /// 自动清理时保留最近几份增量备份（所有链一起按时间算）；0 为全部保留。
  final int keepSnapshots;

  /// 是否自动备份。只有已有一份成功的增量备份（[chain] 不为空）时才生效：
  /// 第一次的大上传与密码设定都由用户手动完成。
  final bool autoBackup;
  final CloudAutoBackupInterval autoInterval;

  /// 本机写入的增量链 id（8 位小写十六进制）；还没做过增量备份时为 null。
  final String? chain;

  /// [chain] 的密码；空串表示这条链不加密。[chain] 为 null 时没有意义。
  final String? password;

  bool get hasChain => chain != null && password != null;

  /// 记住的密码对应的加密密码；不加密时为 null（与导出 ZIP 的口径一致）。
  String? get zipPassword {
    final value = password;
    return value == null || value.isEmpty ? null : value;
  }

  CloudBackupOptions copyWith({
    int? keepSnapshots,
    bool? autoBackup,
    CloudAutoBackupInterval? autoInterval,
  }) {
    return CloudBackupOptions(
      keepSnapshots: keepSnapshots ?? this.keepSnapshots,
      autoBackup: autoBackup ?? this.autoBackup,
      autoInterval: autoInterval ?? this.autoInterval,
      chain: chain,
      password: password,
    );
  }

  /// 换成另一条链（第一次增量备份、密码不一致时开始新链）。
  CloudBackupOptions withChain(String chain, String password) {
    return CloudBackupOptions(
      keepSnapshots: keepSnapshots,
      autoBackup: autoBackup,
      autoInterval: autoInterval,
      chain: chain,
      password: password,
    );
  }

  /// 忘掉记住的链与密码；自动备份随之停用（没有链就不会自动运行）。
  CloudBackupOptions withoutChain() {
    return CloudBackupOptions(
      keepSnapshots: keepSnapshots,
      autoBackup: autoBackup,
      autoInterval: autoInterval,
    );
  }

  static CloudBackupOptions fromJson(Object? raw) {
    if (raw is! Map) return const CloudBackupOptions();
    final keep = raw['keep'];
    final chain = raw['chain'];
    final password = raw['password'];
    final validChain = chain is String && isValidCloudChainId(chain);
    return CloudBackupOptions(
      keepSnapshots: keep is int && keepChoices.contains(keep)
          ? keep
          : defaultKeepSnapshots,
      autoBackup: raw['auto'] == true,
      autoInterval: CloudAutoBackupInterval.fromId(raw['interval']),
      chain: validChain && password is String ? chain : null,
      password: validChain && password is String ? password : null,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    if (keepSnapshots != defaultKeepSnapshots) 'keep': keepSnapshots,
    if (autoBackup) 'auto': true,
    if (autoInterval != CloudAutoBackupInterval.daily)
      'interval': autoInterval.id,
    if (hasChain) 'chain': chain,
    if (hasChain) 'password': password,
  };
}

/// 自动备份的最短间隔。
enum CloudAutoBackupInterval {
  daily('daily', Duration(days: 1)),
  weekly('weekly', Duration(days: 7));

  const CloudAutoBackupInterval(this.id, this.duration);

  final String id;
  final Duration duration;

  static CloudAutoBackupInterval fromId(Object? id) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return daily;
  }
}

/// 增量链 id：8 位小写十六进制。
bool isValidCloudChainId(String value) =>
    RegExp(r'^[0-9a-f]{8}$').hasMatch(value);
