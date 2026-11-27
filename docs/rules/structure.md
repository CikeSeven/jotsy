# 项目目录详解

> 目录与关键入口索引，按需查阅；放置规则见 AGENTS.md §2–§3。

`lib/ui/<功能>/` 内按 AGENTS.md §3 分层（pages / controllers / models / sections / widgets 等），下文只写各目录放什么与关键入口。

## lib/app
- `lib/main.dart`：应用入口。
- `lib/app/`：App 装配 `node_diary_app.dart`（`NodeDiaryApp`）、启动引导、启动品牌图形 `launch_brand_mark.dart`、闪屏随主题色的分档 `launch_splash_theme.dart`（同步给原生：`launch_splash_theme_sync.dart`，原生端 `LaunchSplashThemeChannel.kt`）、同步后失效清单 `synced_data_refresh.dart`（`syncedDataRefreshProvider`）。
- `lib/app/theme/`：主题与 token：`theme.dart`（`MaterialTheme`）、`expressive_motion.dart`（`ExpressiveMotion`）、`app_breakpoints.dart`（`AppBreakpoints` / `AppContentWidth`）、种子色换算、字体、`derived_theme_cache.dart`。

## lib/core/database
- `database/`：Drift 数据库 `app_database.dart`，按职责拆成 `app_database_<职责>_*.dart`（清单见 AGENTS.md §3）；私密排除与范围 SQL 在 `app_database_diary_scope_sql.dart`，迁移在 `app_database_migrations.dart`。
- `database/diary_blocks/`：正文块文档格式：键与类型只在 `diary_blocks_schema.dart`，读取入口 `diary_blocks_codec.dart`（`decodeStoredDiaryBlocks`），媒体扫描与路径重绑 `diary_blocks_media.dart`，另有 Delta 互转、表格与列表样式。
- `database/mind_map/`：思维导图文档：模型与编解码、纯函数编辑、正文 `mind_map` 块、文字日记转导图。
- `database/rich_text/`：导图主题与留言共用的行内样式编解码。

## lib/core/services
平铺文件按前缀分组：
- 平台与目录：`app_platform.dart`（`AppPlatform`）、`app_data_directory.dart`（`appDataRootDirectory`、`appFontsBaseDirectory`）、`app_data_location.dart`（`AppDataLocationStore` 与目录校验/UTF-8 BOM 指针）、`app_data_media_rebind.dart`（本地迁移媒体路径重绑）、`app_data_location_migrator.dart`（迁移与切换）、`app_data_location_bootstrapper.dart`（启动期待迁移恢复）、数据库 provider `app_service.dart`。
- 设置与开关：`settings_service*.dart`、`app_features.dart`（`AppFeatures`）。
- 编辑会话：`editing_session_registry.dart`（`EditingSessionRegistry`）。
- 备份与恢复：编排 `data_archive_service.dart`（导出、预检、合并或覆盖恢复）、`backup_*.dart`。
- 网盘备份：`cloud_backup_service.dart`、各网盘 `cloud_backup_<网盘>.dart`、增量备份 `cloud_backup_incremental*.dart`。
- 导入：`journal_import_service.dart` 与各来源 `journal_import_<来源>.dart`。
- 媒体：托管入库 `diary_media_storage_service.dart` / `diary_cover_storage_service.dart` / `app_background_storage_service.dart`、`heif_image_converter.dart`、回收 `diary_media_sweeper.dart`、写入闸门 `managed_media_write_gate.dart`，及长图、视频、相册、拍摄、录音、字体。
- 其他：定位、天气、分享、应用内更新 `app_update_*.dart`、更新说明 `release_notes_catalog.dart`、系统验证 `device_auth_service.dart`。

