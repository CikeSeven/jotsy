# 局域网同步（LAN Sync）设计规格

> 状态：已实现（Android、Linux、Windows；macOS 可编译）。本文是各模块的共同依据：数据模型、合并规则、协议与状态存储以此为准；改动实现前先改本文再改代码。协作规则见 AGENTS.md §6“局域网同步”，界面规格见 DESIGN.md §5.28。

## 0. 目标与边界

- 同一局域网内的 Jotsy（Android、Linux、Windows；macOS 可编译，iOS 不支持——`AppPlatform.supportsLanSync`）互相发现、配对后双向同步全部日记数据。
- 时机：同步页里手动“立即同步”；应用在前台时与已配对设备自动同步（不做后台常驻）。
- 同步范围：日记（含回收站中的）、标签、日记本（含成员、书序、层级）、留言、日记模板（含改过的内置模板）、纪念日、这天的心情、托管媒体；设置为可选（两端都开启才同步）。
- **不同步**：草稿（单台设备上未完成的工作；发布即删除，两台都发布会重复；载荷带本机标签 id）、导入的字体文件（设置里只带字体 id，缺失回落内置字体）、心情选项 `mood_options`、本机偏好（不随备份导出的那些键）、网盘凭据、应用锁开关。
- 同步不是导入：不走 `chooseBackupImportMode`，不复用 `BackupMerge` 的合并/覆盖模式，也不调用 UI 写库函数（它们会改写 `updatedAt`、清掉归档/删除标记等）。

## 1. 模块与文件归属

| 路径 | 职责 |
|---|---|
| `lib/core/services/lan_sync/sync/sync_model.dart` | `SyncEntity`、`SyncKey`、`SyncRecord`、`SyncManifest`、规范 JSON 与哈希 |
| `lib/core/services/lan_sync/sync/sync_canonical_{diary,notebook,misc,settings,support}.dart`、`sync_media_refs.dart`；原始行 `lib/core/database/sync_rows.dart` | 数据库行 ↔ 规范记录（含反向列值）、媒体路径归一；可送进 isolate 的纯 Dart 原始行 |
| `lib/core/services/lan_sync/sync/sync_local_state.dart`、`sync_state_model.dart`（纯 Dart）、`sync_state_fold.dart`（纯 Dart）、`sync_state_json.dart`、`sync_state_files.dart`、`sync_manifest_builder.dart`、`sync_hash_cache.dart`、`sync_media_index.dart` | 检查点、分面历史、墓碑、标签改名、哈希缓存、媒体索引 |
| `lib/core/services/lan_sync/sync/sync_planner.dart`（+ `_keys` / `_decide` / `_merge` / `_revive` / `_copies` / `_tags` / `_notebooks` / `_lists` / `_output` / `_values`）、`sync_plan.dart`、`sync_plan_side.dart`；本机一侧适配器 `sync_local_plan_side.dart` | 合并判定（纯函数）：按需取数、产出双方的写入计划 |
| `lib/core/database/app_database_sync_ops.dart`（读）、`app_database_sync_writes.dart`（`_AppDatabaseSyncWrites`：按原值写入、关联清理）、`app_database_sync_order.dart`（`_AppDatabaseSyncOrder`：顺序列表重排） | 读规范行；由写入层放进同一个事务的按原值写入与关联清理 |
| `lib/core/services/lan_sync/sync/sync_apply.dart`（+ `_writes` / `_settings` / `_result`）、`sync_media.dart`、`sync_media_library.dart`、`sync_media_rekey.dart` | 写入编排（`SyncApplier`）、媒体暂存与就位（`SyncMediaStaging`）、发送与改键照做（`SyncMediaLibrary`）、写入后更新本机状态 |
| `lib/core/services/lan_sync/lan_sync_identity.dart`、`lan_sync_crypto.dart`、`lan_sync_frames.dart`、`lan_sync_handshake.dart`（+ `_types` / `_flows` / `_sas`）、`lan_sync_channel.dart`（+ `_types` / `_inbound` / `_outlet`）、`lan_sync_messages.dart`、`lan_sync_qr_payload.dart` | 身份、密码学原语、长度前缀帧、握手与配对、加密信道、消息信封、二维码载荷 |
| `lib/core/services/lan_sync/lan_sync_discovery.dart`、`lan_sync_network.dart`、`lan_sync_state_directory.dart` | UDP 信标与在线表、本机地址、原生通道、不备份的状态目录 |
| `lib/core/services/editing_session_registry.dart`（`EditingSessionRegistry`、拖动排序用的 `ReorderEditingGuard`）、`lib/ui/widgets/editing_session_blocker.dart`（`EditingSessionBlocker`）、`lib/app/synced_data_refresh.dart`（`syncedDataRefreshProvider`） | 编辑会话 / 冲刷者 / 撤销窗口登记、“同步已写入”事件与写入后的失效（§7） |
| `lib/core/services/lan_sync/lan_sync_session.dart`（+ `_inbox` / `_initiator` / `_planning` / `_media` / `_responder`）、`lan_sync_session_{types,context,protocol,plan_wire}.dart`、`lan_sync_failure.dart`；`lan_sync_service.dart`（+ `_lifecycle` / `_server` / `_outgoing` / `_pairing` / `_sessions` / `_discovery` / `_types`）、`lan_sync_service_config.dart`、`lan_sync_auto_scheduler.dart`；`lan_sync_store.dart`、`lan_sync_store_models.dart`、`lan_sync_session_record.dart` | 会话状态机与消息（§5.3）、服务端 / 发现 / 配对 / 自动同步（§9）、配对设备与偏好、同步记录 |
| `lib/ui/lan_sync/models/lan_sync_ui_controller.dart`（`LanSyncUiController`）、`lan_sync_view_state.dart`、`lan_sync_ui_events.dart`、`lan_sync_session_view.dart`、`lan_sync_session_summary.dart`、`lan_sync_qr_ticket.dart`、`lan_sync_platform.dart`、`lan_sync_address_input.dart`、`lan_sync_pairing_auth.dart`、`lan_sync_qr_matrix.dart` | 界面接口与视图模型（界面只认这些类型，不直接引用引擎） |
| `lib/ui/lan_sync/models/lan_sync_engine_mapping.dart`、`lan_sync_engine_events.dart` | 引擎状态 / 事件 / 失败原因 → 界面模型的纯换算（对照见 `lan_sync_service.dart` 顶部） |
| `lib/ui/lan_sync/controllers/engine_lan_sync_ui_controller.dart`（+ `_link`）、`inert_lan_sync_ui_controller.dart` | 真正的控制器（包着 `LanSyncService`，异步启动窗口内排队指令）；不支持的平台为不联网的空实现 |
| `lib/ui/lan_sync/providers/lan_sync_providers.dart`、`lan_sync_engine_assembly.dart` | `lanSyncControllerProvider`（挂 `AppLifecycleListener` 跟随前后台，`NodeDiaryApp` 启动时即常驻监听）；生产装配 `createAppLanSyncService`（解析数据根与状态目录、应用版本、本地化的冲突副本后缀） |
| `lib/ui/lan_sync/controllers/`（其余）、`pages/`、`sections/`、`widgets/`；入口 `lib/ui/settings/sections/settings_lan_sync_tile.dart` | 页面可见性与 attach / detach、配对 / 会话 / 页面流程、配对前身份验证、自动同步提示；同步页、设备详情页、扫码页及其区块（DESIGN.md §5.28） |
| `android/app/src/main/kotlin/com/jotsy/diary/LanSyncChannel.kt` | `com.jotsy.diary/lan_sync`：组播锁、设备名、`noBackupFilesDir` |

所有同步引擎类都通过构造参数注入数据库（`AppDatabase`）、数据根目录（`Directory dataRoot`，对应 `appDataRootDirectory()`）、状态目录（`Directory stateDir`）与 `SettingsService`，**不在引擎内部调用 `appDataRootDirectory()` / path_provider**：端到端测试要在一个进程里跑两台“设备”。只有生产装配 `createAppLanSyncService`（`lib/ui/lan_sync/providers/lan_sync_engine_assembly.dart`）解析真实目录（`appDataRootDirectory()` 与 `lanSyncStateDirectory()`）。

## 2. 规范记录

### 2.1 基本类型（`sync_model.dart`）

```dart
const int kSyncFormatVersion = 1;

enum SyncEntity { diary, tag, notebook, membership, orderList, comment, template, anniversary, dayMood, settings }

/// 记录身份：实体 + 业务 id。字符串形式 `<entity>:<id>`（entity 用枚举名）。
class SyncKey { final SyncEntity entity; final String id; }

/// 一条规范记录：分面名 → 规范 JSON 值（已做媒体路径归一，见 2.3）。
class SyncRecord {
  final SyncKey key;
  final Map<String, Object?> facets;
  Map<String, String> get hashes; // 分面名 → 哈希
}

/// 清单：每条记录各分面的哈希。
class SyncManifest {
  final int formatVersion;
  final Map<SyncKey, Map<String, String>> entries;
}
```

