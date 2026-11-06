# AGENTS 协作规范（node_note）

## 1. 文档定位与适用范围
- 必须：本文件是仓库协作规范主入口，适用于整个项目（代码、文档、提交流程、评审）。
- 必须：项目内规则优先级为 `AGENTS.md > 口头约定 > 默认习惯`。
- 必须：若与上层系统/平台硬性指令冲突，以上层指令为准，并在沟通中说明冲突点。
- 禁止：按个人偏好绕开本文件已定义的硬性规则。
- 例外：紧急修复可先提交止血补丁，但后续必须补齐规范项。

## 2. 项目目录结构（精简）
```text
.
├─ lib/
│  ├─ main.dart  # 应用入口
│  ├─ app/  # App 装配与主题系统（theme/：Expressive token、配色、窗口分档 AppBreakpoints、滚动行为）
│  ├─ core/
│  │  ├─ database/  # Drift 数据库，按职责拆分的 ops（见 §3）；diary_blocks/：正文块文档格式与兼容
│  │  └─ services/  # 跨模块服务（平台能力 AppPlatform、数据根目录、设置、备份与网盘、导入、媒体、更新等）
│  │     ├─ ai/  # AI 助手引擎（纯 Dart，docs/ai_assistant.md）
│  │     └─ lan_sync/  # 局域网同步引擎（docs/lan_sync.md）；sync/：同步数据层与纯函数规划器
│  ├─ ui/
│  │  ├─ diaries/  # 日记主业务模块：pages / controllers / providers / models|viewmodels / export / sections|widgets（widgets/diary_editor/ 为共用编辑器）
│  │  ├─ app_surface/  # 背景与材质（玻璃）
│  │  ├─ anniversaries/  # 纪念日与倒数日
│  │  ├─ diary_templates/  # 日记模板
│  │  ├─ notebooks/  # 日记本
│  │  ├─ ai/  # AI 助手界面
│  │  ├─ lan_sync/  # 局域网同步界面
│  │  ├─ home|calendar|explore|settings/  # 首页与各 Tab、设置页
│  │  └─ widgets/  # 跨 feature 公共 UI（app_modal/、expressive_menu/、glass/、text_selection_menu/、fast_scroller/ 等）
│  ├─ l10n/  # 国际化封装
│  └─ utils/  # 工具函数（含 pinyin/）
├─ assets/  # 静态资源
├─ test/  # 测试（源码约束测试、performance/ 微基准、support/ 假实现与夹具）
├─ integration_test/  # 实机集成测试
├─ tool/  # 开发与 CI 脚本（ARB 检查、覆盖率合并、更新清单、拼音表、网盘密钥、AI 模拟服务）
├─ docs/  # 项目文档、rules/ 专题约束、releases/ 版本说明（打进应用）、官网静态页
├─ .github/  # CI 门禁 ci.yml、发布 release-apk.yml、下载统计、setup-flutter（唯一定义 Flutter 版本）
├─ android/ ios/ web/ macos/  # 各平台工程（Android 为主平台）
├─ linux/ windows/  # 桌面 runner 与打包脚本
├─ AGENTS.md  # 协作规范（本文件）
├─ CLAUDE.md  # Claude Code 入口，只导入 AGENTS.md
└─ DESIGN.md  # UI 设计系统规范
```
- 逐目录、到文件与类名一级的说明见 [docs/rules/structure.md](docs/rules/structure.md)，按需查阅。
- 必须：新增代码按职责放置，避免跨层污染。
- 禁止：在页面层直接实现数据库细节与复杂业务编排。
- 例外：短期 PoC 可临时放置，但合并前必须归位到对应层。

