/// 授权类网盘的应用密钥，构建时经 `--dart-define`（或
/// `--dart-define-from-file=cloud_backup_keys.json`）注入，不写进仓库。
///
/// 某个网盘的密钥为空时，添加备份位置的面板里不显示它；已保存的该网盘位置
/// 仍会列出，但操作会提示“此版本未配置该网盘”。各平台的注册方式见
/// `docs/cloud_backup.md`。
abstract final class CloudBackupAppKeys {
  /// Google Cloud 控制台“电视和受限输入设备”类型的 OAuth 客户端。
  static const googleClientId = String.fromEnvironment(
    'JOTSY_GOOGLE_CLIENT_ID',
  );
  static const googleClientSecret = String.fromEnvironment(
    'JOTSY_GOOGLE_CLIENT_SECRET',
  );

  /// 同一 Google Cloud 项目里“Web 应用”类型客户端的 ID（不需要其密钥）。
  /// Android 上经 Google Play 服务选择账号时必须作为 serverClientId；另需
  /// 在同一项目登记包名 + 签名 SHA-1 的 Android 客户端（无需写进这里）。
  static const googleWebClientId = String.fromEnvironment(
    'JOTSY_GOOGLE_WEB_CLIENT_ID',
  );

  /// Microsoft Entra 应用注册的“应用程序(客户端) ID”，需开启“允许公共
  /// 客户端流”。
  static const microsoftClientId = String.fromEnvironment(
    'JOTSY_MICROSOFT_CLIENT_ID',
  );

  /// 授权租户：`common` 同时支持个人与工作/学校账号，`consumers` 仅个人。
  static const microsoftTenant = String.fromEnvironment(
    'JOTSY_MICROSOFT_TENANT',
    defaultValue: 'common',
  );

  /// Dropbox App Console 的 App key（App folder 权限，PKCE 不需要 secret）。
  static const dropboxAppKey = String.fromEnvironment('JOTSY_DROPBOX_APP_KEY');

  /// 百度网盘开放平台的 AppKey / SecretKey。
  static const baiduAppKey = String.fromEnvironment('JOTSY_BAIDU_APP_KEY');
  static const baiduSecretKey = String.fromEnvironment(
    'JOTSY_BAIDU_SECRET_KEY',
  );

  /// 百度网盘里应用专属目录的名称（`/apps/<名称>/`），须与开放平台登记的
  /// 应用目录一致。
  static const baiduAppDirectory = String.fromEnvironment(
    'JOTSY_BAIDU_APP_DIR',
    defaultValue: 'Jotsy',
  );

  /// 阿里云盘开放平台的 App ID。
  static const aliyunClientId = String.fromEnvironment(
    'JOTSY_ALIYUN_CLIENT_ID',
  );

  /// 阿里云盘的 App Secret（可选）。留空时按“公开客户端”走 PKCE：只发 30 天
  /// 的访问令牌、不能刷新，到期需重新授权；配置后可长期刷新。
  static const aliyunClientSecret = String.fromEnvironment(
    'JOTSY_ALIYUN_CLIENT_SECRET',
  );
}
