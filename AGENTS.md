# AGENTS 协作规范（node_note）

## 1. 文档定位与适用范围
- 必须：本文件是协作规范主入口，适用于代码、文档、提交与评审；优先级 `AGENTS.md > 口头约定 > 默认习惯`。
- 必须：与上层系统 / 平台硬性指令冲突时以上层为准，并在沟通中说明冲突点。
- 禁止：按个人偏好绕开本文件的硬性规则。
- 例外：紧急修复可先提交止血补丁，之后补齐规范项。

## 2. 项目目录结构（精简）
```text
.
├─ lib/
│  ├─ main.dart  # 应用入口
│  ├─ app/  # App 装配与主题（Expressive token、配色、断点、滚动行为）
│  ├─ core/
│  │  ├─ database/  # Drift 数据库，按职责拆分的 ops；diary_blocks/、mind_map/ 文档格式
│  │  └─ services/  # 跨模块服务：平台能力、数据根目录、设置、备份网盘、导入、媒体、更新
│  │     ├─ ai/  # AI 助手引擎（纯 Dart）
│  │     ├─ app_passcode/  # 应用密码
│  │     ├─ home_widgets/  # 桌面小组件
│  │     ├─ lan_sync/  # 局域网同步（协议见 docs/lan_sync.md）
│  │     └─ storage/  # 存储管理
│  ├─ ui/
│  │  ├─ diaries/  # 日记主模块（widgets/diary_editor/ 为共用编辑器）
│  │  ├─ app_surface/  # 背景与玻璃材质
│  │  ├─ anniversaries|todos|diary_templates|notebooks|mind_maps|ai|app_lock/
│  │  ├─ lan_sync|storage|home_widgets/
│  │  ├─ home|calendar|explore|settings/
│  │  └─ widgets/  # 跨 feature 公共 UI（app_modal、expressive_menu、glass、text_selection_menu 等）
│  ├─ l10n/  # 国际化
│  └─ utils/  # 工具函数
├─ assets/  test/  integration_test/  tool/
├─ docs/  # 项目文档、rules/ 专题约束、releases/ 版本说明、官网
├─ .github/  # CI、发布、setup-flutter（唯一定义 Flutter 版本）
├─ android/ ios/ web/ macos/ linux/ windows/
├─ AGENTS.md  CLAUDE.md（只导入 AGENTS.md）  DESIGN.md（UI 设计系统）
```
- 必须：新增代码按职责放置，避免跨层污染；文件与类的位置见 [docs/rules/structure.md](docs/rules/structure.md)。
- 禁止：页面层直接实现数据库细节与复杂业务编排。
- 例外：短期 PoC 可临时放置，合并前归位。

## 3. 模块分层规则
- 必须：`pages/` 只做装配；业务流程放 `controllers/`；数据映射与草稿模型放 `models/` / `viewmodels/`；可复用 UI 放 `sections/` / `widgets/`。
- 禁止：单文件混杂“页面布局 + 业务编排 + 数据转换”。
- 例外：极简静态页面可不拆 controller。
- 必须：`core/database` 按职责拆分为各个 ops 文件，新增读写放进对应 ops，禁止堆进主文件。
- 必须：日记正文的新写入统一为 AppFlowy 块文档；旧格式只经 `decodeStoredDiaryBlocks` 读取；编辑与只读正文统一经 `DiaryEditor`。禁止重新引入 Quill。细则见 `docs/rules/editor.md`。
- 必须：库里不开外键，每条删除路径（彻底删除日记、删除 / 合并日记本、覆盖恢复等）都在同一事务里手动清理关联行。
- 必须：私密日记只经统一谓词从全局查询中排除，新增全局日记查询必须经该过滤（见 `docs/rules/notebooks.md`）。
- 必须：握着可编辑内存副本、整份写回的页面要登记为同步的阻塞者；一次性读取同步数据的 provider 要加入同步后刷新清单（见 `docs/rules/lan_sync.md`）。

## 4. 编码与命名规范
- 必须：源码、配置、文档一律 UTF-8。
- 必须：文件 `snake_case`、类 `UpperCamelCase`、成员 `lowerCamelCase`；遵循现有代码风格与 lint。
- 必须：单文件超过约 300 行时评估拆分，职责混杂必须拆。
- 必须：优先复用已有组件与服务。
- 禁止：冗余实现、死代码、复制粘贴式重复逻辑。
- 例外：生成文件（如 `*.g.dart`）不受拆分规则约束。

