# 文字选区菜单、软键盘与拖动手柄

> 从 `AGENTS.md` 拆出的专题约束，与 `AGENTS.md` 同等效力（必须 / 禁止 / 例外）。改动本主题的代码前先读本文件；本主题新增或修改的规则写在这里，不写回 `AGENTS.md`。界面规格见 DESIGN.md §5.4。

## 文字选区菜单

- 必须：文字选区菜单（长按选字 / 桌面右键的复制、粘贴菜单）只经 `lib/ui/widgets/text_selection_menu/`：输入框（`TextField` / `TextFormField` / `SelectableText` / `SearchBar`）一律传 `contextMenuBuilder: appTextContextMenuBuilder`，只读文字（AI 对话的回答、思考、问题气泡等）要能长按选字时套 `AppSelectionArea`（`SelectionArea` + 同一套菜单，手机补「分享」），禁止直接用 SDK 的 `SelectionArea` 默认菜单，日记正文经 `AppTextSelectionMenu.adaptive`（`DiaryEditorSelectionToolbar` / `diaryEditorContextMenuBuilder`）；禁止在该目录之外使用 `AdaptiveTextSelectionToolbar` / `DesktopTextSelectionToolbar` / `CupertinoTextSelectionToolbar` / `TextSelectionToolbar`（`test/ui/widgets/text_selection_menu_source_test.dart` 兜底）。菜单项只经 `AppTextMenuAction`（内置类型经 `appTextMenuActionsFromButtonItems` 统一文字、图标与快捷键）；分享只在 `AppPlatform.supportsTextShare`（手机），其他应用的文字操作只经 `TextProcessActionsService`（`AppPlatform.supportsProcessText`，Android；正文可编辑时把返回的文字以纯文本替换选区、一步撤销，只读时只交出不回写）。视觉规范见 DESIGN.md §5.4。
- 必须：手机日记正文（编辑与只读共用）的选区把手只经 `DiaryEditorSelectionGestures`（`diary_editor/diary_editor_selection_gestures.dart`）接管：触控区按上游水滴几何放大（`diarySelectionHandleTarget`：以水滴为中心宽 56，从水滴中心朝正文 24、向外伸到正文边缘外 `kDiarySelectionHandleOverhang`），按下即认领触点（正文点按 / 长按、外层滚动与翻页都不再参与），拖动按“按下处到该端插入点中心”的偏移平移、第一次移动才交给上游；只按不动就抬起什么也不做。是否接管按上游实际装的是不是手机选区服务判断（上游按宿主系统选服务，桌面服务的 onPan* 直接抛错），测试经 `driver` 注入假实现。收缩嵌入的正文在下方留出同样的 `kDiarySelectionHandleOverhang`。禁止退回上游自带把手的触控区（水滴下方只有水滴本身那十几像素可按、移动 36px 才开始拖，#190）。
- 必须：拖动选区把手到看得见的范围上下 `kDiaryAutoScrollZone` 以内时自动滚动（上游手机选区服务不做），与段落拖动共用 `diary_edge_auto_scroll.dart` 的目标矩形与速度：编辑页滚正文自己的列表（底部去掉键盘与悬浮工具栏 `coveredHeight`），收缩嵌入阅读页的正文滚外层页面（顶部去掉正文所在 sliver 的 `constraints.overlap`——固定或浮出的顶栏——与状态栏，底部去掉导航条）。拖动期间逐帧检查，内容滚过就按手指位置重新取选区；交给上游的位置夹在看得见的范围里，拖到栏或键盘上只选到边缘那一行。禁止另写一套自动滚动参数。
- 必须：上游手机选区服务自己的插入点式拖动（长按后不松手拖着扩选、iOS 长按移光标、横滑移光标、拖折叠光标的把手）拖到边缘时同样由 `DiaryEditorSelectionGestures` 自动滚动：只经不参与手势竞争的 `Listener` 旁听触点，上游写下附加信息为 `MobileSelectionDragMode.cursor` 的选区后跟随，内容滚过时由 `DiaryCursorDragFollow`（`diary_cursor_drag_follow.dart`）按上游同一手势的规则重新取选区（Android 长按按词、以长按的词为固定一端，`diaryLongPressWordSelection`；其余为跟着手指的光标）。同一选区不带拖动方式的再写一次（正文获得焦点时重写原选区、上游松手写回）不算中断，手指抬起才结束。`diary_cursor_drag_follow_test.dart` 兜底。
- 必须：可编辑的整页正文（`DiaryEditor` 非收缩、非只读，`disableAutoScroll` 为真）不把自动滚动器交给上游：`DiaryEditorController` 的 EditorState 覆盖 `autoScroller`，关掉时返回 null。上游只有桌面滚动服务理会 `disableAutoScroll`，手机滚动服务照样在每次选区变化后边缘滚动、拖选区时逐帧续滚；它与选区手势同时 animateTo 同一个滚动位置时互相顶掉对方的动画、在微任务里无限重来，界面卡死（拖把手或长按扩选到正文顶部必现）。光标揭示只经 `DiaryEditorViewport`，拖选区的边缘滚动只经 `DiaryEditorSelectionGestures`；禁止再让上游的自动滚动在这类正文上生效。
- 必须：不输入文字的选区操作（拖选区把手、复制后收成光标、菜单里的全选）在手机软键盘收着时只经 `holdHiddenKeyboard` / `DiaryEditorController.holdingKeyboard`（`diary_editor/diary_editor_keyboard_hold.dart`）执行：其间的选区更新补上 `selectionExtraInfoDoNotAttachTextService`，不把用户收起的键盘拉起来（上游每次选区变化都重新接上输入法，编辑值一变就 `show()`）。把手拖动在开始时定下、整次拖动（含自动滚动与松手）有效；键盘开着时与桌面照常同步输入法。之后点正文打字由上游照常接上并弹出。
- 必须：手机正文的选区菜单（`DiaryEditorSelectionToolbar`）在手指按着正文且选区在变（长按选词与扩选、拖把手、横滑移光标）时收起，让出上游的放大镜，最后一根手指抬起后再按松手时的选区决定是否弹出；按着不动（选区没变）时菜单照旧。按压只经该组件里只观察指针的 `Listener` 统计，禁止为此参与手势竞争。菜单翻到选区下方时让出整块把手触控区（`secondaryAnchor` 下移到文字下方 `kDiarySelectionHandleOverhang`）。`diary_editor_selection_press_test.dart`、`diary_selection_handle_gestures_test.dart` 兜底。