## 3. 模块分层规则
- 必须：日记正文的新写入统一为 AppFlowy `Document.toJson()` 同构的块文档，历史 Delta、旧节点与纯文本的读取只经 `decodeStoredDiaryBlocks`，媒体扫描和路径重绑复用 `diary_blocks_media.dart`；块类型与键只在 `diary_blocks_schema.dart` 定义；编辑与只读正文统一经 `DiaryEditor`，会话与事务经 `DiaryEditorController`。禁止重新引入 Quill 编辑器、扩展或 PDF 插件。容器块、提示块、折叠块、表格、日记链接卡片与模板码的细则见 [docs/rules/editor.md](docs/rules/editor.md)。
- 必须：`pages/` 仅负责装配（路由参数、生命周期、provider watch、widget 组合）。
- 必须：业务流程（异步链路、批量操作、撤销、防抖、发布流程）放 `controllers/`。
- 必须：数据映射、草稿模型、metadata 组装放 `models/` 或 `viewmodels/`。
- 必须：可复用 UI 放 `sections/` 或 `widgets/`，避免页面文件膨胀。
- 必须：`core/database` 维持按职责拆分（query / write / migration / tag ops / anniversary ops / day mood ops / draft ops / template ops / notebook ops / explore ops / comment ops / diary link ops / diary batch writes（多选的批量状态写入）/ sync ops（同步读行）/ sync writes（同步按原值写入）/ sync order（同步顺序列表重排）/ ai ops（AI 对话、消息与结果）/ ai context ops（发给 AI 的日记）/ media repair ops（托管图片格式修复）/ scope SQL）。
- 禁止：单文件混杂“页面布局 + 业务编排 + 数据转换”。
- 例外：极简静态页面可不强制拆 controller。
- 必须：库里从不开启外键：彻底删除日记、删除日记本、合并日记本与覆盖恢复等每条删除路径都必须在同一事务里手动清理关联行（标签、日记本成员、留言、AI 回应等）。
- 必须：私密日记只经统一谓词 `_privateDiaryExclusionSql` 从全局查询中排除：新增全局日记查询必须经 `_writeDiaryScopeFilter`（或该谓词）过滤，并把 `notebooks` 与 `diary_notebooks` 加进 `readsFrom`（`_diaryScopeReadsFrom`）；回收站与按 id 直接打开不过滤（见 `docs/rules/notebooks.md`）。
- 必须：握着可编辑内存副本、整份写回的页面与面板必须登记为 `EditingSessionRegistry` 的阻塞者；新增一次性读取同步数据的 provider 必须加进 `syncedDataRefreshProvider` 的清单（见 `docs/rules/lan_sync.md`）。

## 4. 编码与命名规范
- 必须：所有源码、配置、文档均使用 UTF-8 编码（避免中文乱码）。
- 必须：命名统一：文件 `snake_case`、类 `UpperCamelCase`、成员 `lowerCamelCase`。
- 必须：遵循现有 Dart/Flutter 代码风格与 lint 约束。
- 必须：单文件超过约 300 行时触发拆分评估；出现职责混杂时必须拆分。
- 必须：优先复用已有组件与服务，避免重复造轮子。
- 必须：本地化文案统一走 `gen-l10n + ARB`，代码中使用 `context.l10n.xxxKey`（或参数化 `xxxKey(arg)`），禁止新增硬编码中英分支。
- 必须：ARB 中每个文案 key 都要有对应 metadata（`@key`），至少包含 `description`；含占位符时必须补 `placeholders`。
- 必须：界面语言为 `en`（模板）/ `zh` / `ja` / `ru`，清单只在 `appLanguages`（`lib/l10n/app_languages.dart`，设置存储、首次启动挑选与语言选择都从这里取）；新增或修改文案必须同时改全部语言的 ARB（键集合不一致 `check_arb` 失败），俄语复数写全 `one/few/many/other`，日语不用复数分支；新增语言须在 `appLanguages` 登记并补齐全部键。只与中国相关的能力（农历、节气、法定节假日、拼音）不随界面语言改变口径。
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
- 必须：下表各主题的专题约束拆在 `docs/rules/`，与本文件同等效力；改动涉及某个主题时，动手前必须先读对应文件（只读相关的，不必全读）。

