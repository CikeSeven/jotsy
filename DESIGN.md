# NodeJot (Jotsy) UI 设计系统规范 (DESIGN.md)

> **版本**：v1.0.0  
> **设计语言**：Material 3 Expressive (M3E) + 杂志化典雅版式（Editorial & Publication-Grade）  
> **适用范围**：NodeJot (Jotsy) 全端 UI 界面、组件库、主题定制与交互动效。

---

## 1. 设计系统哲学与核心原则

### 1.1 设计愿景
NodeJot 旨在提供一种**安静、温润、优雅且富有现代呼吸感**的数字笔记与日记体验。通过融合 **Material 3 Expressive** 的前沿交互形变与**杂志化出版物（Editorial）**的克制版式，彻底消灭工具型软件常见的粗糙、廉价与压迫感。

### 1.2 核心设计原则
1. **纯净表面与层次（Clean Surfaces）**：
   - 告别灰暗浑浊：亮色模式下以清透浅冷灰蓝为基底，让卡片以纯白高浮雕形态呼吸浮起；
   - 严禁水泥灰发脏感，暗色模式下使用深灰层次构建空间深度，不使用死黑。
2. **黄金律比例与杂志化排版（Editorial Layout）**：
   - 大字重与分明层次：标题采用高辨识度的加粗（Bold/Heavy）大字阶，建立一目了然的信息锚点；
   - 封面黄金比例：列表卡片封面与文本形成约 1:2 的视觉比重平衡，杜绝局促割裂的小方块。
3. **呼吸微动效（Expressive Motion）**：
   - 状态形变：按钮按压时从圆润胶囊柔和过渡为小圆角，带有微物理回弹反馈；
   - 减弱动画友好：全线严格遵循系统的“减少动态效果”设置。
4. **统一精致细节（Micro-refinements）**：
   - 微胶囊标签（`# 标签名`）：统一色彩不透明度底色与字重，禁止突兀边框；
   - 极细微边框（0.8dp 半透明）：替代粗重黑线与重阴影；
   - **绝对禁止使用渐变色**（`LinearGradient`、`RadialGradient` 等）。

---

## 2. 色彩系统与明暗主题

### 2.1 背景与表面层次规范
系统严格依赖 `Theme.of(context).colorScheme` 语义色槽，禁止硬编码颜色。

| 语义层级 | 亮色模式 (Light) | 暗色模式 (Dark) | 用途说明 |
| :--- | :--- | :--- | :--- |
| **Scaffold 底色** | `colorScheme.surface`（默认种子色约 `#F6FAFE`） | `colorScheme.surface` (`#111318`) | 整个页面与亮色底部导航的背景衬底，统一取 `ExpressiveSurfaces.pageBackground`，随主题色带上同一色调 |
| **卡片/容器主表面** | `surfaceContainerLowest` (`#FFFFFF`) | `surfaceContainerLow` (`#1A1C20`) | 日记卡片、设置分组、悬浮模块主表面 |
| **二级表面/对话框** | `surfaceContainerLowest` (`#FFFFFF`) | `surfaceContainerHigh` (`#282A2F`) | 弹窗 (Dialog)、底部抽屉 (BottomSheet) |
| **输入框填充底色** | `surfaceContainerLow` (0.6 Alpha) | `surfaceContainerHighest` | 文本框、搜索框、选择器底色 |
| **卡片微边框** | `outlineVariant` (0.35 Alpha) | `outlineVariant` (0.20 Alpha) | 0.8dp 极细微边框，构建精致感 |
| **阴影规范** | 单层微柔和语义阴影 (0.12 Alpha) | 单层深色扩散阴影 (0.24 Alpha) | 浮动面板用 `AppEffects.softShadow`；静止卡片用 `AppEffects.restingCardShadow`（仅亮色 0.03 Alpha）；颜色一律取 `colorScheme.shadow`，禁彩色阴影 |