## 软键盘升降

软键盘升降动画期间 `viewInsets.bottom` 每帧都在变，Scaffold（`resizeToAvoidBottomInset` 默认开）随之逐帧缩小 body。依赖它们的组件在动画的每一帧都会重建，重建的子树越大，键盘拉起、收起越卡（曾经编辑页整页连同正文每个段落块、搜索页整列结果卡片逐帧重建）。

- 必须：只关心键盘在不在（如编辑页按键盘显示悬浮工具栏）用 `KeyboardVisibility.of(context)`（`lib/ui/widgets/keyboard_visibility.dart`，应用壳在 `MaterialApp.builder` 里挂了一个），只在弹起 / 收起时重建；禁止在页面的 build 里读 `MediaQuery.viewInsetsOf`。
- 必须：底部面板为键盘留白用 `KeyboardInsetPadding(child: …)`，只有这一层逐帧重建；列表底部的键盘留白同理放进单独的小组件（如模板选择面板的 `_BottomInsetSliverPadding`）。禁止在面板的 build 里直接写 `Padding(bottom: MediaQuery.viewInsetsOf(context).bottom)` 或取整份 `MediaQuery.of(context)` 再读 `viewInsets`。
- 必须：只按宽度（`FormWidth`、`AppContentWidth.gutter`、断点）构建、包着整列内容的 `LayoutBuilder` 改用 `WidthLayoutBuilder`（`lib/ui/widgets/width_layout_builder.dart`）：宽度不变时交回上一次构建的子树。按可用高度构建的（如按剩余高度限制面板）仍用 `LayoutBuilder`，范围尽量小；只为取 `min(定高, 可用高度)` 时直接用 `SizedBox`，父级约束会自动收紧。
- 必须：大页面只取状态栏 / 导航条高度时用 `MediaQuery.viewPaddingOf`：`padding` 的底边在键盘盖过导航条的那几帧逐帧变化，读 `paddingOf(context).top` 也会跟着整页重建；键盘收着时两者相同。
- 必须：`MaterialApp.builder` 读整份 MediaQuery、键盘升降时逐帧重建，挂在里面的主题覆盖（玻璃控件与提示条、减少动画）一律经 `DerivedThemeCache`（`lib/app/theme/derived_theme_cache.dart`）按基础主题记住派生结果；禁止在逐帧重建的位置直接 `Theme(data: theme.copyWith(...))`：其中的 `WidgetStateProperty.resolveWith` 等闭包比较起来永远不相等，Theme 会逐帧通知全应用重建（真机上打开玻璃材质时曾让编辑页、预览页、首页在键盘动画的每一帧整个重建）。基础主题按值比较：`Theme.of` 返回的是框架 5 项缓存里的本地化副本，主题层级一多就是内容相同的新实例。`app_glass_theme_stability_test.dart` 兜底。
- 必须：被别的路由盖着的页面不随键盘动：`AppPageBackground` 在所在路由不是当前路由时经 `KeyboardShield` 把键盘冻结在被盖住那一刻（冻结而不是清零，正打字时盖上带输入框的对话框，下面不会先撑开再缩回）；首页（不为键盘让位、没有输入框）在应用壳里始终屏蔽。新增不经 `AppPageBackground` 的整页必须自己处理。
- 必须：悬浮工具栏的面板上限（`DiaryFloatingToolbar.maxPanelExtent`）是可监听的值，由 `DiaryToolbarPanelLimit` 在布局时按可用高度写入，工具栏只在面板展开时跟随；禁止再用 LayoutBuilder 把高度当参数传给工具栏。
- 必须：编辑器的可滚动正文经 `DiaryScrollPageBuilder`（`diary_editor/diary_scroll_page.dart`）：上游 `ScrollablePositionedList` 在 `LayoutBuilder` 里按视口高度重建整张列表，这里在同一次页面构建内记住各项，键盘动画不重建正文块；页面块重建（顶层块增删、换渲染器或样式）时记忆随之失效。它复刻的是固定版本上游 `PageBlockComponent` 的滚动分支，升级 appflowy_editor 时必须对照上游同步。
- 兜底：`keyboard_visibility_test.dart`、`width_layout_builder_test.dart`、`diary_scroll_page_test.dart`、`edit_diary_page_rebuild_test.dart`、`diary_search_keyboard_test.dart`、`app_glass_theme_stability_test.dart` 按重建次数检查。只在测试里量重建次数不够：默认的经典样式复现不了玻璃材质下的问题，改动后在真机（profile 包，玻璃 + 背景图）上量一次键盘动画的帧耗时。

