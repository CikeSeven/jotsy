# 日记本（Notebooks）功能交接

分支：`feat/notebooks`（基于 main `4f70c02`，已在 `d3e736f` 合入 main `07d260e`）。代码与文档同步都已完成，只剩下文“后续可选项”。
合入 main 时解决了导入解析器的冲突：来源日记本 / 文件夹仍经 `JournalImportEntry.notebooks` 报告；main 新增的纯文本笔记同样记作日记本；落地时被截断的名称存进 `import.originalNotebooks`。
最后一次本地验证（`d3e736f`）：
- `dart format --set-exit-if-changed`、`flutter analyze`、`dart run tool/check_arb.dart` 全部通过；
- 重跑 `flutter gen-l10n` 和 build_runner 后工作区无变化；
- 全量 `flutter test` 2743 通过、1 跳过。

## 已确认的产品决定
- **归属**：一篇日记可以同时收进多本（相册模型）。移出日记本不会删除日记。在某一本里多选时，可以“移动到…”另一本。
- **入口**：在首页原地切换。标签栏第一项是日记本胶囊，点开是书架面板；选中某本后，首页变成这本，顶部出现头部卡片。返回键回到全部日记。当前所在的本子不跨重启记忆。
- **层级**：日记本里可以分章节，只有一层，并支持手动排列的“书序”。
- **本轮全部做完**：智能日记本、隐藏与上锁、统计与写作目标、导出成书、导入时保留来源的日记本或文件夹（导入方式面板里可选：日记本 / 标签 / 两者）。

## 提交一览（按顺序）
| 提交 | 内容 |
|---|---|
| d092997 | 数据层：schema v13 新增 `notebooks` 与 `diary_notebooks` 两张表，`NotebookPayload`，增删改、成员、章节与书序等操作 |
| a7faebc | 查询范围 `DiaryListScope`，以及私密日记的统一 SQL 排除条件（所有全局查询都已接入） |
| 6f3babe, 66217f8 | 备份、合并、日记包、封面媒体接入，以及导入结果和警告里的文案 |
| 6d4b8c5 | 编辑页、书架面板、管理页（设置 → 日记本） |
| ea55bfa, 0b6b02e | 导入保留来源的日记本或文件夹，以及导入方式面板里的“原来的日记本 / 文件夹”分组 |
| c302cb0 | 首页原地切换、头部卡片、`DeviceAuthService`、上锁本子的重锁遮罩 |
| 68f83a8 | 多处收录入口：选本面板、多选栏、发布面板、在本子里写、添加已有日记、预览页胶囊；上锁本子的敏感操作改为需验证身份 |
| 9fc32d2 | 智能日记本（规则与编译器）、章节、目录页、书序分隔 |
| 7d83ce8 | 日历按日记本筛选 |
| 232af33 | 统计页与写作目标 |
| 450a53a | 导出成书，头部卡片 ⋮ 菜单里的“导出成书” |
| d3e736f | 合入 main（云笔记跳过报告、保留第三方正文与媒体），解决导入解析器冲突 |
| docs 提交 | AGENTS.md 日记本规则、DESIGN.md §5.16、中英文 README |

## 文档与规范同步（已完成，以下为当时的清单）
只改 `AGENTS.md`、`DESIGN.md`、README，不动 `docs/` 官网和 release notes。写之前先读代码，按实际实现写，提到的每个标识符都要先 grep 确认存在。

