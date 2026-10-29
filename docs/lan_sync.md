# 局域网同步（LAN Sync）设计规格

> 状态：实现中（分支 `worktree-lan-sync`）。本文是各模块的共同依据：数据模型、合并规则、协议与状态存储以此为准；实现中如需偏离，先改本文再改代码。界面规格定稿后写入 DESIGN.md §5.27。

## 0. 目标与边界

- 同一局域网内的 Jotsy（Android、Linux、Windows；macOS 可编译，iOS 不支持——`AppPlatform.supportsLanSync`）互相发现、配对后双向同步全部日记数据。
- 时机：同步页里手动“立即同步”；应用在前台时与已配对设备自动同步（不做后台常驻）。
- 同步范围：日记（含回收站中的）、标签、日记本（含成员、书序、层级）、留言、日记模板（含改过的内置模板）、纪念日、这天的心情、托管媒体；设置为可选（两端都开启才同步）。
- **不同步**：草稿（单台设备上未完成的工作；发布即删除，两台都发布会重复；载荷带本机标签 id）、导入的字体文件（设置里只带字体 id，缺失回落内置字体）、心情选项 `mood_options`、本机偏好（不随备份导出的那些键）、网盘凭据、应用锁开关。
- 同步不是导入：不走 `chooseBackupImportMode`，不复用 `BackupMerge` 的合并/覆盖模式，也不调用 UI 写库函数（它们会改写 `updatedAt`、清掉归档/删除标记等）。

## 1. 模块与文件归属

| 路径 | 职责 | 任务 |
|---|---|---|
| `lib/core/services/lan_sync/sync/sync_model.dart` | `SyncEntity`、`SyncKey`、`SyncRecord`、`SyncManifest`、规范 JSON 与哈希 | 4 |
| `lib/core/services/lan_sync/sync/sync_canonical_{diary,notebook,misc,settings,support}.dart`、`sync_media_refs.dart`；原始行 `lib/core/database/sync_rows.dart` | 数据库行 ↔ 规范记录（含反向列值）、媒体路径归一；可送进 isolate 的纯 Dart 原始行 | 4 |
| `lib/core/services/lan_sync/sync/sync_local_state.dart`、`sync_state_model.dart`（纯 Dart）、`sync_state_fold.dart`（纯 Dart）、`sync_state_json.dart`、`sync_state_files.dart`、`sync_manifest_builder.dart`、`sync_hash_cache.dart`、`sync_media_index.dart` | 检查点、分面历史、墓碑、标签改名、哈希缓存、媒体索引 | 4 |
| `lib/core/services/lan_sync/sync/sync_planner.dart`、`sync_plan.dart` | 合并判定，产出双方的写入计划 | 5 |
| `lib/core/database/app_database_sync_ops.dart` | `_AppDatabaseSyncOps`：读规范行、单事务按原值写入（带前置条件）、关联清理 | 6（读规范行的部分由 4 先建） |
| `lib/core/services/lan_sync/sync/sync_apply.dart`、`sync_media.dart` | 写入编排、媒体暂存与就位、写入后更新本机状态 | 6 |
| `lib/core/services/lan_sync/lan_sync_identity.dart`、`lan_sync_crypto.dart`、`lan_sync_frames.dart`、`lan_sync_handshake.dart`（+ `_types` / `_flows` / `_sas`）、`lan_sync_channel.dart`（+ `_types` / `_inbound` / `_outlet`）、`lan_sync_messages.dart`、`lan_sync_qr_payload.dart` | 身份、密码学原语、长度前缀帧、握手与配对、加密信道、消息信封、二维码载荷 | 2 |
| `lib/core/services/lan_sync/lan_sync_discovery.dart`、`lan_sync_network.dart`、`lan_sync_state_directory.dart` | UDP 信标与在线表、本机地址、原生通道、不备份的状态目录 | 3 |
| `lib/core/services/editing_session_registry.dart` | 编辑会话 / 撤销窗口登记、“同步已写入”事件 | 7 |
| `lib/core/services/lan_sync/lan_sync_session.dart`、`lan_sync_service.dart`、`lan_sync_store.dart` | 会话状态机、服务端与自动同步、配对设备与偏好、同步记录 | 11 |
| `lib/ui/lan_sync/` | 界面（pages / controllers / providers / models / sections / widgets） | 8、9、10、11 |
| `android/app/src/main/kotlin/com/jotsy/diary/LanSyncChannel.kt` | `com.jotsy.diary/lan_sync`：组播锁、设备名、`noBackupFilesDir` | 3 |