子目录：
- `ai/`：AI 助手引擎（纯 Dart）：协议客户端、服务商配置与本机存储、编排 `ai_service.dart`；`agent/` 为智能体循环与工具 schema。
- `app_passcode/`：应用密码的本机配置、摘要、限流与存储。
- `home_widgets/`：桌面小组件的种类、外观、设置、插件网关与点按链接。
- `lan_sync/`：局域网同步引擎，编排 `lan_sync_service.dart`（`LanSyncService`），说明见 `docs/lan_sync.md`；`sync/` 为同步数据层与纯函数规划器。
- `mind_map_io/`：导图文件导入导出（Markdown、XMind、OPML、FreeMind）。
- `storage/`：存储管理：占用扫描、引用索引、压缩、重复文件（规则 `storage_duplicates.dart`，合并编排 `storage_media_service_duplicates.dart`），编排 `storage_media_service.dart`；导入时复用同内容文件 `managed_media_dedup.dart`，内容哈希缓存 `managed_media_content_index.dart`。
- `todo_reminders/`：待办提醒：纯函数规划器与系统通知网关。

## lib/ui
- `diaries/`：日记主模块。
  - `pages/`：日记 Tab `diaries_page.dart`、预览、编辑 `edit_diary_page.dart`、发布、搜索、草稿箱、归档、导出、上锁日记等页面壳。
  - `controllers/`：跨模块统一入口：`diary_open_flow.dart`（`openDiaryPage`）、`diary_create_entry_flow.dart`（`runDiaryCreateEntryFlow`）、`diary_export_flow.dart`（`runDiaryExportFlow`）、`diary_share_controller.dart`（`DiaryShareController`）、`diary_tag_search_flow.dart`（`openDiaryTagSearch`）、`diary_link_open_flow.dart`（`openDiaryLinkTarget`）、编辑会话 `diary_editor_controller.dart`（`DiaryEditorController`）；其余为各类块的编辑、搜索、多选批量、留言、查找替换等流程。
  - `models/`、`viewmodels/`、`providers/`：筛选、偏好与派生状态；卡片样式 `models/diary_card_style/`、预览页样式 `models/diary_preview_style/`、样式库 `models/style_library/`、代码块 `models/diary_code_block/`。
  - `export/`：导出写出器（PDF / EPUB / Word / Markdown / 网页 / 纯文本 / CSV）与成书结构。
  - `sections/`：页面区块，含分享面板 `diary_share_sheet.dart`（`showDiaryShareSheet`）。
  - `widgets/diary_editor/`：共用编辑器 `diary_editor.dart`（`DiaryEditor`，编辑与只读正文）、块渲染、段落把手与选择模式、小图长按排序（`diary_thumbnail_reorder_layer.dart`）、光标菜单。
  - `widgets/` 其余：`diary_card/` 共用日记卡片，`diary_preview/` 预览页，`publish_panel/` 发布与编辑共用的信息面板，`diary_color_panel/` 等为工具栏面板，另有查找栏、链接、留言、这天的照片、宽窗口右栏 `diary_detail_pane/`。
