# 文字选区菜单、提示条避让、软键盘与拖动手柄

> 专题约束，与 AGENTS.md 同等效力；改动本主题前先读本文件，新规则写在这里。界面规格见 DESIGN.md §5.4。

## 文字选区菜单

- 必须：只读文字要能选字时套 `AppSelectionArea`，禁止用 SDK `SelectionArea` 的默认菜单；日记正文经 `AppTextSelectionMenu.adaptive`。
- 必须：菜单项只经 `AppTextMenuAction`；其他应用的文字操作在可编辑正文里以纯文本替换选区、一步撤销，只读时只交出。
- 必须：手机正文的选区把手只经 `DiaryEditorSelectionGestures`：触控区按水滴放大、按下即认领触点；禁止退回上游的小触控区（#190）。
- 必须：拖把手、长按扩选或拖光标到可见范围边缘时自动滚动，与段落拖动共用同一套参数；可见范围只经 `diaryEditorVisibleRange`（`diary_cursor_drag_follow_test.dart` 兜底）。
- 禁止：可编辑的整页正文启用上游自动滚动器（与选区手势抢滚动会卡死）；光标揭示只经 `DiaryEditorViewport`。
- 必须：拖把手、复制、全选等不输入文字的操作在键盘收着时经 `holdHiddenKeyboard`，不拉起用户收起的键盘。
- 必须：手指按着正文且选区在变时收起选区菜单，抬起后再决定是否弹出；只旁听指针，禁止参与手势竞争（`diary_editor_selection_press_test.dart` 兜底）。
- 必须：菜单随滚动跟着选区走，离开可见范围不画，编辑页菜单不压住底部浮层；禁止恢复“一滚就收起”（#221，`diary_editor_selection_menu_follow_test.dart` 兜底）。

## 软键盘升降

- 必须：只关心键盘在不在用 `KeyboardVisibility.of`；为键盘留白用 `KeyboardInsetPadding` 或单独的小组件，只让这一层逐帧重建。
- 必须：只按宽度构建的整列 `LayoutBuilder` 改用 `WidthLayoutBuilder`；按高度构建的范围尽量小。
- 必须：大页面取状态栏 / 导航条高度用 `MediaQuery.viewPaddingOf`，不用 `paddingOf`。
- 必须：`MaterialApp.builder` 里的主题覆盖经 `DerivedThemeCache`；禁止在逐帧重建处直接 `Theme(data: theme.copyWith(...))`（`app_glass_theme_stability_test.dart` 兜底）。
- 必须：被其他路由盖住的页面不随键盘动；不经 `AppPageBackground` 的整页须自己冻结。
- 必须：悬浮工具栏面板上限经 `DiaryToolbarPanelLimit` 写入，禁止用 LayoutBuilder 把高度传给工具栏。
- 必须：编辑器正文经 `DiaryScrollPageBuilder`，键盘动画不重建正文块；升级 appflowy_editor 时对照上游同步。
- 必须：重建次数由 `keyboard_visibility_test.dart`、`width_layout_builder_test.dart`、`diary_scroll_page_test.dart`、`edit_diary_page_rebuild_test.dart`、`diary_search_keyboard_test.dart` 兜底；改动后在真机 profile 包（玻璃 + 背景图）量一次键盘动画帧耗时。

## 拖动排序手柄

- 必须：可排序列表的手柄一律用 `ReorderHandle`，禁止在其文件外直接写 `ReorderableDragStartListener`（长按拖动的 Delayed 版除外）。
- 必须：`proxyDecorator` 用共用的两个装饰器之一，自写的须包 `ReorderHandleLift`（以上两条 `reorder_handle_source_test.dart` 兜底）。

## 单向横向拖动

- 必须：嵌在首页翻页 PageView 里、只要一个方向的横向拖动经 `DirectionalHorizontalDragGestureRecognizer`，另一方向留给外层；禁止用 `onHorizontalDrag*` 把两个方向都接下。
- 必须：日记列表的卡片左滑（`DiarySwipeActionItem`）没有行首动作时开 `releaseStartDrags`，右滑留给日记本卡组。

## 提示条避让底部栏

- 必须：浮动提示条（`SnackBar`）不得遮挡任何底部可交互工具栏、多选操作栏、查找栏、播放栏或底部面板，底缘距其顶缘保留标准间隙（`SnackBarClearanceHost.defaultGap`，16dp，与距 `bottomNavigationBar` 一致）。
- 必须：非悬浮、非叠层的常规底栏优先放在 `Scaffold.bottomNavigationBar`，由 `Scaffold` 自动把提示条排在其上方。
- 必须：因悬浮、叠层、进出场动效或独立安全区必须放在 `Scaffold.body` 内的底部可交互区域（如日记编辑页悬浮工具栏 / 查找栏 / 录音与 AI 面板、待办多选操作栏、思维导图工具坞 / 键盘附件条、模板编辑页工具栏、预览页查找栏与回到顶部按钮、发布与编辑信息面板、回收站 / 存储媒体多选栏、全屏视频播放栏、扫码底栏），页面根 `Scaffold` 外包 `SnackBarClearanceHost`（`resizeToAvoidBottomInset` 与 `bottomBarExtent` 与该 `Scaffold` 一致），各底部可交互区域外包 `SnackBarClearanceArea`（常驻树里按开关显隐的传 `enabled`）。
- 必须：避让经 `SnackBarTheme` 局部调整 `insetPadding.bottom`，不得改整页 `Theme` 引发键盘动画或正文块重建，且保留外层玻璃提示条配色与宽窗口水平居中；极矮窗口或大面板展开时须为提示条本体保留顶部余量，禁止触发 off-screen 断言。
- 必须：提示条展示期间若有底部操作栏刚收起离场（如待办点击删除后多选栏正在下沉），维持本条提示当前避让高度直到关闭，避免“撤销”按钮中途下跳；停留期间新出现或变高的底部浮层须立即抬高避让。
- 禁止：在业务调用处手写 `SnackBar(margin: ...)` 补偿某页的底部栏高度，或直接用 `Theme(data: theme.copyWith(snackBarTheme: ...))` 逐帧驱动避让。
- 必须：由 `snack_bar_clearance_test.dart` 兜底（含核心页面明暗主题与极矮屏边界）。