### 2.2 配色禁令与兼容性
- ❌ **严禁使用任何渐变色**：禁止在卡片、按钮、顶部栏使用 `LinearGradient` 或 `SweepGradient`。
- ❌ **严禁硬编码纯白与纯黑**：禁止在布局中使用 `Colors.white` / `Colors.black` 作为表面或文字色，必须使用 `colorScheme.surface`、`colorScheme.onSurface` 等。
- ❌ **严禁高饱和度刺眼大色块**：辅助指示色使用柔和容器色（如 `secondaryContainer`、`primaryContainer`），避免大面积使用荧光级原色。

---

## 3. 字体与排版标准

默认全局字体：`HarmonyOSSansSC`（优雅平实的多字重无衬线体）。

### 3.1 字阶与字重表

| 排版角色 | 字号 (sp) | 字重 (FontWeight) | 行高 (Height) | 应用场景示例 |
| :--- | :--- | :--- | :--- | :--- |
| **Display / Top Bar** | 25.0 | `w800` (ExtraBold) | 1.15 | 首页顶栏 Logo ("Jotsy")、特大标题 |
| **AppBar Title** | 20.0 | `w700` (Bold) | 1.20 | 各级页面顶部导航栏标题 |
| **Headline Medium** | 20.0 - 22.0 | `w700` (Bold) | 1.25 | 对话框标题、二级大章节标题 |
| **List Diary Title** | 18.5 | `w700` (Bold) | 1.25 | 普通单列日记卡片标题（支持 2 行优雅折行） |
| **Waterfall Title** | 16.5 | `w700` (Bold) | 1.30 | 双列瀑布流日记卡片标题 |
| **ListTile Title** | 16.5 | `w600` (SemiBold) | 1.30 | 设置项标题、菜单选项主文本 |
| **Body Medium** | 14.0 - 15.0 | `w400` (Regular) | 1.42 | 日记正文、卡片正文摘要（行距舒展） |
| **Subtitle / Meta** | 13.0 - 13.5 | `w400` / `w500` | 1.35 | 设置项副标题、辅助说明文字 |
| **Eyebrow Date** | 13.0 | `w600` (SemiBold) | 1.20 | 列表卡片眉线日期（如 `3月12日 · 周四`） |
| **Tag Label** | 11.5 - 12.0 | `w600` (SemiBold) | 1.00 | 胶囊标签文字（如 `# 生活`） |
| **Small Caption** | 11.0 - 11.5 | `w400` (Regular) | 1.20 | 卡片底部更新时间、轻量辅助标记 |

---

## 4. 间距、圆角与形变 Token

### 4.1 空间间距 (`AppSpacing`)
采用标准的 4dp / 8dp 网格体系：
- `xs: 4.0` - 图标与微文本间隙、胶囊内边距微调
- `s: 8.0` - 组件内部元素紧凑间隙、标签间距
- `m: 12.0` - 文本块段落间距、小型容器内边距
- `l: 16.0` - 页面水平基础安全边距、标准卡片内边距
- `xl: 20.0` - 区块垂直间隔、弹窗主要内边距
- `xxl: 24.0` - 一级信息卡片分组外间距
- `xxxl: 32.0` - 大屏留白、模态底部抽屉安全顶部

### 4.2 容器圆角 (`AppRadii`)
Expressive 设计系统强调有机、舒适的大圆角曲率：
- `card: 24.0` - 日记卡片、设置分组大卡片、浮动菜单
- `nav: 28.0` - 底部导航指示胶囊、顶部大胶囊筛选栏
- `dialog: 28.0` - 模态对话框、日期时间选择器
- `input: 16.0` - 输入框、卡片内封面图 (`16.0`)、提示条
- `chip: 16.0` - 标准系统 Chip、大号操作药丸
- `micro-tag: 12.0` - 标签微胶囊

### 4.3 动态形变 (`ExpressiveControls` & `ExpressiveMotion`)
- **控件按压形变**：
  按钮（Filled, Outlined, Elevated）默认圆角为 `28dp`（完全圆润胶囊）；在手指按压（Pressed）态瞬间缩减为 `12dp`（小圆角方块），释放后弹回 `28dp`。