所有同步引擎类都通过构造参数注入数据库（`AppDatabase`）、数据根目录（`Directory dataRoot`，对应 `appDataRootDirectory()`）、状态目录（`Directory stateDir`）与 `SettingsService`，**不在引擎内部调用 `appDataRootDirectory()` / path_provider**：端到端测试要在一个进程里跑两台“设备”。只有 `lan_sync_service.dart` 的生产装配处解析真实目录。

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

| 文件 | 内容 | 任务 |
|---|---|---|
| `identity.json` | `{v:1, deviceId（UUID v4）, ed25519Seed（base64）, createdAt（UTC 毫秒）}`；不使用静态 X25519（握手只用临时 X25519） | 2 |
| `store.json` | 偏好（设备名、可被发现、自动同步、同步设置）、已配对设备（deviceId、名称、平台、身份公钥、配对时间、上次同步、上次地址、单设备自动同步）、标记（`restoredPending`） | 11 |
| `checkpoint.json.gz` | 上次会话时的本机观测：清单 + tags / orderList 分面的当前值（下次进历史时要用旧值）+ 标签名 → 本地 id 映射 + 观测覆盖的实体集合 | 4 |
| `history.json.gz` | 分面历史：`SyncKey → 分面 → [{hash, value?, seenAt}]`，每分面最多 8 条，新的在前；tags 与 orderList 分面同时记录值 | 4 |
| `tombstones.json.gz` | 墓碑：`SyncKey → {deletedAt, known: 分面 → [哈希…]}`（删除时的当前哈希 + 历史）；超过 365 天或超过 50 000 条时按时间淘汰 | 4 |
| `renames.json.gz` | 标签改名记录：旧名 → 新名、时间（随墓碑同样淘汰） | 4 |
| `hash_cache.json.gz` | 记录键 → [原始列指纹（行原始列值的 sha256 前 16 字节）, 规范分面哈希]；按键索引、整份重写，天然只留当前存在的行；带 `kSyncFormatVersion` 与 `kSyncCanonicalRevision`，不符即作废。只缓存要解码的行（日记的行分面、日记本、模板、纪念日），其余每次现算 | 4 |
| `media_index.json.gz` | 媒体键 → 大小、修改时间、sha256（大小或修改时间变了就重算） | 4 |
| `sessions.json` | 最近 50 次同步记录 | 11 |

- **刷新检查点**（每次会话开始时，在冲刷编辑会话之后）：算出当前清单 C，与检查点 P 比较——
  - P、C 都有且某分面哈希不同：把 P 中的旧哈希（及 tags / orderList 的旧值）插到该分面历史最前，`seenAt` 为当前时间；
  - P 有、C 没有：写墓碑（`known` = P 中各分面哈希 + 各分面历史）；tag 若同一本地 id 在 C 里换了名字，记为改名（旧名 → 新名），旧名仍写墓碑；
  - C 有、P 没有：新记录，无历史；本机若还有它的墓碑或改名记录（删了又建回同名记录）一并去掉——墓碑只描述本机“现在没有”的记录；
  - 写墓碑时该键的历史并进 `known`、不再单独保留；历史按哈希去重（同一哈希只留最新的一条）；已有指向旧名的改名（x → 旧名）顺带改指向新名，规划器只需查一跳；
  - 只比较本次观测到的实体：没请求 settings 时，检查点里 settings 的旧条目原样保留，不当作删除；
  - 然后检查点 := C。
  - 先写历史、墓碑、改名，最后写检查点：中途失败时检查点仍是旧的，下次刷新把同一份差异再折一遍，结果相同。
  - 状态文件读不出（不存在、解压或解析失败）一律当作空并 debugPrint：丢了这些“记忆”只会让规划多判冲突、按并集合并，删除不传播，最坏是多出数据、不会丢数据。
