/// 发布构建用的网盘应用密钥文件 `cloud_backup_keys.json`（经
/// `--dart-define-from-file` 注入，键名见 `lib/core/services/cloud_backup_app_keys.dart`），
/// 供 `tool/write_cloud_backup_keys.dart` 与测试共用。
///
/// 输入：环境变量（发布工作流把仓库 Secrets / Variables 映射进来）；输出：要写入
/// 文件的键值与告警。只做校验与组装，不读写文件、不打印任何值——Android 签名构建
/// 与 Linux / Windows 构建共用这一份规则，三个平台的安装包配置一致。
///
/// 规则（与 docs/cloud_backup.md 一致）：每个网盘都是可选的，没配的只告警（安装包里
/// 不显示该网盘）；配了但不是单行、带首尾空白、格式不对，或成对的值只配了一半时
/// 抛出 [CloudBackupKeysException]，让构建失败，避免发布授权必然失败的包。
library;

/// 一项密钥：环境变量名与它必须匹配的格式。
class CloudBackupKeySpec {
  const CloudBackupKeySpec(this.name, this.pattern);

  final String name;
  final String pattern;
}

const String _googleClient =
    r'^[0-9]+-[a-z0-9]+\.apps\.googleusercontent\.com$';

/// 全部密钥，顺序即写入顺序。
const List<CloudBackupKeySpec> cloudBackupKeySpecs = <CloudBackupKeySpec>[
  CloudBackupKeySpec('JOTSY_GOOGLE_CLIENT_ID', _googleClient),
  CloudBackupKeySpec('JOTSY_GOOGLE_CLIENT_SECRET', r'^GOCSPX-[A-Za-z0-9_-]+$'),
  CloudBackupKeySpec('JOTSY_GOOGLE_WEB_CLIENT_ID', _googleClient),
  CloudBackupKeySpec('JOTSY_DROPBOX_APP_KEY', r'^[a-z0-9]+$'),
  CloudBackupKeySpec('JOTSY_MICROSOFT_CLIENT_ID', r'^[0-9a-fA-F-]{36}$'),
  CloudBackupKeySpec('JOTSY_MICROSOFT_TENANT', r'^[A-Za-z0-9.-]+$'),
  CloudBackupKeySpec('JOTSY_BAIDU_APP_KEY', r'^[A-Za-z0-9]+$'),
  CloudBackupKeySpec('JOTSY_BAIDU_SECRET_KEY', r'^[A-Za-z0-9]+$'),
  CloudBackupKeySpec('JOTSY_BAIDU_APP_DIR', r'^[^/]+$'),
  CloudBackupKeySpec('JOTSY_ALIYUN_CLIENT_ID', r'^[A-Za-z0-9]+$'),
  CloudBackupKeySpec('JOTSY_ALIYUN_CLIENT_SECRET', r'^[A-Za-z0-9]+$'),
];

/// 必须同时配置或同时不配的两项。
const List<(String, String)> _pairs = <(String, String)>[
  ('JOTSY_GOOGLE_CLIENT_ID', 'JOTSY_GOOGLE_CLIENT_SECRET'),
  ('JOTSY_BAIDU_APP_KEY', 'JOTSY_BAIDU_SECRET_KEY'),
];

/// 没配置时的告警：(任一已配置即视为配置了该网盘的变量, 告警文字)。
const List<(List<String>, String)> _missingWarnings = <(List<String>, String)>[
  (
    <String>['JOTSY_GOOGLE_CLIENT_ID', 'JOTSY_GOOGLE_WEB_CLIENT_ID'],
    'Google Drive keys are not set; Google Drive is hidden in this build',
  ),
  (
    <String>['JOTSY_DROPBOX_APP_KEY'],
    'Dropbox key is not set; Dropbox is hidden in this build',
  ),
  (
    <String>['JOTSY_MICROSOFT_CLIENT_ID'],
    'OneDrive key is not set; OneDrive is hidden in this build',
  ),
  (
    <String>['JOTSY_BAIDU_APP_KEY'],
    'Baidu Netdisk keys are not set; Baidu Netdisk is hidden in this build',
  ),
  (
    <String>['JOTSY_ALIYUN_CLIENT_ID'],
    'Alipan key is not set; Alipan is hidden in this build',
  ),
];

/// 校验失败；[message] 只含变量名，不含值。
class CloudBackupKeysException implements Exception {
  const CloudBackupKeysException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 校验结果：要写入文件的键值（只含已配置的项）与告警。
class CloudBackupKeys {
  const CloudBackupKeys(this.values, this.warnings);

  final Map<String, String> values;
  final List<String> warnings;
}

/// 从 [environment] 读出并校验密钥。空值视为未配置，沿用代码里的默认值（空即隐藏）。
CloudBackupKeys readCloudBackupKeys(Map<String, String> environment) {
  String value(String name) => environment[name] ?? '';

  final values = <String, String>{};
  for (final spec in cloudBackupKeySpecs) {
    final raw = value(spec.name);
    if (raw.isEmpty) {
      continue;
    }
    if (raw.contains('\n') || raw.contains('\r')) {
      throw CloudBackupKeysException(
        'Secret ${spec.name} must contain exactly one line',
      );
    }
    if (RegExp(r'^\s|\s$').hasMatch(raw)) {
      throw CloudBackupKeysException(
        'Secret ${spec.name} must not contain leading or trailing whitespace',
      );
    }
    if (!RegExp(spec.pattern).hasMatch(raw)) {
      throw CloudBackupKeysException(
        'Secret ${spec.name} has an unexpected format',
      );
    }
    values[spec.name] = raw;
  }
  for (final (first, second) in _pairs) {
    if (value(first).isEmpty != value(second).isEmpty) {
      throw CloudBackupKeysException(
        'Secrets $first and $second must be set together',
      );
    }
  }
  final warnings = <String>[
    for (final (names, warning) in _missingWarnings)
      if (names.every((name) => value(name).isEmpty)) warning,
  ];
  return CloudBackupKeys(values, warnings);
}