- **空间过渡**：
  位移与缩放允许使用微弹簧曲线（`ExpressiveMotion.spatial`）；透明度与色彩使用 `ExpressiveMotion.effects`（`easeOutCubic`）进场、`ExpressiveMotion.exit`（`easeInCubic`）退场，确保柔和不越界。
- **时长分档**（UI 层禁止手写动画毫秒数，统一取 `ExpressiveMotion` token）：
  - `fast`（180ms）：微交互，图标/颜色切换、小元素显隐、遮罩淡入淡出；
  - `medium`（250ms）：内容切换，列表项进出、区块交叉淡入、面板吸附、翻页与 Tab 切换；
  - `standard`（350ms）：空间过渡，页面级转场、较大位移/形变、FAB 显隐；
  - `long`（500ms）：强调型/仪式感动画，如时间胶囊封存。
- **减少动画**：实际时长一律经 `ExpressiveMotion.duration(context, token)` 解析，系统开启“减少动态效果”时为 0；不能接受 0 时长的 API 改用跳转或 1ms 近似瞬时：`animateTo`/`animateToPage` 用跳转；`AnimatedSize`（0 时长会在自身 performLayout 内重新标脏而触发断言，`AnimatedCrossFade` 与 table_calendar 的 `formatAnimationDuration` 内部同样是 AnimatedSize）使用 `ExpressiveMotion.durationNonZero`；循环动画不启动。页面转场在该模式下由主题直接切换；底部面板传 `sheetAnimationStyle: AnimationStyle.noAnimation`（对话框保留框架淡入，淡入本就是减少动画的推荐替代）。
- **加载反馈防闪**：本地查询等通常毫秒级返回的等待，经 `DelayedLoadingGate` 延迟约 300ms 再显示指示器，避免每次交互都闪一下；页面首屏的 `loading` 分支统一用 `DelayedLoadingIndicator`（300ms 内保持空白，超时后淡入居中指示器），不再在路由滑入途中闪一下 spinner。动作类等待遮罩（导出、保存、分享）统一用 `ActionLoadingOverlay`，淡入淡出且隐藏时静音指示器。
- **图片出场**：展示型图片（列表/瀑布流封面、日历与探索缩略图、发布/预览头图、正文嵌图、看图页）统一挂 `expressiveImageFrameBuilder`：首次解码完成后 `fast + effects` 淡入，ImageCache 命中直接显示、不重复闪烁。分享长图的静态封面例外（截图不等解码，淡入中途会截到半透明）。
- **跟手手势**：拖动过程中的反馈直接映射手指位移，不做补间；只有“状态越界”才触发补间。左滑归档/取消归档（`DiarySwipeActionItem`）：背景与卡片同圆角，阈值（40%）以前为弱化色、图标随距离淡入放大，越过阈值切到动作色、图标弹性放大并轻震一次，拖回阈值以下恢复，用户随时可以反悔。看图页（`DoubleTapZoomViewer`）：双击以点按处为不动点放大到 2.5 倍、再双击复原，过程为 `medium` 补间；放大态锁定左右翻页，拖动只用于平移；页码数字按翻页方向滚动切换。发布面板（`PublishDiaryPanel`）：拖动进度经 `ValueNotifier` 只驱动宽度内缩、详情淡入与表头，面板内容不随进度逐帧重建；表头双箭头随进度纵向翻转（先压扁成横线再翻成下指），文案越过阈值时短交叉淡入，减少动画时朝向按阈值直接切换。
- **触觉反馈**：只用于“动作生效/越过阈值”的瞬间，普通点按不额外加震动：
  - `lightImpact`：手势越过生效阈值（左滑归档、看图页下拉关闭；来回拖动只在进入生效态时震一次）、录音插入正文；
  - `mediumImpact`：拿起可排序条目（拖拽手柄不经过长按，系统不会反馈）、真正开始录音、iOS 长按进入多选（Android 由 InkWell 的系统长按反馈负责，避免震两次）；
  - `successNotification`：时间胶囊封存。