| 改动涉及 | 先读（`docs/rules/` 下） |
|---|---|
| 平台门控与桌面替代、宽窗口与双栏、键鼠快捷键与右键菜单 | `platform_desktop.md` |
| 文字选区菜单（复制 / 粘贴 / 分享 / 其他应用的文字操作） | `ui_components.md` |
| 背景、玻璃材质、页面底色、提示条与小控件的玻璃主题 | `app_surface.md` |
| 日记卡片样式、心情颜色、预览页样式、导航栏样式、样式编辑页 | `appearance_styles.md` |
| 编辑器与正文：块文档格式、排版、格式面板、颜色、列表、表格、代码块、工具栏、视口与键盘 | `editor.md` |
| 看图、图片解码与长图、HEIF、这天的照片、拍照 / 录像 | `media.md` |
| 打开日记、预览翻页与双击编辑、标签搜索、快速滚动条、标签子页与批量标签 | `diary_list_preview.md` |
| 草稿与发布页 | `drafts_publish.md` |
| 日记模板 | `diary_templates.md` |
| 日记本（私密、上锁、嵌套、封面、章节、备份合并、首页范围与启动恢复） | `notebooks.md` |
| 日历、纪念日、这天的心情、法定节假日 | `calendar.md` |
| 探索页 | `explore.md` |
| 留言 | `comments.md` |
| 日记链接与反向链接 | `diary_links.md` |
| AI 助手 | `ai_assistant.md` |
| 局域网同步，以及会被同步的数据 | `lan_sync.md` |
| 导入 / 恢复、其他应用与云端笔记导入、网盘备份 | `backup_import.md` |
| 分享与导出 | `export_share.md` |
| 功能管理开关 | `app_features.md` |
| 应用内更新、更新日志、官网、打赏、发布与下载统计 | `release_website.md` |
| 某个文件 / 类在哪、各目录放什么 | `structure.md` |

- 必须：平台差异与功能门控只经 `AppPlatform`（`lib/core/services/app_platform.dart`，测试用 `debugDefaultTargetPlatformOverride` 切换），禁止 UI 与功能代码直接判断 `Platform.isXxx`（只有原生 MethodChannel / 插件调用旁保留运行时判断兜底）；桌面不可用的能力必须登记为 `supportsXxx` 并隐藏入口或给出桌面替代。托管数据的根目录只经 `appDataRootDirectory`。各能力的平台清单与桌面替代见 `docs/rules/platform_desktop.md`。
- 必须：宽窗口布局按窗口宽度而不是平台分档，只经 `AppBreakpoints`（compact < 600、medium 600–1023、expanded ≥ 1024），compact 必须与改版前的手机布局逐像素一致；内容宽度只取 `AppContentWidth` token，一律按实际可用宽度（`LayoutBuilder`）判断、禁止用 `MediaQuery` 屏宽；新增二级页经 `FormWidth` + `AppTopBar(contentMaxWidth:)` 限宽。键鼠专属行为只在 `AppPlatform.isDesktop` 生效、手机上结构与交互不变；新增横向滚动条带必须套 `DesktopHorizontalScroll`。细则见 `docs/rules/platform_desktop.md`。
- 必须：应用组件统一继承 `MaterialTheme` 的 Material 3 Expressive 主题；新增单选连接按钮组与等待状态分别复用 `ExpressiveButtonGroup`、`ExpressiveLoadingIndicator`，新增动效通过 `ExpressiveMotion` 尊重系统减少动画设置。Expressive 仍基于 `useMaterial3: true`，禁止以关闭 Material 3 的方式迁移。按钮的 `textStyle` 一律由主题文字样式派生（如 `theme.textTheme.labelLarge?.copyWith(...)`），禁止传裸 `TextStyle`：它会整个替换按钮的文字样式、连应用字体一起丢掉，没装中文字体的 Linux 上显示成方块（局域网同步界面由 `lan_sync_source_rules_test.dart` 兜底）。
- 必须：动画时长与曲线只取 `ExpressiveMotion` token（`fast/medium/standard/long`、`effects/exit/spatial`），并经 `ExpressiveMotion.duration(context, …)` 解析；禁止在 UI 层新增 `Duration(milliseconds: …)` 形式的动画时长（防抖/超时等非动画计时不受此限）。
- 必须：新增图标默认使用 `font_awesome_flutter`（`FaIcon` + `FontAwesomeIcons`）。
- 必须：富文本工具栏与设置页工具预览图标来源一致，避免混用。
- 必须：标题栏返回按钮统一使用 `<` 风格图标，即 `FontAwesomeIcons.angleLeft`，默认尺寸使用 `18`，避免在不同页面混用 `arrowLeft/chevronLeft/系统返回箭头`。
- 必须：Dialog 操作按钮统一为文本按钮：
  - 左侧按钮：灰色语义（取消/返回）
  - 右侧按钮：主色语义（确认）
  - 危险动作：右侧按钮使用 `colorScheme.error`
