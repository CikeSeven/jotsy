# 背景与材质（玻璃）

> 专题约束，与 AGENTS.md 同等效力；改动本主题前先读本文件，新规则写在这里。界面规格见 DESIGN.md §5.23。

## 设置与数据

- 必须：背景与材质只存 `AppSurfaceSettings`（单个 JSON 键 `app.settings.app_surface`），随完整备份导出、只在备份含该字段时恢复，导入失败回滚。
- 必须：背景图只经 `AppBackgroundStorageService` 拷进 `app_backgrounds/`，设置只存文件名；该目录只登记在 `backupSettingsMediaDirectories`，禁止加进日记媒体目录（会被媒体回收误删）。
- 必须：区域背景的生效值与可选来源只经 `AppSurfaceSettings` 解析（成环时退回自己的值），禁止页面自行沿来源链取值。

## 页面背景

- 必须：首页 Tab 经 `AppPagedBackground` 画背景；直接落在背景图上的文字经 `AppPageBackdrop.onBackgroundTextStyle`。
- 必须：影响布局的判断只看 `wantsBackground`，禁止用 `hasBackground`（解码完成才变，内容会跳）。
- 必须：首页 Tab 顶栏下的间距与状态栏垫色只经 `HomeTopBarSurface.contentGapOf` / `HomeStatusBarFill`，禁止各 Tab 自行处理。
- 必须：样式编辑页的预览经 `StyleEditorScaffold(previewArea:)` 画所模拟区域的背景，禁止另画。
- 必须：预览页按基调染色遮罩时，背景不画遮罩、由每篇页面画，禁止叠两层。

## 玻璃

- 必须：玻璃只经 `AppGlassSurface`，卡片与分组经 `AppCardSurface`，FAB 经 `AppGlassFab`，输入填充经 `AppGlassField` / `OnGlass`，底层都是 `GlassSurface`。
- 例外：日记卡片的玻璃只经 `DiarySelectionSurface`；对话框的整页磨砂只在 `app_dialog.dart`。
- 必须：主题自带底色的 Chip、输入框、开关轨道只经 `AppGlassControlsTheme` 换底；自定底色的小控件经 `AppGlassField.of` 取未选中态底色。
- 必须：模糊策略只经 `AppGlassBlur`（各组件口径见 DESIGN.md §5.23）。
- 必须：提示条玻璃只经 `AppGlassSnackBarTheme`，禁止在 `showTrackedSnackBar` 或调用处另拼。
- 必须：内容玻璃的静态取样只经 `GlassBackdropSample`，只在背景单一且已落定时启用，其余用实时模糊。
- 必须：相邻多片玻璃共用同一 `BackdropGroup`；自上而下渐隐的玻璃例外。
- 必须：越界效果只经 `AppScrollBehavior`，禁止各处恢复 SDK 拉伸或改 physics 来规避玻璃丢模糊。