- **状态变色**：`Material` 与 `ButtonStyle` 的隐式动画只补间形状与阴影，颜色会硬切；状态驱动的换色（播放中卡片染色、按钮待机/会话态、选中标签行、时间胶囊入口）统一经 `ExpressiveStateBlend` 补间 0↔1 进度后插值颜色，与形变同步。
- **按压反馈**：可点卡片的墨水层叠在内容之上（封面图、不透明主体不会盖住水波纹），探索卡片的点击墨水画在卡片自身表面；小尺寸色块、清除按钮等按下时以 `spatial` 轻微缩小。
- **导航连续性**：
  - 列表/搜索/日历打开预览页时传入已有的 `DiaryWithTags`（`initialDetail`），首帧即完整内容，详情查询返回后无缝接管；列表封面与日历时间线缩略图是预览页头图的共享元素，点按时抓取已绘制画面（`ImageViewerHeroAnchor`），飞入后展开成完整头图；启动预热订阅日记页首帧要用的同一条分页查询（`startupDiariesProvider`），首页出现时列表已就绪；
  - 看图页经 `openImageViewer` 打开：透明背景路由 + 淡入；缩略图/正文图/头图以共享元素（`ImageViewerHeroSource` → `ImageViewerHeroTarget`）从原位展开，盒子取原图比例、两端均按 cover 铺满，飞行与原图解码前显示来源已解码画面，圆角逐角补间到目标端（来源圆角包含外层裁切，如瀑布流封面只有上方两角圆），直线飞行；放大态返回只淡出；减少动画时不建立 Hero；
  - 看图页支持下拉关闭（`SwipeDismissViewer`）：跟手移动并缩小到 0.82，背景与顶栏按距离淡出，越过视口 15% 或快速甩动即关闭（轻震一次），否则 `spatial` 弹回；
  - 新建日记发布成功时，编辑页在发布页退场前静默移出路由栈，只剩发布页一段退场；列表等退场结束后让新卡片以展开动画插入；
  - 重复点击当前 Tab 回到顶部（超过 3 屏先跳到 1 屏处再 `standard` 收尾）；各 Tab 拥有独立的主滚动控制器，且只有可见 Tab 的 ticker 运行（`TickerMode`），后台 Tab 的动画不再空转出帧；
  - 新建日记、搜索页等需要弹键盘的页面经 `RouteEntranceWaiter` 在路由入场结束后再聚焦，键盘不与页面滑入叠加。
- **内容插入与移除**：会推动下方内容的区块不在一帧内出现/消失。发布页选中封面时头图从 0 高度展开并淡入、正文平滑下移，清除时反向收起（解码尺寸固定，过渡期间不重新解码）；日记页进入多选时顶栏由浮动转为固定，从此刻露出的高度展开、下方标签栏同步下移，退出时先收回到浮动态应处的位置再切换，顶栏内容挂在 GlobalKey 下跨形态保留状态（普通行 ↔ 多选行的交叉淡入得以播放）。
- **首次呈现的生长动效**：探索页统计数字首次出现时从 0 递增（`long`，等宽数字），能量柱与心情格共用一个进度错峰生长/着色；只在首次构建播放，之后数据变化从当前值补间；生长期间以 `RepaintBoundary` 隔离重绘。
- **启动接力与揭幕**：
  - Android 12+ 系统闪屏只画底色与居中的品牌图形（带装订环的笔记本，68×80dp，默认种子色 `primary`）；`MainActivity` 在 Flutter 首帧绘制后立即移除系统闪屏（不播系统自带的淡出与窗口上滑），Flutter 首帧在同一位置画同一图形（`LaunchBrandMark`），接力时画面不变。原生矢量 `drawable/launch_brand_mark.xml`、`colors.xml` 的 `launch_*` 颜色与 Dart 几何、默认种子色同源，由测试校验一致；更早的 Android 与其他平台只铺底色；
  - 就绪后品牌图形在 `fast` 内后退至 0.9 并淡出，首页按 `LaunchRevealSlot` 在 `long` 内错峰入场：顶栏 0ms → 标签栏 30ms → 底部导航 50ms → 卡片 100ms 起每张 +30ms（屏幕中部的卡片与图形重叠，等图形基本淡出再进场）→ FAB 250ms 弹出。位移与缩放走 `spatial`，透明度走 `effects`；动画在挂载首页的那一帧结束后才起算，首页首帧再重也不吃掉入场开头；
  - 超过 250ms 未就绪时图形下方淡入加载指示（至少保留 500ms）；应用锁盖着时揭幕暂缓到解锁，与遮罩淡出同时上演；减少动画时就绪即落定；
  - 首页首屏新增的一级区块经 `LaunchReveal` 声明槽位加入编排，不单独起入场动画。

