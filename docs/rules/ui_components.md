# 文字选区菜单与软键盘

> 从 `AGENTS.md` 拆出的专题约束，与 `AGENTS.md` 同等效力（必须 / 禁止 / 例外）。改动本主题的代码前先读本文件；本主题新增或修改的规则写在这里，不写回 `AGENTS.md`。界面规格见 DESIGN.md §5.4。

## 文字选区菜单

- 必须：文字选区菜单（长按选字 / 桌面右键的复制、粘贴菜单）只经 `lib/ui/widgets/text_selection_menu/`：输入框（`TextField` / `TextFormField` / `SelectableText` / `SearchBar`）一律传 `contextMenuBuilder: appTextContextMenuBuilder`，日记正文经 `AppTextSelectionMenu.adaptive`（`DiaryEditorSelectionToolbar` / `diaryEditorContextMenuBuilder`）；禁止在该目录之外使用 `AdaptiveTextSelectionToolbar` / `DesktopTextSelectionToolbar` / `CupertinoTextSelectionToolbar` / `TextSelectionToolbar`（`test/ui/widgets/text_selection_menu_source_test.dart` 兜底）。菜单项只经 `AppTextMenuAction`（内置类型经 `appTextMenuActionsFromButtonItems` 统一文字、图标与快捷键）；分享只在 `AppPlatform.supportsTextShare`（手机），其他应用的文字操作只经 `TextProcessActionsService`（`AppPlatform.supportsProcessText`，Android；正文可编辑时把返回的文字以纯文本替换选区、一步撤销，只读时只交出不回写）。视觉规范见 DESIGN.md §5.4。

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
