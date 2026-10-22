# 编辑器迁移到 AppFlowy Editor：交接文档

更新时间：2026-10-22。状态：**第 2 阶段已完成，继续推进全部阶段；未装机**。

## 1. 目标与已定决策

- **目标**：日记正文编辑器从 flutter_quill 换成 AppFlowy Editor，以获得四项能力：
  - Markdown 快捷输入（手机软键盘可触发）
  - `/` 命令菜单
  - 拖动段落
  - 嵌套块
- **用户决定**：用 AppFlowy Editor，不考虑复杂度。
- **历史**：2026-03-09 项目曾从 appflowy_editor 6.2.0 换到 Quill（c85a2ad）。之前两次提交在调“编辑页滚动”（69d9e9b）和“图片选中”（1c621ca）。用户已不记得当时换掉的原因，表示不用管。原型阶段仍应重点验证滚动、光标跟随与图片选中。
- **依赖**：`appflowy_editor` 用 git 依赖，固定到 main 的 `01eccc6ee36bd07698bd80915289fe7070478cd2`（2026-08-06）。
  - 原因：pub 上的 6.2.0 在 Flutter ≥ 3.44 编译失败（`TextInputClient.onFocusReceived`，上游 issue #1204），修复只在 main 上。
  - 项目 Flutter 为 3.47.5，已验证能编译并跑通 widget 测试。
  - 许可证 MPL-2.0 / AGPL-3.0 双许可，与本项目 GPL-3.0 兼容。
- **存储格式（已定）**：正文改存 AppFlowy 的 `Document.toJson()`，形如 `{"document":{"type":"page","children":[…]}}`。
  - 旧的 Quill Delta 与更早的旧版节点文档，读取时统一转换。
  - 不做一次性数据库迁移，按需转换：读任何格式都能打开，写一律写块文档。

## 2. 工作树

- 路径：`.claude/worktrees/appflowy-editor`
- 分支：`worktree-appflowy-editor`，基于 `origin/main` dd33df7
- 已执行过 `flutter pub get`

## 3. 已完成（全部未提交）

| 文件 | 内容 |
|---|---|
| `pubspec.yaml` / `pubspec.lock` | 加 appflowy_editor git 依赖（带注释说明为何固定提交） |
| `macos/Flutter/GeneratedPluginRegistrant.swift` | pub get 自动生成的插件注册变更 |
| `lib/core/database/diary_blocks/diary_blocks_schema.dart` | 块类型、data 键、行内属性键常量；Quill ↔ 块文档行内键映射表 |
| `lib/core/database/diary_blocks/diary_blocks_from_delta.dart` | `diaryBlocksFromQuillOps`：Quill Delta → 块文档 |
| `lib/core/database/diary_blocks/diary_blocks_to_delta.dart` | `diaryBlocksToQuillOps`：块文档 → 平铺 Delta 投影（嵌套写成 `indent`） |
| `lib/core/database/diary_blocks/diary_blocks_walk.dart` | 容错读取节点字段、先序遍历（带深度） |
| `lib/core/database/diary_blocks/diary_blocks_codec.dart` | 正文存储内容与块文档互转、纯文本、可见内容 / 嵌入判断 |
| `lib/core/database/audio_embed_codec.dart` | `DiaryAudioAttachment.tryDecode` 改为同时接受 JSON 字符串和 Map（块文档的 `data`）。**刚改完，还没跑测试** |
| `test/core/database/diary_blocks/diary_blocks_conversion_test.dart` | 13 个测试，**全部通过** |
| `test/spike/appflowy_compile_test.dart` | 编译验证用的临时测试，**合并前删除** |

`diaryBlocksFromQuillOps` 的转换规则：

- 行级属性的对应：
  - `header` → `heading`（level）
  - `list` → `bulleted_list` / `numbered_list` / `todo_list`（checked / unchecked 写进 `checked`）
  - `blockquote` → `quote`
  - 其他行 → `paragraph`
  - `align` 原样保留
- 连续且语言相同的 `code-block` 行合并为一个 `code` 块。语言写在 `data.language`；值为 `true` 时不写，表示自动识别。
- `indent` 换算成子块：
  - 不跳级；
  - 只挂到能收子块的类型下（paragraph、三种列表、quote），标题、代码块和媒体不收子块。
- 嵌入各自成块：
  - `image`：data 为 url，另可带 width / height / style / align
  - `video`：data 为 url
  - `audio`：data 为 path / durationMs / name / waveform
  - `attachment`：保留来源的全部字段；旧版 `file` 也转成它
  - `divider`
  - 认不出的嵌入存成 `quill_embed`，原值放在 `data.value`
- 文字中间夹嵌入的行，拆成前、后两个块。
- 输出的键序与编辑器 `Node.toJson` 一致（type、children、data）。

测试已覆盖：

- 往返逐 op 一致：行内格式、标题与对齐、嵌套列表、多语言代码块、各类媒体
- 规整：嵌入拆行、缩进不跳级
- 四代存储格式都能解码
- 纯文本镜像与 Quill `toPlainText` 一致
- AppFlowy `Document.fromJson` 读入后 `toJson()` 逐字相同

## 4. 第 2 阶段已完成：存储切换