- `app_surface/`：背景与材质设置模型、背景解码缓存；`widgets/` 为 `AppPageBackground`、`AppPageBackdrop`、`AppGlass.of`（`app_glass_scope.dart`）与 `AppGlassSurface` / `AppCardSurface` / `AppGlassFab` / `AppGlassField`。
- `anniversaries/`：纪念日与倒数日（列表、详情、编辑页）。
- `todos/`：独立待办（待办 Tab、搜索、清单管理、设置、详情面板与批量操作）；列表拍平与缓存 `viewmodels/todo_list_entries.dart` / `todo_list_model.dart`，列表外壳 `sections/todo_list_slivers.dart`（开放区）与 `todo_done_section.dart`（可折叠的已完成组），视图切换 `controllers/todo_view_switch.dart`，拖动排序 `controllers/todo_reorder.dart`，“今天” `todoTodayProvider`；勾选三拍的节拍 `widgets/todo_complete_motion.dart`，行的拆件 `todo_tile_check.dart` / `todo_tile_text.dart`（逐行删除线）/ `todo_tile_steps.dart`，平台外壳 `sections/todo_list_tile.dart`，合并撤销 `controllers/todo_completion_undo.dart`，桌面拖到左栏 `widgets/todo_row_drag.dart` 与左栏 `todo_sidebar.dart`，今天概览卡 `todo_today_hero.dart`，页面的视图与导航 `pages/todos_page_views.dart`（part）；详情里的步骤行 `widgets/todo_step_row.dart`、备注下的清单 / 链接 `todo_note_extras.dart`、坚持记录 `todo_streak_card.dart` + `viewmodels/todo_streak.dart`；快速新建的手上值 `viewmodels/todo_quick_add_draft.dart`、属性按钮行 `widgets/todo_quick_add_fields.dart`、已添加堆栈 `todo_added_stack.dart`、拆分提示 `todo_quick_split_prompt.dart`，重复与提醒的识别规则 `viewmodels/todo_quick_parse_repeat_rules.dart`（part）；改期的快捷日子 `viewmodels/todo_reschedule.dart`，规划今天 `viewmodels/todo_day_plan.dart` + `widgets/todo_day_plan_sheet.dart`，计划视图周条 `widgets/todo_week_strip.dart`；回顾 `viewmodels/todo_review_stats.dart` + `widgets/todo_review_summary.dart`（探索页的待办卡 `explore/sections/explore_todos_card.dart` 共用）；桌面键盘流 `controllers/todo_keyboard.dart`，悬停按钮 `widgets/todo_hover_actions.dart`，搜索筛选 `viewmodels/todo_search_filter.dart` + `sections/todo_search_filter_bar.dart`；待办标签的口径 `core/database/todo_tags.dart` 与读写 `app_database_todo_tag_ops.dart`，标签面板 `widgets/todo_tag_picker_sheet.dart`、行上胶囊 `todo_tag_chips.dart`、视图组 `todo_tag_nav.dart`、改名弹窗 `todo_tag_rename_dialog.dart`，管理页 `pages/todo_tags_page.dart` + `controllers/todo_tag_actions.dart`；清单分区的口径 `core/database/todo_sections.dart` 与读写 `app_database_todo_section_ops.dart`，分区操作 `controllers/todo_section_actions.dart` + `sections/todo_section_callbacks.dart`，标题行尾 `widgets/todo_section_header_actions.dart`、名称弹窗 `todo_section_name_dialog.dart`、选分区 `todo_section_picker_sheet.dart`；快速新建的预填 `widgets/todo_quick_add_preset.dart`，属性面板、写库与 AI 整理 `widgets/todo_quick_add_pickers.dart` / `todo_quick_add_submit.dart` / `todo_quick_add_ai.dart`（part）；专注记录的口径 `core/database/todo_focus.dart` 与读写 `app_database_todo_focus_ops.dart`（同步 `lan_sync/sync/sync_canonical_todo_focus.dart`，备份合并 `core/services/backup_todo_merge.dart`）；待办助手的流程 `controllers/todo_ai_flow.dart`、预览状态 `controllers/todo_ai_drafts.dart`、输出解析 `viewmodels/todo_ai_output.dart`（请求构建在 `ai/viewmodels/ai_todo_prompts.dart`），预览外壳 `widgets/todo_ai_preview.dart`、整理的一条 `todo_ai_organize_item.dart`，详情步骤卡 `sections/todo_steps_card.dart`。
- `mind_maps/`：思维导图：`layout/` 布局引擎、画布与工作区、样式 / 导出 / AI 面板、嵌入导图编辑页与查看页；导图日记经 `diaries/` 的编辑页接入。
- `diary_templates/`：日记模板：`models/built_in/` 内置模板、套用与撤销、管理页与编辑页。
- `notebooks/`：日记本：首页卡组 `widgets/notebook_switcher/`（状态机 `controllers/notebook_switcher_controller.dart`）、编辑、目录与章节、智能规则、统计、上锁、嵌套树、封面 `widgets/notebook_cover/`；`controllers/notebook_navigation.dart`（`openNotebookFromAnywhere`）、选本流程 `diary_notebook_pick_flow.dart`、首页范围 `providers/home_notebook_scope_provider.dart`。
- `ai/`：AI 助手界面（`docs/ai_assistant.md`）：入口 `controllers/ai_assistant_entry.dart`（`openAiAssistant`）、对话 / 写作 / 回顾 / 回应流程、设置页 `pages/settings/`、对话页分区 `sections/chat/`；`tools/` 为智能体工具，清单只在 `ai_tool_registry.dart`，撤销在 `controllers/ai_agent_undo_flow.dart`；日记正文的读写写法在 `ai_diary_markdown.dart`（写出）与 `ai_diary_markdown_edit.dart`（按替换改写），复用模板 Markdown 的 `ai_template_markdown*.dart`。
- `app_lock/`：应用锁与应用密码界面：统一验证 `controllers/identity_verifier.dart`（`IdentityVerifier`）、运行时上锁 `app_lock_controller.dart`、密码设置 / 验证页与锁屏遮罩。
- `lan_sync/`：局域网同步界面（同步页、设备详情页、扫码页）；界面控制器包着 `LanSyncService`，生产装配 `providers/lan_sync_engine_assembly.dart`。
- `storage/`：存储管理界面（总览、媒体页、重复文件页、`sections/storage_location_card.dart` 桌面数据位置卡），操作流程 `controllers/storage_flows.dart`、`controllers/storage_location_flow.dart`。
- `home_widgets/`：桌面小组件界面：小组件页与工作室、快照构建 `viewmodels/`、常驻同步与点按路由 `controllers/home_widget_launch_router.dart`。
- `home/`：首页壳 `pages/home_page.dart`（切页、快捷键）；`models/home_tab.dart`（`HomeTab`）、导航栏样式 `models/home_bar_style/`、底栏与宽窗口侧栏 `widgets/home_bar/`；提示条入口 `widgets/home_hint_visibility_scope.dart`（`showTrackedSnackBar`）。
- `calendar/`：日历 Tab（三档宽度布局、范围统计、纪念日与待办联动）。
- `explore/`：探索 Tab：卡片注册表与布局、统计聚合（后台计算）、图表 `widgets/charts/`、媒体画廊页。
- `settings/`：设置首页 `pages/settings_page.dart`（Tab 为 `SettingsPage`，入口在“更多”菜单时经 `openSettingsPage` 推入 `SettingsRoutePage`）与各二级页；样式编辑页的区块在 `sections/<样式名>/`；功能管理 `providers/app_features_provider.dart`（`appFeaturesProvider` / `saveAppFeatures`）；导入恢复 `controllers/backup_import_flow.dart`（`chooseBackupImportMode`）；另有网盘备份、回收站、标签管理、更新日志。
- `widgets/`：跨 feature 公共 UI：
  - 平铺文件：`app_top_bar.dart`、`form_width.dart`、`keyboard_visibility.dart`（`KeyboardVisibility` / `KeyboardInsetPadding`）、`width_layout_builder.dart`、`expressive_*.dart`（按钮组、加载、入场、图片淡入 `expressiveImageFrameBuilder`）、`delayed_loading_indicator.dart` / `action_loading_overlay.dart`、`launch_reveal.dart`、看图 `image_viewer_page.dart`（`openImageViewer`）、`reorder_handle.dart`、`desktop_horizontal_scroll.dart`、`editing_session_blocker.dart`、滚动显隐判定 `scroll_chrome_hider.dart`、颜色选择。
  - 列表动效：进出场 `list_item_presence.dart`、让位（FLIP）`list_make_room.dart`、数据变化编排 `list_change_host.dart`（`ListChangeHost`，日记与待办共用）、整块折叠 `sliver_collapse.dart`（`AnimatedSliverCollapse`）、逐位滚动的计数 `rolling_text.dart` / `animated_rolling_text.dart`。
  - `floating_top_bar/`：日记页浮岛顶栏（`FloatingTopBarHost`、岛与动作胶囊、标题岛、状态栏渐隐带、`FloatingTopBarCover`）。
  - `app_modal/`：`showAppModalBottomSheet` / `showAppDialog` 唯一入口。
  - `expressive_menu/`：锚定弹出菜单 `ExpressiveMenuAnchor` / `ExpressiveMenuButton` 与二级菜单。
  - `text_selection_menu/`：文字选区菜单（`appTextContextMenuBuilder`、`AppTextSelectionMenu.adaptive`）。
  - `glass/`：磨砂玻璃 `GlassSurface`、背景取样与模糊缓存、`GlassReveal`。
  - `fast_scroller/`：长列表快速滚动条 `FastScroller`。
  - `long_image/`：长图判定、分片与有界解码 `long_image_policy.dart`（`boundedImageProvider`）。
  - `container_transform/`：卡片展开成整页的容器转场与新建日记的整页收放（`ContainerTransformPageRoute` / `MorphPageRoute`）。
  - `markdown/`：Markdown 代码块与表格（更新说明、AI 回答）；`rich_text/`：带行内样式的输入控制器 `InlineRichTextController`。