- **规范 JSON**：对象键按 UTF-16 码元升序、无空白（`jsonEncode` 前递归排序）；时间一律为 UTC 毫秒整数（库里是秒，乘 1000）；布尔、整数原样；可空字段显式写 `null`（不省略，保证两边结构一致）。
- **哈希**：`sha256(utf8(规范 JSON))` 取前 16 字节，小写十六进制（32 字符）。
- 规范化必须是**幂等且跨设备确定**的：A 的记录写入 B 后，B 读出的规范记录与 A 的逐字节相同（测试兜底，含历史 Delta / 旧节点格式的正文、胶囊、带附件的 metadata）。
- 规范形式（分面组成、归一规则、哈希）一旦改变必须提升 `kSyncFormatVersion`（版本不同的设备握手时互相拒绝）；只修正本机实现、不改协议时提升 `kSyncCanonicalRevision`（`sync_hash_cache.dart`），让哈希缓存整份作废重算。

### 2.2 实体与分面

| 实体 | id | 分面：字段 |
|---|---|---|
| diary | `diaryId` | **content**：`title`、`content`（正文块文档对象：`decodeStoredDiaryBlocks` 后再经 `liftHiddenDiaryBlockChildren`（Delta 转换的结果不经过这一步，写回再读时会被提起，必须一开始就提好）、归一；历史格式由此转为块文档）、`cover`、`metadata`（对象；去掉本机 `tagIds`、去掉 `capsule`）、`createdAt`<br>**stamp**：`updatedAt`<br>**pin**：`pinned`<br>**archive**：`archived`、`archivedAt`<br>**trash**：`deleted`、`deletedAt`<br>**capsule**：`unlockAt`、`lockedAt`、`meta`（`metadata.capsule`，没有为 null）<br>**tags**：`names`（排序后的标签名列表） |
| tag | 标签名 | **color**：`color` |
| notebook | `notebookId` | **definition**：`name`、`kind`、`visibility`、`payload`（库中原始 JSON 解析后的对象，键排序、封面路径归一；**不要**经 `NotebookPayload.decode` 再编码，它会丢掉认不出的键）、`pinned`、`closed`、`parentId`、`createdAt`、`updatedAt` |
| membership | `<notebookId>|<diaryId>` | **main**：`chapterId`、`addedAt`（只有手动日记本有成员——按 `kind` 列原始值为 `manual` 判断，与 `acceptsManualEntries` 同一口径；智能本的残留关联行与日记已不在的悬空行忽略；位置不在这里） |
| orderList | `shelf` / `templates` / `book:<notebookId>` | **items**：`ids`（书架：全部日记本按 `sortOrder`、同值按本地 id（应用的 `_notebookManualOrder`，不看置顶——置顶是 definition 的 `pinned`）；模板：只含用户模板（不含 `builtin.*`：改过的内置模板按内置顺序显示、不看 `sort_order`），按 `sortOrder`、同值按本地 id（`_templateOrder`）；书序：手动日记本内日记按 `position`、`addedAt`、日记本地 id（`_entriesInOrder`）的业务 id 列表。平手只在从未排序过的数据上出现，写入层按列表重排为 0..n-1 后两端不再有平手。`shelf`、`templates` 总是存在（可为空列表），每本手动日记本都有 `book:<id>`（空本为空列表），智能本没有） |
| comment | `commentId` | **main**：`diaryId`、`content`、`mood`、`createdAt`、`editedAt` |
| template | `templateId`（含 `builtin.*`） | **main**：`name`、`payload`（库中原始 JSON 解析后的对象，键排序；保存时已经白名单重建，读取时应用自己再经 `sanitizeDiaryTemplateBlocks`，同步层在 core 不引用 UI 模块的清理函数、原样搬运）、`createdAt`、`updatedAt` |
| anniversary | `anniversaryId` | **main**：全部业务列（含 `metadata` 对象、`linkedDiaryId`、`pinned`、`createdAt`、`updatedAt`） |
| dayMood | `YYYY-MM-DD` | **main**：`mood`（原始字符串，认不出的枚举名原样）、`updatedAt` |
| settings | `settings` | 每个设置键一个分面，值为 `{ "value": … }`；键集合 = `BackupSettings.capture` 的键，去掉 `appLockEnabled`、`rememberedTagFilterIdsRaw`；`tagOrderRaw` 换成分面 `tagOrderNames`（按名称的列表）；`appSurfaceRaw` 里的背景文件名（`global.image` 与 `areas.<区域>.background.image`，与 `referencedImages` 同一范围）换成媒体引用 `jotsy-media:app_backgrounds/<文件名>`，整串按规范 JSON 重新编码。只在两端都开启“同步设置”时参与。 |

- `content_text` 由正文推出、不参与哈希；写入时由（还原路径后的）正文经 `diaryBlocksPlainText` 重新生成（与预览页待办保存、导入写库同一口径）。
- 按列长截断：日记标题 200、标签名 40、日记本名 60、纪念日标题 100（按 UTF-16 码元，不切开代理对）。规范化（读）与写回两个方向都截断：正常数据本来不超长，两边口径一致才能保证超长的坏数据写到对方后规范值仍相同。
- 应当是 JSON 对象的列（日记 metadata、日记本 / 模板 payload、纪念日 metadata）解析不成对象时，规范值里保留原文字符串、写回时原样写回，不把坏数据“修”成空对象。
- 日记的 `updatedAt` 单独成 stamp 分面，合并取较大值，从不判为冲突。

### 2.3 媒体路径归一

- 与 `DiaryMediaReferences`（`lib/core/services/diary_media_references.dart`）同一口径：遍历规范值中的每个字符串（只有提到托管目录名的字符串才处理）；字符串本身是 JSON 对象/数组时解码、递归处理后再按规范 JSON 编码回字符串；**整串**是托管媒体路径（绝对路径或 `file:` URI，且 `diaryMediaKeyOf` 非空）时替换为 `jotsy-media:<键>`（键形如 `diary_images/media_x/a.jpg`）。
- 写入时把 `jotsy-media:<键>` 换回本机 `<dataRoot>/<键>`（平台路径分隔符），原来是 `file:` URI 的也写成本机绝对路径。
- 归一只作用于可能存放媒体的列：日记的正文、封面、metadata 与胶囊块，日记本与模板的 payload，纪念日的 metadata，设置值；标题、名称、备注、留言正文这类用户文字不改写。
- 设置背景：`jotsy-media:app_backgrounds/<文件名>` 只在 settings 记录里出现，写入时还原为文件名（文件名须通过 `AppBackgroundStorageService.isValidName`）。
- 还原时键必须满足 `diaryMediaKeyOf(键) == 键`（以托管目录开头、无 `..`），否则原样保留，防止拼出数据根之外的路径。
- 一条记录引用的媒体键集合由同一遍历得出（`SyncRecord` 的派生信息），供传输阶段使用。

## 3. 本机同步状态（`stateDir`，不随系统备份克隆）

`stateDir`：Android 为 `noBackupFilesDir/lan_sync/`（原生通道取得），桌面为应用支持目录下 `lan_sync/`；测试注入临时目录。全部文件写临时文件后原子改名。

| 文件 | 内容 |
|---|---|
| `identity.json` | `{v:1, deviceId（UUID v4）, ed25519Seed（base64）, createdAt（UTC 毫秒）}`；不使用静态 X25519（握手只用临时 X25519） |
| `store.json` | 偏好（设备名、可被发现、自动同步、同步设置）、已配对设备（deviceId、名称、平台、身份公钥、配对时间、上次同步、上次地址与端口、单设备自动同步、备注名，以及按设备的标记 `needsAttention`（自动同步遇到需要确认）与 `restoredPending`（覆盖恢复之后还没和它成功同步过））；不放 SharedPreferences、不进备份 |
| `checkpoint.json.gz` | 上次会话时的本机观测：清单 + tags / orderList 分面的当前值（下次进历史时要用旧值）+ 标签名 → 本地 id 映射 + 观测覆盖的实体集合 |
| `history.json.gz` | 分面历史：`SyncKey → 分面 → [{hash, value?, seenAt}]`，每分面最多 8 条，新的在前；tags 与 orderList 分面同时记录值 |
| `tombstones.json.gz` | 墓碑：`SyncKey → {deletedAt, known: 分面 → [哈希…]}`（删除时的当前哈希 + 历史）；超过 365 天或超过 50 000 条时按时间淘汰 |
| `renames.json.gz` | 标签改名记录：旧名 → 新名、时间（随墓碑同样淘汰） |
| `hash_cache.json.gz` | 记录键 → [原始列指纹（行原始列值的 sha256 前 16 字节）, 规范分面哈希]；按键索引、整份重写，天然只留当前存在的行；带 `kSyncFormatVersion` 与 `kSyncCanonicalRevision`，不符即作废。只缓存要解码的行（日记的行分面、日记本、模板、纪念日），其余每次现算 |
| `media_index.json.gz` | 媒体键 → 大小、修改时间、sha256（大小或修改时间变了就重算） |
| `sessions.json` | 最近 50 次同步记录（时间、用时（不含等用户确认）、自动与否、收到 / 发出的日记篇数与其他变化条数、媒体字节数、冲突副本数、是否首次、失败原因） |