### 本地化
- 必须：文案统一走 `gen-l10n + ARB`，代码用 `context.l10n.xxxKey`；禁止硬编码中英分支与 `context.l10n.tr(...)`。
- 必须：每个 key 都有 `@key` metadata（至少 `description`，有占位符补 `placeholders`，`type` 不用 `Object`）。
- 必须：界面语言为 `en`（模板）/ `zh` / `ja` / `ru`，清单只在 `appLanguages`；改文案必须同时改全部语言（`check_arb` 兜底），俄语复数写全，日语不用复数分支。
- 必须：改 ARB 后执行 `flutter gen-l10n` 并提交生成文件。
- 必须：只与中国相关的能力（农历、节气、法定节假日、拼音）不随界面语言改变。

## 5. 注释规范
- 必须：复杂逻辑写高价值注释，重点是异步流程、状态切换、定时器 / 防抖、边界与平台差异。
- 必须：复杂文件顶部写职责边界（输入、输出、副作用）。
- 必须：注释解释“为什么”，不只是“做了什么”。
- 禁止：低价值复述注释。
- 例外：直白的 getter 与样板代码可不写。

## 6. UI/交互统一规范
- 必须：视觉系统、配色、字阶、组件规格以 [DESIGN.md](DESIGN.md) 为准。
- 必须：改动涉及下表主题时，动手前先读 `docs/rules/` 下对应文件（与本文件同等效力，只读相关的）。

| 改动涉及 | 先读（`docs/rules/` 下） |
|---|---|
| 平台门控与桌面替代、宽窗口与双栏、键鼠快捷键与右键菜单 | `platform_desktop.md` |
| 文字选区菜单、软键盘升降时的重建、拖动排序手柄 | `ui_components.md` |
| 背景、玻璃材质、页面底色、提示条与小控件的玻璃主题 | `app_surface.md` |
| 日记卡片样式、心情颜色、预览页样式、导航栏样式 | `appearance_styles.md` |
| 编辑器与正文（块文档、排版、格式、表格、代码块、工具栏、键盘） | `editor.md` |
| 看图、图片解码与长图、HEIF、这天的照片、拍照 / 录像 | `media.md` |
| 打开日记、预览翻页、标签搜索、快速滚动条、批量标签 | `diary_list_preview.md` |
| 草稿与发布页 | `drafts_publish.md` |
| 日记模板 | `diary_templates.md` |
| 日记本（私密、上锁、嵌套、封面、章节、首页范围） | `notebooks.md` |
| 待办、提醒与日历 / 日记联动 | `todos.md` |
| 思维导图 | `mind_maps.md` |
| 日历、纪念日、这天的心情、法定节假日 | `calendar.md` |
| 探索页 | `explore.md` |
| 留言 | `comments.md` |
| 日记链接与反向链接 | `diary_links.md` |
| AI 助手 | `ai_assistant.md` |
| 局域网同步，以及会被同步的数据 | `lan_sync.md` |
| 导入 / 恢复、云端笔记导入、网盘备份 | `backup_import.md` |
| 分享与导出 | `export_share.md` |
| 存储管理 | `storage.md` |
| 桌面小组件 | `home_widgets.md` |
| 功能管理开关 | `app_features.md` |
| 应用锁、应用密码、验证身份 | `app_lock.md` |
| 应用内更新、更新日志、官网、打赏、发布与下载统计 | `release_website.md` |
| 某个文件 / 类在哪、各目录放什么 | `structure.md` |

### 平台与布局
- 必须：平台差异与功能门控只经 `AppPlatform`，禁止 UI 与功能代码直接判断 `Platform.isXxx`（原生通道调用旁的兜底除外）；桌面不可用的能力登记为 `supportsXxx` 并隐藏入口或给桌面替代。托管数据根目录只经 `appDataRootDirectory`。
- 必须：宽窗口按可用宽度分档，只经 `AppBreakpoints`（compact < 600、medium 600–1023、expanded ≥ 1024），用 `LayoutBuilder` 判断、禁止用 `MediaQuery` 屏宽；compact 必须与手机布局一致；内容宽度只取 `AppContentWidth`。
- 必须：键鼠专属行为只在 `AppPlatform.isDesktop` 生效，手机交互不变；横向滚动条带套 `DesktopHorizontalScroll`。

### 主题、动效与图标
- 必须：组件统一继承 Material 3 Expressive 主题（`useMaterial3: true`）；单选按钮组用 `ExpressiveButtonGroup`，等待状态用 `ExpressiveLoadingIndicator`。
- 必须：动画时长与曲线只取 `ExpressiveMotion` token，并尊重系统减少动画设置；禁止在 UI 层新增 `Duration(milliseconds: …)` 动画时长（防抖 / 超时不受限）。
- 必须：按钮 `textStyle` 由主题文字样式派生，禁止传裸 `TextStyle`（会丢应用字体，Linux 上中文变方块）。
- 必须：新增图标用 `font_awesome_flutter`；返回按钮统一 `FontAwesomeIcons.angleLeft`、尺寸 18；富文本工具栏与设置预览图标同源。
- 必须：亮暗主题都保证文字与图标可读；颜色优先用 `colorScheme` 语义色，禁止用 `Colors.white/black` 做固定前景或背景。
- 例外：用户自定义的卡片 / 预览页颜色属于用户数据，但必须有暗色值并做对比度兜底。
- 禁止：应用界面与默认样式使用任何渐变；同一区域叠加多层重模糊。
- 例外：用户主动开启的卡片两色渐变；代码块配色、提示块底色与取色面板色谱（见 `editor.md`）。
- 必须：启动品牌图形原生端与 Flutter 端同源，改一端同步另一端；首页首屏新增区块经 `LaunchReveal` 编排（DESIGN.md §4.3）。

