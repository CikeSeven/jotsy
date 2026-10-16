# 网盘备份

设置 → 数据与隐私 → 数据管理 → **网盘备份**。可以配置多个备份位置，每个位置都能上传当前数据的完整备份 ZIP（可选加密）、列出远程备份、恢复（先预检，再选择合并或覆盖）和删除。

地址、密码与授权令牌只保存在本机偏好 `app.cloud_backup.targets`（单个 JSON 键），不进入备份 ZIP。旧版的单一 WebDAV 配置（`app.webdav.*`）会在首次打开时自动迁移为一个 WebDAV 备份位置。

## 支持的备份位置

| 类型 | 服务 | 需要的凭据 |
| :-- | :-- | :-- |
| 授权登录的网盘 | Google Drive、OneDrive、Dropbox、百度网盘、阿里云盘 | 在网盘官方页面授权（安装包需配置应用密钥，见下文） |
| WebDAV | 坚果云、123云盘、Alist / OpenList、CloudDrive2、Nextcloud、ownCloud、Seafile、群晖、威联通、Koofr、pCloud（美/欧）、InfiniCLOUD、Hetzner Storage Box、kDrive、Yandex Disk、Mail.ru Cloud，以及任意 WebDAV | 用户名 + 密码 / 应用密码 |
| S3 兼容对象存储 | 阿里云 OSS、腾讯云 COS、七牛云 Kodo、华为云 OBS、火山引擎 TOS、百度智能云 BOS、京东云 OSS、Amazon S3（含中国区）、Cloudflare R2、Backblaze B2、Wasabi、DigitalOcean Spaces、Scaleway、Storj、IDrive e2、Akamai (Linode)、Oracle Cloud、Google Cloud Storage、MinIO，以及任意 S3 兼容服务 | Access Key + Secret |

夸克、115、天翼云盘等没有开放给个人应用的接口，可以经 Alist / OpenList 挂载后以 WebDAV 方式使用。Box 只支持必须带 client secret 的授权方式，没有收录；Box、Icedrive 的 WebDAV 已停用，也没有收录。

## 授权类网盘的应用密钥

这些网盘要求由开发者注册应用。密钥只在构建时注入，不写进仓库；某个网盘没有配置密钥时，添加面板里不会出现它。

```bash
# 推荐：把密钥写进不入库的 JSON 文件（已在 .gitignore 中忽略）
flutter build apk --release --split-per-abi --dart-define-from-file=cloud_backup_keys.json
```

`cloud_backup_keys.json` 示例（只填已注册的平台）：

```json
{
  "JOTSY_GOOGLE_CLIENT_ID": "xxxx.apps.googleusercontent.com",
  "JOTSY_GOOGLE_CLIENT_SECRET": "xxxx",
  "JOTSY_MICROSOFT_CLIENT_ID": "00000000-0000-0000-0000-000000000000",
  "JOTSY_MICROSOFT_TENANT": "common",
  "JOTSY_DROPBOX_APP_KEY": "xxxx",
  "JOTSY_BAIDU_APP_KEY": "xxxx",
  "JOTSY_BAIDU_SECRET_KEY": "xxxx",
  "JOTSY_BAIDU_APP_DIR": "Jotsy",
  "JOTSY_ALIYUN_CLIENT_ID": "xxxx",
  "JOTSY_ALIYUN_CLIENT_SECRET": ""
}
```

各平台注册要点：

- **Google Drive**：Google Cloud 控制台启用 Drive API，OAuth 客户端类型选“电视和受限输入设备”。权限只用 `drive.file`（非敏感，只需基础验证）。同意屏幕处于“测试”状态时刷新令牌 7 天过期，正式发布前需切到“正式版”。授权走设备码，不需要回调地址。
- **OneDrive**：Microsoft Entra 应用注册，支持的账户类型包含个人 Microsoft 账户，在“身份验证 → 高级设置”中开启“允许公共客户端流”。委托权限 `Files.ReadWrite.AppFolder`、`User.Read`、`offline_access`。备份位于“应用/<应用名>”文件夹。工作/学校账号能否使用 AppFolder 取决于租户策略，未实测。
- **Dropbox**：App Console 新建应用，权限类型选 **App folder**，在 Permissions 中勾选 `files.content.write`、`files.content.read`、`files.metadata.read`、`account_info.read`。用 PKCE，不需要 App secret，也不需要配置回调地址（授权码显示给用户后粘贴回应用）。
- **百度网盘**：百度网盘开放平台创建应用（个人开发者限 1 个），取得 AppKey / SecretKey；`JOTSY_BAIDU_APP_DIR` 必须与登记的应用名称一致（文件位于“我的应用数据/<应用名>”）。未通过上线审核的应用最多 10 个用户且接口频控很严，正式使用前需提交审核。百度没有公开客户端模式，SecretKey 会随安装包分发。
- **阿里云盘**：阿里云盘开放平台入驻需资质审核（含 ICP 备案）。未配置 `JOTSY_ALIYUN_CLIENT_SECRET` 时按“公开客户端”走 PKCE，只发 30 天访问令牌、不能刷新，到期需在应用内重新授权；配置 Secret 后刷新令牌 90 天并自动轮换。未购买三方应用权益包的用户下载可能限速。

## 实现位置

- `lib/core/services/cloud_backup_*.dart`：通用模型与接口（`CloudBackupRemote`）、HTTP 层、OAuth（设备码 / PKCE / 令牌刷新）、各网盘客户端、预设目录、编排服务 `CloudBackupService`。新增网盘只需新增 `cloud_backup_<平台>.dart` 并在 `cloud_backup_drives.dart` 登记。
- `lib/ui/settings/pages/cloud_backup_page.dart`（位置列表）、`cloud_backup_target_page.dart`（单个位置），流程在 `controllers/cloud_backup_controller.dart`。

## 验证状态

各网盘客户端都有按官方文档搭建的本地假服务测试（`test/core/services/cloud_backup_*_test.dart`），覆盖授权、分片上传、分页列表、下载、删除、令牌刷新与错误归类；WebDAV 另有完整备份的往返测试。**授权类网盘尚未用真实账号验证**，注册好应用后建议在真机上逐个走一遍：授权 → 测试连接 → 上传 → 刷新列表 → 恢复（合并）→ 删除。
