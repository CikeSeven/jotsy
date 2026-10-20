# AGENTS 协作规范（node_note）

## 1. 文档定位与适用范围
- 必须：本文件是仓库协作规范主入口，适用于整个项目（代码、文档、提交流程、评审）。
- 必须：项目内规则优先级为 `AGENTS.md > 口头约定 > 默认习惯`。
- 必须：若与上层系统/平台硬性指令冲突，以上层指令为准，并在沟通中说明冲突点。
- 禁止：按个人偏好绕开本文件已定义的硬性规则。
- 例外：紧急修复可先提交止血补丁，但后续必须补齐规范项。

## 2. 项目目录结构说明（树状 + 职责）
```text
.
├─ lib/
│  ├─ main.dart                      # 应用入口
│  ├─ app/                           # App 装配与主题系统
│  │  └─ theme/                      # Expressive 控件/表面/动效 token、配色与 provider
│  ├─ core/
│  │  ├─ database/                   # Drift 数据库（schema / query / write / migration / 纪念日 ops / 草稿箱 ops / 模板 ops / 日记本 ops（本子、成员与书序、统计）/ 日记范围与私密排除 SQL / 智能日记本规则拆分）
│  │  └─ services/                   # 跨模块服务（设置、功能管理开关（AppFeatures）、定位、天气、封面存储、导入字体、备份与网盘备份、其他日记应用与云端笔记导入、设备身份验证（应用锁与上锁日记本共用）、分享到其他应用、按日期读取相册照片、图片尺寸与长图分片、应用内更新（检查 / 镜像线路 / 下载校验 / 安装）等）
│  ├─ ui/
│  │  ├─ diaries/                    # 日记主业务模块（已分层）
│  │  │  ├─ pages/                   # 页面壳层（路由/生命周期/组合）
│  │  │  ├─ controllers/             # 业务编排（搜索/筛选/撤销/发布链路、首页日记本范围与收录等）
│  │  │  ├─ providers/               # 状态与筛选条件
│  │  │  ├─ models|viewmodels/       # 数据模型与局部派生状态（models/diary_card_style/：卡片样式模型、预设与样式码；models/diary_preview_style/：预览页样式、阅读行为、预设与样式码；models/style_library/：各样式编辑页共用的“我的样式”、样式码与 JSON 工具）
│  │  │  ├─ export/                  # 导出写出器（正文块模型、PDF / Word / Markdown / 网页 / 纯文本 / CSV、成书结构、媒体与命名、跟随正文排版的导出字体）
│  │  │  └─ sections|widgets/        # 可复用 UI 区块（widgets/diary_card/：列表、瀑布流、搜索、归档与日历共用的日记卡片；widgets/diary_preview/：预览页的单篇视图、整页内容、各区块与左右翻页器；widgets/publish_panel/：发布页与编辑页共用的元数据面板区块；widgets/diary_color_panel/：编辑器悬浮工具栏的文字 / 背景颜色按钮与卡片内颜色面板（色板页预设色块与“我的颜色”一行（新建、横向滚动、管理）、自定义页色谱取色与颜色代码输入）；widgets/diary_day_photos/：补写日记时“这天拍的照片”提示条、全部面板（编辑页 ⋮ 菜单“这天的照片”也打开它）与缩略图格子）
│  │  ├─ anniversaries/              # 纪念日与倒数日（日期推算、编辑页；日历与预览页的入口复用它）
│  │  ├─ diary_templates/            # 日记模板（模型与正文白名单、变量、推荐规则、内置模板、套用与撤销、建议条与模板面板、管理页与模板编辑页）
│  │  ├─ notebooks/                  # 日记本（书架面板 / 编辑页 / 管理页、首页范围与头部卡片、选本面板、目录与章节、智能规则编辑、统计与写作目标、上锁验证与重锁遮罩、导出成书入口）
│  │  ├─ home|calendar|explore|settings/  # home/providers/：首页之外的页面请求切回“日记”Tab（如预览页点日记本胶囊）；home/models/home_tab.dart：首页 Tab 身份与按功能开关推出的可见 Tab；settings/providers/：功能管理开关 appFeaturesProvider
│  │  └─ widgets/                    # 跨 feature 公共 UI（导航、Expressive 选择组/加载、看图页（含长按分享 / 保存 / 打开日记面板）、列表右侧字母索引条 alphabet_index_bar.dart 等；expressive_menu/：全应用共用的锚定弹出菜单；long_image/：长图判定、保持比例的解码尺寸、分片拼图与 cover 裁切对齐）
│  ├─ l10n/                          # 国际化封装
│  └─ utils/                         # 工具函数（pinyin/：由 Unihan 生成的汉字拼音表与名称 A–Z 索引 NameIndexKey）
├─ assets/                           # 静态资源
├─ test/                             # 测试（performance/：手动启用的合成大数据微基准）
├─ integration_test/                 # 实机集成测试（隔离设置与数据库，验证录音/播放）
├─ tool/                             # 开发与 CI 脚本（check_arb.dart：ARB 文案规范检查，规则在 arb_lint.dart；write_update_manifest.dart：发布时生成应用内更新清单，逻辑在 update_manifest.dart；generate_pinyin_table.dart：由 Unihan 生成汉字拼音表）
├─ docs/                             # 项目文档（*.md、releases/ 中英版本说明）与官网（GitHub Pages 源目录：index.html / privacy.html / 404.html，样式脚本图片配色在 assets/）
├─ .github/                          # CI 门禁 workflows/ci.yml、发布 workflows/release-apk.yml、官网下载次数统计 workflows/download-stats.yml、共用的 actions/setup-flutter（唯一定义 Flutter 版本）、Dependabot
├─ android/ ios/ web/ windows/ ...  # 各平台工程
└─ AGENTS.md                         # 协作规范
```
- 必须：新增代码按职责放置，避免跨层污染。
- 禁止：在页面层直接实现数据库细节与复杂业务编排。
- 例外：短期 PoC 可临时放置，但合并前必须归位到对应层。

## 3. 模块分层规则
- 必须：`pages/` 仅负责装配（路由参数、生命周期、provider watch、widget 组合）。
- 必须：业务流程（异步链路、批量操作、撤销、防抖、发布流程）放 `controllers/`。
- 必须：数据映射、草稿模型、metadata 组装放 `models/` 或 `viewmodels/`。
- 必须：可复用 UI 放 `sections/` 或 `widgets/`，避免页面文件膨胀。
- 必须：`core/database` 维持按职责拆分（query / write / migration / tag ops / anniversary ops / draft ops / template ops / notebook ops / scope SQL）。
- 禁止：单文件混杂“页面布局 + 业务编排 + 数据转换”。
- 例外：极简静态页面可不强制拆 controller。