- **刷新检查点**（每次会话开始时，在冲刷编辑会话之后）：算出当前清单 C，与检查点 P 比较——
  - P、C 都有且某分面哈希不同：把 P 中的旧哈希（及 tags / orderList 的旧值）插到该分面历史最前，`seenAt` 为当前时间；
  - P 有、C 没有：写墓碑（`known` = P 中各分面哈希 + 各分面历史）；tag 若同一本地 id 在 C 里换了名字，记为改名（旧名 → 新名），旧名仍写墓碑；
  - C 有、P 没有：新记录，无历史；本机若还有它的墓碑或改名记录（删了又建回同名记录）一并去掉——墓碑只描述本机“现在没有”的记录；
  - 写墓碑时该键的历史并进 `known`、不再单独保留；历史按哈希去重（同一哈希只留最新的一条）；已有指向旧名的改名（x → 旧名）顺带改指向新名，规划器只需查一跳；
  - 只比较本次观测到的实体：没请求 settings 时，检查点里 settings 的旧条目原样保留，不当作删除；
  - 然后检查点 := C。
  - 先写历史、墓碑、改名，最后写检查点：中途失败时检查点仍是旧的，下次刷新把同一份差异再折一遍，结果相同。
  - 状态文件读不出（不存在、解压或解析失败）一律当作空并 debugPrint：丢了这些“记忆”只会让规划多判冲突、按并集合并，删除不传播，最坏是多出数据、不会丢数据。
- 写入后（第 6 节）同一套规则以写入后的清单更新历史、墓碑与检查点：被同步删掉的记录写墓碑，被替换的值进入历史。被替换的值进历史时的 `seenAt` 一般为当前时间，但直接采纳了另一侧值的分面继承那个值在来源一侧的确立时间（§4.1.1）：`foldSyncObservation` 的 `seenAtOverrides` 已支持，`SyncLocalState.recordAppliedState(after, historySeenAt: …)` 传下去，写入层负责把这一侧计划的 `SyncSidePlan.historySeenAt` 原样传入。
- **哈希缓存**：计算清单时先算每行原始列的指纹（便宜），命中缓存直接取分面哈希，未命中才做规范化（解码正文、归一路径、编码），整体在 `Isolate.run` 中进行；缓存只保留当前存在的行。
- **覆盖恢复**：`DataArchiveService` 的 replaceAll 成功后通知 `DataArchiveService.replacedAllListeners`（`LanSyncService` 启动时登记 `noteDataReplacedByRestore`，不支持局域网同步的平台不登记）：取消正在进行的会话，删除检查点、历史、墓碑、改名、哈希缓存（`resetAfterRestore()`），并给当时全部已配对设备置 `restoredPending`（按设备记，与那台成功同步一次后清除）。之后与每台设备的第一次同步走“以哪边为准”（4.5）；恢复之后才配对的设备本来就是首次同步。
- **身份**：`identity.json` 缺失或内容损坏时重新生成（`LanSyncIdentityStore.loadOrCreate()` 返回 `created: true`），调用方据此清空已配对设备与上述同步状态（视为一台新设备）；读文件本身的 I/O 错误（权限等）照常抛出，不当作损坏。

## 4. 合并判定（规划器，`sync_planner*.dart`）

发起方是唯一规划者：持有双方清单、所需完整记录、双方相关键的历史与墓碑，产出 `SyncPlan`（双方各一份写入列表 + 统计 + 需要用户确认的事项）。规划器（`sync_planner.dart` 及其 part 文件、`sync_plan.dart`、`sync_plan_side.dart`）是纯函数：不碰数据库、文件、时钟与随机数，遍历一律按 `SyncKey` 排序，同一份输入得到逐项相同的计划（中断后重新规划得到同一个副本 id）。

记号：L = 本机（发起方）分面哈希，R = 对方分面哈希，H_L / H_R = 双方该分面历史（哈希集合）。

### 4.0 两段规划与按需取数
- 会话层反复调用 `planSyncFetch(local, remote, options)`，按返回的 `SyncFetchRequest` 取数（对方的历史 `history.get`、墓碑详情、记录 `records.get`；本机记录经 `buildRecords`），直到 `isEmpty`，再调用 `planSync`。两者跑同一条流水线，区别只在缺数据时：前者记下要取的数据、跳过依赖它的判定，后者抛 `StateError`。两侧以 `SyncPlanSide` 表示：本机为 `SyncLocalPlanSide`（`sync_local_plan_side.dart`，适配 `SyncLocalSnapshot`；历史、墓碑详情恒可答，`hasHistory` 恒为 true；本机记录经它的 `loadRecords(SyncLocalState, keys)` 构建）；对方为 `SyncPlanSideData`，清单、墓碑键与改名随清单送达，其余边取边填。
- 只取判定真正用到的数据，每段结束时若还缺数据就停下（后一段依赖前一段的完整结果，提前往下走只会猜着取）：
  - 两侧哈希全同：什么都不取；
  - 两侧都有、某个非 stamp 分面不同：取对方这个键的历史（全部分面）；判定后只取“值确实要用”的一侧记录——全部分面都取同一侧时只取那一侧，stamp 不同或真冲突时两侧都取；
  - 只有本机有：对方有墓碑时先取墓碑详情，覆盖即删除、不再取记录；否则构建本机记录；
  - 只有对方有：本机墓碑覆盖时什么都不取（删除只要清单）；否则取对方记录；
  - 第二段（跨键）：复活的日记 / 日记本在保留一侧的成员关系、被一并删除的留言（读所属日记）、改过的纪念日；冲突副本败方的成员关系；
  - 第三段（收尾，多为本机记录）：有日记本变化时两侧原样的日记本（层级校验）、所在日记本有变化时两侧原样的成员关系（章节校验）、集合有变化的两侧原样的顺序列表、有标签只在一侧时的 settings、被引用而改判保留的标签。
  - 两侧原样的值一律读本机记录，不走网络。典型同步（只有编辑）两次网络往返；复活、冲突副本、被引用的标签最多各加一次。

### 4.1 两边都有的记录，逐分面
1. L == R：不动。
2. 一侧缺少该分面（只会来自规范形式不同的版本，如更新版本多出的设置键）：有值的一侧胜出，不算冲突——取有值的一侧从不丢数据，写入层也表达不了“去掉一个分面”。
3. R ∈ H_L 而 L ∉ H_R：L 是 R 的后代 → 取 L（推给对方）；L ∈ H_R 而 R ∉ H_L：取 R（写到本机）。
4. R ∈ H_L 且 L ∈ H_R（来回改过：A → B → A）：取**当前值确立时间**（历史头条的 `seenAt`）较晚的一侧，平手按 deviceId 较大者。见 4.1.1。
5. 否则真冲突：
   - diary.content：stamp 较新者（平手按 deviceId 字典序较大者）留在原 id；另一份写成**冲突副本**：新 `diaryId = UUIDv5(kSyncConflictCopyNamespace, 原 diaryId + 败方 content 哈希)`（两串直接拼接；只由数据决定，中断重试、换一台发起方都得到同一个 id）；标题 = 原标题 + 本地化后缀（由调用方传入，按败方选：败方是本机（发起方）用 `SyncPlanOptions.localLoserTitleSuffix`，是对方用 `remoteLoserTitleSuffix`，写的是副本所保存版本那一台的设备名，如“（冲突副本 · ThinkPad）”；后缀不影响副本 id），截断到 200 个 UTF-16 码元、不切开代理对；metadata 加 `sync.conflictOf = 原 diaryId`（metadata 是坏数据原文时原样保留）；副本继承**败方**的 stamp、tags、日记本成员（含章节）、capsule、archive、trash、pin 分面——私密日记本里的内容不能因副本而出现在全部日记，未解封的胶囊不能提前解封。副本 id 在任一侧已存在（上次同步只写了一侧）或任一侧有它的墓碑（用户看过并删掉了）时不再生成，已存在的作为普通记录照常复制。副本与它的成员关系两侧都是新增；书序里新副本排在原日记之后。原 id 的其余分面照常逐分面判定。
   - diary.tags、orderList.items：取双方历史中最近的共同祖先值（同一哈希出现在两边历史里且带值，取两边 `seenAt` 中较大者最新的，再平手按哈希）做三方合并。集合：祖先 ∪ 双方新增 − 任一方删除。列表：去掉任一方删除的项；双方都保留的项的相对顺序——只有一方调整过（与祖先不同）就用那一方的，双方都调整过用主侧的，都没调整即祖先顺序；再依次把主侧、次侧的新增项按各自的相对位置插入（插在它在自己列表里最近的、已在结果中的前一项之后，没有就放最前）。找不到共同祖先时取并集（集合直接并；列表：主侧顺序 + 次侧独有项按次侧顺序追加）。主侧 = 变化时间较新的一侧（规则同下面“其他分面”，平手按 deviceId），与谁发起同步无关。（原文“保留祖先顺序”“按 L / R 的相对位置”在只有一方拖动过时会丢掉那次拖动、且结果随发起方而变，故作此解释。）
   - diary.stamp：取较大值（不是冲突）。content 的最终值与某一侧当前值不同、而最终 stamp 恰等于那一侧的当前值时 +1000 毫秒（库里按秒存），保证各处按 `diaryId + updatedAt` 的缓存失效；抬高后大于两侧。
   - 其他分面：取该分面“变化时间”较新的一方——历史头条的 `seenAt`；没有历史时用记录自身时间字段（日记：archive 用 `archivedAt`、trash 用 `deletedAt`、capsule 用 `lockedAt`，缺省及其余分面用 stamp；日记本 `definition.updatedAt`；成员 `addedAt`；留言 `editedAt ?? createdAt`；模板、纪念日、心情 `updatedAt`；标签、顺序列表、设置为 0）——平手按 deviceId 较大者。