## lib/l10n 与 lib/utils
- `l10n/`：ARB（`app_en.arb` 为模板，另有 zh / ja / ru）、语言清单 `app_languages.dart`（`appLanguages`）、`context.l10n` 封装 `app_localizations.dart`；`app_localizations_gen*.dart` 为生成文件。
- `utils/`：字数 `text_stats.dart`（`TextStats` / `DiaryWordCounts`）、盘古之白 `pangu_spacing.dart`（`findPanguGapRanges`）、查询保活、日期与时间格式化、日期选择统一范围 `date_picker_range.dart`、三态选择、序列的最长公共子序列 `sequence_lcs.dart`；`pinyin/` 为拼音表与 A–Z 索引。

## 其他顶层目录
- `assets/`：内置字体、天气图标、应用图标、示例与收款图片、AI 使用指南 `ai_guide/zh|en/`（`docs/releases/` 也作为资源打进应用）。
- `test/`：按 `lib/` 镜像组织；源码约束 `ui/source_rules_test.dart` 与 `ui/widgets/*_source_test.dart`；`support/` 为假实现与夹具（如 `fake_ai.dart`、`lan_sync_two_devices.dart`）；`performance/` 为手动启用的微基准。
- `integration_test/`：实机录音 / 播放集成测试。
- `tool/`：`check_arb.dart`、`merge_lcov.dart`、`write_update_manifest.dart`、`generate_pinyin_table.dart`、`write_cloud_backup_keys.dart`、`ai_mock_server.dart`（本地模拟 AI 流式接口）。
- `docs/`：项目文档与验证记录、`rules/` 专题约束、`releases/` 版本说明、官网静态页（`index.html` 等，资源在 `docs/assets/`）。
- `.github/`：`workflows/`（`ci.yml` 门禁、`release-apk.yml` 发布、`download-stats.yml` 下载统计）、`actions/setup-flutter`（唯一定义 Flutter 版本）、`actions/main-cache`、`dependabot.yml`。
- `android/`：主平台工程；`app/src/main/kotlin/com/jotsy/diary/` 下为原生通道（局域网同步、图片转码、拍摄、应用锁、录音前台服务等）与 `widgets/`（Jetpack Glance 桌面小组件）；`app/src/test/` 为原生回归测试；`app/proguard-rules.pro` 为 R8 规则。
- `ios/ web/ macos/`：Flutter 默认工程（macOS entitlements 开了网络客户端 / 服务端）。
- `linux/ windows/`：桌面 runner；`linux/packaging/`（`.desktop`、图标、`install.sh`）、`windows/packaging/jotsy.iss`（Inno Setup 安装程序）。
