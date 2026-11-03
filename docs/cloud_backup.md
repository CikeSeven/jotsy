# 网盘备份

设置 → 数据与隐私 → 数据管理 → **网盘备份**。可以配置多个备份位置。每个位置都能：

- **备份**（增量，见下文）：只上传新增与变化的内容；
- **上传完整 ZIP**（可选加密）：一个可以单独下载、在“数据管理 → 导入”里恢复的文件；
- 列出远程备份（完整 ZIP 与增量备份混在一个列表里，按时间排序）；
- 恢复：先预检，再选择合并或覆盖；
- 删除；
- 设置增量备份的保留份数与自动备份。

地址、密码、授权令牌、增量备份的选项与记住的链密码只保存在本机偏好 `app.cloud_backup.targets`（单个 JSON 键；选项在每个位置的 `options` 字段，与连接配置 `config` 分开），不进入备份。旧版的单一 WebDAV 配置（`app.webdav.*`）会在首次打开时自动迁移为一个 WebDAV 备份位置。

## 增量备份

坚果云这类网盘有月度流量额度（免费账户约每月 1 GB 上传、3 GB 下载），还限制请求次数（每 30 分钟 600 次）。完整 ZIP 每次都要把全部照片、视频重新上传一遍，恢复时也要整包下载，额度很快就用完了。增量备份的做法：

- 媒体按内容（sha256）去重，同一份内容在网盘上只存一次，打成约 32 MiB 一个的**媒体包**。打包是为了省请求次数，几千张照片一张一个文件会被限流。
- 每次备份上传两类文件：这次新增内容的媒体包，以及一份**快照**和它的**索引**。快照是载荷 JSON 的 gzip，索引记录全部媒体（媒体键 → 哈希）和每个哈希在哪个包里。数据没有任何变化时什么都不传。
- 在本机恢复时，本机已有同样内容的媒体直接复制，只下载缺少内容所在的包。同一台设备上恢复，通常只下载几 MB 的快照。

### 文件格式

全部文件平铺在备份位置原有的目录里，所以 7 种网盘都不需要支持子目录。这些文件都不以 `.zip` 结尾，旧版应用列表时看不到它们。

| 文件 | 内容 |
| :-- | :-- |
| `jotsy_pack_<链>_<yyyyMMddHHmmss>_<随机8位>.pack` | 媒体包：ZIP，条目一律 STORE，条目名是内容的 sha256 |
| `jotsy_inc_<yyyyMMdd_HHmmss>_<链>.snap` | 快照：ZIP，只有 `snapshot_data.json.gz` |
| `jotsy_inc_<yyyyMMdd_HHmmss>_<链>.idx` | 索引：ZIP，只有 `snapshot_index.json`（`IncrementalIndex`） |

- 写入顺序是 包 → 快照 → 索引。索引是提交标记：没有索引的快照与包都算垃圾。
- 快照里的载荷刻意不叫 `backup_data.json`：旧版应用与“数据管理 → 导入”会以缺少该文件拒绝它，不会把没有媒体的快照当成完整备份覆盖恢复。
- 索引来自网盘，读取时严格校验：哈希必须是 64 位十六进制，包名必须是合法的包文件名，媒体键必须以托管目录开头、不含 `.` / `..`，防止被篡改的索引写出暂存目录。

### 链与密码

一串共用同一个密码的增量备份叫一条**链**（8 位十六进制 id）。媒体包、快照、索引都用这个密码加密，与完整备份同一套 WinZip AES。

- 第一次备份时设定密码，留空即不加密。之后密码记在本机，与网盘凭据放在一起，不随备份导出、不同步。
- 网盘上已有别的设备写的链时：加密的链要输入密码接上，核对的方式是用它解开最新的索引；输错可以重新输入，也可以开始新的一串。不加密的链可以直接接着备份，或开始新的一串（以便加密）。
- 换新设备恢复成功后，自动记住这条链与密码，之后接着备份时已在网盘上的媒体一份也不用重传。
- “重新设置密码”会忘掉本机记住的链，自动备份随之暂停，下次备份时重新选择。

### 续传与重试

- 上传中途断网、被系统杀掉或在 iOS 后台被挂起时，已上传的包记在本机的续传日志里。下次备份确认这些包仍在网盘上，就直接沿用。
- 遇到限流或网络错误时退避重试，最多 3 次，间隔 2 / 8 / 30 秒。包重试时换一个文件名，上一次可能已落地的半成品交给清理。