- 必须：内容少的操作（约 4 项以内、单行文字的动作）用 `ExpressiveMenuButton` / `ExpressiveMenuAnchor`（菜单项为 `ExpressiveMenuItem`，`lib/ui/widgets/expressive_menu/`）弹出菜单；项目多、需要说明文字、预览或分组时用底部面板（如预览页“更多”）。禁止在该目录之外使用 `PopupMenuButton`、`PopupMenuItem` / `PopupMenuEntry`、`showMenu` 或 SDK 的 `MenuAnchor`（`test/ui/widgets/expressive_menu_source_test.dart` 源码检查兜底）。菜单规格见 DESIGN.md §5.4。
- 例外：桌面日记卡片的右键菜单（编辑、置顶、日记本、归档、删除，最多 5 项）经同一 `ExpressiveMenuAnchor` 的 `openAt` 在指针处打开（键盘为菜单键 / Shift+F10，在卡片中央），不受“约 4 项以内”与锚定位置限制；首页多选顶栏的“更多”菜单（置顶、设置标签、导出，在普通日记本里另有移出、移动到，最多 5 项单行动作）同样仍用弹出菜单。
- 必须：文字选区菜单只经 `lib/ui/widgets/text_selection_menu/`：输入框一律传 `contextMenuBuilder: appTextContextMenuBuilder`，日记正文经 `AppTextSelectionMenu.adaptive`；禁止在该目录之外使用 `AdaptiveTextSelectionToolbar` / `DesktopTextSelectionToolbar` / `CupertinoTextSelectionToolbar` / `TextSelectionToolbar`（`text_selection_menu_source_test.dart` 兜底）。细则见 `docs/rules/ui_components.md`。
- 必须：用户可感知的耗时等待操作（如启动预热、分页首屏加载、远程请求等待）统一使用 `loading_indicator_m3e` 的加载效果，不再新增 `CircularProgressIndicator` 作为主加载表现；页面首屏 `loading` 分支使用 `DelayedLoadingIndicator`（300ms 内不出现），动作等待遮罩使用 `ActionLoadingOverlay`。
- 必须：新增展示型图片（`Image.file/network/Image(image:)`）挂 `frameBuilder: expressiveImageFrameBuilder`，首次解码淡入、缓存命中直接显示；仅截图/导出用的静态图片例外。
- 必须：打开大图统一经 `openImageViewer`；展示型图片解码一律经 `boundedImageProvider` 保持比例缩小（禁止新增只给一边的 `cacheWidth` / `cacheHeight`）；托管图片入库经 `HeifImageConverter.convertImported`（新增图片入库路径须经 `DiaryMediaStorageService` / `DiaryCoverStorageService` / `AppBackgroundStorageService` 之一）。看图页、长图、HEIF 修复、这天的照片与拍摄的细则见 `docs/rules/media.md`。
- 必须：启动品牌图形两端同源——原生 `drawable/launch_brand_mark.xml`、`values*/colors.xml` 的 `launch_*` 颜色与 `LaunchBrandMark` 几何、默认种子色，改动任一端须同步另一端；首页首屏新增一级区块经 `LaunchReveal` 声明启动编排槽位（见 DESIGN.md §4.3）。
- 必须：新增有 Scaffold 的页面一律经 `AppPageBackground(area:)` 画背景，页面底色与实色栏底色只取 `AppPageBackdrop`，禁止把 Scaffold 底色写死为主题 surface；玻璃只经 `AppGlass.of(context)` 判断，经 `AppGlassSurface` / `AppCardSurface` / `AppGlassFab` / `AppGlassField` / `GlassSurface` 绘制，禁止自拼 `BackdropFilter` 或另写磨砂配方；色调按钮必须传 `style: AppGlassField.tonalButtonStyle(context)`；玻璃表面禁止放进 `Opacity` / `FadeTransition`（整块淡入经 `GlassReveal`）。默认（无背景、全部经典）必须与改版前逐像素一致（`app_surface_source_test.dart` 兜底）。细则见 `docs/rules/app_surface.md`。
- 必须：模态底部面板与对话框只经 `showAppModalBottomSheet` / `showAppDialog`（`lib/ui/widgets/app_modal/`，经典时原样调用 SDK，玻璃时为玻璃面板 / 整页磨砂对话框），禁止在该目录之外直接调用 `showModalBottomSheet` / `showDialog`（`test/ui/widgets/app_modal_source_test.dart` 兜底）。视觉规范见 DESIGN.md §5.23。
- 必须：跨模块的统一入口（细则见各专题文档）：点开一篇日记经 `openDiaryPage`，按标签搜索经 `openDiaryTagSearch`，新建日记经 `runDiaryCreateEntryFlow`，导出经 `runDiaryExportFlow`，分享经 `showDiaryShareSheet` → `DiaryShareController`，导入 / 恢复经 `chooseBackupImportMode`，从首页之上打开日记本经 `openNotebookFromAnywhere`，打开日记链接经 `openDiaryLinkTarget`；禁止另拼路由或另写同类流程。
- 必须：一个功能的设置与偏好收进它自己的单个 JSON 设置键（模型类逐字段容错解析），并明确是否随备份导出（随备份导出的在导入失败时回滚；本机偏好不随备份）；禁止另加零散的设置键。各功能的键名与备份口径见对应专题文档。
- 必须：界面上的“字数”一律经 `TextStats`（`lib/utils/text_stats.dart`，按日记版本缓存用 `DiaryWordCounts`）计算，口径见 DESIGN.md §3.3；禁止自行用 `.length` 或按空白分词统计字数。
- 必须：所有 `SnackBar` 提示统一通过 `HomeHintVisibilityScope.showTrackedSnackBar` 触发，禁止直接调用 `ScaffoldMessenger.showSnackBar`，以确保 Home 页 FAB 上移联动在所有提示场景下保持一致。带按钮（`action`）的 SnackBar 必须显式 `persist: false`：Flutter 3.38 起带 action 的 SnackBar 默认常驻、到时不关，撤销窗口与 FAB 上移会一直不结束（`showTrackedSnackBar` 有断言兜底）；禁止另起计时器强制关闭。
- 必须：设置页按语义分组组织一级信息架构（如“外观与语言 / 编辑器 / 数据与隐私 / 关于”）；一级页优先展示导航与低风险项。
- 必须：功能管理的开关只存于 `AppFeatures`（经 `appFeaturesProvider` 读取、`saveAppFeatures` 写入）；关闭只隐藏该功能在应用里的全部入口、选项与自动行为，数据一律保留；首页 Tab 一律按 `HomeTab` 身份判断，禁止按固定下标。新增可关闭的功能必须在 `AppFeatures` 登记、在功能管理页加开关，并补“关闭时入口不出现、开启时照常”的测试。细则见 `docs/rules/app_features.md`。
- 必须：高风险或高复杂设置项（如数据导入导出、应用锁、回收站）必须下沉到二级页面，不得在设置首页平铺堆叠。
- 必须：亮色/暗色主题都保证文字和图标可读性，不允许出现暗色模式全黑图标等失配。
- 必须：涉及颜色的 UI 改动必须同步适配暗色主题，禁止硬编码 `Colors.white/Colors.black` 作为固定背景或前景色；优先使用 `colorScheme` 语义色并在明暗主题分别验证。
- 例外：用户自定义的卡片颜色与预览页颜色（任意 HEX，只存在于 `DiaryCardStyle` / `DiaryPreviewStyle`）不算硬编码，但必须有暗色值或经 `DiaryCardColors.deriveDark` 推导，文字经对比度兜底。
- 禁止：应用界面与默认样式使用任何渐变（`LinearGradient`、`RadialGradient`、`SweepGradient`）。
- 例外：用户在日记卡片样式中主动开启的两色卡片渐变（默认关闭），只经 `DiaryCardSurfaceSpec` 由 `DiarySelectionSurface` 绘制。
- 例外：代码块配色主题、提示块底色档位与颜色面板「自定义」页的色谱属内容配色或颜色空间，不算硬编码颜色 / 渐变，条件见 `docs/rules/editor.md`。
- 禁止：同一区域叠加多层重模糊导致性能劣化。
- 例外：可访问性修复或平台组件约束导致偏离时，需在代码注释说明原因。

