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
| **Scaffold 底色** | `#F7F9FC` (暖柔冷灰) | `colorScheme.surface` (`#111318`) | 整个页面的背景衬底 |
| **卡片/容器主表面** | `surfaceContainerLowest` (`#FFFFFF`) | `surfaceContainerLow` (`#1A1C20`) | 日记卡片、设置分组、悬浮模块主表面 |
| **二级表面/对话框** | `surfaceContainerLowest` (`#FFFFFF`) | `surfaceContainerHigh` (`#282A2F`) | 弹窗 (Dialog)、底部抽屉 (BottomSheet) |
| **输入框填充底色** | `surfaceContainerLow` (0.6 Alpha) | `surfaceContainerHighest` | 文本框、搜索框、选择器底色 |
| **卡片微边框** | `outlineVariant` (0.35 Alpha) | `outlineVariant` (0.20 Alpha) | 0.8dp 极细微边框，构建精致感 |
| **阴影规范** | 单层微柔和语义阴影 (0.12 Alpha) | 单层深色扩散阴影 (0.24 Alpha) | `AppEffects.softShadow`，禁彩色阴影 |

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
  位移与缩放允许使用微弹簧曲线（`ExpressiveMotion.spatial`），时长约 `180ms - 350ms`；透明度与色彩使用 `easeOutCubic` 确保柔和不越界。

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
- **耗时等待操作**：
  - 启动预热、首屏分页加载统一使用 `loading_indicator_m3e`（`ExpressiveLoadingIndicator`），不再新增裸 `CircularProgressIndicator`。
- **全局提示 (SnackBar)**：
  - 统一调用 `HomeHintVisibilityScope.showTrackedSnackBar`，严禁直接裸调 `ScaffoldMessenger`，确保与首页 FAB 联动规避。

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
