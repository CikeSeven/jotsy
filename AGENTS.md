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
│  │  ├─ database/                   # Drift 数据库（schema / query / write / migration / 纪念日 ops 拆分）
│  │  └─ services/                   # 跨模块服务（设置、定位、天气、封面存储、导入字体、备份与网盘备份、其他日记应用与云端笔记导入、分享到其他应用、按日期读取相册照片、图片尺寸与长图分片等）
│  ├─ ui/
│  │  ├─ diaries/                    # 日记主业务模块（已分层）
│  │  │  ├─ pages/                   # 页面壳层（路由/生命周期/组合）
│  │  │  ├─ controllers/             # 业务编排（搜索/筛选/撤销/发布链路等）
│  │  │  ├─ providers/               # 状态与筛选条件
│  │  │  ├─ models|viewmodels/       # 数据模型与局部派生状态（models/diary_card_style/：卡片样式模型、预设与样式码；models/diary_preview_style/：预览页样式、阅读行为、预设与样式码；models/style_library/：各样式编辑页共用的“我的样式”、样式码与 JSON 工具）
│  │  │  ├─ export/                  # 导出写出器（正文块模型、PDF / Word / Markdown / 网页 / 纯文本 / CSV、媒体与命名）
│  │  │  └─ sections|widgets/        # 可复用 UI 区块（widgets/diary_card/：列表、瀑布流、搜索、归档与日历共用的日记卡片；widgets/diary_preview/：预览页的单篇视图、整页内容、各区块与左右翻页器；widgets/publish_panel/：发布页与编辑页共用的元数据面板区块；widgets/diary_day_photos/：补写日记时“这天拍的照片”提示条、全部面板与缩略图格子）
│  │  ├─ anniversaries/              # 纪念日与倒数日（日期推算、编辑页；日历与预览页的入口复用它）
│  │  ├─ home|calendar|explore|settings/
│  │  └─ widgets/                    # 跨 feature 公共 UI（导航、Expressive 选择组/加载、看图页等；long_image/：长图判定、保持比例的解码尺寸、分片拼图与 cover 裁切对齐）
│  ├─ l10n/                          # 国际化封装
│  └─ utils/                         # 工具函数
├─ assets/                           # 静态资源
├─ test/                             # 测试
├─ integration_test/                 # 实机集成测试（隔离设置与数据库，验证录音/播放）
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
- 必须：`core/database` 维持按职责拆分（query / write / migration / tag ops / anniversary ops）。
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
- 必须：数据导入/恢复入口统一经 `chooseBackupImportMode`（`DataArchiveService.inspectZip` 只读预检 → 选择合并或覆盖），会改写本机已有数据的方式必须经 `showBackupOverwriteWarningDialog` 严重警告确认；禁止新增不经警告直接覆盖本机数据的入口。其他日记应用的导出经 `JournalImportService.prepare` 解析为备份载荷并只读预检，同样走 `chooseBackupImportMode`，写入复用 `BackupMerge`；新增来源只加 `journal_import_<来源>.dart` 解析器，不另建写库路径。手机厂商与 WPS 的云端笔记经 `CloudNotesLoginPage` 在官方网页登录、`JournalImportService.prepareCloud` 读取（平台客户端为 `journal_import_cloud_<平台>.dart`，在 `cloudNotePlatforms` 登记），只做读取；登录 Cookie 只存在于本次导入的内存与网页视图中，登录前与导入结束后都必须清除，禁止落盘或用于读取以外的请求。
- 必须：用户可感知的耗时等待操作（如启动预热、分页首屏加载、远程请求等待）统一使用 `loading_indicator_m3e` 的加载效果，不再新增 `CircularProgressIndicator` 作为主加载表现；页面首屏 `loading` 分支使用 `DelayedLoadingIndicator`（300ms 内不出现），动作等待遮罩使用 `ActionLoadingOverlay`。
- 必须：新增展示型图片（`Image.file/network/Image(image:)`）挂 `frameBuilder: expressiveImageFrameBuilder`，首次解码淡入、缓存命中直接显示；仅截图/导出用的静态图片例外。
- 必须：打开大图统一经 `openImageViewer`（来源图片用 `ImageViewerHeroSource` 包裹并在点按时 `ImageViewerHero.capture`）；状态驱动的颜色变化经 `ExpressiveStateBlend` 补间；新增触觉反馈只用于“动作生效/越过阈值”的瞬间，类型对照 DESIGN.md §4.3。
- 必须：启动品牌图形两端同源——原生 `drawable/launch_brand_mark.xml`、`values*/colors.xml` 的 `launch_*` 颜色与 `LaunchBrandMark` 几何、默认种子色，改动任一端须同步另一端；首页首屏新增一级区块经 `LaunchReveal` 声明启动编排槽位（见 DESIGN.md §4.3）。
- 必须：网盘备份（WebDAV、S3 兼容对象存储、授权类网盘）统一经 `CloudBackupService` 编排、`CloudBackupRemote` 访问远程，恢复同样走 `chooseBackupImportMode`；备份位置与凭据只存于 `CloudBackupSettingsService`（单个 JSON 偏好键 `app.cloud_backup.targets`，逐条容错解析，**不随备份导出**），禁止另加零散的连接/令牌设置键。授权类网盘的应用密钥只经 `CloudBackupAppKeys`（`--dart-define` 注入）读取，禁止写进仓库；授权只用系统账号授权（Android 上 Google Drive 经 Play 服务，不可用时回落设备码）、设备码或在系统浏览器授权后粘贴授权码（Google、Dropbox 禁止内嵌网页授权），刷新后的令牌必须立即落盘（多家会轮换刷新令牌）。新增网盘只加 `cloud_backup_<平台>.dart`（实现 `CloudDriveProvider`）并在 `cloud_backup_drives.dart` 登记；新增 WebDAV/S3 服务只在 `cloud_backup_presets.dart` 加预设、在 `cloud_backup_labels.dart` 加名称与填写说明。上传与下载一律流式读写文件，禁止整包读入内存。说明见 docs/cloud_backup.md。
- 必须：日记正文排版（字体、字号、行距、字间距、段间距）只存于 `DiaryTypography`（单个 JSON 设置键 `app.settings.diary_typography`，逐字段容错并随备份导出）；编辑页、预览页、发布页与设置预览的 Quill 样式一律经 `DiaryQuillStylesBuilder(appearance: ref.watch(diaryTextAppearanceProvider), …)` 在正文位置生成（禁止用页面 State 的 context 直接调用 `buildDiaryQuillStyles`：那里在 Scaffold 之上，只有 MaterialApp 的红色兜底样式），标题字体经 `DiaryTextAppearance.titleStyle`，禁止页面自行设置正文字号/行距或另加排版设置键。导入字体只经 `DiaryFontStorageService`（应用支持目录 `diary_fonts/`，字体文件不进备份，备份只带字体 id，缺失时回落内置字体）；修改经 `DiaryTypographyController`，滑块拖动只改草稿、松手才提交。规范见 DESIGN.md §3.2。
- 必须：日历页的显示偏好统一加在 `CalendarDisplayOptions`（单个 JSON 设置键 `calendarDisplayOptionsRaw`，逐字段容错解析并随备份导出），禁止为日历另加零散设置键；新增日期格样式经 `CalendarDayCell` 的填充/描边两种高亮形态实现，视觉规范见 DESIGN.md §5.7。
- 必须：纪念日存 Drift `anniversaries` 表（业务 id `anniversaryId`；`linkedDiaryId` 存日记业务 id、不建外键），随完整备份导出、覆盖恢复与合并（按 `anniversaryId` 去重），日记包不含纪念日；某天落在哪、下一次是哪天一律经 `AnniversaryCalendar` 推算，禁止页面自行换算公历/农历；纪念日页面与提示统一经 `anniversary_navigation.dart` 打开，关联的日记只经 `watchActiveDiaryWithTags`（排除回收站）读取，彻底删除日记时解除关联。不做提醒通知。
- 必须：日记卡片外观统一收在 `DiaryCardStyleSettings`（单个 JSON 设置键 `diaryCardStyleRaw`：当前样式 + 最多 12 份“我的样式”，逐字段容错解析，随备份导出与失败回滚），渲染统一经 `DiaryCard` + `DiaryCardResolvedStyle`；禁止各页另拼日记卡片或另加零散的卡片外观设置键（标签显示数量 `diaryCardTagLimit` 为既有独立键）。`DiaryCardStyle.defaults` 必须逐项等于 DESIGN.md §5.1 的默认规格；未解封胶囊只套用表面样式，心情色与标签色回退主题色。编辑入口为设置 → 外观与语言 → 日记卡片样式（日记页视图选项面板有快捷入口）。
- 必须：日记预览页的外观与阅读行为统一收在 `DiaryPreviewSettings`（单个 JSON 设置键 `diaryPreviewStyleRaw`：当前样式 + 最多 12 份“我的样式” + 阅读行为，逐字段容错解析，随备份导出与失败回滚）；渲染统一经 `DiaryPreviewContent` + `DiaryPreviewResolvedStyle`（页面外壳 `DiaryPreviewSurface`），设置页预览复用同一套组件；阅读行为不随预设与样式码改变；正文字体与排版仍只在 `DiaryTypography`，禁止另加零散的预览页设置键。`DiaryPreviewStyle.defaults` 必须等于 DESIGN.md §5.8 的默认规格。样式编辑页（卡片、预览页）共用 `StyleEditorScaffold`、`StyleEditorController` 与 `StyleLibraryTab`，禁止复制一份。
- 必须：预览页左右滑动切换日记统一经 `DiaryPreviewPage(sequence:)`：入口传进入时所在列表的 `DiaryPreviewSequence`（打开时冻结顺序；首页 / 搜索还有没加载的部分时带 `DiaryPreviewListQuery`，由 `getActiveDiaryIds` 按同一筛选与排序接上），单篇入口不传；翻页器为 `DiaryPreviewPager` → `DiaryPagerView`（设置页预览复用同一个）。手势冲突只靠起滑距离倍数（外层放大、页内还原）与页内始终可滚动的 physics 解决，禁止另写翻页手势识别器，禁止在预览页内放横向滚动容器（会抢走翻页）。预览页的删除结果带被删日记的 id（`DiaryPreviewResult.deleted(id)`），入口按它撤销；预览页勾选待办只经 `updateDiaryContent` 写正文，禁止用会取消归档 / 删除、重写标签的 `updateDiary`。
- 必须：界面上的“字数”一律经 `TextStats`（`lib/utils/text_stats.dart`，按日记版本缓存用 `DiaryWordCounts`）计算，口径见 DESIGN.md §3.3；禁止自行用 `.length` 或按空白分词统计字数。
- 必须：日历的法定节假日（休/班）只取自 tyme 的 `LegalHoliday`，经 `CalendarHolidayDay` 读取，开关为 `CalendarDisplayOptions.holidayMode`；数字左上角标统一经 `CalendarCellLeadingBadge` 按优先级取一个，禁止在日期格另加角标位置。
- 必须：日记分享统一经预览页的分享面板 `showDiaryShareSheet`（只负责挑选）→ `DiaryShareController`（执行）；分享文字只经 `DiaryShareContent.composeText` 组装为纯文本（社交应用不渲染 Markdown），内容开关只存于 `DiaryShareOptions`（单个 JSON 设置键 `app.settings.diary_share_options`，逐字段容错并随备份导出），地点默认不带。分享到指定应用只经 `DiaryShareChannel`（Android 原生按包名发 Intent），图片先暂存到缓存 `diary_share/`（`DiaryShareFileProvider` 只暴露该目录，禁止直接交出日记原图路径），带图时文字经剪贴板传递；新增目标应用在 `DiaryShareTarget` 登记，并同步 `AndroidManifest.xml` 的 `<queries>` 包名。视觉规范见 DESIGN.md §5.9。
- 必须：日记导出统一经 `runDiaryExportFlow`（预览页“更多 → 导出”、日记列表多选、设置 → 数据管理 → 导出日记三个入口共用）：导出面板 `showDiaryExportSheet` 只负责挑选，生成、保存与分享由 `DiaryExportController` 执行；导出选项只存于 `DiaryExportOptions`（单个 JSON 设置键 `app.settings.diary_export_options`，逐字段容错并随备份导出）。正文一律先经 `ExportBlockParser` 解析为块再交给 `lib/ui/diaries/export/` 下的写出器（PDF 例外，仍经 flutter_quill_to_pdf 渲染，但图片只经虚拟地址交付、缺失图片与媒体嵌入先改写）；新增格式只加写出器并在 `DiaryExportFormat` 登记，禁止在页面里另写导出逻辑。未解封的时间胶囊在任何导出格式中都不导出（完整备份除外）；导出文件不得写出设备私有路径，媒体以包内相对路径或内嵌方式交付；批量导出的媒体一律按文件流式打包（`DiaryExportBundleFile.file`），禁止把全部照片读进内存，PDF 这类只能整份持有图片的格式须设总量上限并提示。视觉规范见 DESIGN.md §5.10。
- 必须：补写日记的“这天拍的照片”只经 `DayPhotoLibrary`（`dayPhotoLibraryProvider`；photo_manager 实现在 Android 按 `datetaken` 拍摄时间筛选，缺失时才退回 `date_added`）读取相册，状态经 `DiaryDayPhotosController`，界面为编辑页标题下的 `DiaryDayPhotosStrip` 与 `showDiaryDayPhotosSheet`；只在新建模式且发表日期早于今天时出现，开关为编辑器设置 `dayPhotoSuggestionsEnabled`（本机偏好，不随备份导出）。进入页面只查询授权状态，系统权限框只能由用户点“允许访问”触发；只申请图片读取权限（Android 13+ `READ_MEDIA_IMAGES` 与 14+ 部分授权，不申请视频、音频与照片位置）。插入复用 `DiaryMediaImportController.pickAndInsert(picker:)` 复制到日记私有目录，禁止删除、移动或改写相册原文件；勾选与已插入状态只在本次编辑页内存中，不落盘。设为封面只经 `DiaryMetaActions.setCoverFromFile` 拷贝到封面私有目录并写进新建草稿（与发布页选封面同一条链路），禁止直接引用相册原图路径作为封面。视觉规范见 DESIGN.md §5.11。
- 必须：展示型图片解码一律经 `boundedImageProvider` 保持比例缩小（禁止新增只给一边的 `cacheWidth`/`cacheHeight`、`Image.file(cacheWidth:)` 或 `ResizeImage.resizeIfNeeded`：另一边按比例推出后仍可能超过 GPU 纹理上限，被 Impeller 单独压扁）；长图（高 ≥ 宽 × 3）只经 `isLongImageSize` 判定，解码前的尺寸只经 `ImageDimensions` 读取（只读文件头）。正文图片经 `DiaryEmbeddedImage`：比列宽窄时靠行首（段落带对齐属性时从之），长图折叠为 `DiaryLongImageFold`（预览页阅读行为 `longImageMode` 为完整显示时用 `DiaryLongImageFull`，分片按滚动可见范围构建）；点按菜单只经 `showDiaryImageOptions`（“查看”经 `openImageViewer`），禁止回退到上游 `ImageOptionsMenu`；看图页每页经 `ImageViewerImagePage`，长图按屏宽竖向滚动（`DoubleTapZoomViewer.tall`）并关闭该页的下拉关闭；cover 裁切的封面与缩略图经 `CoverCroppedImage`（长图顶部对齐）。长图分片只经 `LongImageTileService`（Android 原生 `DiaryLongImageSlicer`，缓存 `getTemporaryDirectory()/diary_image_tiles/`，不随备份导出，原图只读），原图已不存在的分片目录由 `sweepDiaryMediaFiles` 回收。视觉规范见 DESIGN.md §5.12。
- 必须：编辑页正文的光标跟随（打字、键盘扩选、软键盘弹起后把光标保持在底部浮层上方）只经 `DiaryCaretFollowController`：正文以 `scrollable: false` 嵌在页面滚动容器里，Quill 自带的光标揭示不生效；遮挡高度与正文底部占位 `_editorBottomSpacer` 同源，新增叠在正文上的底部浮层必须同时计入占位。软键盘“选择”模式的扩选经 `SoftKeyboardSelectionKeys`（绕开 flutter/flutter#185849，弃用的 `RawKeyboard` 只允许在该文件使用）；清理条件：上游修复并升级到含修复的 Flutter 后删除该组件及其包裹。
- 必须：所有 `SnackBar` 提示统一通过 `HomeHintVisibilityScope.showTrackedSnackBar` 触发，禁止直接调用 `ScaffoldMessenger.showSnackBar`，以确保 Home 页 FAB 上移联动在所有提示场景下保持一致。
- 必须：设置页按语义分组组织一级信息架构（如“外观与语言 / 编辑器 / 数据与隐私 / 关于”）；一级页优先展示导航与低风险项。
- 必须：高风险或高复杂设置项（如数据导入导出、应用锁、回收站）必须下沉到二级页面，不得在设置首页平铺堆叠。
- 必须：亮色/暗色主题都保证文字和图标可读性，不允许出现暗色模式全黑图标等失配。
- 必须：涉及颜色的 UI 改动必须同步适配暗色主题，禁止硬编码 `Colors.white/Colors.black` 作为固定背景或前景色；优先使用 `colorScheme` 语义色并在明暗主题分别验证。
- 例外：用户自定义的卡片颜色与预览页颜色（任意 HEX，只存在于 `DiaryCardStyle` / `DiaryPreviewStyle`）不算硬编码，但必须有暗色值或经 `DiaryCardColors.deriveDark` 推导，文字经对比度兜底。
- 禁止：应用界面与默认样式使用任何渐变（`LinearGradient`、`RadialGradient`、`SweepGradient`）。
- 例外：用户在日记卡片样式中主动开启的两色卡片渐变（默认关闭），只经 `DiaryCardSurfaceSpec` 由 `DiarySelectionSurface` 绘制。
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
- 执行前检查项：
  - 影响范围是否明确
  - 是否存在状态同步/空值/异步取消风险
- 完成后检查项：
  - 关键交互在明暗主题下是否正常
  - 列表、导航、弹窗等关键路径是否无回退

## 9. 提交与变更管理
- 必须：使用 Conventional Commit（如 `feat:`、`fix:`、`refactor:`、`docs:`、`test:`）。
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