- `content_codec.dart` 统一经块文档解码、投影到 Quill；保存一律输出块文档。纯文本入口改为 `diaryContentToPlainText`。
- `diary_blocks_media.dart` 统一媒体扫描、图片顺序与路径重绑，卡片、预览、探索、备份均已接入。录音 / 文件路径提取已移入该文件。
- 备份恢复先解码再重绑块数据，保留附件额外 metadata、录音波形与缺失 / 远程媒体引用；覆盖和合并均经原有暂存机制。
- 导入写出器末尾输出块文档；智能日记本音频 SQL 同时识别块节点与旧 Delta。
- 旧节点媒体转换保留 metadata，增加录音支持与坏字段容错；代码行夹媒体的边界已补回归，避免丢内容。
- 单个嵌入的字段映射拆到 `diary_blocks_embed.dart`，行拆分 / 缩进转换仍在 `diary_blocks_from_delta.dart`。
- 删除临时编译 spike；更新 ARB 以外的相关测试与 AGENTS.md 的存储规则。
- 验证：全量 `flutter test` 3,521 项通过、2 项跳过（手动性能微基准）；随后代码行媒体修正的块文档 22 项测试通过。最终全量检查将在所有迁移完成后重跑。
- 模板仍保持既有 Delta 白名单，旧数据库 schema 迁移未改，分别在后续阶段处理。

用户已明确本次范围：**继续全部阶段，直到彻底替换 Quill**。下一步是第 3 阶段。

## 5. 后续阶段

1. **第 3 阶段：编辑器核心**
   - 新建基于 AppFlowy 的编辑器组件，相当于现在的 `DiaryQuillStylesBuilder`：
     - `EditorStyle` 由 `DiaryTextAppearance` 生成；
     - 各类块的组件：段落、标题、列表、待办、引用、分隔线、图片（长图折叠、`boundedImageProvider`、点按菜单）、视频、录音、附件、代码块（高亮、标题栏、回车规则）。
   - 替换编辑页 `edit_diary_page.dart`（1375 行）。
   - 标题、模板建议条、“这天的照片”放进编辑器的 `header`，由 AppFlowy 管滚动，替代 `DiaryCaretFollowController`。
2. **第 4 阶段：只读渲染**
   - 用 `editable: false` 替换预览页、发布预览、模板编辑页、设置页里的各个预览。
   - 预览页勾选待办：仍只经 `updateDiaryContent` 写库。
3. **第 5 阶段：新功能与工具栏**
   - Markdown 快捷输入：AppFlowy 自带，代码围栏、分隔线等需补充。
   - `/` 菜单：用 AppFlowy 的 selection menu，样式改成 Expressive。
   - 手机端拖动：AppFlowy 只提供桌面的拖放落点，需用 `blockWrapper` 自己做长按把手。
   - 缩进 / 取消缩进（嵌套）。
   - 颜色面板写 `font_color` / `bg_color`，值为大写 `#AARRGGBB`；AppFlowy 的 `tryToColor` 支持 `#` 开头。
   - 代码块面板、链接、插入当前时间、录音、媒体导入。
4. **第 6 阶段：其他模块直接读块文档**
   - 导出块解析支持嵌套深度；分享、探索。
   - 模板正文改为块文档，模板码升级到 v2 并兼容 v1。
   - 导入写出器直接写块文档。
5. **第 7 阶段：移除 Quill**
   - PDF 导出现在依赖 `flutter_quill_to_pdf`：要么保留“投影成 Delta 再生成 PDF”，要么改写为自己的 PDF 写出器。
   - 更新 AGENTS.md：目录树与大量 Quill 相关规则，例如代码块、颜色面板、光标跟随、`DiaryQuillStylesBuilder`。
   - 更新 DESIGN.md 与源码检查类测试。

规模参考：lib 里有 53 个文件直接 import flutter_quill（约 1.17 万行），约 51 个文件读写 Delta，61 个测试文件 import flutter_quill。

## 6. 风险与注意

- **降级读不了新格式（最重要）**
  - 装了本分支的包之后，再装任何基于当前 main 的包，旧的解码器会把块文档当成“旧版节点文档”，读出空正文。用户若再编辑保存，内容会被覆盖。
  - 本分支的包装机前必须先告诉用户。可选的缓解办法：先往 main 合一个小 PR，让现有解码器认识块文档（只读兼容）。
- **AppFlowy 自身的问题**
  - pub 已 10 个月没发版，会跟着 AppFlowy 主应用的 Flutter 版本走，以后升级 Flutter 可能再坏。
  - 有未关闭的输入法问题（韩文、个别输入法字符顺序错乱）。中文输入法（搜狗、Gboard、小米）要在真机上测。
- **AGENTS.md 规范仍然适用**：
  - 提交署名只用 `CikeSeven <llyllydyx@163.com>`，提交说明和 PR 不加任何 Claude 署名；
  - 改完代码跑 `dart format` 和 `flutter analyze`；
  - 用 Conventional Commit。

## 7. 参考位置

- AppFlowy 源码：`~/.pub-cache/git/appflowy-editor-01eccc6ee36bd07698bd80915289fe7070478cd2/`
  - 编辑器入口：`lib/src/editor/editor_component/service/editor.dart`
  - 行内键：`lib/src/editor/block_component/rich_text/appflowy_rich_text_keys.dart`
  - 输入法与快捷输入：`lib/src/editor/editor_component/service/ime/`、`lib/src/editor/editor_component/service/shortcuts/character/`
  - 拖动示例：`example/lib/pages/drag_to_reorder_editor.dart`
- 本项目：
  - 现有正文编解码：`lib/core/database/content_codec.dart`、`legacy_content_codec.dart`
  - 导出块模型：`lib/ui/diaries/export/diary_export_blocks.dart`