## 4. 编码与命名规范
- 必须：所有源码、配置、文档均使用 UTF-8 编码（避免中文乱码）。
- 必须：命名统一：文件 `snake_case`、类 `UpperCamelCase`、成员 `lowerCamelCase`。
- 必须：遵循现有 Dart/Flutter 代码风格与 lint 约束。
- 必须：单文件超过约 300 行时触发拆分评估；出现职责混杂时必须拆分。
- 必须：优先复用已有组件与服务，避免重复造轮子。
- 必须：本地化文案统一走 `gen-l10n + ARB`，代码中使用 `context.l10n.xxxKey`（或参数化 `xxxKey(arg)`），禁止新增硬编码中英分支。
- 必须：ARB 中每个文案 key 都要有对应 metadata（`@key`），至少包含 `description`；含占位符时必须补 `placeholders`。
- 必须：ARB placeholder 的 `type` 只能使用 Flutter `gen-l10n` 可接受类型（如 `String/int/double/num/DateTime`），禁止使用 `Object`。
- 必须：新增或修改 ARB 后同步执行 `flutter gen-l10n` 并提交生成文件，保持源码与生成代码一致。
- 禁止：继续使用 `context.l10n.tr(...)` 作为常规本地化方案（仅允许临时迁移阶段短期存在，且需在同任务内清理）。
- 禁止：冗余实现、死代码、复制粘贴式重复逻辑。
- 例外：生成文件（如 `*.g.dart`）不按手写文件拆分规则执行。

## 5. 注释规范（详细版）
- 必须：为复杂逻辑编写高价值详细注释，重点覆盖：
  - 异步流程（触发条件、顺序、失败回滚）
  - 状态机/多态 UI（状态边界与切换条件）
  - 定时器/防抖/队列（生命周期、取消时机、mounted 保护）
  - 边界条件与兼容策略（空值、异常、平台差异）
- 必须：复杂文件顶部添加职责边界注释（输入、输出、副作用）。
- 必须：注释解释“为什么这样做”，而不只描述“做了什么”。
- 禁止：低价值复述注释（如“给变量赋值”）。
- 例外：语义极直白的简单 getter / 纯样板代码可不写注释。

## 6. UI/交互统一规范
- 必须：项目视觉系统、色彩层次、字阶排版、组件规格与设计哲学详见 [DESIGN.md](DESIGN.md)，所有 UI 模块开发与评审均须遵循该规范。
- 必须：应用组件统一继承 `MaterialTheme` 的 Material 3 Expressive 主题；新增单选连接按钮组与等待状态分别复用 `ExpressiveButtonGroup`、`ExpressiveLoadingIndicator`，新增动效通过 `ExpressiveMotion` 尊重系统减少动画设置。Expressive 仍基于 `useMaterial3: true`，禁止以关闭 Material 3 的方式迁移。
- 必须：动画时长与曲线只取 `ExpressiveMotion` token（`fast/medium/standard/long`、`effects/exit/spatial`），并经 `ExpressiveMotion.duration(context, …)` 解析；禁止在 UI 层新增 `Duration(milliseconds: …)` 形式的动画时长（防抖/超时等非动画计时不受此限）。
- 必须：新增图标默认使用 `font_awesome_flutter`（`FaIcon` + `FontAwesomeIcons`）。
- 必须：富文本工具栏与设置页工具预览图标来源一致，避免混用。
- 必须：标题栏返回按钮统一使用 `<` 风格图标，即 `FontAwesomeIcons.angleLeft`，默认尺寸使用 `18`，避免在不同页面混用 `arrowLeft/chevronLeft/系统返回箭头`。
- 必须：Dialog 操作按钮统一为文本按钮：
  - 左侧按钮：灰色语义（取消/返回）
  - 右侧按钮：主色语义（确认）
  - 危险动作：右侧按钮使用 `colorScheme.error`