#### 4.1.1 历史时间继承（收敛性修正）
- **规则**：同步写入之后折叠时，凡是直接采纳了另一侧原值的分面（取一侧、变化时间较新者、正文胜方、合并结果恰好等于一侧原值），被换掉的旧值进历史时的 `seenAt` 不用写入时刻，而用那个值在来源一侧的确立时间（来源一侧的历史头条 `seenAt`，没有历史时用上面的记录时间字段）；合并出的新值、由从属关系改出的值（章节置 null、关联置 null、层级断开、改名换名、列表校正）照常用写入时刻。规划器在 `SyncSidePlan.historySeenAt`（键 → 分面 → 毫秒）给出，写入后的折叠已支持（`foldSyncObservation` 的 `seenAtOverrides`，经 `SyncLocalState.recordAppliedState(after, historySeenAt: …)`；第 3 节“写入后”），写入层负责把这一侧计划的 `historySeenAt` 原样传入。
- **为什么**：原规则在 R ∈ H_L 且 L ∈ H_R 时比较“谁离开对方当前值更晚”，而每次同步采纳都会把旧值以写入时刻记进历史，采纳者立刻成为“最晚离开者”。收敛模拟在 3–5 台设备时找到了不收敛的情形，最小复现：四台设备 a、b 的 pin 为 true（历史里有 false，seenAt 996 / 1000），c、d 为 false（历史里有 true，seenAt 994 / 1005），按 (a,c) (a,d) (b,d) (c,d) (a,b) (b,c) 循环同步——每一对都“正确”地判给较晚的一方，但败方采纳后又成了最晚的，四台的值每轮整体翻转，永远不收敛（`test/core/services/lan_sync/sync/sync_planner_convergence_test.dart` 保留了这个复现）。
- **修复后**：同一个值在所有设备上的确立时间相同（采纳时继承），4.1 第 4 条与“其他分面”的冲突都等价于按值确立时间的后写者胜（LWW），与经过哪些设备、谁发起无关，因而收敛；两台设备之间“改回旧值”仍是后改的一侧胜出。只改第 4 条的比较方式（不继承）仍会翻转；只继承而保留“离开时间”的比较，在有中间值时离开时间不等于确立时间，二者一起才成立。

### 4.2 只有一边有的记录
- 设缺失一方对该键有墓碑 T（对方的墓碑详情按需取）：
  - 在场一方**每个分面**的哈希都在 `T.known` 对应分面里（它没在删除之后改过）→ 删除传播到在场一方；
  - 否则（在场一方删除后又改过，或两边无关）→ 保留，复制给缺失一方（“改过的赢”），记为复活（4.3）。
- 缺失一方没有墓碑 → 新记录，复制。
- 缺少某类实体（不在两侧共同的实体集合里）、对方不提供设置：整类跳过，从不视为删除。
- tag：
  - 还被任何最终日记引用的标签名不删（改判保留并复制）。“最终日记”指不是两侧原样的日记（含复活的、冲突副本）；两侧原样的日记引用的标签两侧都有，不会被判删除。
  - 改名：一侧 X 的 `renames` 有 旧名 → 新名，且 X 已经没有旧名、有新名时生效（两侧把同一个旧名改成不同新名时取改名时间较新者，平手按 deviceId；跨侧的链 a → b、b → c 沿链解析为 a → c，成环的整条不生效）。生效的改名作用于全部最终日记的 tags 分面（旧名换成新名，包括对方在改名之后才打上旧名的日记——否则旧名会被它们“引用”而重新出现）；对方 Y 还有旧名、没有新名，且最终只剩新名时，Y **原地改名**（`SyncTagRenameOp`，保持本地 id，见 6.3），代替 Y 上“删旧名 + 建新名”两条写入。Y 在改名之后改过旧名的颜色时，旧名作为“删除后改过”的记录保留，Y 另建新名、不原地改名，日记上的旧名照样换成新名。
  - settings 的 `tagOrderNames`：写入后各侧由本机标签表重新推出（本地 id → 名称，查不到的丢掉），所以最终值按改名换名、只留最终存在的标签、去重；只在有标签只在一侧时才可能变化。

### 4.3 从属与复活
- 复活（4.2 中缺失一侧有墓碑却“保留并复制”的记录）时，它的从属按保留一方为准：日记 → 它在保留一侧的成员关系、留言（被墓碑覆盖的也改判保留）、指向它的纪念日关联（最终值里恢复 `linkedDiaryId`）；tags 分面随记录本身；日记本 → 它在保留一侧的成员关系、书序列表、在保留一侧挂在它下面的子本的 `parentId`。没有墓碑的新记录不必特殊处理：它的从属在缺失一侧本来就没有墓碑。
- 给已被对方删除的日记新增或修改留言，算作对日记的修改：保留下来的留言（不是两侧原样的）指向判为删除的日记时，该日记改判复活（连同上面的从属）。成员关系、书序列表、纪念日的改动不复活日记 / 日记本，它们随日记 / 日记本不存在而丢弃。
- 最终状态里日记或日记本不存在、或日记本不是手动本（`kind` 原始值）的成员关系、书序项一律丢弃；留言所属日记不存在时丢弃；纪念日 `linkedDiaryId` 指向不存在的日记时置 null。只检查不是两侧原样的记录：两侧原样的成员 / 留言 / 纪念日引用的日记与日记本在两侧都在（删除时会一并清理），最终也一定还在。
- 智能日记本没有成员与书序；成员的 `chapterId` 不在目标日记本最终章节里时写 null（章节口径同 `NotebookPayload.chapterIds`：id 与标题去掉首尾空白后非空，比较去掉空白后的 id）。检查范围：不是两侧原样的成员关系，以及所在日记本不是两侧原样的全部成员关系（两侧原样的读本机记录）。
- 顺序列表恰好是最终集合：书架 = 全部最终日记本；我的模板 = 全部最终用户模板（不含 `builtin.*`）；书序 = 这本最终手动本的最终成员。先按 4.1 / 4.2 定出底（复活日记本的书序以保留一侧为准；判为删除但日记本最终仍是手动本的，以在场一侧的列表为底），去掉不在集合里的 id、去重，再补上缺的：新冲突副本插在原日记之后（同一原日记的多份按 id 排序），其余按 id 排序追加到末尾。两侧原样、且最终集合与两侧现有集合（由清单的键算出，不必读值）都相同的列表不动。

### 4.4 日记本层级
在最终日记本集合上按 `NotebookHierarchy`（`lib/core/database/app_database_notebook_hierarchy.dart`）口径校验——它基于 Drift 的 `NotebookRow`，纯 Dart 的规划器按同一规则重写，测试与 `NotebookHierarchy.repairs` 对拍：上级须存在、为手动本、不是自己；成环时环上的每一本都断开；之后层数超过 `kNotebookMaxDepth` 且上级恰在最深一层的断开（只断开放不下的那一层，下面的跟着上移）。结果与遍历顺序无关；断开即把 `parentId` 精确写成 null。只在有日记本不是两侧原样时校验（两侧原样的读本机记录）；复活日记本的子本先按保留一侧恢复 `parentId` 再校验。

### 4.5 需要用户确认的情况（规划器只报告，会话层决定）
- **删除保护**：任一侧将彻底删除的日记数 > max(20, 该侧日记总数的 10%)（总数 = 该侧清单里的日记数）。
- **以哪边为准**：本次与该设备是首次同步、或任一侧 `restoredPending`，且出现没有共同祖先的冲突（两侧该分面历史没有任何共同哈希；stamp 与缺分面不算）时，按实体报告涉及的记录数（`SyncPendingConfirmations.sideChoiceCounts`），请用户选：保留两份（按 4.1 生成副本）/ 以本机为准 / 以对方为准；后两种对这些冲突直接取一方，不生成副本。顺序列表（`orderList`）不计入、也不受这个选择影响：书架与“我的模板”顺序两侧总是都有，新设备上是空列表，与对方天然没有共同哈希，却谈不上“两边都改过”——没有共同祖先时一律按 4.1 的列表规则取并集（之后再按 4.3 校正为最终集合）。对话框只有日记时说“有 N 篇日记……”，还有别的种类时逐项列出（收录与书架 / 书序归日记本，“我的模板”顺序归模板，见 `syncSummaryEntityOf`）。“不删除任何记录”：选择只作用于这些冲突分面，不把只在一侧的记录变成删除——只在一侧的记录仍按 4.2（覆盖恢复后墓碑已清空，实际都是复制）。不论本次按哪种选择规划都照样报告数量，用户是否已经选过由会话层记住。
- 自动同步遇到以上任一情况：中止，不写入，在同步页标记“需要确认”。

