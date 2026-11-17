# 文字选区菜单、软键盘与拖动手柄

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