- 写入后（第 6 节）同一套规则以写入后的清单更新历史、墓碑与检查点：被同步删掉的记录写墓碑，被替换的值进入历史。
- **哈希缓存**：计算清单时先算每行原始列的指纹（便宜），命中缓存直接取分面哈希，未命中才做规范化（解码正文、归一路径、编码），整体在 `Isolate.run` 中进行；缓存只保留当前存在的行。
- **覆盖恢复**：`DataArchiveService` 的 replaceAll 成功后删除检查点、历史、墓碑、改名、哈希缓存，并在 `store.json` 置 `restoredPending`（任务 11 接线；任务 4 提供 `resetAfterRestore()`）。之后与每台设备的第一次同步走“以哪边为准”（4.5）。
- **身份**：`identity.json` 缺失或内容损坏时重新生成（`LanSyncIdentityStore.loadOrCreate()` 返回 `created: true`），调用方据此清空已配对设备与上述同步状态（视为一台新设备）；读文件本身的 I/O 错误（权限等）照常抛出，不当作损坏。

## 4. 合并判定（规划器，`sync_planner.dart`）

发起方是唯一规划者：持有双方清单、所需完整记录、双方相关键的历史与墓碑，产出 `SyncPlan`（双方各一份写入列表 + 统计 + 需要用户确认的事项）。规划器是纯函数，不碰数据库与文件。

记号：L = 本机（发起方）分面哈希，R = 对方分面哈希，H_L / H_R = 双方该分面历史（哈希集合）。

### 4.1 两边都有的记录，逐分面
1. L == R：不动。
2. R ∈ H_L：L 是 R 的后代 → 取 L（推给对方）。
3. L ∈ H_R：R 是 L 的后代 → 取 R（写到本机）。
4. 否则真冲突：
   - diary.content：stamp 较新者（平手按 deviceId 字典序较大者）留在原 id；另一份写成**冲突副本**：新 `diaryId = UUIDv5(命名空间, 原 diaryId + 败方 content 哈希)`（中断重试不重复）；标题 = 原标题 + 本地化后缀（由调用方传入，如“（冲突副本 · ThinkPad）”）并截断到 200；metadata 加 `sync.conflictOf = 原 diaryId`；副本继承**败方**的 tags、日记本成员（含章节）、capsule、archive、trash、pin 分面——私密日记本里的内容不能因副本而出现在全部日记，未解封的胶囊不能提前解封。
   - diary.tags、orderList.items：取双方历史中最近的共同祖先值（同一哈希出现在两边历史里、且 `seenAt` 最新者）做三方合并（集合：祖先 ∪ 双方新增 − 任一方删除；列表：保留祖先顺序，依次并入双方新增项、去掉任一方删除项，确定性规则：按 L 的相对位置插入 L 的新增，再按 R 的相对位置插入 R 的新增），找不到共同祖先时取并集（列表：L 的顺序 + R 独有项按 R 顺序追加）。
   - diary.stamp：取较大值（不是冲突）。content 的最终值与任一方不同（或取了对方的 content）时，最终 `updatedAt` 至少为 max(L, R)，并在与写入方原值相同时 +1 秒，保证各处按 `diaryId + updatedAt` 的缓存失效。
   - 其他分面：取该分面“变化发现时间”（历史头条的 `seenAt`，没有历史时用记录自身时间字段）较新的一方，平手按 deviceId 较大者。

### 4.2 只有一边有的记录
- 设缺失一方对该键有墓碑 T：
  - 在场一方**每个分面**的哈希都在 `T.known` 对应分面里（它没在删除之后改过）→ 删除传播到在场一方；
  - 否则（在场一方删除后又改过，或两边无关）→ 保留，复制给缺失一方（“改过的赢”）。
- 缺失一方没有墓碑 → 新记录，复制。
- tag：还被任何最终日记引用的标签名不删除；改名记录（缺失一方 `renames` 有 旧名 → 新名、且新名在最终集合里）让对方**原地改名**（保持本地 id，见 6.3）。