---

## 5. 核心组件与布局模式

### 5.1 日记卡片 (Diary Cards)

#### 1) 普通单列列表模式（Magazine Horizontal Feed）
- **外层容器**：`borderRadius: 24`，背景色为 `cardColor`，微边框 `0.8dp`。
- **内边距**：外层统一提供 `EdgeInsets.fromLTRB(16, 14, 16, 14)`。
- **封面布局**：
  - 固定放置在**卡片左侧**；
  - 尺寸为 **`116 × 116 dp`**（面积比早期 88dp 扩大 74%），圆角为 **`16 dp`**；
  - 采用 `BoxFit.cover` 与高清 DPR 采样，图片与右侧文字列形成黄金高度平衡。
- **右侧文本列**：
  - **眉线行**：左侧展示 `日期 · 星期`（加粗 13sp，如带置顶则伴随浅色 `[置顶]` 徽章），右侧条件渲染心情与天气微印章；
  - **标题行**：18.5sp 大粗体，最多展示 2 行；多选态时在标题最右侧展示 `solidCircleCheck` 勾选图标；
  - **标签行**：展示 1~3 个 `# 标签` 微胶囊，超出自动折叠为 `+N`；
  - **摘要行**：最多展示 2 行正文摘要，颜色为 `onSurfaceVariant`；
  - **底部时间**：右下或左下展示相对更新时间。
- **置顶与交互规约**：
  - ❌ **绝对禁止在卡片最左侧悬挂生硬的竖条或单边粗线**；
  - 置顶卡片通过眉线 `[置顶]` 胶囊徽章与轻微的主题色微辉光/底色融合进行优雅传达。

#### 2) 双列瀑布流模式（Waterfall Grid）
- **封面布局**：
  - 采用**通栏顶盖式**封面（`width: double.infinity, height: 140, radius: 0`）；
  - 顶部由外层卡片 24dp 圆角自动裁切；
  - 封面与正文之间使用 `0.6dp` 的 `outlineVariant` (0.25 Alpha) 极细分割线过渡。
- **正文区域**：下方包裹 `Padding(14, 12, 14, 12)`，紧凑展示眉线、标题、微标签与正文。

---

### 5.2 标签系统 (Tags Micro-Capsules)
全应用（卡片流、预览页、筛选栏、抽屉发布面板）保持 100% 统一的微胶囊视觉：
- **前缀符号**：所有展示态标签强制带有 `# ` 前缀（如 `# 生活`、`# 灵感`）；
- **底色规范**：使用对应标签主题色的浅淡透明底（`tagColor.withValues(alpha: 0.12 ~ 0.15)`）；
- **文字样式**：字号 `11.5 - 12sp`，字重 `FontWeight.w600`，字色为增强对比度的标签主色；
- **边框与阴影**：无边框（`BorderSide.none`），无阴影，纯粹轻盈。

---

### 5.3 设置页信息架构 (Settings Layout)
遵循语义分组与分层降噪原则：
1. **卡片分组架构（Grouped Cards）**：
   - 严禁在一级页面使用长列表直接以系统分割线（`Divider`）平铺；
   - 统一收纳到 `SettingsCardGroup`（圆角 `24dp`，纯净卡片表面）；
   - 每个卡片组内包含 2~5 个高频语义项，首尾项目边缘平滑收拢。