### 4.6 产出
`SyncPlan`：
- `local` / `remote`（`SyncSidePlan`）：
  - `writes`：每项 `SyncWrite{ key, expected: 规划时依据的该方当前分面哈希（记录不存在为 null）, record: 最终规范记录（删除为 null） }`，按 `SyncKey` 排序（实体枚举顺序）；最终值与该方当前哈希全同的不写；冲突副本与其成员关系是 `expected == null` 的新增；
  - `renames`：原地改名 `SyncTagRenameOp{ from, to, expected: 该方 tag:from 的哈希, record: tag:to 的最终记录 }`，按旧名排序；写入列表里没有对应的 `tag:from` 删除与 `tag:to` 新增；
  - `mediaNeeded`：该方需要从另一方取得的媒体键候选（写入记录里哈希有变化的分面引用的媒体键；写入层经 `media.have` 按 sha256 核对后只传缺的）；
  - `stats`：每类实体的新增 / 更新 / 删除（原地改名记为标签更新）；
  - `historySeenAt`：写入后折叠用的继承时间（4.1.1）。
- `conflictCopies`：新生成的冲突副本（原 id、副本 id、标题、败方），按原 id 排序；`confirmations`：删除保护（0–2 项）与“以哪边为准”按实体的冲突数。
- 写入层须知（第 6 节）：
  1. 事务开始时先逐条比对**全部**前置条件（写入的 `expected`；改名的 from 哈希等于 `expected` 且 to 不存在），不符的跳过；再执行原地改名；再按 `writes` 的顺序写——引用旧名的日记写入里 tags 已是新名，它的 `expected` 是改名前的哈希。
  2. 日记排在标签之前：日记的标签按名称（`ensureTagsByName` 口径）建出后，颜色由同一计划里 `tag:` 记录的写入定下；计划保证每个最终日记引用的标签名都有最终的 tag 记录（不被删除）。
  3. 删除日记 / 日记本 / 标签时写入层的关联清理，与计划里显式列出的成员、留言、纪念日、书序写入一致（重复执行无害）；删除日记本不提升子本，子本的 `parentId` 由计划精确给出。
  4. 顺序列表写入后按列表重排为 0..n-1；计划给出的列表恰为最终集合，“列表里没有的现有项排在末尾”只在有写入被跳过时才会出现。
  5. 一侧的智能本被改成手动本时，先清掉该本残留的关联行（智能本的残留行不进清单），否则写入后的清单与计划不符。
  6. 写入后调用 `recordAppliedState(after, historySeenAt: plan.historySeenAt)`（4.1.1），漏传则多台设备之间可能不收敛。

## 5. 协议

### 5.1 发现（UDP）
- 信标 JSON：`{"j":"jotsy-lan","v":1,"id":deviceId,"n":名称,"p":平台,"port":TCP端口,"fp":身份公钥指纹前 8 字节十六进制,"f":kSyncFormatVersion}`。
- 发送到 255.255.255.255:24561 与组播 239.255.47.61:24561；同步页打开时每 2 秒，前台自动模式每 5 秒；收到他人信标即记入在线表，8 秒没收到即离线；忽略自己的 deviceId。
- 只听不发（`LanSyncDiscovery.advertise = false`，“可被发现”关闭时）：照常绑定端口、收信标、维护在线表，但不周期发送、也不给新设备单播回复——别人看不到本机，本机仍能看到已配对设备在线；可在运行中切换，打开时立即补发一次。
- Android 发现期间持有 `MulticastLock`（原生通道 `acquireMulticastLock` / `releaseMulticastLock`）。
- 本机地址：私有 IPv4、非回环、优先 Wi-Fi / 以太网接口；供二维码与英雄卡显示。

### 5.2 连接与加密
- TCP 服务端优先 24562，占用时随机端口（信标里广播实际端口；英雄卡在实际端口不是 24562 时显示 `ip:port`，“手动输入地址”的地址框粘贴 `ip:port` 时自动拆开）。两个端口（UDP 24561 / TCP 24562）都取在所有平台的临时端口范围之外（Linux / Android 32768–60999、Windows / macOS 49152–65535），不会被其他程序的出站连接临时占用；24555–24576 在 IANA 未分配。早先的 47561 / 47562 落在 Linux / Android 的临时端口范围里，真机上被占用过。
- 身份：只有 Ed25519（签名）；不使用静态 X25519（每次会话的临时 X25519 + 对 transcript 的签名已足够认证）。指纹 = sha256(Ed25519 公钥) 十六进制（64 字符），短指纹 = 前 8 字节（16 字符）。
- 握手（SIGMA 式，三种模式共用同一消息顺序；I = 连接方 / 发起方，R = 监听方 / 响应方）：
  1. I→R `hs.hello{v, f, intent: sync|pair, method?: sas|qr, id, name, platform, pk, nonce, commit}`（明文）
  2. R→I `hs.hello{v, f, id, name, platform, pk, nonce, eph}`（明文）
  3. I→R `hs.reveal{eph}`（明文；R 校验承诺，不符直接断开）——之后全部为密文帧
  4. R→I `hs.auth{sig}`；5. I→R `hs.auth{sig, token?}`；6. R→I `hs.ok`；
  7. 仅核对码配对：双方显示核对码，用户确认后互发 `pair.confirm`（拒绝 / 超时发 `pair.reject{reason}`）。
  任一步可由 `hs.reject{reason}` 代替（reason：version / untrusted / signature / fingerprint / token / protocol …；R 在 1 之后、I 在 2 之后为明文，之后加密）。`v` 是握手协议版本（`kLanSyncProtocolVersion = 1`，不同即 `version` 拒绝，带上本机版本）；`f` 是同步格式版本，由调用方传入、握手只交换不比较（§5.3 由会话层决定）。
- transcript = 规范串联（每个字段 `u32 长度 ‖ 字节`）：前缀 `jotsy-lan/v1 transcript`，再依次是 I、R 的 hello 字段（v、f、intent、method、id、name、platform、pk、nonce、commit、eph）；签名输入 = `"jotsy-lan/v1 sig <initiator|responder>" ‖ SHA-256(transcript)`（带角色，防反射）。共享密钥全 0（低阶点）即拒绝。HKDF-SHA256(ikm = 共享密钥, salt = transcript 哈希)：info `jotsy-lan/v1 key initiator->responder` / `…responder->initiator` 各 32 字节，`jotsy-sas` 8 字节 → 取前 48 位 mod 10^6 为核对码。
- 帧：`[长度 u32 大端][密文 ‖ 16 字节标签]`，明文 ≤ 64 KiB；AEAD = ChaCha20-Poly1305（纯 Dart 同步实现）；nonce = 4 字节方向前缀（I→R 为 1、R→I 为 2）+ 8 字节计数器；**计数器不随帧传输**，接收方用自己期望的下一个值构造 nonce，重放、乱序、丢帧都表现为认证失败；帧头作附加数据；认证失败即断开。吞吐基准（本机 x86-64，64 KiB 帧，`test/core/services/lan_sync/lan_sync_aead_benchmark_test.dart`）：ChaCha20-Poly1305 加密 53 / 解密 54 MiB/s（JIT），AOT 48 / 50 MiB/s；同库 AES-256-GCM 约 20 MiB/s（JIT 与 AOT 相同，纯 Dart 无硬件 AES），故保持 ChaCha20-Poly1305。
- 信道明文的首字节为种类：`0x01` 消息（最后一段）/ `0x02` 消息分段（大消息自动分段，单条 JSON ≤ 32 MiB）/ `0x10` 数据块开始 `[u32 id][u64 长度]` / `0x11` 数据 `[u32 id][字节]` / `0x12` 结束 / `0x13` 发送方放弃 `[u32 id][原因]` / `0x7f` 关闭（经认证的正常结束；没有关闭帧的断开报 `connectionLost`）。背压：发送每帧等 `flush`，数据块按帧加锁、控制消息可插在两帧之间；接收侧消费者没在听或暂停时分发循环停住、读取器缓冲满 256 KiB 即暂停读套接字。使用方必须一直监听 `messages` 与 `blobs`，并对每个数据块读完或取消其 `data`。
- **首次配对（核对码）**：承诺 = `SHA-256("jotsy-lan/v1 commit" ‖ 临时公钥 ‖ 随机数)`，在 R 发出临时公钥之前送达、R 收到揭示后校验——没有承诺时中间人可以先看一侧的临时公钥再挑选自己的（约 2^20 次尝试）让两侧核对码相同；有了承诺，中间人在每一侧都得先定下自己的值，两侧相同的概率只剩 10^-6。配对意图不看已有信任（重新配对时替换旧公钥）。双方用户都确认才成功；任一方拒绝或超时（默认 60 秒，可注入）即放弃，不保存任何东西；成功后由调用方互存对方 Ed25519 公钥。最后一条 `pair.confirm` 在途中丢失时可能一边成功、一边超时（两军问题），成功的一边之后同步会被 `untrusted` 拒绝、提示重新配对。
- **扫码配对**：二维码 `jotsy-lan:v1:<base64url 无填充(规范 JSON，键按字典序 {fp, h:[地址…], id, n:名称, p:端口, t:令牌})>`；fp 为**完整**指纹（64 个小写十六进制），令牌为 128 位随机数的 base64url（22 字符），地址 1–8 个、名称 1–100 字符；解码严格校验（未知前缀 / 版本、缺字段、多字段、端口越界、超长一律拒绝）。扫码方在揭示临时公钥前校验对方公钥指纹 == fp，验证对方签名后才在信道里出示令牌；显示方验证扫码方签名后才核销令牌（2 分钟有效、一次性，同步完成检查与作废；不一致的令牌不作废当前码），通过即视为已确认，无需核对码。
- 已配对设备之间：发起方 intent = sync，双方身份公钥都已受信 → 直接建立会话；任一方不认识对方 → 返回 `untrusted`（对方收到明确原因），界面提示重新配对。
- 传入的配对请求只在本机同步页打开（`attachPage` 期间）时接受，否则引擎直接拒绝（没有人在场核对数字，留着只会等到超时）；界面一侧对同步页不是当前路由时收到的配对事件同样 `respond(false)`。

