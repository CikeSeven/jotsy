# 编辑器与正文

> 专题约束，与 AGENTS.md 同等效力；改动本主题前先读本文件，新规则写在这里。界面规格见 DESIGN.md §3.2 / §5.5 / §5.6 / §5.20。

## 块文档
- 必须：块类型与键只在 `diary_blocks_schema.dart` 定义；媒体扫描与路径重绑复用 `diary_blocks_media.dart`；会话与事务经 `DiaryEditorController`。
- 禁止：重新引入 Quill 编辑器、扩展或 PDF 插件；历史 Delta 只保留纯数据兼容。
- 必须：只有段落、列表、待办、折叠块能挂子块（`diary_blocks_hidden_children_test.dart` 兜底），换成其他类型时子块提到它后面。
- 必须：提示块是文字块，日记链接卡片与思维导图是嵌入块，都不挂子块；折叠块只在 `data.collapsed == true` 时收起。
- 必须：表格校验与整理只经 `diary_blocks_table.dart`（上限 12 列 / 200 行），无效表格按行展开为段落、不丢内容。
- 必须：模板正文同为块文档，模板码 v2 兼容读取 v1。

## 排版与字体
- 必须：正文排版只存 `DiaryTypography`（单个 JSON 设置键，随备份导出）；禁止页面自建 `EditorStyle` 或另设正文字号 / 行距。
- 必须：字体作用范围只经“用于整个界面”（默认关）与主题扩展 `AppFonts`；日记卡片只从 `AppFonts` 取正文字体。
- 必须：导入字体文件不进备份，备份只带字体 id，缺失时回落内置字体。
- 必须：首行缩进用等长占位实现，宽度只取 `firstLineIndentExtent`（Word 导出同口径）；禁止在文档里插空格缩进。
- 必须：段落 `data.firstLineIndent` 三态（true 两字与全局取大 / false 不缩进 / 无键跟随全局），只经 `diaryParagraphIndentFor` 取值。
- 必须：正文段落的缩进按钮只写该标记、按下后画面不变时停用（#253）；禁止改回嵌套缩进。

## 工具栏与格式
- 必须：工具栏面板只在工具栏卡片内展开、选区离开对应的块即收起，手机 `/` 菜单内联在光标旁；禁止另开路由、对话框或底部面板，以免抢走焦点、收起键盘。
- 必须：“始终显示工具栏”（默认关）与“工具栏大小”各存一个设置键，都是本机偏好、不随备份；标准大小必须与改版前逐像素一致。
- 必须：格式写入只作用于选区里的文字块、跳过代码块，每次一步撤销；对齐写 `data.align`，字号与上下标写行内 `size` / `script`，默认值删键。
- 必须：上下标逐字占位、所在行不变高；占位里的高亮只由 `DiaryGlyphLineBox` 画一次，以免叠深。
- 必须：折叠块编辑态点按写入收起状态，只读只改本地显示；选区落进收起内容时自动展开，不进撤销栈。
- 必须：表格等宽列、禁止横向滚动（会抢走预览翻页），编辑器里最多 6 列；格内段落不换类型、不缩进。
- 必须：列表样式只存列表块 `data.listStyle`，按一段相邻同类型列表整段生效；序号与形状只经 `diary_list_style.dart` 生成，新字形必须在内置字体里。

## 颜色
- 必须：正文文字色 / 背景色只经颜色面板写入，值为大写 `#AARRGGBB`；色谱拖动只改预览，松手写入。
- 必须：“我的颜色”只存 `DiarySavedColors`（单个 JSON 设置键，文字 / 背景各最多 24 个，随备份导出）；自定义页写入后自动保存，预设与套用不保存。
- 禁止：另加零散颜色设置键；面板高度随保存的颜色数变化。
- 必须：颜色代码输入框用普通文字键盘，有焦点时工具栏保持挂载、不以键盘高度为显示条件。

