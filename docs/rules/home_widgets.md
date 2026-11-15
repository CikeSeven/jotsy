# 桌面小组件

改动桌面小组件（种类、快照、原生渲染、小组件页与工作室）前先读本文件；视觉规范见 DESIGN.md「桌面小组件」。

## 范围与分工

- 必须：只在 Android 提供（`AppPlatform.supportsHomeWidgets`）。不支持的平台不出现设置入口，`homeWidgetGatewayProvider` 为 null，同步与点按路由都不启动。
- 必须：数据、隐私过滤、本地化文案与配色一律在 Dart 侧算好，写进一份快照（`HomeWidgetSnapshotBuilder`，`lib/ui/home_widgets/viewmodels/`）；原生（Jetpack Glance，`android/app/src/main/kotlin/com/jotsy/diary/widgets/`）只负责渲染、按本机日期挑快照里的那一天、以及按尺寸选版式。禁止在 Kotlin 里重新实现查询、私密判断、农历换算或复数规则。
- 必须：与插件打交道只经 `HomeWidgetGateway`（插件实现 `PluginHomeWidgetGateway`，测试用 `FakeHomeWidgetGateway`）。插件实现里的 `Platform.isAndroid` 判断是原生通道旁的兜底（widget 测试的目标平台是 Android，但宿主没有插件），不得挪到 UI。

## 快照

- 必须：快照存于 home_widget 的 SharedPreferences（`HomeWidgetPreferences`）键 `jotsy.widgets.snapshot`（Dart `kHomeWidgetSnapshotKey` 与 Kotlin `WidgetSnapshot.KEY` 同步）。字段：
  - `v`：格式版本；原生遇到更高版本照常按认得的字段绘制。
  - `locale`、`displayFont`（展示字体族，`HarmonyOSSansSC`）、`redacted`（应用锁开着）。
  - `palettes`：配色键 → `{light, dark}` 色槽表；色槽名只取 `kHomeWidgetPaletteRoles`。总带 `app`，再加各实例与待领取设计里的自选种子色（`seed:AARRGGBB`）。
  - `strings`：原生用的文案；要原生代入的变量写成 `%s`（如 `yearProgress`）。`icons`：图标键 → 字体族与码位。
  - `plurals`：原生现算数量的文案（纪念日的“天后 / 天前 / 还有 N 天”），每个键是“复数类别 → 写法”，数量写成 `%d`；由 `homeWidgetPluralForms` 用各类别的代表数调 ARB 导出，原生用 `android.icu.text.PluralRules` 按界面语言挑类别（`WidgetSnapshot.plural`）。新增界面语言必须在 `home_widget_plurals.dart` 登记代表数（测试兜底）。
  - `builtAt`：写入时刻；比它新的乐观更新才覆盖快照（见「桌面上的操作」）。
  - `instances`：appWidgetId → 原生口径的配置（`homeWidgetNativeConfig`：功能开关、界面语言与日记本已过一遍），`defaults`：种类 → 默认配置（刚放下、应用还没同步过的实例用它）。
  - 数据节：`today`（逐日的日期文字、农历、节假日、待办数，今天的字数与心情）、`anniversaries`（按列表顺序的纪念日，各带接下来 3 次的日子与第几周年）、`calendar`（这个月与前两个月每天的心情段、是否写过、节假日，以及一周从哪天开始）、`todos`（按截止日 / 时刻 / 优先级排好的未完成待办（最多 80 条）、今天完成的（最多 20 条）与清单名；“今天 / 明天 / 已逾期”与视图筛选由原生按本机日期做）。只为桌面上有的种类计算；小组件页 / 工作室打开期间（`homeWidgetPreviewDemandProvider`）为全部种类计算，预览才有真实数据。
- 必须：按日期变化的内容逐日预算 `kHomeWidgetDayHorizon`（14）天，原生按本机日期取那一天；超出预算时只显示本机算得出的东西（公历日期与星期），不显示可能过期的内容。
- 必须：快照字段变化时同步改 Kotlin 解析、`docs` 本节，并用 `UPDATE_WIDGET_FIXTURE=1 flutter test test/ui/home_widgets/home_widget_snapshot_builder_test.dart` 重新生成原生渲染测试读的夹具 `android/app/src/test/resources/widget_snapshot_fixture.json`（测试比对两者逐字一致）。

## 同步与刷新