## 7. 命令与执行约束
- 必须：代理与用户的一切沟通（回复、进度同步、提问与总结）使用简体中文；代码标识符、命令、路径与报错原文保持原样，不翻译。
- 必须：代理在完成代码改动后执行 `dart format` 与 `flutter analyze`，并回传执行结果。
- 例外：若本次改动可明确判定不会引入 Dart 编译或静态检查问题（如仅文档/注释/纯资源调整），可跳过 `dart format` 与 `flutter analyze`，并在回复中说明跳过原因。
- 必须：高耗时构建/代码生成命令执行前说明目的与潜在耗时。
- 必须：常用命令在仓库根目录运行：
  - `flutter pub get`
  - `flutter test`
  - `dart run build_runner build --delete-conflicting-outputs`
  - `dart run tool/check_arb.dart`（改动 ARB 后）
  - `flutter build linux --release`（桌面改动后本地验证；Windows 包只在 CI / 发布中构建）
- 必须：本地构建 Linux 需先装 `clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev`，以及 audioplayers_linux 需要的 GStreamer 开发包（`libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev`，与 `ci.yml` 同一份）。
- 必须：`.github/workflows/ci.yml` 是合并门禁，PR 与推送到 main 时运行（只改 `docs/`、Markdown、LICENSE 时跳过）：`dart format --set-exit-if-changed lib test integration_test tool`、`flutter analyze`（info 同样视为失败）、`dart run tool/check_arb.dart`、生成代码一致性（重跑 `flutter gen-l10n` 与 build_runner 后工作区必须无变化，含插件注册文件）、全量 `flutter test`（按文件分片，覆盖率经 `tool/merge_lcov.dart` 合并；`Tests` 门禁须等所有分片通过）、Android 视频选择器原生回归测试、arm64 的 Android release 构建、Linux 与 Windows 的 release 构建（只验证能否编译，产物不上传；发布工作流经 `skip-desktop-builds` 跳过）、actionlint；PR 另查每个非合并提交是否为 Conventional Commit。CI 未全绿不得合并；提交前在本地先跑与改动相关的同名命令。
- 必须：Flutter 版本只定义在 `.github/actions/setup-flutter/action.yml`（CI 与发布共用），升级须单独提交并先让 CI 全绿；依赖以 `pubspec.lock` 为准（CI 用 `flutter pub get --enforce-lockfile`），改动 `pubspec.yaml` 的依赖必须同时提交锁文件。
- 必须：工作流引用的 action 一律固定到 commit SHA 并在行尾注明版本（由 Dependabot 升级）；工作流默认只读权限，写权限只授予确需写入的 job。
- 禁止：CI 门禁读取签名材料或任何 secrets（fork 的 PR 也要能跑）；CI 用一次性密钥构建的 APK 不上传（签名与正式版不同，装上后无法覆盖升级）。secrets 只在 `release-apk.yml` 的发布构建 job 中使用：Android 签名构建（签名材料、运行时密钥与网盘应用密钥）与 Linux / Windows 构建（只有网盘应用密钥，权限只读）；网盘应用密钥一律经 `tool/write_cloud_backup_keys.dart` 校验并写入 `cloud_backup_keys.json`（不打印值，桌面构建后删除），禁止各 job 另写一份校验。
- 必须：发布（GitHub Release → `release-apk.yml`）、官网下载统计与装机测试包的流程见 `docs/rules/release_website.md`。
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
- 禁止：在提交说明里加 `Co-Authored-By` 等署名。
- 必须：保持提交单一目的，禁止夹带无关改动。
- 必须：提交说明至少包含“改了什么 + 为什么 + 影响范围”。
- 禁止：擅自回退用户已有改动或执行破坏性 git 操作（如 `git reset --hard`）。
- 禁止：在未获明确要求时改写历史（如 `commit --amend`）。
- 例外：用户明确授权回滚/改写时可执行，并先说明影响。
- 必须：只要改动仓库内容（代码、测试、配置、文档、生成文件都算），动手前一律先用代理自带的工作树工具新建工作树，改动、验证、提交与推送都在工作树里完成（Claude Code 为 `EnterWorktree`，落在已忽略的 `.claude/worktrees/`）。
- 必须：工作树以最新的远程 `origin/main` 为基准：创建前先 `git fetch origin`（`EnterWorktree` 取本地已知的 `origin/main`，不先 fetch 会落后），建好后仍落后就在新分支上 `git merge --ff-only origin/main` 跟上；新工作树需先执行 `flutter pub get`（无网络时加 `--offline`）再分析与测试。
- 禁止：在主目录修改文件、切换分支（`git checkout` / `git switch`）或提交；手动 `git worktree add` 新建工作树；在工作树中工作时读写、暂存或提交主目录的文件（`git stash` 为所有工作树共享，不得使用不带标记的 `git stash` / `git stash pop`）。
- 例外：只读的工作（阅读代码、回答问题、在主目录跑不改动受版本控制文件的命令）不需要工作树；用户明确要求在主目录改动时照做。
- 必须：每次开 PR 前先 `git fetch origin`，检查 `origin/main` 有没有分支里还没有的新提交；有就先合并进分支（`git merge origin/main`，已推送的分支不 rebase、不改写历史），解决冲突后重跑与改动相关的 `dart format`、`flutter analyze` 与测试，通过后再推送、开 PR。PR 开着期间 main 有新提交并与之冲突时同样处理；PR 说明里写明合并了哪些冲突、怎么解决的。
- 提交前检查项：
  - 本次变更是否仅覆盖目标文件
  - 是否满足本规范中的编码、注释、分层、UI 规则
  - 是否附带必要验证结论或待用户执行项

## 10. 维护机制
- 必须：新增团队规则时同步写进规范文档，避免仅停留在对话记录：跨模块的全局规则写本文件，单个功能 / 主题的规则写 `docs/rules/` 对应文件（新主题新建文件，并在 §6 索引表登记一行）。
- 必须：本文件每次会话都会整份加载，体积保持在 30 KiB 以内（`wc -c AGENTS.md` ≤ 30720；部分代理工具如 Codex 默认只读前 32 KiB，超出部分直接看不到）；单个功能的细节一律放进 `docs/rules/`，本文件只放全局规则与索引。
- 必须：新增或调整一级 / 二级目录时同步更新 §2 的精简树；模块内的文件说明补在 `docs/rules/structure.md`。
- 必须：发现规则冲突时收敛为单一权威条目，删除重复或矛盾描述。
- 必须：规则文本使用“必须/禁止/例外”表达，减少执行歧义。
- 禁止：长期保留过期规则或互相矛盾条目。
- 例外：过渡期允许短期并存规则，但必须标注清理条件与截止时点。