## 粘贴与链接
- 必须：纯文字与 HTML 的取舍只经 `DiaryEditorClipboard.pasteText`：像 Markdown 才转为块，HTML 只包着原文时按 Markdown。
- 必须：输入法一次上屏的多行文字与菜单粘贴同一路径，每行一段；代码块、表格格子与 Ctrl / ⌘ + Shift + V 一律粘原文。
- 必须：链接输入会话只在上游写入后补 `href`、遇空白结束；禁止为它拦截输入（组字会重复）。

## 视口与键盘
- 禁止：新增包住编辑正文的第二套页面滚动（标题与正文共用原生虚拟滚动）。
- 必须：悬浮层避让只经 `DiaryEditorViewport`，新增底部浮层必须计入正文末尾留白；用户滚开的选区与单纯调色不拉回（#221）。
- 必须：叠在正文顶部的浮岛顶栏只经 `FloatingTopBarCover` 计入看得见的范围（`diaryEditorVisibleRange` 与 `DiaryEditorViewport` 同源），禁止各处另算顶部遮挡。
- 必须：拉起键盘时切到别的应用再回来，键盘回来后正文停回离开前的滚动位置（`DiaryEditorResumeScroll`，经 `DiaryEditorViewport`）；回来后改了光标、打字或拖动正文就不放回。
- 必须：收起键盘后点回原处重弹键盘只经 `DiaryEditorKeyboardReopen`；禁止直接调用 `TextInput.show`。
- 例外：`RawKeyboard` 只允许在 `SoftKeyboardSelectionKeys`（绕开 flutter/flutter#185849，上游修复后删除）。

## 嵌入块
- 必须：嵌入块左 / 右侧可停插入点并照常弹键盘；禁止为插入点补空行，打字或回车时才在那一侧补段落。
- 必须：块里自己处理点按的内容必须包 `DiaryEmbedContent`，点它不弹键盘；新增嵌入块同样包上。
- 必须：越过嵌入块与表格的退格 / Delete 只经 `diary_embed_editing.dart`；禁止交回上游合并文字（块会被挤到后面）。

## 查找与替换
- 必须：正文查找与替换（#231）只经 `DiaryFindReplace`；逐块匹配、不跨块，只读正文能查不能换。
- 必须：一次替换、一次全部替换各一步撤销，不动正文选区。
- 禁止：改用上游 `SearchServiceV3`（全部替换会拆成多步撤销）；把高亮写进文档或借正文选区表示当前匹配。
- 必须：从搜索结果打开经 `openDiaryPage(findQuery:)`，正文里没有命中时不打开、不弹键盘。

## 段落选择模式
- 必须：选择只存 `DiaryBlockSelection`，规整为最上层块；模式里正文选区为空，别处设非空选区即退出。
- 必须：整组移动只经 `moveDiaryEditorBlocks`（保持原缩进层级），批量操作与移动各一步撤销；面板只在操作栏卡片内展开。
- 必须：返回键 / Esc 先退出模式；桌面鼠标在正文上按下即退出并交还上游（#293）。

## 代码块
- 必须：外观只存 `DiaryCodeBlockStyle`（单个 JSON 设置键，与默认相同时删键，随备份导出、失败回滚）。
- 必须：语言只存每个代码块的 `data.language`：缺省为自动识别，`plain` 为纯文本，其余为 22 种语言。
- 必须：高亮只经 `DiaryCodeHighlighter`，禁止导入整个 highlight 包；超过 20000 字或 600 行不高亮（`diary_code_block_source_test.dart` 兜底）。
- 必须：块尾连续第二个空行回车退出代码块，其余回车沿用缩进；导出高亮只经 `DiaryExportCodeTheme`。

## 内容配色例外
- 例外：代码块配色主题须有浅 / 深两套，经 `ensureContrast` 兜底（正文 ≥ 4.5:1，注释与行号 ≥ 3:1，`diary_code_theme_test.dart`）。
- 例外：提示块底色只取 `DiaryCalloutTone` 档位，每档须有明暗两套、正文对底色 ≥ 4.5:1（`diary_callout_tone_test.dart`）。
- 例外：「自定义」页色谱只在 `diary_color_spectrum_painters.dart` 绘制（`diary_card_style_source_test.dart` 兜底）。