- 必须：快照只由 `HomeWidgetSyncController`（`NodeDiaryApp` 常驻监听）写入：库表变化（`tableUpdates`）、功能开关、小组件设置、界面语言、主题色、应用锁与回到前台都会触发，防抖后串行执行。桌面上没有小组件且小组件页没开时什么都不做；快照与上一份相同就不写入、不刷新。
- 必须：每天第一次同步为桌面上的种类排好之后 14 天零点的重画（快速记录另加问候换时段的整点，`homeWidgetRedrawTimes`），经 home_widget 的 `HomeWidgetScheduledUpdateReceiver`（已在 Manifest 登记，开机 / 更新后重排）。
- 必须：新增数据来源的表时，把它加进同步控制器的 `tableUpdates` 清单。

## 设置与配置

- 必须：小组件设置只存单个 JSON 键 `app.settings.home_widgets`（`HomeWidgetSettings`，逐项容错），是本机偏好：不随备份导出、不参与局域网同步（实例按启动器分配的 appWidgetId 记，换设备没有意义）。经 `homeWidgetSettingsProvider` 读取、`saveHomeWidgetSettings` 写入。
- 必须：每个实例一份外观（`HomeWidgetStyle`：配色、明暗、底色与不透明度、圆角、文字大小、间距、强调色）与一份按种类不同的内容（`HomeWidgetContent` 的子类）。对账（`reconcile`）删掉已移除实例的配置。
- 必须：工作室“添加到桌面”时先把设计存为待领取（`pending`），再请求系统固定：`requestPinAppWidget` 不回传新实例的 id，桌面上第一个出现的、还没有配置的同类实例在 15 分钟内领走它。启动器不支持固定时同样暂存，并提示用户手动添加。
- 必须：小组件信息声明 `reconfigurable|configuration_optional`，配置入口 `WidgetConfigureActivity` 只做中转：先 `setResult(RESULT_OK)`（否则启动器移除刚放下的小组件），Android 12+ 带着 id 与种类打开工作室；更早的系统放置时直接确认、不打开应用。
- 例外：小组件可以由用户主动添加，不在 `AppFeatures` 登记独立开关；但所需功能（待办、日历、纪念日、探索）关闭时，组件库隐藏对应种类，桌面上已有的显示“已在功能管理中关闭”占位，快速记录剔除相关动作，内容选项不提供相关项。

## 隐私

- 必须：快照只用已带私密过滤的查询；私密日记（含继承）与未到期的时间胶囊的 id、标题、正文、照片路径永远不进快照。快速记录“写进日记本”只列可写的普通日记本（非智能、非私密、未合上），本子之后变得不可写时按不指定处理。
- 必须：应用锁开启时快照标记 `redacted`，涉及日记标题、正文与照片的数据节不写入内容，原生显示锁定占位；纪念日、待办与统计照常显示。
- 必须：点按链接打开日记 / 日记本前按当前状态复核（日记是否私密、日记本是否可写、功能是否开启），不能因为桌面上留着旧链接而绕过功能开关或私密规则。

## 桌面上的操作

- 必须：不打开应用就完成的点按（今日小组件的心情脸、待办的勾选与恢复）链接为 `jotsy://widget-action/<动作>?参数`，Dart `HomeWidgetAction.parse` 解析、`applyHomeWidgetAction` 是唯一的写库口径。原生先乐观更新（`WidgetOverlay`，存 `HomeWidgetPreferences` 的 `jotsy.widgets.overlay`，只有比快照 `builtAt` 新的条目生效）并立刻重画，再经 home_widget 的后台广播交给 `homeWidgetBackgroundCallback`。
- 必须：后台回调先经 `IsolateNameServer` 转交主 isolate（端口 `jotsy.home_widget_actions`，同步控制器启动时打开，等 3 秒），由主 isolate 用自己的连接写库；主 isolate 不在时后台引擎自己打开 `AppDatabase()` 写库、按同一套口径重建快照并刷新，再关闭连接。与待办通知按钮同一种做法，两个连接不同时写库。
- 必须：勾选待办只完成小组件上显示的那一次（`todo-complete?id=&due=`，截止日已被别处推进时不写，与通知上的“完成”同一口径）；后台引擎写库后顺手取消这一次剩下的提醒（`cancelTodoOccurrenceNotifications`，与通知按钮共用），应用下次运行时提醒调度器再按库对账。恢复为未完成（`todo-reopen`）与待办列表里取消勾选同一口径。
- 必须：`HomeWidgetBackgroundReceiver` 在 Manifest 里不导出（只接受本应用发出的显式广播），其他应用不能借它改数据。
- 必须：只影响显示的操作（心情月历翻月）不经过 Dart，状态存原生自己的 `JotsyWidgetState`；翻月 10 分钟后回到这个月。
- 必须：心情脸的五官画法逐笔移植自应用的 `DayMoodFace`（`WidgetMoodFace.kt`），改动任一端须同步另一端。