### 5.3 会话消息

握手成功、已配对设备之间（intent = sync）在同一条加密信道上运行一次会话（`lan_sync_session*.dart`，编解码在 `lan_sync_session_protocol.dart` / `lan_sync_session_plan_wire.dart`）。信封同 §5.2（`{"type": …}` JSON，信道自动分段，单条 ≤ 32 MiB），清单与媒体走数据块。I = 发起方（唯一规划者），R = 响应方（只应答，不主动请求）。

| # | 方向 | 消息 | 字段 / 说明 |
|---|---|---|---|
| 1 | I→R | `sync.hello` | `f` 同步格式版本、`app` 应用版本、`entities` 实体名（排序，不含 settings）、`settings` 是否开启“同步设置”、`restored` 本方对对方的 `restoredPending`、`auto` 是否自动同步 |
| 1′ | R→I | `sync.hello` 或 `sync.reject{reason}` | 同上（无 `auto`）。R 依次判定：`f` 或实体集合不同 → `version`；R 有编辑页或正与别的设备同步 → `busy`；`auto` 而 R 关了全局 / 这台设备的自动同步、或这台设备还有未处理的“需要确认” → `declined`。拒绝后关闭。I 同样比较，不同即 `abort{incompatibleVersion}`。`untrusted` 在握手里（`hs.reject`），不在这里 |
| 2 | 双方 | — | `flushAll()` → `refreshCheckpoint(includeSettings: 两边 settings 都为 true)` |
| 3 | I→R / R→I | `sync.manifest.get` / `sync.manifest{blob, size}` + 数据块 | gzip JSON `{manifest, tombstones:[键…], renames:{旧名:{to,t}}}`，≤ 64 MiB |
| 4 | I→R / R→I | `sync.history.get{history:[键…]}` 或 `{tombstones:[键…]}` / `sync.history{history, tombstones}` | 状态文件同一 JSON 形态（`syncEncodeHistory` / `syncEncodeTombstones`）；每条请求 ≤ 2000 键，没有历史的键不出现在应答里（I 记为“问过、没有”） |
| 4′ | I→R / R→I | `sync.records.get{keys}` / `sync.records{records:[{k,f}…], more}` | 每条请求 ≤ 2000 键；应答按 JSON 大小分段（每段约 4 MiB，单条记录超过时独占一段），`more:false` 为最后一段 |
| 5 | I | — | `planSyncFetch` 直到为空（每轮取回后核对要过的数据都到手，没到齐说明期间数据变了，中止为 `unknown`），`planSync`，再处理 §4.5 的确认 |
| 6 | I→R / R→I | `sync.media.have{keys}` / `sync.media.status{files:{键:{size, sha256}}}` | 两个方向候选（`plan.remote.mediaNeeded` ∪ `plan.local.mediaNeeded`）一起问；接收方已有同样 sha256 的不传 |
| 7 | I→R | `sync.plan{incoming, outgoing, files, bytes, waitedMs}` | 只供 R 显示进度：R / I 各要收到的日记篇数、两个方向合计的媒体文件数与字节数；`waitedMs` 为 I 等用户确认（§4.5）花的毫秒数，两边的用时都扣掉它（摘要与同步记录的“用时”只算真正同步的时间） |
| 8 | I→R | `sync.media.put{key, size, sha256, blob}` + 数据块 × N | 推给 R 的文件，R 流式写进暂存区并按大小与 sha256 校验，不符即 `abort{transferFailed}` |
| 8′ | I→R / R→I | `sync.media.get{keys}` / `sync.media.put` × N + `sync.media.end` | 从 R 取的文件（R 已没有的键略过）；I 同样暂存、校验 |
| 9 | I→R | `sync.apply.part{writes:[{k, e, r}…]}` × N + `sync.apply{renames, seenAt, stats, copies}` | 写入列表分段（每段约 4 MiB；`e` 规划时的分面哈希或 null，`r` 最终分面或 null = 删除），收尾带原地改名 `[{from,to,e,r}]`、历史时间继承 `{键:{分面:毫秒}}`、统计 `{实体:[增,改,删]}` 与冲突副本 `[{id,title}]` |
| 10 | R→I | `sync.applied{counts, rekeys}` | R 执行 `apply(plan.remote, staging, includeSettings)` 后：日记计数、日记以外的变化条数与就位的媒体 `{a,u,d,o:{实体:条数},mf,mb}`（`o` 按 `syncSummaryEntityOf` 归类，没有时省略）、媒体改键 `[{old,new,sha256}]`。不回传写入后的清单（早先草案有，发起方用不到，下次同步重新交换） |
| 11 | I→R | `sync.finish{counts, rekeys}` | I 执行 `apply(plan.local, staging)`、照做 R 的改键之后：I 的计数与改键 |
| 12 | R→I | `sync.done` | R 照做 I 的改键之后；随后关闭信道（关闭帧） |
| * | 双方 | `sync.ping{}` | 做耗时的本机步骤（刷新检查点、构建记录、写入、等用户确认）时每 5 秒一次，只重置对方的静默计时 |
| * | 双方 | `sync.abort{reason}` | 任何时候；`reason` 为发送方的失败原因名（`cancelled` / `declined`（用户取消了确认）/ `needsConfirmation`（自动同步遇到确认）/ `deferred`（撤销提示没关）/ `timedOut` / `writeFailed` / `transferFailed` / `protocolError` / `incompatibleVersion` / `unknown`），接收方把 `cancelled` 读作“对方取消”。发出后关闭；之后排队的消息一律不再处理 |

- 顺序：R 只检查 `sync.apply` 至多一次、`sync.finish` 在它之后，其余由 I 驱动。两个方向的媒体都在任何写入之前传完，传输失败两边都不写。
- 计时：等对方消息时 30 秒内没有任何消息、ping 或数据块数据即 `timedOut`（衡量“对方没声音”，不是某一步的总时长）；手动同步等用户确认的上限 10 分钟。取消（任一方）立即发 `sync.abort{cancelled}` 并关闭信道；正在执行的本机步骤（刷新、写入事务）执行完才结束。
- 失败点与已写入的内容：写入之前的任何失败（含自动同步遇到确认、用户取消确认、推迟）两边都不写；R 写入后、I 写入前失败只有 R 写了；I 写入后、照做改键前失败两边都写了、只差改键——都由下一轮同步收敛（`lan_sync_session.dart` 顶部有逐项说明）。
- 缺少某类实体、对方不提供设置，从不视为删除；双方版本不一致（格式版本或实体集合）即拒绝并提示升级。

## 6. 写入（`SyncApplier`：`sync_apply.dart` + `_AppDatabaseSyncWrites` / `_AppDatabaseSyncOrder`）

入口：`SyncApplier.apply(sidePlan, {staging, includeSettings})`，结果 `SyncApplyResult{status: applied|deferred, skipped: [{key, reason}], rekeys, manifest（写入后）, counts（实际执行的新增 / 更新 / 删除）, summary（实际执行的条数按 `syncSummaryEntityOf` 归类，界面的“其他”）, mediaFiles, mediaBytes}`；跳过原因 `precondition` / `invalidRecord` / `missingDependency` / `settingsFailed`。冲突副本数取计划的 `SyncPlan.conflictCopies`。

