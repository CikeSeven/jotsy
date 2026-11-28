# 存储管理

> 专题约束，与 AGENTS.md 同等效力；改动本主题前先读本文件，新规则写在这里。界面规格见 DESIGN.md §5.34。

## 入口与口径
- 必须：扫描、删除、压缩与清理只经 `StorageMediaService`；不进 `AppFeatures`（与回收站同类的工具页）。
- 必须：媒体一律按定位键匹配，禁止按绝对路径；解析不认识的引用算“在用”，禁止从存储管理删除或压缩。
- 必须：新增会引用托管媒体的数据时，同时接进存储管理的引用索引、改写规划与媒体回收。
- 必须：设备空间只经 `MediaCompressor.deviceSpace`；总览与设置首页的“已用”同一口径。
- 必须：偏好只存单个 JSON 键 `app.settings.storage_manager`，不随备份、不同步。

## 删除与压缩
- 必须：删除先移除引用、再只删已无引用的文件，禁止直接删仍被引用的文件；确认对话框写明影响范围与无法恢复。
- 必须：AI 消息的图片位置留墓碑、不前移编号；改写的行刷新修改时间，以便同步带到对端。
- 必须：有编辑阻塞者或撤销提示未关闭时拒绝写入。
- 必须：压缩只在 `AppPlatform.supportsMediaCompression`（Android）；禁止原地改写托管文件，输出写到新路径，不到原文件 90% 即丢弃。
- 必须：不压动图、带透明的图、小于 300 KB 的文件与已够小的视频；预计节省一律写“约”。
- 禁止：删除 `proguard-rules.pro` 保留 Media3 `LogSessionId` 字段的规则（Android 7–11 压视频会闪退）；Media3 须与 `video_player_android` 同版本，升级后在发布包复查。
- 必须：查看媒体只经 `openStorageMedia`（图片经 `openImageViewer`）；打码项不提供查看。

## 重复文件
- 必须：重复只按内容逐字节相同（sha256）判定；查找与合并只经 `StorageMediaService.findDuplicates` / `mergeDuplicates`，规则只在 `storage_duplicates.dart`；禁止按文件名、尺寸或画面相似度合并。
- 必须：一处引用只能改指向它允许的托管目录（`managedMediaShareableDirectories`，与备份恢复重绑路径的范围一致）：正文、留言与 AI 图片只在 `diary_images/`，封面在 `diary_covers/` 或 `diary_images/`，视频与附件两个目录互通，录音只在 `diary_recordings/`；改恢复重绑范围或新增引用类型时同步改这里。
- 必须：合并与删除同一条链路（守卫 → `ManagedMediaWriteGate.exclusive` → 串行队列里重新读取引用、重新规划 → 一次事务改写 → 只删已无引用的副本）；执行前按文件内容直接重算哈希核对，不信缓存。
- 必须：有不知道怎么改写的引用（`StorageOtherRef`）的副本不能被并掉，只能当保留的那份；保留哪份按“释放最多 → 在 `diary_images/` 或 `diary_videos/` → 引用多 → 修改时间早 → 定位键小”决定。
- 必须：哈希缓存只经 `ManagedMediaContentIndex`（`<数据根>/media_dedup_state/`，不随备份、不同步），只给同一目录范围里大小相同的文件算。
- 必须：重复文件页的缩略图按整组最公开的一档打码，每份副本的标题与日期按它自己的引用打码。
- 禁止：自动合并；合并只由用户在存储管理发起并确认（改写的日记会同步到对端）。

## 清理与宽限期
- 必须：清理不需确认、只清安全的：缓存只删一小时内未改动的条目，各类暂存与同步 / 网盘状态目录一律不碰。
- 必须：未使用的文件一次清完；数据库空闲页 ≥ 1 MB 才提供整理；“可释放”与实际清理同一口径。
- 必须：零宽限期只在存储管理的删除与清理里成立，须持 `ManagedMediaWriteGate.exclusive`，等不到即什么都不删。
- 必须：“先放文件、后写引用”的后台流程（同步、HEIC 修复、压缩等）必须整段包进 `ManagedMediaWriteGate.write`。
- 必须：自动回收不经闸门，保留 24 小时宽限期。

## 隐私
- 必须：只出现在私密日记或私密本子封面里的媒体默认打码，“显示”只在本页生效，涉及上锁日记本先经 `IdentityVerifier`。
- 必须：只在未解封胶囊里的媒体永远打码；在任一公开处出现过的不打码；打码项仍可删除与压缩。

## 桌面端数据目录与迁移
- 必须：桌面端（`AppPlatform.supportsCustomDataDirectory`）活动数据根目录只经 `appDataRootDirectory()` / `AppDataLocationStore` 解析，字体目录只经 `appFontsBaseDirectory()`，禁止在服务或 UI 中绕过它们自拼默认应用支持目录路径；`shared_preferences.json`、用户指针 `data_location.json` 与窗口状态 `window_state.json` 始终保留在系统默认 `getApplicationSupportDirectory()`（恢复默认位置检查时放行）。
- 必须：解析优先级严格为“用户显式配置（`data_location.json`）> 默认目录已存在 `node_diary.sqlite` 兼容保护 > 可执行文件旁 `jotsy_data_location.json` 预设/便携配置 > 系统默认目录”；不得覆盖已存在的默认目录老库。
- 必须：目标目录不可选在应用安装目录及其 `data/` 运行时子目录内（与 Windows 安装包 `[InstallDelete]` 互斥），也不得与当前目录相同或互为嵌套父子目录。
- 必须：跨卷/跨目录迁移采用“预检可写 → 整库拷贝与逐文件流式校验 → 无 `updatedAt`/`editedAt` 副作用地重绑 SQLite 与草稿绝对媒体路径 → 原子写入 `.jotsy_data_root.json` 与 `data_location.json` → 校验失败回滚目标”的四段事务；待迁移或未完成迁移通过 `AppDataLocationBootstrapper` 在启动时兜底完成并清缓存重载作用域。