### 背景与玻璃
- 必须：有 Scaffold 的新页面经 `AppPageBackground(area:)` 画背景，底色只取 `AppPageBackdrop`，禁止写死主题 surface。
- 必须：玻璃只经 `AppGlass.of(context)` 判断、只经现有玻璃组件绘制，禁止自拼 `BackdropFilter`；色调按钮传 `AppGlassField.tonalButtonStyle(context)`；玻璃表面禁止放进 `Opacity` / `FadeTransition`（淡入经 `GlassReveal`）。
- 必须：默认外观（无背景、全部经典）与改版前一致（`app_surface_source_test.dart` 兜底）。细则见 `app_surface.md`。

### 弹层、菜单与提示
- 必须：模态面板与对话框只经 `showAppModalBottomSheet` / `showAppDialog`，禁止在 `lib/ui/widgets/app_modal/` 外直接调 SDK（`app_modal_source_test.dart` 兜底）；视觉见 DESIGN.md §5.23。
- 必须：Dialog 操作按钮为文本按钮：左灰色取消、右主色确认，危险动作右侧用 `colorScheme.error`。
- 必须：约 4 项以内的单行动作用 `ExpressiveMenuButton` / `ExpressiveMenuAnchor` 弹出菜单；项目多、带说明或预览时用底部面板。禁止在 `expressive_menu/` 外使用 `PopupMenuButton`、`showMenu` 或 SDK `MenuAnchor`（`expressive_menu_source_test.dart` 兜底）。规格见 DESIGN.md §5.4。
- 例外：桌面日记卡片右键菜单与首页多选顶栏“更多”菜单最多 5 项，仍用弹出菜单。
- 必须：文字选区菜单只经 `lib/ui/widgets/text_selection_menu/`（输入框传 `appTextContextMenuBuilder`），禁止在外面使用 SDK 选区工具栏（`text_selection_menu_source_test.dart` 兜底）。
- 必须：`SnackBar` 只经 `HomeHintVisibilityScope.showTrackedSnackBar`；带 `action` 的必须显式 `persist: false`，禁止另起计时器关闭。
- 必须：键盘升降时大组件不得逐帧重建：禁止在页面 / 面板 build 里直接读 `MediaQuery.viewInsetsOf`，改用 `ui_components.md` 列出的替代组件。

### 加载与图片
- 必须：用户可感知的等待用 `loading_indicator_m3e` 效果，不新增 `CircularProgressIndicator`；首屏加载用 `DelayedLoadingIndicator`，动作等待用 `ActionLoadingOverlay`。
- 必须：展示型图片挂 `frameBuilder: expressiveImageFrameBuilder`、解码经 `boundedImageProvider`（禁止只给一边的 `cacheWidth/Height`）；打开大图经 `openImageViewer`；托管图片入库经现有存储服务与 `HeifImageConverter`。细则见 `media.md`。

### 统一入口与设置
- 必须：打开日记经 `openDiaryPage`、标签搜索经 `openDiaryTagSearch`、新建经 `runDiaryCreateEntryFlow`、导出经 `runDiaryExportFlow`、分享经 `showDiaryShareSheet`、导入恢复经 `chooseBackupImportMode`、打开日记本经 `openNotebookFromAnywhere`、日记链接经 `openDiaryLinkTarget`；禁止另拼路由或另写同类流程。
- 必须：一个功能的设置收进它自己的单个 JSON 设置键（逐字段容错解析），并明确是否随备份导出；禁止零散设置键。
- 必须：界面上的“字数”一律经 `TextStats` 计算（口径见 DESIGN.md §3.3）。
- 必须：设置首页按语义分组、只放进入二级页的导航行（DESIGN.md §5.3）；高风险或复杂设置下沉到二级页。
- 必须：功能开关只存于 `AppFeatures`；关闭只隐藏入口与自动行为、数据保留；首页 Tab 按 `HomeTab` 身份判断；新增可关闭功能须登记并补开关测试（见 `app_features.md`）。
- 例外：可访问性修复或平台组件约束导致偏离时，在代码注释中说明原因。