- 必须：内容少的操作（约 4 项以内、单行文字的动作）用 `ExpressiveMenuButton` / `ExpressiveMenuAnchor`（菜单项为 `ExpressiveMenuItem`，`lib/ui/widgets/expressive_menu/`）弹出菜单；项目多、需要说明文字、预览或分组时用底部面板（如预览页“更多”）。禁止在该目录之外使用 `PopupMenuButton`、`PopupMenuItem` / `PopupMenuEntry`、`showMenu` 或 SDK 的 `MenuAnchor`（`test/ui/widgets/expressive_menu_source_test.dart` 源码检查兜底）。菜单规格见 DESIGN.md §5.4。
- 必须：数据导入/恢复入口统一经 `chooseBackupImportMode`（`DataArchiveService.inspectZip` 只读预检 → 选择合并或覆盖），会改写本机已有数据的方式必须经 `showBackupOverwriteWarningDialog` 严重警告确认；禁止新增不经警告直接覆盖本机数据的入口。其他日记应用的导出经 `JournalImportService.prepare` 解析为备份载荷并只读预检，同样走 `chooseBackupImportMode`，写入复用 `BackupMerge`；新增来源只加 `journal_import_<来源>.dart` 解析器，不另建写库路径。解析器（含云端平台客户端）只把来源里的日记本 / 笔记本 / 文件夹名原样报告在 `JournalImportEntry.notebooks`，禁止自行转成标签；落成日记本、标签还是两者只由 `JournalImportFolderMode`（notebooks / tags / both）在 `buildJournalImportPayload` 里决定，用户在导入方式面板的“原来的日记本 / 文件夹”一节（`BackupImportFolderChoice`）选择，选择只记在内存 `journalImportFolderModeProvider`、不加设置键；落成日记本经 `JournalImportNotebookBuilder`，先按确定性 id（`journalImportNotebookId`）再按同名手动日记本复用，复用时载荷里放本机那一行的原样拷贝（合并并覆盖不得重置用户改过的图标、封面与章节），都没有才新建；名称落地时被规整或截断的，原名记在日记 metadata 的 `import.originalNotebooks`（与 `originalTags` 并列）。导入正文的文字色、背景色、字号与对齐只经 `journal_import_style.dart` 换算（颜色统一 `#AARRGGBB`、来源默认墨色不导入、字号只写 small / large / huge 三档、对齐只写 center / right / justify），分隔线一律写成 `diaryDividerEmbed`（`divider_embed_codec.dart`，由 `DiaryDividerEmbedBuilder` 渲染、导出为各格式的分隔线），禁止各解析器自拼颜色字符串或绝对字号；8 位十六进制颜色按来源约定区分 CSS `#RRGGBBAA` 与 Android `#AARRGGBB`（`journalArgbToCss`）。手机厂商与 WPS 的云端笔记经 `CloudNotesLoginPage` 在官方网页登录、`JournalImportService.prepareCloud` 读取（平台客户端为 `journal_import_cloud_<平台>.dart`，在 `cloudNotePlatforms` 登记），只做读取；登录 Cookie 只存在于本次导入的内存与网页视图中，登录前与导入结束后都必须清除，禁止落盘或用于读取以外的请求。平台客户端整篇不导入某篇笔记时（回收站中的除外）必须按原因记入 `CloudReadIssues`（加密 / 专有类型 / 无法识别），由导入预览逐项说明，禁止静默丢弃；参考实现「笔记互迁」是迁移工具，为“原笔记留在云端”而整篇拒绝的内容，导入时尽量降级保留（未知区块留文字、正文读不到用摘要并计入 `summaryOnly`），不照搬整篇拒绝。
- 必须：用户可感知的耗时等待操作（如启动预热、分页首屏加载、远程请求等待）统一使用 `loading_indicator_m3e` 的加载效果，不再新增 `CircularProgressIndicator` 作为主加载表现；页面首屏 `loading` 分支使用 `DelayedLoadingIndicator`（300ms 内不出现），动作等待遮罩使用 `ActionLoadingOverlay`。
- 必须：新增展示型图片（`Image.file/network/Image(image:)`）挂 `frameBuilder: expressiveImageFrameBuilder`，首次解码淡入、缓存命中直接显示；仅截图/导出用的静态图片例外。
- 必须：打开大图统一经 `openImageViewer`（来源图片用 `ImageViewerHeroSource` 包裹并在点按时 `ImageViewerHero.capture`）；看图页顶栏只放返回、页码与 ⋮，图片操作只经操作面板 `showImageViewerActionsSheet`（长按图片与 ⋮ 打开同一个）（只负责挑选：分享到已安装应用或“更多应用”、保存到相册、打开日记）→ `ImageViewerExportController`（执行；分享复用 `DiaryShareController`，按钮复用 `DiaryShareTargetButton.forTarget`），禁止再在顶栏加保存 / 分享按钮或另写图片分享链路；“打开日记”只在 `ImageViewerItem.diaryId` 与 `onOpenDiary` 都给出时出现，只由日记不在下层的入口（探索页媒体画廊）提供，预览页与编辑页看图不提供；状态驱动的颜色变化经 `ExpressiveStateBlend` 补间；新增触觉反馈只用于“动作生效/越过阈值”的瞬间，类型对照 DESIGN.md §4.3。
- 必须：启动品牌图形两端同源——原生 `drawable/launch_brand_mark.xml`、`values*/colors.xml` 的 `launch_*` 颜色与 `LaunchBrandMark` 几何、默认种子色，改动任一端须同步另一端；首页首屏新增一级区块经 `LaunchReveal` 声明启动编排槽位（见 DESIGN.md §4.3）。
- 必须：网盘备份（WebDAV、S3 兼容对象存储、授权类网盘）统一经 `CloudBackupService` 编排、`CloudBackupRemote` 访问远程，恢复同样走 `chooseBackupImportMode`；备份位置与凭据只存于 `CloudBackupSettingsService`（单个 JSON 偏好键 `app.cloud_backup.targets`，逐条容错解析，**不随备份导出**），禁止另加零散的连接/令牌设置键。授权类网盘的应用密钥只经 `CloudBackupAppKeys`（`--dart-define` 注入）读取，禁止写进仓库；授权只用系统账号授权（Android 上 Google Drive 经 Play 服务，不可用时回落设备码）、设备码或在系统浏览器授权后粘贴授权码（Google、Dropbox 禁止内嵌网页授权），刷新后的令牌必须立即落盘（多家会轮换刷新令牌）。新增网盘只加 `cloud_backup_<平台>.dart`（实现 `CloudDriveProvider`）并在 `cloud_backup_drives.dart` 登记；新增 WebDAV/S3 服务只在 `cloud_backup_presets.dart` 加预设、在 `cloud_backup_labels.dart` 加名称与填写说明。上传与下载一律流式读写文件，禁止整包读入内存。说明见 docs/cloud_backup.md。
- 必须：日记正文排版（字体、字号、行距、字间距、段间距）只存于 `DiaryTypography`（单个 JSON 设置键 `app.settings.diary_typography`，逐字段容错并随备份导出）；编辑页、预览页、发布页与设置预览的 Quill 样式一律经 `DiaryQuillStylesBuilder(appearance: ref.watch(diaryTextAppearanceProvider), …)` 在正文位置生成（禁止用页面 State 的 context 直接调用 `buildDiaryQuillStyles`：那里在 Scaffold 之上，只有 MaterialApp 的红色兜底样式），标题字体经 `DiaryTextAppearance.titleStyle`，禁止页面自行设置正文字号/行距或另加排版设置键。导入字体只经 `DiaryFontStorageService`（应用支持目录 `diary_fonts/`，字体文件不进备份，备份只带字体 id，缺失时回落内置字体）；修改经 `DiaryTypographyController`，滑块拖动只改草稿、松手才提交。规范见 DESIGN.md §3.2。
- 必须：日历页的显示偏好统一加在 `CalendarDisplayOptions`（单个 JSON 设置键 `calendarDisplayOptionsRaw`，逐字段容错解析并随备份导出），禁止为日历另加零散设置键；新增日期格样式经 `CalendarDayCell` 的填充/描边两种高亮形态实现。日历打点筛选 `CalendarMarkerFilter`（心情 / 标签 / 日记本三组，页面临时状态，不写进 `CalendarDisplayOptions`）的日记本组只列可见性为 normal 的手动日记本（`calendarFilterNotebooks`），禁止加入智能日记本或私密日记本；未解封的时间胶囊不参与筛选。视觉规范见 DESIGN.md §5.7。
- 必须：纪念日存 Drift `anniversaries` 表（业务 id `anniversaryId`；`linkedDiaryId` 存日记业务 id、不建外键），随完整备份导出、覆盖恢复与合并（按 `anniversaryId` 去重），日记包不含纪念日；某天落在哪、下一次是哪天一律经 `AnniversaryCalendar` 推算，禁止页面自行换算公历/农历；纪念日页面与提示统一经 `anniversary_navigation.dart` 打开，关联的日记只经 `watchActiveDiaryWithTags`（排除回收站）读取，彻底删除日记时解除关联。不做提醒通知。
- 必须：新建日记的草稿只存 Drift `diary_drafts` 表（业务 id `draftId`；`payload` 为 `NewDiaryDraft.toJson`，`title` / `contentText` 为列表镜像），每次新建都是独立的一份，经 `DebouncedAutoSaveController` 自动保存；返回、切后台与页面销毁时必须 flush，发布成功后先 `close` 自动保存再删除这一份。禁止重新引入单键草稿（旧键 `app.settings.diary_create_draft` 只作 `migrateLegacyCreateDraft` 的启动迁移来源），禁止“新建空白”删除已有草稿。所有新建入口（首页 FAB 与空列表、日历、探索）统一经 `runDiaryCreateEntryFlow`（有草稿时弹 `showDiaryDraftPickerSheet`，其中“从模板新建”再弹 `showDiaryTemplatePickerSheet`），禁止另写新建弹窗或绕过它直接打开新建编辑页；管理页为 `DiaryDraftsPage`（首页顶栏与设置 → 数据与隐私），删除与撤销经 `DiaryDraftsController`，媒体回收必须等撤销窗口结束、确定不撤销后才执行。草稿随完整备份导出与覆盖恢复（旧备份设置里的单份草稿在解析时转成草稿行），合并导入与日记包不带草稿；媒体清理把草稿 `payload` 当作引用来源。视觉规范见 DESIGN.md §5.14。
- 必须：日记模板的用户模板只存 Drift `diary_templates` 表（业务 id `templateId`；`payload` 为 `DiaryTemplateJson.toPayload`，`name` 为镜像，`sort_order` 为手动排序）；内置模板只由 ARB 文案经块描述编译（`buildBuiltInDiaryTemplates`，id 为 `builtin.<key>`，只读，想改就“复制为我的模板”），禁止落库。行为偏好（建议条开关、按时间段自动套用的规则 `autoRules`（最多 12 条，JSON 字段 `rules`，逐条容错解码）与其他时间的默认模板 `autoTemplateId`、隐藏的内置模板、最近使用）只存于 `DiaryTemplatePrefs`（单个 JSON 设置键 `app.settings.diary_template_prefs`，逐字段容错并随备份导出与失败回滚）；删除或隐藏模板时一并移除指向它的规则与默认模板，撤销时放回，禁止另加零散的模板设置键。模板随完整备份导出与覆盖恢复；两种合并都只新增本机没有的模板（按 `templateId`），从不覆盖本机模板；日记包不带模板。正文只允许文字与分隔线：保存、导入模板码、读出数据库行、另存为模板一律经 `sanitizeDiaryTemplateOps` 白名单清洗，禁止任何媒体嵌入或设备路径进入模板。变量只经 `DiaryTemplateVariable` 的中英别名表解析（认不出的原样保留），取值经 `DiaryTemplateVariableValues`：日期类按日记日期（补写取那一天），时间按当下，农历与节气只经 `CalendarLunarDay`；ARB 不能写字面 `{{…}}`，内置文案用 ICU 占位符填入变量写法。套用只经 `DiaryTemplateApplyController`：只在新建空白日记、标题与正文都为空时套用，预设只填空着的项（心情须在本机心情选项里，日历预设的胶囊优先），套用后原样未动的内容不算草稿（`snapshotFor`），撤销只在内容仍原样时生效；自动套用只经 `DiaryTemplatePrefs.autoApplyCandidates` 给出候选（只在日记日期为今天时看时间段，更具体的在前，默认模板最后），套用第一个仍存在的；换模板（顶栏菜单“选择模板”与“全部”面板）只经 `apply(..., replacePristine: true)`，只在内容仍是本次套用的模板原样时替换（先撤回旧模板的预设与它新建的标签），用户写过字时只提示、禁止覆盖；预设标签按名称经 `ensureTagsByName` 匹配、只新建缺失的，禁止在模板模块调用会改色的 `createTag`。新建编辑页的建议条与模板面板读一次性快照 `userDiaryTemplatesSnapshotProvider`（管理页每次写入后 invalidate），禁止在编辑页挂模板表的实时查询。管理页为设置 → 编辑器设置 → 日记模板（`DiaryTemplatesPage`，读写经 `DiaryTemplatesController`），模板码格式为 `jotsy-template:v1:`（`StyleCodeFormat`）。视觉规范见 DESIGN.md §5.15。
- 必须：日记本存 Drift `notebooks` 表（schema v13；业务 id `notebookId`；`kind`（manual / smart）与 `visibility`（normal / hidden / locked）是独立列，供 SQL 过滤，其余可演进设置（简介、图标、颜色、封面、章节、排序、写作目标、默认模板、智能规则）只放 `payload`，格式与逐字段容错见 `NotebookPayload`）；成员关系存 `diary_notebooks` 关联表（两端都是本地 id，带 `chapter_id` 与本内 `position`），一篇日记可同时在多本里（多对多），移出日记本不删除日记。库里从不开启外键，彻底删除日记、删除日记本、合并日记本与覆盖恢复等每条删除路径都必须在同一事务里手动清理关联行。只有手动日记本有成员行；智能日记本的成员只经 `NotebookRuleSet`（最多 12 条，认不出的规则原文保留为 `NotebookUnknownRule`）→ `compileNotebookRules` 编译为 SQL 现算（首页范围、头部统计与书架篇数共用 `compileNotebookPayloadRules`），规则里的标签只存名称、禁止存本地 id，空规则与认不出的规则一律编译为不匹配，未解封的时间胶囊只按标题、日期与置顶参与匹配；智能本可经 `convertSmartNotebookToManual` 转为普通本。私密：只有手动日记本能设为隐藏 / 上锁（智能本写入时一律存 normal）；私密日记（在任一手动、可见性非 normal 的本子里）只经统一谓词 `_privateDiaryExclusionSql` 从所有全局查询（全部日记、搜索、探索、日历、归档、导出候选等）中排除，只在它所在的私密本里出现；新增全局日记查询必须经 `_writeDiaryScopeFilter`（或该谓词）过滤，并把 `notebooks` 与 `diary_notebooks` 加进 `readsFrom`（`_diaryScopeReadsFrom`）；回收站与按 id 直接打开不过滤；认不出的可见性按 locked 解读（`NotebookVisibility.fromName`）。上锁：进入上锁本子只经 `authorizeNotebookEntry`（`DeviceAuthService`，与应用锁同一口径，设备没有锁屏密码时不放行）；编辑、合并、转换、删除这类会露出内容或设置的操作（`notebookRevealingActions`）一律经 `runNotebookAction` 先验证，禁止绕过；首页停在上锁本子时切到后台即由 `NotebookLockLayer` 盖住整个应用，回来须重新验证。首页范围：当前所在的本子与章节只存于 `homeNotebookScopeProvider`（内存，不持久化、禁止加设置键，每次从全部日记启动），日记本到查询范围的换算只经 `resolveNotebookScope`；首页之上的页面打开某本经 `openNotebookFromAnywhere`。收录：成员的增删与移动只经选本面板 `showNotebookPickerSheet`（三态）+ `NotebookMembershipOps`（撤销信息在写入时一并取得）、发布面板与编辑页的日记本行（`PublishNotebookTile`，随日记保存在同一事务里改写，仍选中的本子保留章节与位置）以及数据库层的成员 ops，禁止页面直接写 `diary_notebooks`；首页多选与目录页的移出必须带撤销（`persist: false`）。在本子里写：首页停在某本普通日记本时新建经 `runDiaryCreateEntryFlow(notebookId:, chapterId:)`，新建空白时套用这本的默认模板（`NotebookPayload.templateId`，优先于 `autoApplyCandidates`；用户在草稿面板选了模板时以所选为准），续写已有草稿原样打开。章节与书序：章节只有一层，存于 payload（`NotebookChapter`），删除章节时其中的日记回到“未分章”；手动书序只经目录页（`NotebookContentsPage` → `NotebookContentsController`）由 `reorderNotebookEntries` 一次写回整份顺序；本子排序为书序（`NotebookSort.book`）时按章节顺序 + 本内位置排，列表排序与置顶不生效，智能本没有书序。备份：两张表随完整备份导出与覆盖恢复；合并经 `BackupNotebookMerge` 按 `notebookId` 匹配（本机没有的新增；合并保留本机定义，合并并覆盖替换定义、保留本机书架顺序），只写本次实际写入的日记的成员关系，章节只认目标本现有的章节，智能本从不写关联行；日记包（`BackupPayload.captureDiaries`）只带包内日记所在的手动本及其成员行。封面只经 `DiaryCoverStorageService` 拷贝到私有目录，随备份作为媒体搬运（`rebindNotebookPayload`），`DiaryMediaCleanupService` 把日记本 `payload` 当作引用来源。导入与导出成书见导入、导出两条规则。统计与目标：统计页 `NotebookInsightsPage` 与头部卡片的字数只经 `DiaryWordCounts`（`TextStats` 口径）；写作目标（`NotebookGoal`）只对手动本计算进度，不做提醒通知。日历只支持按手动本筛选（见日历规则）。管理页为设置 → 日记本（`NotebooksPage`）。视觉规范见 DESIGN.md §5.16。
- 必须：发布面板标签子页（`PublishTagPickerPage`）的排序方式（`TagPickerSort`：默认排序即标签管理里的顺序 / 按字母）只存于设置键 `app.settings.tag_picker_sort`（随备份导出），经 `tagPickerSortProvider` 读写；筛选与分组只经 `TagPickerView`，检索词只在子页内存里。汉字的 A–Z 归组、拼音排序与拼音检索只经 `NameIndexKey`（`lib/utils/pinyin/`），拼音表 `pinyin_table.dart` 由 `tool/generate_pinyin_table.dart` 从 Unihan `kMandarin` 生成，禁止手改，禁止为此引入把整本字典编进安装包的拼音库；列表的字母索引条复用 `AlphabetIndexBar`。视觉规范见 DESIGN.md §5.17。
- 必须：日记卡片外观统一收在 `DiaryCardStyleSettings`（单个 JSON 设置键 `diaryCardStyleRaw`：当前样式 + 最多 12 份“我的样式”，逐字段容错解析，随备份导出与失败回滚），渲染统一经 `DiaryCard` + `DiaryCardResolvedStyle`；禁止各页另拼日记卡片或另加零散的卡片外观设置键（标签显示数量 `diaryCardTagLimit` 为既有独立键）。`DiaryCardStyle.defaults` 必须逐项等于 DESIGN.md §5.1 的默认规格；未解封胶囊只套用表面样式，心情色与标签色回退主题色。编辑入口为设置 → 外观与语言 → 日记卡片样式（日记页视图选项面板有快捷入口）。
- 必须：日记预览页的外观与阅读行为统一收在 `DiaryPreviewSettings`（单个 JSON 设置键 `diaryPreviewStyleRaw`：当前样式 + 最多 12 份“我的样式” + 阅读行为，逐字段容错解析，随备份导出与失败回滚）；渲染统一经 `DiaryPreviewContent` + `DiaryPreviewResolvedStyle`（页面外壳 `DiaryPreviewSurface`），设置页预览复用同一套组件；阅读行为不随预设与样式码改变；正文字体与排版仍只在 `DiaryTypography`，禁止另加零散的预览页设置键。`DiaryPreviewStyle.defaults` 必须等于 DESIGN.md §5.8 的默认规格。样式编辑页（卡片、预览页）共用 `StyleEditorScaffold`、`StyleEditorController` 与 `StyleLibraryTab`，禁止复制一份。
- 必须：预览页左右滑动切换日记统一经 `DiaryPreviewPage(sequence:)`：入口传进入时所在列表的 `DiaryPreviewSequence`（打开时冻结顺序；首页 / 搜索还有没加载的部分时带 `DiaryPreviewListQuery`，由 `getActiveDiaryIds` 按同一筛选与排序接上），单篇入口不传；翻页器为 `DiaryPreviewPager` → `DiaryPagerView`（设置页预览复用同一个）。手势冲突只靠起滑距离倍数（外层放大、页内还原）与页内始终可滚动的 physics 解决，禁止另写翻页手势识别器，禁止在预览页内放横向滚动容器（会抢走翻页）。预览页的删除结果带被删日记的 id（`DiaryPreviewResult.deleted(id)`），入口按它撤销；预览页勾选待办只经 `updateDiaryContent` 写正文，禁止用会取消归档 / 删除、重写标签的 `updateDiary`。
- 必须：界面上的“字数”一律经 `TextStats`（`lib/utils/text_stats.dart`，按日记版本缓存用 `DiaryWordCounts`）计算，口径见 DESIGN.md §3.3；禁止自行用 `.length` 或按空白分词统计字数。
- 必须：日历的法定节假日（休/班）只取自 tyme 的 `LegalHoliday`，经 `CalendarHolidayDay` 读取，开关为 `CalendarDisplayOptions.holidayMode`；数字左上角标统一经 `CalendarCellLeadingBadge` 按优先级取一个，禁止在日期格另加角标位置。
- 必须：日记分享统一经预览页的分享面板 `showDiaryShareSheet`（只负责挑选）→ `DiaryShareController`（执行）；分享文字只经 `DiaryShareContent.composeText` 组装为纯文本（社交应用不渲染 Markdown），内容开关只存于 `DiaryShareOptions`（单个 JSON 设置键 `app.settings.diary_share_options`，逐字段容错并随备份导出），地点默认不带。分享到指定应用只经 `DiaryShareChannel`（Android 原生按包名发 Intent），图片先暂存到缓存 `diary_share/`（`DiaryShareFileProvider` 只暴露该目录，禁止直接交出日记原图路径），带图时文字经剪贴板传递；新增目标应用在 `DiaryShareTarget` 登记，并同步 `AndroidManifest.xml` 的 `<queries>` 包名。视觉规范见 DESIGN.md §5.9。
- 必须：日记导出统一经 `runDiaryExportFlow`（预览页“更多 → 导出”、日记列表多选、设置 → 数据管理 → 导出日记、日记本头部 ⋮ 菜单“导出成书”四个入口共用）：导出面板 `showDiaryExportSheet` 只负责挑选，生成、保存与分享由 `DiaryExportController` 执行；导出选项只存于 `DiaryExportOptions`（单个 JSON 设置键 `app.settings.diary_export_options`，逐字段容错并随备份导出）。正文一律先经 `ExportBlockParser` 解析为块再交给 `lib/ui/diaries/export/` 下的写出器（PDF 例外，仍经 flutter_quill_to_pdf 渲染，但图片只经虚拟地址交付、缺失图片与媒体嵌入先改写）；新增格式只加写出器并在 `DiaryExportFormat` 登记，禁止在页面里另写导出逻辑。导出成书经 `exportNotebookAsBook` 组装 `DiaryExportBook`（`notebookExportBook` / `smartNotebookExportBook`）传入 `runDiaryExportFlow`：顺序以书序为准，面板不显示先后选项；`supportsBookStructure` 的格式（CSV 与 Jotsy 日记文件除外）在选项最前显示“书籍结构”开关（默认开，只对本次有效，不写进 `DiaryExportOptions`），控制器按实际导出的日记解析为 `DiaryExportBookLayout` 交给写出器，写出器只读不改。各格式的书籍结构：PDF 为扉页、带真实页码与点按跳转的目录、章与篇的书签，每章另起一页；Word 为扉页与带链接的目录（不写页码），每章另起一页；网页为扉页、`<nav>` 目录与锚点；Markdown 全书合成一个文件，不写每篇的 front matter；纯文本为扉页、目录与带横线的章节标题。导出的字体跟随 `DiaryTypography`：选了导入字体时只经 `DiaryExportFont.load`（`DiaryFontStorageService.readFontBytes`）读取，PDF 经 `DiaryPdfFonts.load` 嵌入（`extractTrueTypeFace` 取出 TrueType 字面并试解析，CFF 轮廓或解析失败整份回落内置字体，缺字回落内置字体），Word 与网页只按字族名引用、不嵌入字体文件；禁止写出器自行读取字体文件或排版设置。未解封的时间胶囊在任何导出格式中都不导出（完整备份除外）；导出文件不得写出设备私有路径，媒体以包内相对路径或内嵌方式交付；批量导出的媒体一律按文件流式打包（`DiaryExportBundleFile.file`），禁止把全部照片读进内存，PDF 这类只能整份持有图片的格式须设总量上限并提示。视觉规范见 DESIGN.md §5.10。
- 必须：补写日记的“这天拍的照片”只经 `DayPhotoLibrary`（`dayPhotoLibraryProvider`；photo_manager 实现在 Android 按 `datetaken` 拍摄时间筛选，缺失时才退回 `date_added`）读取相册，状态经 `DiaryDayPhotosController`，界面为编辑页标题下的 `DiaryDayPhotosStrip` 与 `showDiaryDayPhotosSheet`；提示条只在新建模式且发表日期早于今天时自动出现，编辑器设置开关 `dayPhotoSuggestionsEnabled`（“自动显示当天照片”，默认开，本机偏好，不随备份导出）只控制这一自动出现；编辑页 ⋮ 菜单“这天的照片”在新建与编辑模式、相册可用且这天不在未来（新建取所选日期或今天，编辑取 `_draftPublishAt`）时出现，经 `DiaryDayPhotosController.browse()` 打开同一面板，不受该开关与“本次不再显示”影响。进入页面只查询授权状态，系统权限框只能由用户点“允许访问”触发；只申请图片读取权限（Android 13+ `READ_MEDIA_IMAGES` 与 14+ 部分授权，不申请视频、音频与照片位置）。插入复用 `DiaryMediaImportController.pickAndInsert(picker:)` 复制到日记私有目录，禁止删除、移动或改写相册原文件；勾选与已插入状态只在本次编辑页内存中，不落盘。设为封面只经 `DiaryMetaActions.setCoverFromFile` 拷贝到封面私有目录（与发布页选封面同一条链路），新建时写进草稿、编辑时写进这篇日记的封面并随编辑自动保存（禁止写入新建草稿），禁止直接引用相册原图路径作为封面。视觉规范见 DESIGN.md §5.11。
- 必须：展示型图片解码一律经 `boundedImageProvider` 保持比例缩小（禁止新增只给一边的 `cacheWidth`/`cacheHeight`、`Image.file(cacheWidth:)` 或 `ResizeImage.resizeIfNeeded`：另一边按比例推出后仍可能超过 GPU 纹理上限，被 Impeller 单独压扁）；长图（高 ≥ 宽 × 3）只经 `isLongImageSize` 判定，解码前的尺寸只经 `ImageDimensions` 读取（只读文件头）。正文图片经 `DiaryEmbeddedImage`：比列宽窄时靠行首（段落带对齐属性时从之），长图折叠为 `DiaryLongImageFold`（预览页阅读行为 `longImageMode` 为完整显示时用 `DiaryLongImageFull`，分片按滚动可见范围构建）；点按菜单只经 `showDiaryImageOptions`（“查看”经 `openImageViewer`），禁止回退到上游 `ImageOptionsMenu`；看图页每页经 `ImageViewerImagePage`，长图按屏宽竖向滚动（`DoubleTapZoomViewer.tall`）并关闭该页的下拉关闭；cover 裁切的封面与缩略图经 `CoverCroppedImage`（长图顶部对齐）。长图分片只经 `LongImageTileService`（Android 原生 `DiaryLongImageSlicer`，缓存 `getTemporaryDirectory()/diary_image_tiles/`，不随备份导出，原图只读），原图已不存在的分片目录由 `sweepDiaryMediaFiles` 回收。视觉规范见 DESIGN.md §5.12。
- 必须：正文文字色 / 背景色只经悬浮工具栏卡片内的颜色面板（`DiaryColorPanel`，按钮为 `DiaryToolbarColorButton`；「色板」页为色块，「自定义」页为 `DiaryColorCustomPicker` 色谱取色）写入，值一律为大写 `#AARRGGBB`（经 `encodeDiaryColor`，预设与解析见 `diary_text_colors.dart`）；色谱拖动中只改面板预览，松手才写入正文（每次松手一步撤销）。“我的颜色”只存于 `DiarySavedColors`（单个 JSON 设置键 `app.settings.diary_recent_colors`，键名与备份字段 `diaryRecentColorsRaw` 沿用早先的最近颜色、已有记录原样成为我的颜色；文字色与背景色各最多 24 个，逐项容错并随备份导出与失败回滚），一切增删只经 `diarySavedColorsProvider` 的 `edit`（在最新记录上执行）：自定义页写入正文后自动保存（同一选区上接连调色经 `save(replacing:)` 原地替换、只留最后一个；已存过的不重复、不挪位置；预设不存），色板页“我的颜色”一行（`DiaryColorSavedStrip`）的管理里移除或收藏本篇用过的颜色；点色块套用不改动我的颜色。禁止另加零散的颜色设置键；面板高度不得随保存的颜色数变化。颜色代码输入框用普通文字键盘（`TextInputType.text`，`enableSuggestions` 保持默认开启：Android 上关掉联想会被当成可见密码框、弹出密码键盘），输入法组字期间不改写文字；输入框取得焦点期间，编辑页与模板编辑页须经包住工具栏的 `Focus` 保持工具栏挂载，且此时不以键盘高度为显示条件（交接焦点时输入法可能先收起再弹出，键盘高度短暂归零）。禁止回退到 Quill 自带取色对话框（`QuillToolbarColorButton` / `ColorPickerDialog`）或任何会抢走正文焦点的路由、对话框与底部面板。视觉规范见 DESIGN.md §5.6。
- 必须：编辑页正文的光标跟随（打字、键盘扩选、软键盘弹起后把光标保持在底部浮层上方）只经 `DiaryCaretFollowController`：正文以 `scrollable: false` 嵌在页面滚动容器里，Quill 自带的光标揭示不生效；遮挡高度与正文底部占位 `_editorBottomSpacer` 同源（悬浮工具栏可见时含光标空隙 `_caretToolbarClearance`），新增叠在正文上的底部浮层必须同时计入占位；软键盘变高的每一帧立即揭示光标（与 `EditableText.didChangeMetrics` 一致），禁止改回只在键盘停稳后揭示（真机上点底部的字后那一行会留在键盘下）。软键盘“选择”模式的扩选经 `SoftKeyboardSelectionKeys`（绕开 flutter/flutter#185849，弃用的 `RawKeyboard` 只允许在该文件使用）；清理条件：上游修复并升级到含修复的 Flutter 后删除该组件及其包裹。
- 必须：应用内更新统一经 `AppUpdateController`（编排与状态）→ `AppUpdateService`（检查 `AppUpdateChecker`、下载与校验 `AppUpdateDownloader`、原生安装 `AppUpdateInstaller`）；界面只有软件更新页 `AppUpdatePage`（设置 → 关于 → 检查更新）与自动检查提示（`AppUpdateAutoChecker` 决定时机 → `runAutoUpdateCheck`）。面向国内网络：版本信息优先读 Release 附件 `jotsy-update.json`，多线路同时请求、取最先成功；回退 GitHub 接口与 `releases/latest` 跳转 + `SHA256SUMS.txt`（读不到校验文件不提示新版本）；下载先测速择优，断线、换线路一律 Range 续传，失速或低速自动切换。线路只在 `AppUpdateSource.builtInSources` 登记（另有用户填写的自定义镜像），禁止在别处拼镜像地址；Android 上禁止以跳转浏览器作为主更新路径（只在没有适配安装包、安装失败或非 Android 时兜底）。偏好只存于 `AppUpdatePreferences`（单个 JSON 键 `app.update.preferences`，逐字段容错，本机偏好**不随备份导出**），禁止另加零散的更新设置键。安装包只暂存 `getTemporaryDirectory()/app_update/`（`AppUpdateFileProvider` 只暴露该目录），交给系统安装器前必须通过大小 / SHA-256（已知时）与包名 / 签名 / 版本校验，不通过即删除。自动检查只在 Android、冷启动与回到前台时进行，每 2 小时最多一次（`AppUpdatePreferences.autoCheckInterval`），过程静默、不改动界面状态，可关闭；同一版本每次进程只提示一次，“跳过此版本”只影响自动提示。说明见 docs/app_update.md，视觉规范见 DESIGN.md §5.13。
- 必须：官网在 `docs/`（GitHub Pages，域名见 `docs/CNAME`），保持纯静态 HTML / CSS / 原生 JS 模块，禁止引入构建步骤与外部 CDN（国内访问不稳）；视觉与 app 同源（Material 3 Expressive、无渐变），颜色只用 `--c-*` 色槽，80 种主题色配色在 `docs/assets/data/themes.json`（由 `kColorPaletteFamilies` 经 `ColorScheme.fromSeed(tonalSpot)` 导出，改色板或配色算法时重新导出）；中英文写在同一元素（中文为正文，英文在 `data-en` / `data-en-html` / `data-en-<属性>`），改文案两种语言一起改；下载线路与 `AppUpdateSource.builtInSources` 同步；`privacy.html` 是 OAuth 同意屏幕引用的地址，禁止改路径，应用的联网场景或权限变化时同步更新中英两份政策与生效日期。
- 必须：打赏（支持开发者）只在设置 → 关于提供入口，经 `showSupportDeveloperSheet`（展示与挑选）→ `SupportDeveloperController`（执行：经 `ExternalUriLauncher` 拉起支付宝 / 微信、经 `ImageExportService.saveBytesToGallery` 保存收款码）；收款码图片只取 `assets/img/support/`（与 README 共用），支付宝收款码链接与跳转地址只在 `SupportChannel`（`support_channel.dart`）登记，换收款码时图片与链接一起改。打赏不得与任何功能、设置或数据挂钩，禁止弹窗催促或在关于页以外加入口；不联网、不记录任何打赏信息。视觉规范见 DESIGN.md §5.18。
- 必须：所有 `SnackBar` 提示统一通过 `HomeHintVisibilityScope.showTrackedSnackBar` 触发，禁止直接调用 `ScaffoldMessenger.showSnackBar`，以确保 Home 页 FAB 上移联动在所有提示场景下保持一致。带按钮（`action`）的 SnackBar 必须显式 `persist: false`：Flutter 3.38 起带 action 的 SnackBar 默认常驻、到时不关，撤销窗口与 FAB 上移会一直不结束（`showTrackedSnackBar` 有断言兜底）；禁止另起计时器强制关闭。
- 必须：设置页按语义分组组织一级信息架构（如“外观与语言 / 编辑器 / 数据与隐私 / 关于”）；一级页优先展示导航与低风险项。
- 必须：功能管理（设置 → 功能管理，`AppFeaturesPage`）的开关只存于 `AppFeatures`（单个 JSON 设置键 `app.settings.app_features`，逐字段容错，随备份导出与失败回滚），经 `appFeaturesProvider` 读取、`saveAppFeatures` 写入，禁止另加零散的功能开关设置键。可关闭的有日历 Tab、探索 Tab（日记与设置始终保留）、日记本、纪念日、日记模板、时间胶囊，默认全部开启；关闭只隐藏该功能在应用里的全部入口、选项与自动行为，数据一律保留，重新开启即恢复。首页底栏由 `visibleHomeTabs` 按开关生成，当前页、FAB 与返回键一律按 `HomeTab` 身份判断，禁止再按固定下标；可见集合变化时保持当前 Tab（它被关闭时回到日记），被关闭 Tab 的页面随之销毁。纪念日依附日历：界面只读 `anniversariesEnabled`（`calendar && anniversaries`），日历关闭时一并关闭；功能管理页里纪念日开关放在日历下方，只在日历开启时显示。日记本关闭时：私密日记本中的日记继续被统一谓词排除（禁止为此放回全局列表），有私密本子时关闭前须先确认；首页停在某本时经页面自己的范围控制器回到全部日记（不 `popUntil`、不提示已删除）；导入其他应用时来源文件夹按标签落地；发布新日记不写草稿里的日记本成员。时间胶囊关闭时发布忽略草稿与模板预设里的胶囊，已有胶囊照常显示与解封；模板关闭时不显示建议条、不自动套用（含日记本默认模板）。新增可关闭的功能必须在 `AppFeatures` 登记并在功能管理页加开关，隐藏它在所有模块里的入口、设置项与自动行为，并补“关闭时入口不出现、开启时照常”的测试。视觉规范见 DESIGN.md §5.3。
- 必须：高风险或高复杂设置项（如数据导入导出、应用锁、回收站）必须下沉到二级页面，不得在设置首页平铺堆叠。
- 必须：亮色/暗色主题都保证文字和图标可读性，不允许出现暗色模式全黑图标等失配。
- 必须：涉及颜色的 UI 改动必须同步适配暗色主题，禁止硬编码 `Colors.white/Colors.black` 作为固定背景或前景色；优先使用 `colorScheme` 语义色并在明暗主题分别验证。
- 例外：用户自定义的卡片颜色与预览页颜色（任意 HEX，只存在于 `DiaryCardStyle` / `DiaryPreviewStyle`）不算硬编码，但必须有暗色值或经 `DiaryCardColors.deriveDark` 推导，文字经对比度兜底。
- 禁止：应用界面与默认样式使用任何渐变（`LinearGradient`、`RadialGradient`、`SweepGradient`）。
- 例外：用户在日记卡片样式中主动开启的两色卡片渐变（默认关闭），只经 `DiaryCardSurfaceSpec` 由 `DiarySelectionSurface` 绘制。
- 例外：颜色面板「自定义」页的色谱（饱和度 / 亮度面、色相条、不透明度条）是颜色空间本身而非装饰，只在 `diary_color_spectrum_painters.dart` 绘制（`test/ui/diaries/diary_card_style_source_test.dart` 源码检查只允许这两处）。
- 禁止：同一区域叠加多层重模糊导致性能劣化。
- 例外：可访问性修复或平台组件约束导致偏离时，需在代码注释说明原因。