### 清理

- 按“保留份数”（10 / 30 / 100 / 全部，默认 30）保留最近的增量备份，所有链一起按时间算。更早的先删索引、再删快照。
- 媒体包按链回收：这条链保留下来的索引都读得出时，没被它们引用的包删掉；一份索引都不剩的链，整链的包删掉；有读不出的索引（别的设备用别的密码写的链）时，整条链不动。
- 包名里的时间不满 24 小时的不删，以免误删另一台设备正在上传的包。每次最多删 100 个文件，剩下的下次再删。
- 完整备份 ZIP 不参与自动清理。

### 自动备份

自动备份按位置开启，默认关闭；要先成功手动备份过一次才能开启，第一次的大上传和密码设定都由用户完成。频率为每天或每周。

- 检查时机：冷启动后 10 秒、切到后台后 3 秒（让编辑页的自动保存先写完）、前台每小时一次。
- 数据没变化时只在本机比较指纹，不联网。
- 新增内容超过 50 MB 时不上传，状态显示“请手动备份”。应用没有判断网络类型的依赖，用大小兜住移动数据。
- 失败后至少隔 1 小时再试。全程静默：不弹窗、不弹提示条，结果显示在网盘备份页的位置列表与位置页里。

### 本机状态

本机状态放在 `<数据根>/cloud_backup_state/`。完整备份只导出列出的托管目录，所以它不进备份，也不会被覆盖恢复换掉。删掉它不会丢数据。里面有：

- `media_index.json.gz`：媒体哈希缓存，复用局域网同步的 `SyncMediaIndex`，按大小 + 修改时间缓存；
- 每个位置的 `state.json.gz`：上次的索引与指纹、自动备份结果、续传日志；
- `idx/`：已解开的索引缓存，与打开它的密码绑定。

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
  "JOTSY_GOOGLE_WEB_CLIENT_ID": "yyyy.apps.googleusercontent.com",
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

OAuth 同意屏幕需要的首页与隐私政策由 GitHub Pages 托管（仓库 `docs/` 目录）：首页 `https://cikeseven.github.io/jotsy/`，隐私政策 `https://cikeseven.github.io/jotsy/privacy.html`，已获授权的网域填 `cikeseven.github.io`。

GitHub Actions 发布（`.github/workflows/release-apk.yml`）从仓库 Secrets 读取同名的值（`JOTSY_GOOGLE_CLIENT_ID`、`JOTSY_GOOGLE_CLIENT_SECRET`、`JOTSY_GOOGLE_WEB_CLIENT_ID`、`JOTSY_DROPBOX_APP_KEY`、`JOTSY_MICROSOFT_CLIENT_ID`、`JOTSY_BAIDU_APP_KEY`、`JOTSY_BAIDU_SECRET_KEY`、`JOTSY_ALIYUN_CLIENT_ID`、`JOTSY_ALIYUN_CLIENT_SECRET`；`JOTSY_MICROSOFT_TENANT`、`JOTSY_BAIDU_APP_DIR` 为仓库 Variables）生成该文件。Android 签名构建与 Linux / Windows 构建共用同一份密钥与同一个脚本 `tool/write_cloud_backup_keys.dart`（只打印变量名，不打印值；桌面构建后删除该文件）。每个网盘都可选：没配的只告警、发布包里不显示；格式不对或成对的值只配一半时构建失败。桌面上 Google Drive 只走设备码（需要“电视和受限输入设备”客户端，只配了 Web 客户端 ID 时桌面版不显示 Google Drive），OneDrive、百度网盘走设备码，Dropbox、阿里云盘在系统浏览器授权后粘贴授权码。

各平台注册要点：

- **Google Drive**：Google Cloud 控制台启用 Drive API，权限只用 `drive.file`（非敏感，只需基础验证）。同意屏幕处于“测试”状态时只有测试用户能授权、且授权 7 天过期，正式发布前需切到“正式版”。同一项目里建三个 OAuth 客户端：
  - **Android**（包名 `com.jotsy.diary` + 正式签名 SHA-1；不用写进密钥文件）与 **Web 应用**（只取客户端 ID 填 `JOTSY_GOOGLE_WEB_CLIENT_ID`，不填重定向 URI）：装有 Google Play 服务的 Android 手机经系统账号选择器授权，令牌由 Play 服务续期，应用不保存刷新令牌；
  - **电视和受限输入设备**（`JOTSY_GOOGLE_CLIENT_ID` / `JOTSY_GOOGLE_CLIENT_SECRET`）：没有 Play 服务的手机、iOS 与桌面走设备码授权，也是系统授权不可用时的自动回落。
