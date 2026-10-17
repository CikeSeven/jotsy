import 'dart:io';

/// 网盘备份的通用模型：存储类型、远程备份条目、失败分类与备份文件命名。
///
/// 职责边界：
/// - 只描述“远程有哪些备份、操作为何失败”，不做网络请求、不读写设置；
/// - 各网盘客户端把各自的错误归入 [CloudBackupFailure]，界面只按分类给出
///   文案，不需要认识每个平台的错误码。
enum CloudBackupKind {
  webDav('webdav'),
  s3('s3'),
  googleDrive('google_drive'),
  oneDrive('onedrive'),
  dropbox('dropbox'),
  baiduPan('baidu_pan'),
  aliyunDrive('aliyun_drive');

  const CloudBackupKind(this.id);

  /// 持久化用的稳定标识，改名会让已保存的备份位置失效。
  final String id;

  /// 需要在网盘官方页面授权登录（而不是填写地址与密钥）的类型。
  bool get usesAuthorization => switch (this) {
    CloudBackupKind.webDav || CloudBackupKind.s3 => false,
    _ => true,
  };

  static CloudBackupKind? fromId(Object? id) {
    for (final kind in values) {
      if (kind.id == id) return kind;
    }
    return null;
  }
}

/// 远程的一份备份。[remoteId] 是该网盘定位文件所需的标识：WebDAV 与百度
/// 网盘是路径，S3 是对象键，其余网盘是文件 id。
class CloudBackupEntry {
  const CloudBackupEntry({
    required this.fileName,
    required this.remoteId,
    this.size,
    this.createdAt,
    this.updatedAt,
  });

  final String fileName;
  final String remoteId;
  final int? size;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

/// 传输进度回调；[total] 未知时为 null。
typedef CloudBackupProgress = void Function(int transferred, int? total);

/// 失败分类，界面据此选择提示文案。
enum CloudBackupFailure {
  /// 配置不完整或格式错误（地址、桶名、目录等）。
  config,

  /// 此安装包没有配置该网盘的应用密钥，无法发起授权。
  appKeyMissing,

  /// 本机无法使用该网盘要求的系统授权（如没有 Google Play 服务），且没有
  /// 可用的备用授权方式。
  platformUnavailable,

  /// 账号、密码或密钥被拒绝，或无权访问目标位置。
  unauthorized,

  /// 授权已失效（被撤销或刷新令牌过期），需要重新登录授权。
  sessionExpired,

  /// 用户在网盘授权页拒绝了授权。
  authorizationDenied,

  /// 授权码或设备码超时未完成。
  authorizationExpired,

  /// 远程文件或目录不存在。
  notFound,

  /// 网盘空间不足。
  storageFull,

  /// 文件超过该网盘允许的单文件大小。
  fileTooLarge,

  /// 请求过于频繁，被网盘限流。
  rateLimited,

  /// 网络不可达、超时或服务端临时错误。
  network,

  /// 响应与预期协议不符（接口变更或被代理改写）。
  protocol,
}

class CloudBackupException implements Exception {
  const CloudBackupException(this.failure, [this.detail, this.statusCode]);

  final CloudBackupFailure failure;
  final String? detail;
  final int? statusCode;

  /// 按 HTTP 状态码归类；各客户端拿到更具体的错误码时应优先自行归类。
  factory CloudBackupException.forStatus(int statusCode, [String? detail]) {
    final failure = switch (statusCode) {
      HttpStatus.unauthorized ||
      HttpStatus.forbidden => CloudBackupFailure.unauthorized,
      HttpStatus.notFound => CloudBackupFailure.notFound,
      HttpStatus.requestEntityTooLarge => CloudBackupFailure.fileTooLarge,
      HttpStatus.tooManyRequests => CloudBackupFailure.rateLimited,
      507 => CloudBackupFailure.storageFull,
      >= 500 => CloudBackupFailure.network,
      _ => CloudBackupFailure.protocol,
    };
    return CloudBackupException(failure, detail, statusCode);
  }

  @override
  String toString() {
    final status = statusCode == null ? '' : ' ($statusCode)';
    final suffix = detail == null ? '' : ': $detail';
    return 'CloudBackupException(${failure.name}$status)$suffix';
  }
}

/// 备份文件名：`jotsy_backup_YYYYMMDD_HHMMSS.zip`（本地时间）。各网盘统一
/// 命名，列表时也能从文件名还原创建时间，不依赖网盘返回的修改时间。
String buildCloudBackupFileName(DateTime now) {
  String two(int value) => value.toString().padLeft(2, '0');
  final local = now.toLocal();
  return 'jotsy_backup_'
      '${local.year}${two(local.month)}${two(local.day)}_'
      '${two(local.hour)}${two(local.minute)}${two(local.second)}.zip';
}

/// 从 [buildCloudBackupFileName] 生成的文件名还原创建时间；其他文件名返回
/// null（用户手动放进目录的 ZIP 仍会列出，只是时间取网盘的修改时间）。
DateTime? cloudBackupCreatedAtFromFileName(String fileName) {
  final match = RegExp(
    r'jotsy_backup_(\d{8})_(\d{6})\.zip$',
  ).firstMatch(fileName);
  if (match == null) {
    return null;
  }
  final date = match.group(1)!;
  final time = match.group(2)!;
  return DateTime.tryParse(
    '${date.substring(0, 4)}-${date.substring(4, 6)}-${date.substring(6, 8)}T'
    '${time.substring(0, 2)}:${time.substring(2, 4)}:${time.substring(4, 6)}',
  );
}

/// 备份目录里只把 ZIP 当作备份展示，manifest 与其他文件忽略。
bool isCloudBackupFileName(String fileName) =>
    fileName.toLowerCase().endsWith('.zip');

/// 新的在前；时间相同按文件名倒序，保证列表顺序稳定。
List<CloudBackupEntry> sortCloudBackups(Iterable<CloudBackupEntry> entries) {
  final copied = entries.toList();
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  copied.sort((a, b) {
    final byTime = (b.createdAt ?? b.updatedAt ?? epoch).compareTo(
      a.createdAt ?? a.updatedAt ?? epoch,
    );
    return byTime != 0 ? byTime : b.fileName.compareTo(a.fileName);
  });
  return copied;
}

/// 网盘客户端统一接口。
///
/// 每个实例绑定一个已配置的备份位置；调用方用完必须 [close] 释放连接。
/// 上传与下载都以流方式读写本地文件，不把整个备份读入内存。
abstract interface class CloudBackupRemote {
  /// 校验凭据并确保备份目录存在；“测试连接”即调用它。
  Future<void> prepare();

  /// 备份目录里的 ZIP，新的在前。
  Future<List<CloudBackupEntry>> list();

  /// 把本地 [file] 以 [fileName] 上传到备份目录，返回远程条目。文件名精确到
  /// 秒，同名几乎不会发生；真遇到时按各网盘语义覆盖或自动改名。
  Future<CloudBackupEntry> upload({
    required File file,
    required String fileName,
    CloudBackupProgress? onProgress,
  });

  /// 下载到 [target]；失败时删除不完整的文件。
  Future<void> download({
    required CloudBackupEntry entry,
    required File target,
    CloudBackupProgress? onProgress,
  });

  Future<void> delete(CloudBackupEntry entry);

  void close();
}