2. **两级沉淀机制**：
   - **一级页面**：外观主题、主列表卡片形态、通用偏好等低风险直观项；
   - **二级页面**：数据导入导出、WebDAV 同步详情、应用锁与隐私、回收站等高风险复杂配置必须下沉到独立二级页面，禁止在设置首页平铺。

---

### 5.4 图标与操作控件规范
- **图标源统一**：全部使用 `font_awesome_flutter`（`FaIcon` + `FontAwesomeIcons`），严禁混用系统 Material 图标与第三方图标。
- **标题栏返回按钮**：统一使用 `<` 风格，即 `FontAwesomeIcons.angleLeft`，标准尺寸 `18dp`。
- **对话框操作按钮**：
  - 左侧按钮：灰色文本按钮（取消/返回）；
  - 右侧按钮：主色加粗文本按钮（确定/保存）；
  - 危险动作：右侧按钮使用 `colorScheme.error`。
  - 不可撤销的覆盖（导入覆盖本机数据）：严重警告弹窗——error 色警示图标、`errorContainer` 底色的后果说明块（逐项列出将被替换的数据与数量）、先备份的建议；确认键须勾选“我已了解”且 5 秒倒计时结束后才可点。其前一步的导入方式面板默认选中安全的“合并”，危险选项标题常驻 error 色、选中时底色为 `errorContainer`。
- **耗时等待操作**：
  - 启动预热、首屏分页加载统一使用 `loading_indicator_m3e`（`ExpressiveLoadingIndicator`），不再新增裸 `CircularProgressIndicator`；页面首屏 `loading` 分支用 `DelayedLoadingIndicator` 包装，动作等待遮罩用 `ActionLoadingOverlay`。
- **全局提示 (SnackBar)**：
  - 统一调用 `HomeHintVisibilityScope.showTrackedSnackBar`，严禁直接裸调 `ScaffoldMessenger`，确保与首页 FAB 联动规避。

---

### 5.5 录音面板与正文录音卡片

#### 1) 录音面板（`DiaryRecordingPanel`）
- **容器**：悬浮在编辑器工具栏下方，属于浮动面板——`cardColor` 表面 + 24dp 圆角 + 0.8dp 微边框 + `AppEffects.softShadow`，必须与页面形成层次。
- **版式（自上而下）**：名称微胶囊（点按重命名）+ 关闭 → 一行状态（待机提示 / 脉动 REC 圆点 + 录音中 / 暂停图标 + 已暂停 / 失败原因）→ 44sp 等宽计时 → 48dp 实时声纹 → 操作区。**面板高度在待机/录音/暂停三态恒定（约 292dp）**，状态切换只允许淡入淡出与按钮形变，不得因出现声纹或按钮而跳动。
- **主按钮永远是“当前阶段最该点的动作”**：待机 = 麦克风（72dp 圆形，`primaryContainer`）；录音/暂停 = 结束（72dp 圆角方块，实心 `primary`）。暂停/继续是会话中从主按钮左侧展开的 56dp 次要按钮（`secondaryContainer`）。禁止出现“最大的按钮置灰当摆设、真正的操作藏在小按钮里”。
- **阶段稳定性**：版面由稳定阶段决定（`settleRecordingPhase`），暂停/继续途中控制器会短暂经过 `preparing`，此时控制区只禁用交互、不得塌缩；加载指示只在“开始（可能在等权限弹窗）”与“结束（落盘）”且超过 300ms 时出现，禁用态沿用原配色，不闪灰。
- **实时声纹**：每个振幅采样一根柱（3.5dp 柱宽 + 3dp 间距），自右向左匀速滚动（速度与 `recordingAmplitudeSamplePeriod` 对齐）；尚无采样的左侧显示基线圆点；暂停时保留已录制的柱子并换弱化色；没有新采样就不出帧。左缘用逐柱透明度淡出，不使用渐变着色。
- **动效**：主按钮 圆形 ↔ 圆角方块 形变 + 图标缩放淡入（`ExpressiveIconSwap`，弹簧只作用于缩放）；暂停键随 `AnimatedSize` 展开；状态文案 fade-through（淡出前半程、淡入后半程）；REC 圆点与暂停时计时闪烁共用一个呼吸循环；减少动画时循环不启动、一切直接落位。