## 拖动排序手柄

- 必须：可排序列表（`ReorderableListView` / `SliverReorderableList`）的拖动手柄一律用 `ReorderHandle`（`lib/ui/widgets/reorder_handle.dart`，规格见 DESIGN.md §5.4）；禁止在该文件之外直接写 `ReorderableDragStartListener`（长按后拖的 `ReorderableDelayedDragStartListener` 不在此列）。以前各列表用 `Padding` 包 14px 图标当手柄，`Padding` 的留白不参与命中测试，实际只有图标那十几像素能按到。
- 必须：可排序列表的 `proxyDecorator` 用 `expressiveReorderProxyDecorator`（加卡片表面与投影）或 `cardRowReorderProxyDecorator`（行本身已是卡片，只轻微放大），自写的必须把拖起的副本包进 `ReorderHandleLift`，拖起的那一行手柄才保持握住状态。拿起时在 `onReorderStart` 里给 `HapticFeedback.mediumImpact()`。
- 兜底：`reorder_handle_source_test.dart` 查以上两条；`reorder_handle_test.dart` 在两种列表里检查整块 48dp 可拿起、禁用、握住态与读屏标签（`SliverReorderableList` 拖起时原行直接卸载、`ReorderableListView` 的原行 State 会搬进副本，两种都要测）。