## 7. 命令与执行约束
- 必须：与用户的沟通一律简体中文；标识符、命令、路径与报错保持原文。
- 必须：改完代码执行 `dart format` 与 `flutter analyze` 并回报结果。
- 例外：只改文档 / 注释 / 纯资源时可跳过，并说明原因。
- 必须：高耗时构建 / 代码生成前说明目的与耗时。
- 必须：常用命令在仓库根目录运行：`flutter pub get`、`flutter test`、`dart run build_runner build --delete-conflicting-outputs`、`dart run tool/check_arb.dart`、`flutter build linux --release`（桌面改动后）。
- 必须：本地构建 Linux 先装 `ci.yml` 里同一份系统包。
- 必须：`.github/workflows/ci.yml` 是合并门禁（格式、analyze 含 info、ARB、生成代码一致性、全量测试、Android / Linux / Windows 构建、actionlint、PR 提交信息检查）；CI 未全绿不得合并，提交前本地先跑相关命令。CI 下载内容必须缓存，缓存只由 main 写入（见 `docs/ci_performance.md`）。
- 必须：Flutter 版本只定义在 `.github/actions/setup-flutter/action.yml`，升级单独提交；依赖以 `pubspec.lock` 为准，改依赖须同时提交锁文件。
- 必须：工作流 action 固定到 commit SHA 并注明版本；默认只读权限，写权限只给确需的 job。
- 禁止：CI 门禁读取签名材料或 secrets；secrets 只在 `release-apk.yml` 的发布构建 job 使用，网盘应用密钥只经 `tool/write_cloud_backup_keys.dart` 写入。发布流程见 `release_website.md`。
- 必须：安装 Android 包先 `adb devices -l` 确认设备，多台时指定序列号，用 `adb -s <serial> install -r` 覆盖安装；profile 包须用相同 release 签名，签名缺失或不匹配就停止。
- 禁止：为安装执行 `adb uninstall`、`pm clear` 等会丢数据的操作；覆盖安装失败时保留设备数据并报告原因。
- 禁止：未经请求接管长生命周期任务并长时间阻塞终端。
- 例外：用户明确要求接管运行 / 调试时可执行，并持续同步状态。

## 8. 测试与验收规范
- 必须：功能改动至少覆盖“主流程 + 一个异常 / 边界路径”。
- 必须：UI 改动给出可复现检查清单（步骤 + 预期），并在明暗主题下确认。
- 必须：测试按行为命名，文件 `*_test.dart`。
- 禁止：未验证核心路径就提交“看起来可用”的改动。
- 例外：紧急热修可先发，后补验证。
- 例外：`integration_test/` 需真机，不在 CI 运行；改录音 / 播放链路须实机运行并在提交说明记录结果。

## 9. 提交与变更管理
- 必须：Conventional Commit（`feat:`、`fix:`、`refactor:`、`docs:`、`test:` 等），提交单一目的，说明写“改了什么 + 为什么 + 影响范围”。
- 禁止：提交说明加 `Co-Authored-By` 等署名；夹带无关改动。
- 禁止：擅自回退用户改动、执行破坏性 git 操作（如 `git reset --hard`）或改写历史（如 `commit --amend`）。
- 例外：用户明确授权时可执行，并先说明影响。
- 必须：改动仓库内容前先用代理自带的工作树工具新建工作树（Claude Code 为 `EnterWorktree`），改动、验证、提交、推送都在工作树里完成。
- 必须：工作树基于最新 `origin/main`：创建前 `git fetch origin`，落后就 `git merge --ff-only origin/main`；新工作树先 `flutter pub get`。
- 禁止：在主目录改文件、切分支或提交；手动 `git worktree add`；在工作树中读写主目录文件；使用不带标记的 `git stash` / `git stash pop`。
- 例外：只读工作不需要工作树；用户明确要求在主目录改动时照做。
- 必须：开 PR 前 `git fetch origin`，有新提交就 `git merge origin/main`（已推送分支不 rebase），解决冲突后重跑相关检查；PR 说明写明合并了哪些冲突、怎么解决。

## 10. 维护机制
- 必须：新规则写进规范文档：全局规则写本文件，单个功能 / 主题写 `docs/rules/` 对应文件（新主题新建文件并在 §6 表格登记）。
- 必须：只写规则（必须 / 禁止 / 例外），不写代码怎么实现；本文件保持在 30 KiB 以内（`wc -c AGENTS.md` ≤ 30720），细节放 `docs/rules/`。
- 必须：调整一级 / 二级目录时同步更新 §2；模块内文件说明写在 `structure.md`。
- 必须：发现规则冲突或过期时收敛为单一条目，删除重复与矛盾描述。
- 例外：过渡期可短期并存，但须标注清理条件与截止时点。
