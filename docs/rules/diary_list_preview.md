# 日记列表、打开与预览

> 专题约束，与 AGENTS.md 同等效力；改动本主题前先读本文件，新规则写在这里。界面规格见 DESIGN.md §5.2 / §5.8 / §5.17 / §5.24 / §5.33。

## 打开日记
- 必须：“打开日记时直接编辑”（默认关）开启时跳过预览页；导图日记一律直接进编辑页（见 `mind_maps.md`）。
- 禁止：未解封的时间胶囊与查不到的日记绕过预览页（封存页）；宽窗口右栏选中不算打开。
- 必须：从搜索结果打开时带上搜索词，打开查找栏并跳到第一处、不弹键盘（见 `editor.md`）。
- 必须：可点开的日记卡片包 `ContainerTransformSource`，经 `openDiaryPage(origin:)` 从卡片展开；卡片画面从页面层截取，容器接管后经 `ContainerTransformSourceVisibility` 暂停原卡片绘制（保留布局），拍下层快照前必须先隐藏原卡片（展开 / 收回露出原位置时不再留着原卡片），停稳、归位或提前移除路由时当帧恢复。
- 禁止：转场容器透出列表、给原卡片套 `Opacity`，或换回 SDK `SnapshotWidget`（玻璃卡片会变透明）。
- 必须：等待路由入场结束只经 `RouteEntranceWaiter`，禁止直接读路由 `animation`。

## 预览页
- 必须：左右翻页只经 `DiaryPreviewPage(sequence:)`，顺序取进入时的列表并冻结，单篇入口不传。
- 禁止：另写翻页手势识别器，或在预览页内放横向滚动容器（会抢走翻页）。
- 必须：删除结果带被删日记 id，入口按它撤销；勾选待办只经 `updateDiaryContent`（`updateDiary` 会移出归档）。
- 必须：双击正文进编辑只在手机上、阅读行为开启（默认开）时生效，禁止改成双击识别器（单击会等超时）。
- 必须：预览页与编辑页的“更多”条目只经 `diaryMoreMenuItems` 分组，禁止改回底部面板或另拼一份。

## 阅读式编辑页与保存
- 必须：编辑已有日记一律是阅读式版式，只经预览页样式与共用部件绘制；新建日记保持表单式。
- 必须：点标签 / 日记本胶囊、分享、导出、AI 回应与删除前先补存，失败留在本页。
- 必须：被盖住时立即补存；回到最上层时读库比对，已删除则退出、别处改过则换成库里内容。
- 禁止：回到前台时把内存副本直接写回；删除只经 `softDeleteDiary(touchUpdatedAt: false)`。
- 必须：写库方式只看 `DiaryEditPrefs`（单个 JSON 键，随备份导出、失败回滚），默认自动保存。
- 必须：手动保存只经“保存”、Ctrl / ⌘ + S 与 `showUnsavedChangesDialog` 的“保存并退出”写库，其余时机一律不写。

## 搜索
- 必须：搜索会话只在 `DiarySearchController`，页内条件不回写首页筛选。
- 必须：关键词只经 `splitSearchTerms`（最多 8 个、LIKE 转义），查询、留言命中与高亮共用，禁止另写。
- 必须：筛选只经 `DiarySearchFilters`（每项一条智能日记本规则），它与“含归档”都传到结果数与翻页。
- 必须：未解封胶囊只按标题匹配、不标命中；隐藏日记本可搜到、上锁的排除（见 `notebooks.md`）。
- 必须：“存为智能日记本”只经 `runSaveSearchAsSmartNotebook`，范围与“含归档”不进规则。
- 必须：最近搜索（只记关键词）与排序只存本机键 `app.search.preferences`，不随备份、不同步。
- 必须：`openDiaryTagSearch` 从日记本统计页进入时带这本的范围，其余为全局搜索。
- 必须：胶囊形搜索框（搜索页、标签子页）统一经 `SearchPillField`。

## 首页列表与标签
- 必须：布局存 `app.settings.diary_layout_mode`（随备份导出），未选过或认不出时为瀑布流。
- 必须：只有列表布局可左滑归档，瀑布流不挂侧滑（易与切 Tab 混淆误归档，#311）。
- 必须：标签筛选单击只选这一个、再点取消，长按（桌面 Ctrl / ⌘ 点击）进多选；禁止让单击恢复成增减（#196）。
- 必须：列表整体切换只经 `DiaryListSwitchMotion`，禁止给列表套整块淡入淡出。
- 必须：列表就在眼前换数据（增删、换位、改高）的动效只经 `DiariesListSection(animateChanges:)`（首页与归档页开启），宿主刻意直接拿掉的日记经 `hiddenDiaryIds` 传入；禁止让瀑布流卡片逐帧改高（会换列乱跳）。
- 必须：切换标签后只经 `jumpDiaryListToStart` 回到列表开头，禁止跳到最顶（刊头会弹出）。
- 必须：标签子页排序只存 `app.settings.tag_picker_sort`（随备份导出），检索词只在内存里。
- 必须：拼音归组、排序与检索只经 `NameIndexKey`；拼音表由脚本生成、禁止手改，禁止引入整本字典的库。
- 必须：批量改标签只经 `applyDiaryTagBatch`（单事务、不动更新时间），撤销只经 `restoreDiaryTagBatch`。

## 快速滚动条
- 必须：只经 `DiariesFastScroller`，按“第几篇”换算，总篇数只经同口径、不带正文的 `watchDiaryTimeline`。
- 禁止：跳往未加载部分时逐页追加，或远距离直接 `jumpTo`（须逐帧限步）。
- 必须：替换 `pagedDiariesProvider` 且会滚动长列表的测试，同时替换 `diaryTimelineProvider`。

## 功能提示
- 必须：一次性提示进度只存本机键 `app.settings.feature_tips`（不随备份、不同步），新提示登记为 `FeatureTip`。
- 禁止：把缓存的整份进度写回；只经 `SettingsService.updateFeatureTips` 改自己那条。
- 必须：标签“下拉展开”提示只在入场编排后、不在多选且一行放不下时出现，每次冷启动最多一次。
- 必须：下拉提示累计 3 次或展开过一次后不再出现；多选提示每次启动最多一次，长按过即不再出现。