1. 等待撤销窗口结束（`EditingSessionRegistry.waitForUndoWindows`，默认 15 秒）：超时返回 `deferred`，什么都不写（暂存件一并丢弃，下次重新传）。撤销提示开着时写入，用户点“撤销”会把旧内容写回、覆盖同步刚写入的值。
2. 媒体（`SyncMediaStaging`，在开事务**之前**就位：记录落库那一刻文件必须已经在）：
   - 会话层把来件流式写进 `<dataRoot>/.lan_sync_staging/<会话>/<键>`（与数据根同一文件系统，就位用改名、原子），写完按声明的大小与 sha256 `verify`，不符即删除暂存件并拒收；
   - 就位规则（`place`）：目标键不存在 → 改名就位，修改时间设为现在（不沿用发送方的时间，媒体回收的 24 小时宽限期才对新到的文件生效）；目标键已有同样 sha256 → 复用、丢掉暂存件；目标键已是**另一份文件**（托管目录是随机的 `createTemp('media_')`，几乎只会因巧合出现）→ 绝不覆盖，放到同目录的派生键 `<文件名>.<sha256 前 12 位>.<扩展名>`（`syncDerivedMediaKey`；派生键上已有同样内容即复用，再被占用时改用完整 64 位），并把本次这一侧**所有**写入记录里的 `jotsy-media:<旧键>` 改写为新键（含嵌在 JSON 字符串里的，改过才按规范 JSON 重新编码），改写过的分面不再继承历史时间（不再是另一侧的原值）；
   - 改键随结果报告（`SyncMediaRekey{old, new, sha256}`），会话层发给来源一侧，来源一侧在**自己的 `apply` 之后**调用 `adoptMediaRekeys`：本机 `oldKey` 仍是那个 sha256 时拷一份到 `newKey`（先写同目录临时文件再改名），再把本机所有引用 `oldKey` 的记录改写为 `newKey`，经同一条写入路径（前置条件 = 现在的哈希、单事务、写入后折叠）。两边由此得到逐字节相同的规范记录；旧文件不删，没人引用后由媒体回收收走；
   - 设置背景图（`app_backgrounds/<文件名>`）同样在这一步按键就位（文件名须通过 `AppBackgroundStorageService.isValidName`），设置写入时文件已在；
   - 暂存目录在 `apply` 结束时（成功、失败、推迟）一律删除；进程中途退出留下的由 `SyncMediaStaging.sweepStale`（服务启动时调用）清掉超过 24 小时的。
3. 还原列值（反向列值类）在开事务之前做完：结构不对的记录记为 `invalidRecord` 跳过，不让一条坏记录使整批（以及之后每一次同步）回滚。然后在 `DataArchiveService.runSerialized` 中开**单个** Drift 事务：
   - 读行（`readSyncRows`）并经 `SyncLocalState.observeRows` 算出当前清单（哈希缓存命中时很便宜）；
   - 先逐条比对**全部**前置条件：写入的 `expected` 与当前分面哈希完全相同（null = 必须不存在），改名的 `tag:from` 哈希等于 `expected` 且 `tag:to` 不存在；不符的记入 `skipped`（下次同步再处理）；
   - 原地改名：更新那一行的 `name` 与颜色，本地 id 不变（编辑器与 `tagOrderRaw` 持有本地 id）；
   - 其余写入按计划顺序执行，**顺序列表放到最后**：计划按键排序，`orderList:templates` 排在模板写入之前，照原顺序执行时新模板还没插入、重排后会被当作“列表里没有的现有项”排到末尾；重排只看行是否存在，挪到最后与计划的结果相同（这是写入层对 §4.6 第 1 条“按 writes 的顺序写”的执行细节，规划器不变）；
   - 按原值写入列（业务 id ↔ 本地 id 换算；时间、标志原样，不刷新 `updatedAt`）。日记的标签按名称**精确**匹配（不去空白：规范名就是库里的原名），缺的以中性色 `0xFF9E9E9E` 建出，颜色随后由同一计划里 `tag:` 记录的写入定下（那条被跳过时留着中性色，下次同步照常合并颜色）；已有标签的颜色只由 tag 记录改动；
   - 删除时的关联清理与现有删除路径一致：日记复用 `hardDeleteDiary`（diary_tags、diary_notebooks、留言、纪念日关联置 null），标签复用 `deleteTag`（diary_tags），日记本删掉它的 diary_notebooks 行；与计划里显式列出的成员 / 留言 / 纪念日写入重复执行无害；
   - 不调用 `deleteNotebook` / `mergeNotebook`（它们的子本上提会覆盖另一边的移动），`parent_id` 精确取自记录，删除父本不提升子本；智能本改成手动本时先清掉它残留的关联行；新日记本 / 新模板 / 新成员先排在最后，再由顺序列表重排；
   - 成员关系的日记或日记本不存在（它们的写入被跳过）、或日记本不是手动本时不写，记为 `missingDependency`；
   - orderList 写入后按列表重排 `sortOrder` / `position` 为 0..n-1，列表里没有的现有项按原相对顺序（与规范化读取同一排序）排在末尾；模板列表只排用户模板，`builtin.*` 的位置不动；书序列表的删除（日记本被删或改成智能本）不需要任何操作；
   - 写入层不因删除模板而改动日记本定义（`NotebookPayload.templateId` 保持原样）：应用自己删除模板（`DiaryTemplatesController.delete` → `deleteDiaryTemplates`）也只清 `DiaryTemplatePrefs` 里的规则、不动日记本，指向已删模板的默认模板在应用里本来就会出现，读取时找不到即回落；写入层若改了日记本定义，写入后的清单就与计划不符，下次同步又判成差异。`DiaryTemplatePrefs` 是设置，由 settings 同步处理；
   - 写完在事务里再读一次行，作为写入后状态（提交后的库就是它）。
   事务里任何异常回滚这一侧的全部数据库写入、不更新同步状态（下次重新规划）；第 2 步已就位的文件留着、没有记录引用，由媒体回收收走。
4. 事务提交后应用设置（见第 5 条；SharedPreferences 不在 Drift 事务里，放在前面的话数据库回滚时设置已经改了），失败只回滚设置、这条记为 `settingsFailed`，数据库写入保留。
5. 用写入后的观测（事务里读出的行 + 应用设置之后取的设置值）调用 `recordAppliedState(after, historySeenAt: …)`：`historySeenAt` 取这一侧计划的 `SyncSidePlan.historySeenAt`，只保留真正写成了的键、去掉被媒体改键改写过的分面（跳过的键若因用户编辑而变了，旧值的时间应当是现在）。有任何写入时发出 `EditingSessionRegistry.notifyDataReplaced()`。会话同步设置时调用方应传 `includeSettings: true`（默认只在计划里有设置写入时才观测设置）：标签改名会改变按名称的标签顺序，写入后的观测带上设置才记得准。
6. settings 分面只应用本次变化的键（`record` 哈希与 `expected` 不同的分面），部分节点由 `syncSettingsRestoreNode` 生成（`tagOrderNames` 按写入后的标签表换回本地 id，背景图引用还原为文件名），经 `BackupSettings.restore(…, clearLegacyDraft: false)` 应用：覆盖恢复会顺带 `clearCreateDiaryDraft()`（只有读不出来、迁移时保留下来的旧版单份草稿才会还在），同步只应用设置变化、不能删掉本机用户的数据。`restore` 对若干键的“空值”什么也不做，写入层直接调用 setter：`tagOrderRaw` 为空串 → `setTagOrderRaw('')`；`diarySortModeRaw` / `diaryLayoutModeRaw` 为空串 → 对应 setter；`diaryToolbarOrderRaw` / `tagPickerSortRaw` / `diaryLocationPrecisionRaw` 为 null → `clearDiaryToolbarOrderRaw()` / `clearTagPickerSortRaw()` / `clearDiaryLocationPrecisionRaw()`（`SettingsService` 为此新增），为空串 → 对应 setter；`appLocaleCode` 读出来从不为空。否则本机规范值不变、下次同步会反复判为差异。失败按 `SettingsServiceBackup` 的快照回滚（快照补上了之前漏掉的“我的颜色”键）。

会话层的顺序（§5.3）：发起方规划 → 两个方向的媒体协商（`media.have`，接收方已有同样 sha256 的不传）→ 把 `plan.remote` 需要的媒体传进对方暂存区、从对方取 `plan.local` 需要的媒体进本机暂存区（都在任何写入之前，传输失败两边都不写）→ 对方 `apply(plan.remote, staging)`，回 `applied{counts, rekeys}` → 发起方 `apply(plan.local, staging)` → 发起方 `adoptMediaRekeys(对方的 rekeys)`，把自己的 rekeys 发给对方 → 对方 `adoptMediaRekeys`。某一侧的计划为空时不调用写入层（不必等撤销窗口）。只执行了一侧（中断）时下一轮照常收敛：未写的一侧的差异重新规划即可。会话期间同一个 `SyncLocalState` 不能被别处并发调用（写入事务里会调用它的 `observeRows`，它的队列里若排着要读库的操作会与事务互相等待）。