#### 2) 正文录音卡片（`DiaryAudioPlayer`）
- **表面**：静止卡片使用 `AppEffects.restingCardShadow`；播放中卡片染上 28% 的 `primaryContainer`，多段录音并列时一眼可辨哪一段在播放。
- **播放按钮**：44dp，未播放 = 圆形 tonal，播放中 = 圆角方块实心 `primary`（与录音面板主按钮同一套“状态即形变”语言）；取音频较慢时才显示加载指示（延迟 300ms）。
- **波形**：已播放用 `primary`、未播放用 `onSurfaceVariant` 弱化色（不再使用与描边同级的 `outlineVariant`），播放头为 2dp 竖线；播放位置事件约每 200ms 一次，用线性补间抹平成连续扫动，拖动时补间归零、播放头跟手。时间标签中已播放时长高亮、总时长弱化。

### 5.6 编辑器悬浮工具栏（`DiaryFloatingToolbar`）
- **一排、不横向滚动**：工具按 40dp 一格排布（「缩进」占两格）。全部放得下时紧凑居中；放不下时整排按列等分，最后一格固定为「更多」，常驻工具是设置排序里放得下的**连续前缀**（`resolveDiaryToolbarLayout`）。设置排序页用同一规则按屏宽画出「以下收进「更多」」分界线，拖过分界线的工具留在放下的一侧、相邻工具换边。禁止退回横向滚动长条。
- **「更多」面板**：在同一张浮层卡片内向上展开（`SizeTransition` 顶端对齐 + 淡入，`medium`，`effects` 进 / `exit` 出），沿用工具栏列宽对齐成网格，最多露 3 行，再多则面板内滚动并露出半行提示。不得改用 BottomSheet：新路由会抢走焦点、收起键盘，而工具栏随键盘显示，会连同面板一起消失。录音面板打开时立即收起。
- **状态不藏**：面板收起时，若收进去的工具正在生效（引用、列表、录音等），「更多」右上角亮 6dp `primary` 圆点；展开态按钮换成向下箭头，并经 `ExpressiveStateBlend` 过渡到已选中工具的 `primaryContainer`。
- **正文避让**：面板展开时正文末尾立即追加等高留白（`DiaryToolbarPanelReserve`），光标会被挡住时与面板同速滚到面板上方（`revealDiaryCaretAbove`）；收起时留白随面板同速缩回，正文不跳动。编辑标题时不滚动正文。

---

## 6. 无障碍与跨端屏幕自适应

1. **窄屏极端适配（320dp 逻辑像素基准）**：
   - 所有横向 `Row` 容器内的标题与日期必须具备 `Expanded` 或 `Flexible` 截断保护（`TextOverflow.ellipsis`）；
   - 在狭窄屏幕与超大系统字体下，必须保证卡片不溢出（0 Overflow Exception）。
2. **明暗主题双向校验**：
   - 任何涉及颜色的代码变更，必须同时在 Light 和 Dark 两种主题下审查图标、文字与卡片底色的反差；
   - 严禁暗色模式下出现全黑看不清的图标或无对比度的浅灰文字。

---

## 7. UI 代码审查清单 (Checklist)

代理与开发者在提交任何 UI 改动前，请依次确认：
- [ ] 是否在明亮主题与暗色主题下均无任何“发脏、发暗或看不清”现象？
- [ ] 是否绝对未引入任何 `LinearGradient` 渐变色？
- [ ] 卡片圆角是否为 `24dp`，输入框/图片是否为 `16dp`？
- [ ] 普通列表模式下的左侧封面图是否维持 `116×116` 大画幅与优雅比例？
- [ ] 是否未在置顶卡片左侧增加任何突兀竖线？
- [ ] 新增图标是否统一使用 `FontAwesomeIcons`？返回键是否为 `angleLeft (18)`？
- [ ] 是否执行并通过了 `dart format` 与 `flutter analyze`（0 error, 0 warning）？