### 4.3 从属与复活
- 复活（4.2 中“保留并复制”的被删记录）时，它的从属记录一并按保留一方为准：日记 → 它的成员、留言、tags 分面、引用它的纪念日关联；日记本 → 它的成员、书序列表、子本的 `parentId`。
- 给已被对方删除的日记新增或修改留言，算作对日记的修改（该日记复活）。
- 最终状态里日记或日记本不存在的成员关系、书序项一律丢弃；留言所属日记不存在时丢弃；纪念日 `linkedDiaryId` 指向不存在的日记时置 null。
- 智能日记本没有成员与书序；成员的 `chapterId` 不在目标日记本的章节里时写 null。

### 4.4 日记本层级
在最终日记本集合上按 `NotebookHierarchy`（`lib/core/database/app_database_notebook_hierarchy.dart`）口径校验：上级必须存在且为手动本、不成环、深度不超过 `kNotebookMaxDepth`；不合法的按业务 id 排序确定性地断开（`parentId` 置 null），写入精确的 `parentId`。

### 4.5 需要用户确认的情况（规划器只报告，会话层决定）
- **删除保护**：任一侧将彻底删除的日记数 > max(20, 该侧日记总数的 10%)。
- **以哪边为准**：本次与该设备是首次同步、或任一侧 `restoredPending`，且出现没有共同祖先的冲突时，列出数量，请用户选：保留两份（按 4.1 生成副本）/ 以本机为准 / 以对方为准；后两种对这些冲突直接取一方，不生成副本、不删除任何记录。
- 自动同步遇到以上任一情况：中止，不写入，在同步页标记“需要确认”。

### 4.6 产出
`SyncPlan`：
- `localWrites` / `remoteWrites`：每项为 `SyncWrite{ key, expected: 规划时依据的该方当前分面哈希（记录不存在为 null）, record: 最终规范记录（删除为 null） }`；冲突副本是 `expected == null` 的新增；
- `mediaNeeded`：每方需要从另一方取得的媒体键；
- 统计（每方：新增 / 更新 / 删除，按实体）、冲突副本列表（原 id、副本 id、标题）、待确认事项。

## 5. 协议

### 5.1 发现（UDP）
- 信标 JSON：`{"j":"jotsy-lan","v":1,"id":deviceId,"n":名称,"p":平台,"port":TCP端口,"fp":身份公钥指纹前 8 字节十六进制,"f":kSyncFormatVersion}`。
- 发送到 255.255.255.255:47561 与组播 239.255.47.61:47561；同步页打开时每 2 秒，前台自动模式每 5 秒；收到他人信标即记入在线表，8 秒没收到即离线；忽略自己的 deviceId。
- Android 发现期间持有 `MulticastLock`（原生通道 `acquireMulticastLock` / `releaseMulticastLock`）。
- 本机地址：私有 IPv4、非回环、优先 Wi-Fi / 以太网接口；供二维码与英雄卡显示。

### 5.2 连接与加密
- TCP 服务端优先 47562，占用时随机端口（信标里广播实际端口）。
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

### 5.3 会话消息（任务 11 定稿）
`hello`（格式版本、应用版本、deviceId、名称、平台、实体集合、是否同步设置、意图 sync/pair）→ `reject{reason: version|busy|untrusted|declined}` 或继续；`manifest.get` / `manifest`（gzip，含墓碑键列表）；`records.get{keys}` / `records`（分批）；`history.get{keys}` / `history`（分面历史与墓碑详情）；`media.have{keys}` / `media.status`；`media.get{keys}` 与 `media.put`（二进制块，附大小与 sha256）；`apply{writes, mediaKeys}` / `applied{skipped, manifest}`；`done` / `abort{reason}`。双方版本不一致（格式版本或实体集合）即拒绝并提示升级；缺少某类实体、对方不提供设置，从不视为删除。

## 6. 写入（`_AppDatabaseSyncOps` + `sync_apply.dart`）