## 7. 命令与执行约束
- 必须：代理在完成代码改动后执行 `dart format` 与 `flutter analyze`，并回传执行结果。
- 例外：若本次改动可明确判定不会引入 Dart 编译或静态检查问题（如仅文档/注释/纯资源调整），可跳过 `dart format` 与 `flutter analyze`，并在回复中说明跳过原因。
- 必须：高耗时构建/代码生成命令执行前说明目的与潜在耗时。
- 必须：常用命令在仓库根目录运行：
  - `flutter pub get`
  - `flutter test`
  - `dart run build_runner build --delete-conflicting-outputs`
  - `dart run tool/check_arb.dart`（改动 ARB 后）
- 必须：`.github/workflows/ci.yml` 是合并门禁，PR 与推送到 main 时运行（只改 `docs/`、Markdown、LICENSE 时跳过）：`dart format --set-exit-if-changed lib test integration_test tool`、`flutter analyze`（info 同样视为失败）、`dart run tool/check_arb.dart`、生成代码一致性（重跑 `flutter gen-l10n` 与 build_runner 后工作区必须无变化，含插件注册文件）、全量 `flutter test`（附覆盖率）、arm64 的 Android release 构建、actionlint；PR 另查每个非合并提交是否为 Conventional Commit。CI 未全绿不得合并；提交前在本地先跑与改动相关的同名命令。
- 必须：Flutter 版本只定义在 `.github/actions/setup-flutter/action.yml`（CI 与发布共用），升级须单独提交并先让 CI 全绿；依赖以 `pubspec.lock` 为准（CI 用 `flutter pub get --enforce-lockfile`），改动 `pubspec.yaml` 的依赖必须同时提交锁文件。
- 必须：工作流引用的 action 一律固定到 commit SHA 并在行尾注明版本（由 Dependabot 升级）；工作流默认只读权限，写权限只授予确需写入的 job。
- 禁止：CI 门禁读取签名材料或任何 secrets（fork 的 PR 也要能跑）；CI 用一次性密钥构建的 APK 不上传（签名与正式版不同，装上后无法覆盖升级）。secrets 只在 `release-apk.yml` 的签名构建 job 中使用。
- 必须：发布经 GitHub Release 触发 `release-apk.yml`：tag 必须与 `pubspec.yaml` 的版本一致（`v0.6.0` 或 `v0.6.0+17`），先过同一套 CI 门禁再构建签名分包，随 APK 上传 `SHA256SUMS.txt` 与应用内更新清单 `jotsy-update.json`（`tool/write_update_manifest.dart` 生成，最后上传）；每个版本须在 `docs/releases/` 写好中英文说明（`<tag>.md` / `<tag>.en.md`），应用内更新页按界面语言显示。
- 必须：官网的“累计下载”只统计 `.apk`、不含草稿：优先读 GitHub 接口的实时值，读不到时用 `download-stats.yml` 每小时（及每次 `release-apk.yml` 结束后）以 `jotsy-downloads.json` 上传到最新 Release 的统计（官网经允许跨域的镜像读取）；该 job 只授予 `contents: write`、只用仓库自带令牌，禁止改成提交到仓库或读取其他 secrets；统计口径改动时 `download-stats.yml` 与 `docs/assets/js/download.js` 一起改。
- 例外：装机测试可手动触发 `release-apk.yml` 并勾选 `test-build`（`gh workflow run release-apk.yml --ref <分支> -f test-build=true`）：跳过 CI 门禁、只编译 arm64、不生成更新清单，签名与正式版相同、可覆盖安装，只上传为 workflow artifact（`test-apk-<分支>`）。测试包禁止用于发布；只对已过门禁或仅供本机验证的代码使用，Release 事件始终走完整流程。
- 必须：用户要求安装 Android 包时，先用 `adb devices -l` 确认设备；存在多台设备时必须指定目标序列号。构建后使用 `adb -s <serial> install -r <apk>` 覆盖安装，以保留现有应用数据。
- 必须：profile 包覆盖安装到已有 release 包时，必须使用相同 release signing config；签名材料缺失或不匹配时停止安装，不得改用 debug 签名。
- 禁止：为安装或升级应用执行 `adb uninstall`、`pm clear`、清除应用数据或恢复出厂设置。
- 必须：若覆盖安装因签名不匹配、版本降级或其他原因失败，保留设备上的应用与数据并报告原因；未经用户明确要求不得改用会丢失数据的安装方式。
- 禁止：未经请求接管长生命周期运行任务并长时间阻塞终端。
- 例外：用户明确要求接管运行/调试时可执行，并在过程里持续同步状态。