1. **`AGENTS.md`**
   - §2 目录树：
     - 加上 `lib/ui/notebooks/`，职责包括：书架 / 编辑 / 管理、首页范围与头部卡片、选本面板、目录与章节、智能规则编辑、统计与目标、上锁流程、导出成书入口；
     - `lib/ui/home/providers/`；
     - `core/database` 那一行补上 notebook ops、scope SQL 和 rules。
   - §3：数据库拆分清单加上 notebook ops。
   - §6：新增一条权威规则“日记本”，写法和草稿箱、模板那两条一样密。要覆盖：
     - **存储**：v13，`notebookId`，`kind` 和 `visibility` 是独立列，其余放 payload；关联表用本地 id，带章节和位置；库里没有启用外键，所以每条删除路径都要手动清关联行。
     - **多对多**。
     - **手动与智能**：规则只经 `NotebookRuleSet` 和 `compileNotebookRules`；规则里存标签名，不存本地 id；空规则或认不出的规则一律不匹配；未解封的胶囊只按标题、日期和置顶参与匹配。
     - **私密**：只有手动本能私密；私密日记由统一谓词从所有全局查询里排除；新加的全局查询必须用这个谓词，并在 `readsFrom` 里加上日记本两张表；回收站和按 id 直接打开不过滤；认不出的可见性按 locked 处理。
     - **上锁**：`DeviceAuthService`、`authorizeNotebookEntry`、`NotebookLockLayer`；编辑、合并、删除、转换这几种会让内容露出来的操作必须先验证。
     - **首页范围**：`homeNotebookScopeProvider`，不持久化。
     - **收录**：只经选本面板、发布面板和 `NotebookMembershipOps`，都可撤销。
     - **在本子里写**：`runDiaryCreateEntryFlow(notebookId:, chapterId:)`，并套用这本的默认模板。
     - **章节与书序**：`reorderNotebookEntries`、目录页。
     - **备份与合并**：按 `notebookId` 匹配；合并并覆盖时替换本子定义；只写这次写入的日记的成员关系；日记包带上被引用的手动本；封面算作媒体引用。
     - **导入**：folder mode 三种方式；按确定性 id 或同名手动本复用，复用时原样拷贝本机那一行。
     - **导出成书**：`DiaryExportBook`。
     - **统计**：字数经 `TextStats`；不做提醒。
     - **日历筛选**：只支持手动本。
     - 最后指向 DESIGN.md §5.16。
   - §6 里已有的几条规则也要更新：
     - 导出规则：加上“书籍结构”开关。默认开、不保存，CSV 和日记文件不显示；书序优先于面板里的先后选项。各格式结构：PDF 有扉页、带真实页码和跳转的目录、书签、每章分页；Word 有带链接的目录，没有页码；HTML 用 nav 和锚点；Markdown 合成单个文件，不带每篇的头信息；纯文本有扉页、目录和带横线的章标题。
     - 日历规则：加上日记本筛选组。
     - 导入规则：加上 folder mode。
     - 备份规则：如果规则里列了备份包含哪些表，加上日记本两张表。
2. **`DESIGN.md`**：新增 `### 5.16 日记本`，按实际实现写：
   - 切换胶囊、书架面板与封面格；
   - 头部卡片：操作行、目标行、章节胶囊（横向贴边滚动）、左右边距与日记卡片一致；
   - 选本面板（三态）、多选栏、发布面板的日记本行；
   - 编辑页各分组、规则编辑区、管理页；
   - 目录页（“未分章”拖放区）、统计页；
   - 重锁遮罩、导出成书的版式、日历筛选组。

   同时更新 §5.10（书籍结构）、§5.7（日历筛选里的日记本组），以及 §5.4 列出 ExpressiveMenu 使用处的地方。
3. **README**：在功能列表里加一条“日记本”，语气和长度与其他条目一致。如果有英文版 README，也一起加。
4. 提交：`docs: notebooks rules, design spec and README`。

## 后续可选项（还没做）
- **装机实测**：以下内容还没在真机上看过，测试和截图都是在组件测试里跑的：
  - 首页切换、上锁本子切到后台后重锁；
  - 导出成书的 PDF 和 Word 实际排版；
  - 发布面板高度没改（470dp），多了日记本一行后，下面几行需要往下滚才能看到。
- **官网与版本说明**（`docs/index.html`、`docs/releases/`）：发版时再写。
- **开 PR**：文档已同步，可以开；合并前删除本交接文档。

## 代码导航（入口）
- 数据层：
  - `lib/core/database/app_database_notebook_{schema,ops,entry_ops,stats_ops}.dart`
  - `notebook_payload.dart`
  - `notebook_rules.dart`（规则模型与 SQL 编译）
  - `diary_list_scope.dart`、`app_database_diary_scope_sql.dart`（范围与私密谓词）
- 备份与导入：
  - `lib/core/services/backup_notebook_merge.dart`、`backup_payload.dart`
  - `journal_import_notebooks.dart`
- 界面：
  - `lib/ui/notebooks/**`（providers、controllers、pages、sections、widgets、viewmodels）
  - 首页编排：`lib/ui/diaries/controllers/diaries_notebook_scope_controller.dart`、`diaries_notebook_membership_controller.dart`
  - 导出：`lib/ui/diaries/export/diary_export_book.dart`、`lib/ui/notebooks/controllers/notebook_book_export_flow.dart`
- 测试：
  - `test/ui/notebooks/**`
  - `test/core/database/notebook_*_test.dart`、`diary_list_scope_test.dart`
  - `test/core/services/backup_notebook_test.dart`、`journal_import_payload_test.dart`
  - 写首页相关测试时，`DiariesPage` 的测试要为页面监听的每个新 provider 单独 stub。