## 7. 并发安全（`EditingSessionRegistry`）

- **阻塞者**：编辑页与发布页（`DebouncedAutoSaveController`）、纪念日编辑页与日记本编辑页（`EditingSessionBlocker`）、模板编辑页、留言编辑面板、目录页与日记本管理页的拖动排序（`ReorderEditingGuard`：从拿起到新顺序写完，落回原位即结束）。登记期间不发起自动同步，对方的会话请求以 `busy` 拒绝；手动同步提示“请先关闭正在编辑的页面”。
- **冲刷者**：预览页待办自动保存（`DiaryTodoAutoSaveController`）。会话开始时 `flushAll()`；写入后由 `notifyDataReplaced` 让其文档重新读取。
- **撤销窗口**：带按钮（撤销）的 `showTrackedSnackBar` 显示期间自动计数（`beginUndoWindow`，随提示关闭结束）；同步写入前等待清零，超时即推迟（§6 第 1 步）。
- **写入后失效**：`syncedDataRefreshProvider`（`lib/app/synced_data_refresh.dart`，`NodeDiaryApp` 常驻监听）收到 `dataReplaced` 时失效一次性读取的 provider：`diaryDetailProvider` 族、`diaryNotebooksProvider` 族、`diaryPreviewBacklinksProvider` 族（预览页的反向链接）、`userDiaryTemplatesSnapshotProvider`、`tagListProvider`（自定义顺序取自设置、只在标签表推送时套用）。实时查询（`watch…`）由 Drift 自动刷新，设置类 Notifier 经 `SettingsService` 的通知刷新；新增一次性读取同步数据的 provider 必须加进它的清单。

## 8. 安全与隐私

- 只有已配对设备能建立同步会话；配对需双方确认（核对码）或扫码（一次性令牌）。
- 本机开启了应用锁、或存在上锁日记本，且 `AppPlatform.supportsDeviceAuth` 时，用户点“一致，配对”时先经 `DeviceAuthService` 验证（`LanSyncPairingAuthGate`）：没有通过、或设备没有设置锁屏密码弹不出验证时不确认配对，面板上提示原因；平台不支持身份验证（Linux）时不验证、也不额外提示（安全说明块已写明会合并私密日记本）。
- 首次配对时说明：同步会双向合并两台设备的全部数据（含私密日记本与回收站），建议先导出完整备份（提供入口）。
- 所有传输端到端加密；身份私钥只在 `stateDir`，不进备份、不进 SharedPreferences。
- 隐私政策（`docs/privacy.html`）写明局域网同步的联网方式（只与已配对设备、端到端加密、不经服务器；只在同步页打开或配对后应用在前台时联网；可被发现时在局域网广播设备名）与相机、局域网 / 组播权限。

## 9. 服务与自动同步（`lan_sync_service*.dart`、`lan_sync_auto_scheduler.dart`）

`LanSyncService` 是应用生命周期内的一份编排，界面适配层只经它的 `state` / `events` / `qrTicket` 与指令方法（对照见 `lan_sync_service.dart` 顶部）。全部外部能力经构造注入（数据库、数据根、状态目录、设置服务、编辑会话接口、套接字 / 发现 / 地址 / 时钟 / 计时器），测试在一个进程里跑两三台。

- **界面接线**：`lanSyncControllerProvider` 在支持的平台上建 `EngineLanSyncUiController`，由 `createAppLanSyncService` 装配引擎；应用根组件 `NodeDiaryApp` 启动时就常驻监听这个 provider，所以引擎随应用创建并启动（读身份与 store），不等用户打开同步页——已配对设备的自动同步与对方发起的手动同步都要本机在前台时连得上。创建引擎本身不碰网络：什么时候起服务端与发现由下面的规则决定。provider 挂一个 `AppLifecycleListener`，resumed 为前台，paused / hidden / detached 为后台（`setForeground`），inactive 不改变。引擎异步启动完成之前，界面指令排队、页面引用计数与前后台先记下，启动后补给引擎（前后台在 `start` 之前交给引擎，后台启动的应用不会先开端口再关）；二维码面板先拿到准备中的占位码，引擎能签发时再换上真码。不支持的平台（iOS）为不联网的 `InertLanSyncUiController`。
- **启动**：读身份（`created` → 清空已配对设备、同步记录与同步状态）→ 打开 `store.json` → 建同步部件（`SyncLocalState`、媒体索引 / 库、`SyncApplier`）→ `SyncMediaStaging.sweepStale` → 按下面的规则决定是否起服务端（优先 24562，占用时上次的端口，再随机）与发现；登记覆盖恢复监听（§3）。
- **什么时候碰网络**：没有已配对设备时，服务端与发现只在同步页打开（`attachPage`，二维码面板也只在同步页上）期间运行，离开即全部停掉——从没用过局域网同步的用户不该在应用启动时就开 TCP 端口、向局域网广播带设备名的信标（隐私，也费电）。有至少一台已配对设备且在前台时，服务端与发现保持运行，不管自动同步开没开：对方的手动同步也要连得上本机。后台一律停掉。配对成功、取消配对、页面进出、前后台切换后立即按新的状态重新判定（串行执行，避免交错起两个服务端）；服务端停下时作废正在显示的二维码。
- **前后台与页面**：后台停服务端与发现、取消全部自动同步计时（不做后台常驻）；回到前台恢复。`attachPage` / `detachPage` 按引用计数：页面打开时信标 2 秒一拍、列出附近（未配对）设备、接受传入的核对码配对，并每 15 秒重读本机地址（另在启动、回到前台、打开页面时读）；没有页面时 5 秒一拍。发现跟随服务端运行。
- **不可被发现**：发现只听不发（§5.1）。已配对设备照样显示在线、上线照样触发自动同步；对方看不到本机，若对方是先发起的一方（deviceId 较小），10 秒的双向重试让本机发起。
- **会话**：同一时刻最多一个（任一方向）。会话进行中，传入的同步以 `busy` 拒绝、出站同步不开始；会话期间的表更新视为同步自己的写入，不触发自动同步。手动同步时本机有编辑页即以 `localEditing` 结束、不连接；自动同步静默跳过。连接候选：信标里的地址与端口优先，其次上次连上的。
- **配对**：同一时刻一个。传入的核对码配对只在页面打开时交给用户，否则立即拒绝；扫码令牌 2 分钟一次性，用掉或到期立即换发（经 `qrTicket` 通知），关闭二维码面板时作废。按地址连接先按已配对设备握手，任一方不认识（`untrusted`）再改走核对码配对。配对成功只保存对方公钥（重新配对同一身份保留同步记忆，换了身份按首次同步），之后由界面决定是否立即同步。
- **自动同步**（前台、全局与单设备开关都开、对方在线、没有未处理的“需要确认”、不在编辑）：
  - 触发：已配对设备上线；应用回到前台；本机同步范围内的表变化——每次变化重新计时 20 秒，到点时还在编辑就等编辑结束再计 20 秒；
  - 谁发起：deviceId 较小的一方立即发起；较大的一方等 10 秒，期间没有与对方的会话到达才自己发起（某个方向被防火墙拦住时另一个方向仍能同步）；
  - 节流：同一台设备两次自动同步（两个方向合计）至少相隔 60 秒，没到时间就排到时间到了；较大的一方到点后仍先等 10 秒（两边的节流常同时到期，同时发起会互相以 `busy` 拒绝）；正忙时 10 秒后再试一次；
  - 结果：写入了本机日记 → `LanSyncAutoSyncApplied`（篇数）；没有变化不提示；遇到需要确认 → 中止、什么都不写，两边都标记 `needsAttention` 并发 `LanSyncAttentionNeeded`；用户“查看”时，若有正在等的手动确认就把同一个请求再交一次，否则发起一次手动同步（重新规划后再问）。自动同步之前就失败（连不上、被拒绝）的不记同步记录；
  - 响应方拒绝自动同步（`declined`）：本机关了全局或这台设备的自动同步，或这台设备还有未处理的“需要确认”。
- **手动确认**：会话把请求经 `LanSyncConfirmationRequested` 交给界面并等应答，期间每 5 秒 ping 对方，上限 10 分钟；以哪边为准选了以某边为准就按它重新规划；删除保护选“保留并恢复”时，把导致删除的那一侧的日记墓碑当作“删除之后又改过”重新规划，这些日记连同成员关系、留言与纪念日关联按复活规则保留并复制回去（规划器不变，经 `SyncPlanSide` 视角实现）。
- **同步记录**：hello 之后的会话（两个角色）都记一条，之前就失败的只记本机手动发起的（本机在编辑的不记）；成功时更新上次同步时间、清除 `needsAttention` 与 `restoredPending`。
- **设置**：两端“同步设置”都开启（且装配时给了 `SettingsService`）才参与，`includeSettings` 同时传给刷新、写入与改键照做。
