// AI 助手能带用户去的页面（“前往”按钮与 `open_page` 工具共用的登记表）。
//
// 每个目标都经现有的统一入口打开（`openDiaryLinkTarget`、
// `openNotebookFromAnywhere`、`openTodoDetail`、各设置页的构造函数），不另拼
// 路由。功能关闭或本平台没有的页面 [AiDestination.isAvailable] 为 false：
// 模型拿到“不可用”的说明，界面不显示按钮。
//
// 新增页面：在 [aiDestinations] 加一项（id 用 snake_case，发布后不改），标题
// 复用页面自己的标题文案，写明类别、位置、图标与色调；会关掉对话页的（回到
// 首页）标 `leavesChat`。使用指南的文章用 id 引用它（一致性测试会核对）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/database/diary_blocks/diary_link_target.dart';
import '../../../core/services/app_platform.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../anniversaries/controllers/anniversary_navigation.dart';
import '../../app_lock/pages/app_lock_settings_page.dart';
import '../../diaries/controllers/diary_link_open_flow.dart';
import '../../diaries/pages/archived_diaries_page.dart';
import '../../diaries/pages/diary_drafts_page.dart';
import '../../diaries/pages/diary_export_page.dart';
import '../../diaries/pages/diary_search_page.dart';
import '../../diary_templates/pages/diary_templates_page.dart';
import '../../home/models/home_tab.dart';
import '../../home/providers/home_tab_request_provider.dart';
import '../../lan_sync/pages/lan_sync_page.dart';
import '../../notebooks/controllers/notebook_navigation.dart';
import '../../notebooks/pages/notebooks_page.dart';
import '../../notebooks/providers/notebook_providers.dart';
import '../../settings/pages/about_page.dart';
import '../../settings/pages/app_features_page.dart';
import '../../settings/pages/app_surface_page.dart';
import '../../settings/pages/app_update_page.dart';
import '../../settings/pages/appearance_page.dart';
import '../../settings/pages/changelog_page.dart';
import '../../settings/pages/cloud_backup_page.dart';
import '../../settings/pages/data_management_page.dart';
import '../../settings/pages/diary_card_style_page.dart';
import '../../settings/pages/diary_code_block_style_page.dart';
import '../../settings/pages/diary_preview_style_page.dart';
import '../../settings/pages/diary_typography_page.dart';
import '../../settings/pages/editor_settings_page.dart';
import '../../settings/pages/explore_layout_page.dart';
import '../../settings/pages/home_bar_style_page.dart';
import '../../settings/pages/mood_options_page.dart';
import '../../settings/pages/recycle_bin_page.dart';
import '../../settings/pages/tag_management_page.dart';
import '../../storage/pages/storage_page.dart';
import '../../todos/controllers/todo_navigation.dart';
import '../../todos/pages/todo_settings_page.dart';
import '../pages/ai_recap_page.dart';
import '../pages/settings/ai_settings_page.dart';
import 'ai_tool.dart';

typedef AiDestinationOpener =
    Future<void> Function(
      BuildContext context,
      WidgetRef ref,
      Map<String, Object?> params,
    );

/// 前往的目标是什么：决定卡片的标题怎么取（具体一篇 / 一本 / 一项的名称，
/// 还是页面名）。
enum AiDestinationKind { tab, diary, notebook, todo, search, page }

/// 页面在应用里的位置（卡片副标题写成“首页 › 日历”“设置 › 外观”）。
enum AiDestinationSection { none, home, settings }

/// 卡片与图标徽标的色调（只取主题的语义容器色，见 DESIGN §5.29）。
enum AiTint { primary, secondary, tertiary, neutral }

/// 一个可以前往的页面。
@immutable
class AiDestination {
  const AiDestination(
    this.id, {
    required this.title,
    required this.open,
    required this.kind,
    required this.icon,
    required this.tint,
    this.section = AiDestinationSection.none,
    this.leavesChat = false,
    this.available,
    this.requires = const <String>{},
  });

  final String id;

  /// 按钮上的页面名（界面语言）。
  final String Function(AppLocalizations l10n) title;

