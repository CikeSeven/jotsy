# WebDAV 同步设计

## 目标

为 Jotsy 增加面向 NAS / 私有 WebDAV 的“备份式同步”能力：用户可在设置中配置 WebDAV 服务器，将当前完整 ZIP 备份上传到远程目录，并从远程备份列表选择恢复。该能力应复用现有 `DataArchiveService` 的 ZIP 导入/导出，保持离线优先与隐私友好，不引入公有云账号体系。

## 范围

本期实现：

- WebDAV 连接配置：服务器地址、用户名、密码/Token、远程目录。
- 测试连接：校验 URL、认证、远程目录可访问，并递归创建目标目录。
- 上传备份：导出完整 ZIP 后通过 WebDAV `PUT` 流式上传，更新远程 `manifest.json`。
- 远程列表：通过 `PROPFIND` 列出 ZIP 备份，并用 manifest 补充上传时间、大小等信息。
- 恢复备份：下载远程 ZIP 到临时文件，沿用现有导入逻辑覆盖恢复；加密 ZIP 继续要求用户输入密码。
- 删除远程备份：用户确认后删除单个远程 ZIP，并同步更新 manifest。
- NAS 适配：规范化路径、递归 `MKCOL`、兼容相对/绝对 href、处理 401/403/404/507 等常见错误。

本期不实现：

- 多端逐条合并、自动双向同步、冲突副本、删除墓碑、后台定时同步。
- 将 WebDAV 凭据写入导出的 ZIP 备份。

## 架构

### 核心服务

- `webdav_models.dart`：定义 `WebDavConfig`、`WebDavBackupEntry`、`WebDavManifest`、`WebDavException` 等纯模型与 JSON 编解码。
- `webdav_settings_service.dart`：使用已有 `SharedPreferences` 保存 WebDAV 配置。密码/Token 仅存本机设置，不进入备份包；UI 文案提示用户优先使用应用专用 Token。
- `webdav_client.dart`：封装 WebDAV 协议细节，直接使用 `dart:io` `HttpClient`，支持 `PROPFIND`、`MKCOL`、`PUT`、`GET`、`DELETE`，上传/下载均使用流，避免大备份 OOM。
- `webdav_sync_service.dart`：编排“导出 ZIP → 上传 → manifest 更新”和“下载 ZIP → 导入恢复”等业务流程。
- `app_service.dart`：暴露 `webDavSettingsServiceProvider` 与 `webDavSyncServiceProvider`。

### UI

在 `DataManagementPage` 增加“WebDAV 同步”入口，跳转到 `WebDavSyncPage`。该页负责配置表单、连接测试、上传当前备份、刷新远程列表、恢复/删除备份。所有 SnackBar 使用 `HomeHintVisibilityScope.showTrackedSnackBar`，加载态使用 `loading_indicator_m3e`，图标使用 `font_awesome_flutter`。

### 数据流

1. 用户保存配置。
2. 测试连接：`WebDavSyncService.testConnection` → `WebDavClient.ensureDirectory` → `PROPFIND`。
3. 上传：`DataArchiveService.exportToZip` 生成临时 ZIP → `WebDavClient.putFile` 上传到远程目录 → 读取/合并/写回 manifest。
4. 列表：`PROPFIND` 列出 ZIP → 读取 manifest → 合并为 `WebDavBackupEntry` 列表。
5. 恢复：下载 ZIP 到临时文件 → 判断是否加密 → 必要时提示密码 → `DataArchiveService.importFromZip` 覆盖恢复。

## 错误处理

- URL 非 HTTP/HTTPS、缺少 host、远程目录为空：本地校验失败，显示可读错误。
- 401/403：提示认证失败或无权限。
- 404：提示路径不存在；测试连接时会尝试递归创建目录。
- 507：提示 NAS 存储空间不足。
- XML 解析失败：返回空列表或可读错误，不影响上传已有备份。
- 下载/导入失败：不删除远程文件，本地导入由现有覆盖导入流程保证完整性。

## 验证

- 单元测试覆盖路径规范化、manifest 编解码、WebDAV 基本认证与流式上传/下载、PROPFIND 解析。
- 源码测试确保 WebDAV 上传/下载不使用 `readAsBytes()` 读取整包。
- Widget/源码检查覆盖设置页存在 WebDAV 入口且 SnackBar 使用统一封装。
- 完成后执行 `dart format`、`flutter gen-l10n`、`flutter analyze` 与相关 `flutter test`。