## 8. 测试与验收规范
- 必须：功能改动至少覆盖“主流程 + 一个异常/边界路径”验证。
- 必须：UI 改动提供可复现检查清单（触发步骤 + 预期结果）。
- 必须：测试命名采用行为描述，文件命名 `*_test.dart`。
- 禁止：未验证核心路径就提交“看起来可用”的改动。
- 例外：紧急热修可先发补丁，后续必须补充验证与回归记录。
- 例外：`integration_test/` 依赖真机麦克风与播放器，不在 CI 中运行（只经 `flutter analyze` 检查能否编译）；改动录音/播放链路时必须在实机运行并在提交说明中记录结果。
- 执行前检查项：
  - 影响范围是否明确
  - 是否存在状态同步/空值/异步取消风险
- 完成后检查项：
  - 关键交互在明暗主题下是否正常
  - 列表、导航、弹窗等关键路径是否无回退

## 9. 提交与变更管理
- 必须：使用 Conventional Commit（如 `feat:`、`fix:`、`refactor:`、`docs:`、`test:`）。
- 必须：提交的作者与提交者署名只使用 `CikeSeven <llyllydyx@163.com>`（代理提交前在仓库内设好 `git config user.name` / `user.email`），提交说明不加 `Co-Authored-By` 等其他署名。
- 必须：保持提交单一目的，禁止夹带无关改动。
- 必须：提交说明至少包含“改了什么 + 为什么 + 影响范围”。
- 禁止：擅自回退用户已有改动或执行破坏性 git 操作（如 `git reset --hard`）。
- 禁止：在未获明确要求时改写历史（如 `commit --amend`）。
- 例外：用户明确授权回滚/改写时可执行，并先说明影响。
- 必须：需要新建工作树（如主目录已有其他代理在改动）时，使用代理自带的工作树工具创建（Claude Code 为 `EnterWorktree`，落在已忽略的 `.claude/worktrees/`），默认以远程 `origin/main` 为基准；新工作树需先执行 `flutter pub get`（无网络时加 `--offline`）再分析与测试。
- 禁止：手动 `git worktree add` 新建工作树；在工作树中工作时读写、暂存或提交主目录的文件（`git stash` 为所有工作树共享，不得使用不带标记的 `git stash` / `git stash pop`）。
- 提交前检查项：
  - 本次变更是否仅覆盖目标文件
  - 是否满足本规范中的编码、注释、分层、UI 规则
  - 是否附带必要验证结论或待用户执行项

## 10. 维护机制
- 必须：新增团队规则时，同步更新 `AGENTS.md`，避免仅停留在对话记录。
- 必须：目录结构变化时，同步更新“树状结构 + 职责”段落。
- 必须：发现规则冲突时收敛为单一权威条目，删除重复或矛盾描述。
- 必须：规则文本使用“必须/禁止/例外”表达，减少执行歧义。
- 禁止：长期保留过期规则或互相矛盾条目。
- 例外：过渡期允许短期并存规则，但必须标注清理条件与截止时点。