  final AiDestinationOpener open;

  final AiDestinationKind kind;
  final AiDestinationSection section;
  final FaIconData icon;
  final AiTint tint;

  /// 打开它要关掉对话页（回到首页的某个 Tab、切换首页的日记本范围）：对话
  /// 页打开前先登记“回到对话”，首页的返回键据此重新打开这段对话。
  final bool leavesChat;

  /// 功能开关 / 平台条件；为空时总是可用。
  final bool Function(AiToolEnv env)? available;

  /// 必须给的参数（如打开某篇日记要 `diary_id`）。
  final Set<String> requires;

  bool isAvailable(AiToolEnv env) => available?.call(env) ?? true;
}

Future<void> _push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

AiDestinationOpener _page(Widget Function() build) =>
    (context, ref, params) => _push(context, build());

/// 需要 `SettingsService` 的设置页。
AiDestinationOpener _settingsPage(
  Widget Function(SettingsService settings) build,
) => (context, ref, params) async {
  final settings = await ref.read(settingsServiceProvider.future);
  if (!context.mounted) return;
  await _push(context, build(settings));
};

/// 回到首页并切到 [tab]。
AiDestinationOpener _tab(HomeTab tab) => (context, ref, params) async {
  final tabs = ref.read(homeTabRequestProvider.notifier);
  Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
  tabs.request(tab);
};

String? _param(Map<String, Object?> params, String key) {
  final value = params[key];
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}