1. 等待撤销窗口结束（`EditingSessionRegistry.waitForUndoWindows`，超时则本次推迟）。
2. 媒体：需要的文件已流式写入 `<dataRoot>/.lan_sync_staging/<会话>/`（与数据根同一文件系统，保证改名原子），按 sha256 校验；目标键已存在：sha256 相同则直接复用，不同则**不覆盖**，为来件换新键并在本次写入的记录里改写引用（规划器之后的这一步由写入层处理，并把改键告知对方，对方同样改写，保证两边规范形式一致）；文件就位用改名，不沿用发送方的修改时间。
3. 在 `DataArchiveService.runSerialized` 中开**单个** Drift 事务：
   - 逐条比对前置条件：本机该记录当前分面哈希 ≠ `expected` → 跳过这一条（记入 `skipped`，下次同步再处理）；
   - 按原值写入列（业务 id ↔ 本地 id 换算；标签按名称 `ensureTagsByName` 口径但**不改已有标签颜色**，颜色只由 tag 记录决定；删除时手动清理关联行，与 `hardDeleteDiary` 等现有删除路径的清理范围一致：日记 → diary_tags、diary_notebooks、留言、纪念日关联；日记本 → diary_notebooks、书序；标签 → diary_tags）；
   - 不调用 `deleteNotebook` / `mergeNotebook`（它们的子本上提会覆盖另一边的移动），层级以计划里的精确 `parentId` 为准；
   - orderList 写入后按列表重排 `sortOrder` / `position` 为 0..n-1，列表里没有的现有项按原相对顺序排在末尾；
   - 模板删除时同时移除指向它的日记本默认模板（`NotebookPayload.templateId`）；`DiaryTemplatePrefs` 是设置，由 settings 同步处理；
   - 事务内算出写入后的清单。
4. 事务提交后：用写入后的清单更新历史、墓碑与检查点（第 3 节），移动暂存媒体的残留清理，发出 `EditingSessionRegistry.notifyDataReplaced()`。
5. settings 分面经 `BackupSettings.restore` 只应用本次变化的键（部分节点），背景图从暂存目录拷入 `app_backgrounds/`；失败按 `SettingsServiceBackup` 的快照回滚。部分节点由 `syncSettingsRestoreNode` 生成（`tagOrderNames` 按写入后的标签表换回本地 id）。注意 `BackupSettings.restore` 对若干键的“空值”什么也不做（`tagOrderRaw` 为空串，`diarySortModeRaw` / `diaryLayoutModeRaw` / `diaryToolbarOrderRaw` / `tagPickerSortRaw` / `diaryLocationPrecisionRaw` / `appLocaleCode` 为 null 或空串时保留本机值），另外它总会顺带 `clearCreateDiaryDraft()`：要把这些键清空时写入层须直接调用对应的 setter，否则本机规范值不变、下次同步会反复判为差异。

标签原地改名：计划里出现 旧名 → 新名 的改名时，更新那一行的 `name`，本地 id 不变（编辑器与 `tagOrderRaw` 持有本地 id）。

## 7. 并发安全（任务 7：`EditingSessionRegistry`）

- **阻塞者**：编辑页与发布页（`DebouncedAutoSaveController`）、纪念日编辑页、日记本编辑页、模板编辑页、留言编辑面板、目录页与日记本管理页的拖动排序进行中。登记期间不发起自动同步，对方的会话请求以 `busy` 拒绝；手动同步提示“请先关闭正在编辑的页面”。
- **冲刷者**：预览页待办自动保存（`DiaryTodoAutoSaveController`）。会话开始时 `flushAll()`；写入后由 `notifyDataReplaced` 让其文档重新读取。
- **撤销窗口**：带按钮（撤销）的 `showTrackedSnackBar` 显示期间计数；同步写入前等待清零。
- **写入后失效**：界面层监听 `dataReplaced`，失效一次性读取的 provider（`diaryDetailProvider` 族、`userDiaryTemplatesSnapshotProvider`、日记本相关的一次性读取等）。实时查询（`watch…`）由 Drift 自动刷新。

## 8. 安全与隐私

- 只有已配对设备能建立同步会话；配对需双方确认（核对码）或扫码（一次性令牌）。
- 本机开启了应用锁、或存在上锁日记本，且 `AppPlatform.supportsDeviceAuth` 时，确认配对前先经 `DeviceAuthService` 验证；Linux 不支持身份验证，只提示。
- 首次配对时说明：同步会双向合并两台设备的全部数据（含私密日记本与回收站），建议先导出完整备份（提供入口）。
- 所有传输端到端加密；身份私钥只在 `stateDir`，不进备份、不进 SharedPreferences。
- 隐私政策（`docs/privacy.html`）补充局域网同步与相机权限说明。
