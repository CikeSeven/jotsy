# 草稿箱与发布页

> 从 `AGENTS.md` 拆出的专题约束，与 `AGENTS.md` 同等效力（必须 / 禁止 / 例外）。改动本主题的代码前先读本文件；本主题新增或修改的规则写在这里，不写回 `AGENTS.md`。界面规格见 DESIGN.md §5.14。

- 必须：新建日记的草稿只存 Drift `diary_drafts` 表（业务 id `draftId`；`payload` 为 `NewDiaryDraft.toJson`，`title` / `contentText` 为列表镜像），每次新建都是独立的一份，经 `DebouncedAutoSaveController` 自动保存；返回、切后台与页面销毁时必须 flush，发布成功后先 `close` 自动保存再删除这一份。禁止重新引入单键草稿（旧键 `app.settings.diary_create_draft` 只作 `migrateLegacyCreateDraft` 的启动迁移来源），禁止“新建空白”删除已有草稿。所有新建入口（首页 FAB 与空列表、日历、探索）统一经 `runDiaryCreateEntryFlow`（有草稿时弹 `showDiaryDraftPickerSheet`，其中“从模板新建”再弹 `showDiaryTemplatePickerSheet`），禁止另写新建弹窗或绕过它直接打开新建编辑页；管理页为 `DiaryDraftsPage`（首页顶栏与设置 → 数据与隐私），删除与撤销经 `DiaryDraftsController`，媒体回收必须等撤销窗口结束、确定不撤销后才执行。草稿随完整备份导出与覆盖恢复（旧备份设置里的单份草稿在解析时转成草稿行），合并导入与日记包不带草稿；媒体清理把草稿 `payload` 当作引用来源。视觉规范见 DESIGN.md §5.14。
- 必须：新建日记只经发布页 `PublishDiaryPage` 发表：进入即写库（`PublishDiaryController.submit`，成功即经 `onPublished` 删除草稿，顶栏标题经 `PublishStatusTitle` 换成“✓ 日记已发表”并轻震，不弹提示条），之后面板改动（含发表时间与时间胶囊，胶囊两列只经 `updateDiary(capsule:)` 改写）像编辑页一样经 `DebouncedAutoSaveController` 防抖保存，切后台与页面销毁时 flush；写库前后不可返回，写库失败提示后退回编辑页（草稿原样保留）；返回时先补存（失败则留在本页），未解封的胶囊再播放封存卡片，然后经 `onLeave` 把编辑页移出路由栈、以新日记 id 回到打开者。禁止恢复发表按钮或带草稿返回编辑页。