/// 全部可前往的页面（顺序即 `open_page` 说明里的顺序）。
final List<AiDestination> aiDestinations = <AiDestination>[
  // ---- 首页各 Tab ----
  AiDestination(
    'tab_diaries',
    kind: AiDestinationKind.tab,
    section: AiDestinationSection.home,
    icon: FontAwesomeIcons.solidRectangleList,
    tint: AiTint.primary,
    leavesChat: true,
    title: (l10n) => l10n.navDiaries,
    open: _tab(HomeTab.diaries),
  ),
  AiDestination(
    'tab_todos',
    kind: AiDestinationKind.tab,
    section: AiDestinationSection.home,
    icon: FontAwesomeIcons.solidSquareCheck,
    tint: AiTint.secondary,
    leavesChat: true,
    title: (l10n) => l10n.navTodos,
    open: _tab(HomeTab.todos),
    available: (env) => env.features.todos,
  ),
  AiDestination(
    'tab_calendar',
    kind: AiDestinationKind.tab,
    section: AiDestinationSection.home,
    icon: FontAwesomeIcons.solidCalendar,
    tint: AiTint.secondary,
    leavesChat: true,
    title: (l10n) => l10n.navCalendar,
    open: _tab(HomeTab.calendar),
    available: (env) => env.features.calendar,
  ),
  AiDestination(
    'tab_explore',
    kind: AiDestinationKind.tab,
    section: AiDestinationSection.home,
    icon: FontAwesomeIcons.solidCompass,
    tint: AiTint.primary,
    leavesChat: true,
    title: (l10n) => l10n.navExplore,
    open: _tab(HomeTab.explore),
    available: (env) => env.features.explore,
  ),
  AiDestination(
    'tab_settings',
    kind: AiDestinationKind.tab,
    section: AiDestinationSection.home,
    icon: FontAwesomeIcons.gear,
    tint: AiTint.neutral,
    leavesChat: true,
    title: (l10n) => l10n.navSettings,
    open: _tab(HomeTab.settings),
  ),
  // ---- 具体的一篇 / 一本 / 一项 ----
  AiDestination(
    'diary',
    kind: AiDestinationKind.diary,
    icon: FontAwesomeIcons.bookOpen,
    tint: AiTint.primary,
    title: (l10n) => l10n.aiDestinationDiary,
    requires: const <String>{'diary_id'},
    open: (context, ref, params) => openDiaryLinkTarget(
      context,
      ref,
      DiaryLinkTarget.diary(_param(params, 'diary_id')!),
    ),
  ),
  AiDestination(
    'notebook',
    kind: AiDestinationKind.notebook,
    icon: FontAwesomeIcons.book,
    tint: AiTint.tertiary,
    leavesChat: true,
    title: (l10n) => l10n.notebookTitle,
    requires: const <String>{'notebook_id'},
    available: (env) => env.features.notebooks,
    open: (context, ref, params) async {
      final notebook = ref.read(
        notebookTreeProvider,
      )?[_param(params, 'notebook_id')!];
      if (notebook == null) return;
      await openNotebookFromAnywhere(context, ref, notebook);
    },
  ),
  AiDestination(
    'todo',
    kind: AiDestinationKind.todo,
    icon: FontAwesomeIcons.squareCheck,
    tint: AiTint.secondary,
    title: (l10n) => l10n.navTodos,
    requires: const <String>{'todo_id'},
    available: (env) => env.features.todos,
    open: (context, ref, params) =>
        openTodoDetail(context, _param(params, 'todo_id')!),
  ),
  AiDestination(
    'search',
    kind: AiDestinationKind.search,
    icon: FontAwesomeIcons.magnifyingGlass,
    tint: AiTint.primary,
    title: (l10n) => l10n.aiDestinationSearch,
    open: (context, ref, params) => Navigator.of(context).push(
      DiarySearchPage.buildRoute(initialKeyword: _param(params, 'query') ?? ''),
    ),
  ),
  AiDestination(
    'archive',
    kind: AiDestinationKind.page,
    icon: FontAwesomeIcons.boxArchive,
    tint: AiTint.primary,
    title: (l10n) => l10n.autoT0100,
    open: _page(() => const ArchivedDiariesPage()),
  ),
  AiDestination(
    'anniversaries',
    kind: AiDestinationKind.page,
    icon: FontAwesomeIcons.cakeCandles,
    tint: AiTint.secondary,
    title: (l10n) => l10n.anniversaryListTitle,
    available: (env) => env.features.anniversariesEnabled,
    open: (context, ref, params) => openAnniversaryList(context),
  ),
  AiDestination(
    'ai_recap',
    kind: AiDestinationKind.page,
    icon: FontAwesomeIcons.wandMagicSparkles,
    tint: AiTint.tertiary,
    title: (l10n) => l10n.aiRecapTitle,
    open: _page(() => const AiRecapPage()),
  ),
  // ---- 设置 ----
  AiDestination(
    'settings_appearance',
    kind: AiDestinationKind.page,
    section: AiDestinationSection.settings,
    icon: FontAwesomeIcons.palette,
    tint: AiTint.neutral,
    title: (l10n) => l10n.settingsAppearance,
    open: _page(() => const AppearancePage()),
  ),
  AiDestination(
    'settings_background',
    kind: AiDestinationKind.page,
    section: AiDestinationSection.settings,
    icon: FontAwesomeIcons.image,
    tint: AiTint.neutral,
    title: (l10n) => l10n.appSurfaceTitle,
    open: _settingsPage((s) => AppSurfacePage(settingsService: s)),
  ),
  AiDestination(
    'settings_card_style',
    kind: AiDestinationKind.page,
    section: AiDestinationSection.settings,
    icon: FontAwesomeIcons.brush,
    tint: AiTint.neutral,
    title: (l10n) => l10n.diaryCardStyleTitle,
    open: _settingsPage((s) => DiaryCardStylePage(settingsService: s)),
  ),
  AiDestination(
    'settings_preview_style',
    kind: AiDestinationKind.page,
    section: AiDestinationSection.settings,
    icon: FontAwesomeIcons.bookOpenReader,
    tint: AiTint.neutral,
    title: (l10n) => l10n.diaryPreviewStyleTitle,
    open: _settingsPage((s) => DiaryPreviewStylePage(settingsService: s)),
  ),
  AiDestination(
    'settings_nav_bar_style',
    kind: AiDestinationKind.page,
    section: AiDestinationSection.settings,
    icon: FontAwesomeIcons.tableColumns,
    tint: AiTint.neutral,
    title: (l10n) => l10n.homeBarStyleTitle,
    open: _settingsPage((s) => HomeBarStylePage(settingsService: s)),
  ),
  AiDestination(
    'settings_explore_layout',
    kind: AiDestinationKind.page,
    section: AiDestinationSection.settings,
    icon: FontAwesomeIcons.solidCompass,
    tint: AiTint.neutral,
    title: (l10n) => l10n.settingsExploreLayout,
    available: (env) => env.features.explore,
    open: (context, ref, params) async {
      final settings = await ref.read(settingsServiceProvider.future);
      if (!context.mounted) return;
      await Navigator.of(
        context,
      ).push(ExploreLayoutPage.route(settingsService: settings));
    },
  ),
  AiDestination(
    'settings_features',
    kind: AiDestinationKind.page,
    section: AiDestinationSection.settings,
    icon: FontAwesomeIcons.toggleOn,
    tint: AiTint.neutral,
    title: (l10n) => l10n.settingsFeaturesTitle,
    open: _page(() => const AppFeaturesPage()),
  ),
  AiDestination(
    'settings_editor',
    kind: AiDestinationKind.page,
    section: AiDestinationSection.settings,
    icon: FontAwesomeIcons.penNib,
    tint: AiTint.neutral,
    title: (l10n) => l10n.settingsEditor,
    open: _page(() => const EditorSettingsPage()),
  ),
  AiDestination(
    'settings_typography',
    kind: AiDestinationKind.page,
    section: AiDestinationSection.settings,
    icon: FontAwesomeIcons.font,
    tint: AiTint.neutral,
    title: (l10n) => l10n.diaryTypographyTitle,
    open: _page(() => const DiaryTypographyPage()),
  ),
  AiDestination(
    'settings_code_block_style',
    kind: AiDestinationKind.page,
    section: AiDestinationSection.settings,
    icon: FontAwesomeIcons.code,
    tint: AiTint.neutral,
    title: (l10n) => l10n.codeBlockStyleTitle,
    open: _settingsPage((s) => DiaryCodeBlockStylePage(settingsService: s)),
  ),
  AiDestination(
    'settings_templates',
    kind: AiDestinationKind.page,
    section: AiDestinationSection.settings,
    icon: FontAwesomeIcons.fileLines,
    tint: AiTint.neutral,
    title: (l10n) => l10n.diaryTemplatesTitle,
    available: (env) => env.features.templates,
    open: _page(() => const DiaryTemplatesPage()),
  ),
  AiDestination(
    'settings_drafts',
    kind: AiDestinationKind.page,
    section: AiDestinationSection.settings,
    icon: FontAwesomeIcons.filePen,
    tint: AiTint.neutral,
    title: (l10n) => l10n.diaryDraftsTitle,
    open: _page(() => const DiaryDraftsPage()),
  ),
  AiDestination(
    'settings_tags',
    kind: AiDestinationKind.page,
    section: AiDestinationSection.settings,
    icon: FontAwesomeIcons.tags,
    tint: AiTint.tertiary,
    title: (l10n) => l10n.settingsTagManagement,
    open: _page(() => const TagManagementPage()),
  ),
  AiDestination(
    'settings_moods',
    kind: AiDestinationKind.page,
    section: AiDestinationSection.settings,
    icon: FontAwesomeIcons.solidFaceSmile,
    tint: AiTint.neutral,
    title: (l10n) => l10n.settingsMoodOptionsTitle,
    open: _settingsPage((s) => MoodOptionsPage(settingsService: s)),
  ),
  AiDestination(
    'settings_notebooks',
    kind: AiDestinationKind.page,
    section: AiDestinationSection.settings,
    icon: FontAwesomeIcons.book,
    tint: AiTint.tertiary,
    title: (l10n) => l10n.notebookTitle,
    available: (env) => env.features.notebooks,
    open: _page(() => const NotebooksPage()),
  ),
  AiDestination(
    'settings_todos',
    kind: AiDestinationKind.page,
    section: AiDestinationSection.settings,
    icon: FontAwesomeIcons.listCheck,
    tint: AiTint.secondary,
    title: (l10n) => l10n.todoSettingsTitle,
    available: (env) => env.features.todos,
    open: _page(() => const TodoSettingsPage()),
  ),
  AiDestination(
    'recycle_bin',
    kind: AiDestinationKind.page,
    section: AiDestinationSection.settings,
    icon: FontAwesomeIcons.trashCan,
    tint: AiTint.neutral,
    title: (l10n) => l10n.settingsRecycleBin,
    open: _page(() => const RecycleBinPage()),
  ),
  AiDestination(
    'data_management',
    kind: AiDestinationKind.page,
    section: AiDestinationSection.settings,
    icon: FontAwesomeIcons.database,
    tint: AiTint.neutral,
    title: (l10n) => l10n.settingsDataManagement,
    open: _page(() => const DataManagementPage()),
  ),
  AiDestination(
    'cloud_backup',
    kind: AiDestinationKind.page,
    section: AiDestinationSection.settings,
    icon: FontAwesomeIcons.cloudArrowUp,
    tint: AiTint.neutral,
    title: (l10n) => l10n.dataMgmtCloudBackup,
    open: _page(() => const CloudBackupPage()),
  ),
  AiDestination(
    'export_diaries',
    kind: AiDestinationKind.page,
    section: AiDestinationSection.settings,
    icon: FontAwesomeIcons.fileExport,
    tint: AiTint.neutral,
    title: (l10n) => l10n.diaryExportPageTitle,
    open: _page(() => const DiaryExportPage()),
  ),
  AiDestination(
    'storage',
    kind: AiDestinationKind.page,
    section: AiDestinationSection.settings,
    icon: FontAwesomeIcons.hardDrive,
    tint: AiTint.neutral,
    title: (l10n) => l10n.storageMgmtTitle,
    open: _page(() => const StoragePage()),
  ),
  AiDestination(
    'lan_sync',
    kind: AiDestinationKind.page,
    section: AiDestinationSection.settings,
    icon: FontAwesomeIcons.wifi,
    tint: AiTint.neutral,
    title: (l10n) => l10n.lanSyncTitle,
    available: (env) => AppPlatform.supportsLanSync,
    open: _page(() => const LanSyncPage()),
  ),
  AiDestination(
    'app_lock',
    kind: AiDestinationKind.page,
    section: AiDestinationSection.settings,
    icon: FontAwesomeIcons.lock,
    tint: AiTint.neutral,
    title: (l10n) => l10n.settingsAppLockAndPasscode,
    open: _page(() => const AppLockSettingsPage()),
  ),
  AiDestination(
    'ai_settings',
    kind: AiDestinationKind.page,
    section: AiDestinationSection.settings,
    icon: FontAwesomeIcons.wandMagicSparkles,
    tint: AiTint.neutral,
    title: (l10n) => l10n.aiSettingsTitle,
    open: _page(() => const AiSettingsPage()),
  ),
  AiDestination(
    'about',
    kind: AiDestinationKind.page,
    section: AiDestinationSection.settings,
    icon: FontAwesomeIcons.circleInfo,
    tint: AiTint.neutral,
    title: (l10n) => l10n.settingsAbout,
    open: _page(() => const AboutPage()),
  ),
  AiDestination(
    'changelog',
    kind: AiDestinationKind.page,
    section: AiDestinationSection.settings,
    icon: FontAwesomeIcons.clockRotateLeft,
    tint: AiTint.neutral,
    title: (l10n) => l10n.changelogTitle,
    open: _page(() => const ChangelogPage()),
  ),
  AiDestination(
    'app_update',
    kind: AiDestinationKind.page,
    section: AiDestinationSection.settings,
    icon: FontAwesomeIcons.circleArrowUp,
    tint: AiTint.neutral,
    title: (l10n) => l10n.appUpdateTitle,
    open: _page(() => const AppUpdatePage()),
  ),
];

final Map<String, AiDestination> _byId = <String, AiDestination>{
  for (final destination in aiDestinations) destination.id: destination,
};

AiDestination? aiDestinationById(String id) => _byId[id];
