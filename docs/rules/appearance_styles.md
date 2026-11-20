# 外观样式：日记卡片、心情色、预览页、导航栏

> 专题约束，与 AGENTS.md 同等效力；改动本主题前先读本文件，新规则写在这里。界面规格见 DESIGN.md §5.1 / §2.3 / §5.8 / §5.19 / §5.38。

## 样式设置
- 必须：卡片、预览页、导航栏样式各只存一个 JSON 键（当前样式 + 最多 12 份“我的样式”），随备份导出、失败回滚。
- 必须：键为 `diaryCardStyleRaw`、`diaryPreviewStyleRaw`（含阅读行为）、`app.settings.home_bar_style`（含行为，备份里没有时不恢复）；禁止另加零散键。
- 必须：（阅读）行为不随预设与样式码改变；样式编辑页共用 `StyleEditorScaffold` 与 `StyleDraftController`，禁止复制一份。
- 必须：条件出现的设置行统一经 `SettingsReveal` 展开收起。

## 日记卡片与预览页
- 必须：卡片只经 `DiaryCard` + `DiaryCardResolvedStyle` 渲染，禁止各页另拼；默认值逐项等于 DESIGN.md §5.1。
- 必须：未解封的时间胶囊只套用表面样式，正文仍封存，心情色与标签色回退主题色。
- 必须：卡片“显示所属日记本”只取列表查询带出的日记本，禁止卡片自查；日记本功能关闭时视为关、值保留。
- 必须：预览页只经 `DiaryPreviewContent` + `DiaryPreviewResolvedStyle` 渲染，默认值等于 DESIGN.md §5.8。
- 禁止：预览页样式重复设置正文字体排版（只在 `DiaryTypography`），或再加顶栏按钮开关。
- 必须：“顶栏标题”的 `label` 值表示页头滚过后浮出这篇的标题，沿用旧值名、不做存档迁移。

## 心情色
- 必须：心情颜色只经 `DiaryMoodPalette`，禁止自行按心情符号换算；十档相邻色相至少约 20°（测试兜底）。
- 必须：用户改的心情符号与颜色只存 `app.settings.mood_options` / `app.settings.mood_colors`，随备份、局域网同步时始终同步，只在心情符号页编辑。
- 禁止：日历年视图与探索心情图表改用心情色板（只经 `MoodBandPalette`）。

## 导航栏
- 禁止：再引入贴底实色底栏、材质开关、SDK `NavigationBar` 或实色顶栏选项。
- 必须：颜色与几何只经 `HomeBarResolvedStyle` 解析，栏高、格高、指示器圆角只由形状参数推导。
- 禁止：开放栏高、指示器圆角、描边、模糊等单项；范围只在 `HomeBarStyleLimits`（`home_bar_style_test.dart` 兜底）。
- 必须：JSON 相对默认值稀疏编码，旧字段忽略不迁移；改默认值须有意为之并在 `HomeBarStyle` 注释写明。
- 必须：内置预设保持偶数；改玻璃配方后截图核对每个预设明暗下都像玻璃，改形状后核对 360 宽放下五项不收窄（`home_bar_resolved_style_test.dart` 兜底）。
- 必须：多片拼成的顶栏只用一块玻璃（最下面一片画并往上铺），禁止各片各画一块（接缝出线）。
- 必须：顶栏下缘渐变 / 分隔线 / 实边只由 `topBarFades` 决定；渐变时栏内自带底色的控件改用 `topBarControlFill`。
- 禁止：用 `ShaderMask` / `Opacity` 或叠多层模糊做顶栏渐变（只经 `GlassSurface.fadeToBottom`），或借它做颜色过渡。
- 必须：新增首页 Tab 经 `HomeChromeScope` 取样式、`HomeTopBarSurface` 画顶栏，末尾补底部安全区。
- 必须：设置入口的位置只存 `HomeBarBehavior.settingsPlacement`（默认导航栏）：在导航栏时日记页“更多”菜单不列设置，在菜单时导航栏没有设置 Tab，两处禁止同时出现；Tab 集合只经 `visibleHomeTabs` 推出。

## 日记页浮岛顶栏
- 必须：预览、阅读式编辑、新建、导图、封存与出错页的顶栏只经 `FloatingTopBarHost`（`lib/ui/widgets/floating_top_bar/`）画浮岛；禁止给这些页的 Scaffold 设 `appBar` 或另拼浮岛。
- 必须：浮岛随滚动显隐只经 `ScrollChromeHider`（与首页底栏共用），禁止另写判定。
- 必须：状态栏渐隐带只经 `FloatingTopBarStatusStrip`（`GlassSurface.fadeToBottom`）画、浮岛叠在它之上；禁止恢复只垫状态栏的硬边（高对比度除外）。
- 必须：渐隐带只做不透明底色（玻璃时为 `solidFill`）的透明度过渡、不模糊；压在上面的玻璃浮岛照常模糊，同一区域只有这一层模糊。
- 必须：翻页时浮岛只经 `DiaryPreviewChromeBoard` 画在所有页之上；禁止放回各页里（会随页面滑走）。
- 必须：动作胶囊里随状态出现 / 消失的按钮包 `FloatingIslandSlot`；禁止整套按钮交叉淡化替换（同一按钮会同时出现两份）。
- 禁止：浮岛顶栏的页面恢复整条顶栏底色或“日记”二字标题。

## 切换 Tab
- 必须：页面位移只由真弹簧 `springPage` 推动，跨页临时顺序只经 `HomeTabPageOrder`，景深只经 `HomeTabDepth`。
- 禁止：回到固定时长 `animateToPage`、“先跳隔壁再滑一页”或切页途中丢弃点按。
- 禁止：给页面套 `Opacity` / `FadeTransition` 或离屏层做退远；景深静止时不得产生图层（`home_tab_depth_test.dart` 兜底）。
- 禁止：对没完整显示过的 Tab 拍景深快照（会冻结成空页）；减少动画与宽窗口不拍快照。