- **OneDrive**：Microsoft Entra 应用注册，支持的账户类型包含个人 Microsoft 账户，在“身份验证 → 高级设置”中开启“允许公共客户端流”。委托权限 `Files.ReadWrite.AppFolder`、`User.Read`、`offline_access`。备份位于“应用/<应用名>”文件夹。工作/学校账号能否使用 AppFolder 取决于租户策略，未实测。
- **Dropbox**：App Console 新建应用，权限类型选 **App folder**，在 Permissions 中勾选 `files.content.write`、`files.content.read`、`files.metadata.read`、`account_info.read`。用 PKCE，不需要 App secret，也不需要配置回调地址（授权码显示给用户后粘贴回应用）。
- **百度网盘**：百度网盘开放平台创建应用（个人开发者限 1 个），取得 AppKey / SecretKey；`JOTSY_BAIDU_APP_DIR` 必须与登记的应用名称一致（文件位于“我的应用数据/<应用名>”）。未通过上线审核的应用最多 10 个用户且接口频控很严，正式使用前需提交审核。百度没有公开客户端模式，SecretKey 会随安装包分发。
- **阿里云盘**：阿里云盘开放平台入驻需资质审核（含 ICP 备案）。未配置 `JOTSY_ALIYUN_CLIENT_SECRET` 时按“公开客户端”走 PKCE，只发 30 天访问令牌、不能刷新，到期需在应用内重新授权；配置 Secret 后刷新令牌 90 天并自动轮换。未购买三方应用权益包的用户下载可能限速。

## 实现位置

- `lib/core/services/cloud_backup_*.dart`：
  - 通用模型与接口：`CloudBackupRemote` 的 `list` 只列 ZIP，`listFiles` 列出全部文件；
  - HTTP 层、OAuth（设备码 / PKCE / 令牌刷新）、各网盘客户端、预设目录；
  - 编排服务 `CloudBackupService`；
  - 新增网盘只需新增 `cloud_backup_<平台>.dart` 并在 `cloud_backup_drives.dart` 登记。
- 增量备份（都在 `lib/core/services/`）：
  - `cloud_backup_incremental_format.dart`：文件名与索引；
  - `_scan.dart`：扫描本机；
  - `_packs.dart`：打包与解包；
  - `_io.dart`：重试与读索引 / 快照；
  - `_prune.dart`：清单与清理规划，纯函数；
  - `_cleanup.dart`：执行清理；
  - `_state.dart`：本机状态与自动备份时机；
  - `cloud_backup_incremental.dart`：备份编排；
  - `_models.dart`：结果与回调类型；
  - `_restore.dart`：恢复编排；
  - `cloud_backup_options.dart`：位置选项；
  - `cloud_backup_service_incremental.dart`：服务的增量入口（part）；
  - 恢复的导入复用 `DataArchiveService.importFromPreparedStaging`。
- 界面（`lib/ui/settings/`）：
  - 页面：`pages/cloud_backup_page.dart`（位置列表）、`cloud_backup_target_page.dart`（单个位置）；
  - 流程：`controllers/cloud_backup_controller.dart`（完整 ZIP、授权）、`cloud_backup_incremental_flows.dart`（增量备份）、`cloud_backup_auto_scheduler.dart`（自动备份时机，在首页启动）；
  - 分组：`sections/cloud_backup_incremental_section.dart`（增量备份分组）。

## 验证状态

各网盘客户端都有按官方文档搭建的本地假服务测试（`test/core/services/cloud_backup_*_test.dart`），覆盖授权、分片上传、分页列表（含 `listFiles` 不过滤非 ZIP 文件）、下载、删除、令牌刷新与错误归类。

WebDAV 另有完整备份与增量备份的往返测试。增量备份的编排在 `cloud_backup_incremental_test.dart` 里用内存网盘覆盖：

- 去重与没有变化不上传；
- 同机恢复不下载媒体，新装恢复从包里重建；
- 合并恢复；
- 加密与换设备接上链；
- 续传与限流重试；
- 删除后的清理；
- 自动备份的时机与失败退避。**授权类网盘尚未用真实账号验证**，注册好应用后建议在真机上逐个走一遍：授权 → 测试连接 → 上传 → 刷新列表 → 恢复（合并）→ 删除。