## 点按与打开

- 必须：链接格式 `jotsy://widget/<目标>?参数`，原生 `WidgetLaunch.uri` 拼、Dart `HomeWidgetLaunch.parse` 解析，两端目标名一致：`home`、`write?notebook=`、`todo-new`、`calendar?day=YYYY-MM-DD`、`search`、`anniversary`（列表）/ `anniversary?id=`（详情）、`todo?id=`（切到待办 Tab 打开详情）、`todo-new?list=`（预先选好清单）、`configure?id=&kind=`。认不出的目标只打开应用。
- 必须：链接经 `homeWidgetLaunchInboxProvider` 交给首页（`homeWidgetLaunchRequestProvider`，冷启动经 `fireImmediately` 接住），由 `openHomeWidgetLaunch` 走统一入口：`runDiaryCreateEntryFlow`、`showTodoQuickAddSheet`、切到日历 Tab 后经 `calendarFocusRequestProvider` 选中那天、`DiarySearchPage.buildRoute`、小组件工作室。应用锁遮罩盖在导航之上，打开的页面同样要先解锁。

## 文案、配色与字形

- 例外：启动器列表里的名称与描述、快照到达前的兜底文字是 Android 资源（`res/values*/widget_strings.xml`，en / zh / ja / ru 四份同步）；小组件上其余文字一律来自快照（ARB）。
- 必须：“跟随壁纸”用系统动态色资源（`widget_dynamic_colors.xml`：values-v31 用系统色调盘近似、values-v34 用系统色槽；`values/` 为兜底），色槽映射在 `WidgetDynamicColors.kt`，改动须同步各目录。不透明度小于 1 的颜色要读出当时的值再组合，换壁纸后要等下一次重画才跟上；其余颜色由启动器按当前壁纸解析，不必重画。Android 12 以下没有动态色，按应用主题色显示。
- 必须：跟随系统明暗时颜色一律是昼夜一对（`ColorProvider(day, night)`），系统切深色不必重画。位图（图标、展示数字）一律画成白色再经 `ColorFilter.tint` 着色，不把颜色画死在位图里。
- 必须：图标与展示数字从应用自带的字体画（`WidgetGlyphs`，经 home_widget 的 `HomeWidgetFonts` 读 `flutter_assets`）；图标在 Dart 的 `homeWidgetIcons` 里以 const 引用，发布构建的图标字体裁剪才会保留这些字形。

## 版式

- 必须：每个种类声明 `SizeMode.Responsive` 的几档尺寸，版式按阈值分档（如高度不足方块即为一行），禁止比较 `LocalSize` 是否等于某一档：桌面上它是挑中的那一档，应用内预览按精确尺寸组合时则是实际尺寸。
- 必须：可用尺寸三处一致：`res/xml/widget_info_*.xml` 的缩放范围、Kotlin 的分档、Dart `HomeWidgetCellSize.sizesOf`（预览与组件库的尺寸标签）。

## 预览

- 必须：应用内预览经 PlatformView `com.jotsy.diary/home_widget_preview`（`WidgetPreviewView`）用桌面上同一份 Glance 代码画出来（`compose(state = WidgetPreviewState)`），禁止另写一套 Flutter 版的小组件外观。预览拦下全部触摸（RemoteViews 里的点按会真的打开页面）；快照写入后自动重画。

## 新增一个种类

依次：Dart `HomeWidgetKind`（id、接收器名、分组、所需功能；所需功能决定组件库是否显示、桌面上是否显示“已关闭”）→ 内容子类与 `homeWidgetNativeConfig` 分支 → 快照数据节 → 名称 / 图标（`home_widget_kind_labels.dart`）与 `HomeWidgetCellSize.sizesOf` → 工作室的内容选项 → Kotlin 小组件与接收器、`WidgetKinds`、Manifest、`widget_info_*.xml`、`widget_strings.xml` 四份 → 渲染测试的用例 → 重新生成夹具。

## 测试

- 必须：Dart 侧覆盖设置与链接解析、快照构建（功能关闭、私密、应用锁、配色）与同步控制器；页面测试覆盖入口按平台显隐、组件库、添加到桌面与即时保存。
- 必须：Kotlin 渲染测试（`WidgetRenderTest`，Robolectric，Android 11 与 14）对每种小组件的每档尺寸、各种外观与明暗做组合与展开。看效果时设 `JOTSY_WIDGET_RENDER_DIR=<目录>` 跑 `./gradlew :app:testDebugUnitTest --tests '*WidgetRenderPreviewTest*'`，把各组合画成 PNG（Robolectric 不画圆角裁切，圆角以真机为准）。
