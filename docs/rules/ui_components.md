# 文字选区菜单

> 从 `AGENTS.md` 拆出的专题约束，与 `AGENTS.md` 同等效力（必须 / 禁止 / 例外）。改动本主题的代码前先读本文件；本主题新增或修改的规则写在这里，不写回 `AGENTS.md`。界面规格见 DESIGN.md §5.4。

- 必须：文字选区菜单（长按选字 / 桌面右键的复制、粘贴菜单）只经 `lib/ui/widgets/text_selection_menu/`：输入框（`TextField` / `TextFormField` / `SelectableText` / `SearchBar`）一律传 `contextMenuBuilder: appTextContextMenuBuilder`，日记正文经 `AppTextSelectionMenu.adaptive`（`DiaryEditorSelectionToolbar` / `diaryEditorContextMenuBuilder`）；禁止在该目录之外使用 `AdaptiveTextSelectionToolbar` / `DesktopTextSelectionToolbar` / `CupertinoTextSelectionToolbar` / `TextSelectionToolbar`（`test/ui/widgets/text_selection_menu_source_test.dart` 兜底）。菜单项只经 `AppTextMenuAction`（内置类型经 `appTextMenuActionsFromButtonItems` 统一文字、图标与快捷键）；分享只在 `AppPlatform.supportsTextShare`（手机），其他应用的文字操作只经 `TextProcessActionsService`（`AppPlatform.supportsProcessText`，Android；正文可编辑时把返回的文字以纯文本替换选区、一步撤销，只读时只交出不回写）。视觉规范见 DESIGN.md §5.4。
