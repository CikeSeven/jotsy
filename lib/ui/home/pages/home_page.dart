import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_enums.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_fab.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_scope.dart';
import 'package:node_diary/ui/app_surface/widgets/app_paged_background.dart';
import 'package:node_diary/ui/calendar/pages/calendar_page.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/diaries/controllers/diary_create_entry_flow.dart';
import 'package:node_diary/ui/explore/pages/explore_page.dart';
import 'package:node_diary/ui/todos/controllers/todo_navigation.dart';
import 'package:node_diary/ui/todos/controllers/todo_reminder_scheduler.dart';
import 'package:node_diary/ui/todos/pages/todos_page.dart';
import 'package:node_diary/ui/home/controllers/home_bar_scroll_hider.dart';
import 'package:node_diary/ui/home/controllers/page_position_listenable.dart';
import 'package:node_diary/ui/home/controllers/page_spring_driver.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_behavior.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_resolved_style.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';
import 'package:node_diary/ui/home/models/home_tab.dart';
import 'package:node_diary/ui/home/models/home_tab_page_order.dart';
import 'package:node_diary/ui/home/providers/home_bar_settings_provider.dart';
import 'package:node_diary/ui/home/providers/home_tab_request_provider.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_bottom_bar.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_chrome_scope.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_floating_bar.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_bar.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_rail.dart';
import 'package:node_diary/ui/home/widgets/home_tab_depth.dart';
import 'package:node_diary/ui/home/widgets/home_tab_entrance.dart';
import 'package:node_diary/ui/widgets/primary_shortcut.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/notebooks/providers/home_notebook_scope_provider.dart';
import 'package:node_diary/ui/home/widgets/keep_alive_page.dart';
import 'package:node_diary/ui/lan_sync/controllers/lan_sync_auto_sync_notices.dart';
import 'package:node_diary/ui/lan_sync/providers/lan_sync_providers.dart';
import 'package:node_diary/ui/settings/controllers/app_update_auto_check.dart';
import 'package:node_diary/ui/settings/controllers/cloud_backup_auto_scheduler.dart';
import 'package:node_diary/ui/settings/providers/app_features_provider.dart';
import 'package:node_diary/ui/settings/pages/settings_page.dart';
import 'package:node_diary/core/services/app_platform.dart';

import '../../../app/theme/app_breakpoints.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../widgets/glass/glass_reveal.dart';
import '../../widgets/launch_reveal.dart';
import '../../ai/controllers/ai_chat_return_flow.dart';
import '../../ai/providers/ai_chat_return_provider.dart';
part '../controllers/home_page_controller.dart';
part 'home_page_chrome.dart';
part 'home_page_pager.dart';
part 'home_page_shortcuts.dart';

/// 主框架页：承载 Tab 导航（日记 / 待办 / 日历 / 探索）。设置不是 Tab，从
/// 日记页顶栏“更多 → 设置”推入（[openSettingsPage]）。
///
/// 待办、日历与探索可在设置 → 功能管理中关闭，底栏随之变为 2–4 项（见
/// [visibleHomeTabs]）；三者都关闭时只剩日记，没有可切换的页面，窄窗口不显示
/// 底栏（新建入口回到全局 FAB，见 [_hasBottomBar]）。当前页、目标页、FAB 与
/// 返回键一律按 [HomeTab] 身份判断，可见集合变化时由
/// `_HomePageController.syncVisibleTabs` 重新对齐下标。
///
/// 按窗口宽度两种外壳（[AppBreakpoints]，不按平台）：
/// - 窄于 600：底栏 + 全局 FAB，与改版前完全相同；
/// - 600 及以上：左侧 [HomeNavRail]（新建按钮在栏顶，对所有 Tab 有效），没有
///   底栏、全局 FAB 与玻璃栏的并排按钮，不能左右滑动切页，切页改为新 Tab
///   沿侧边栏方向移入、淡入并轻微放大（[HomeTabEntrance]），“滚动时隐藏”与
///   “指示器跟随滑动”不生效。
///
/// 窄窗口切页（点按与左右滑动同一套运动）：
/// - 页面由真弹簧推动（[PageSpringDriver]，松手吸附同为
///   `ExpressiveMotion.springPage`），与底栏指示器的弹簧同时落位；途中再点
///   别的 Tab 带着速度改道，弹簧途中也能用手指接住；
/// - 跨过几个 Tab 时临时把目标排到当前页隔壁（[HomeTabPageOrder]），只滑
///   一页，停稳后换回底栏顺序；
/// - 途中每页按离视口中心的距离缩成圆角卡片并压暗（[HomeTabDepth]），落位时
///   铺满；减少动画时直接跳页、没有景深。
/// 窗口拖动跨过 600 时，页面区挂在 `_contentKey` 这个 GlobalKey 下随外壳
/// 搬家而不重建，各 Tab 的状态（滚动位置、筛选、日记本范围）都保留。
///
/// 键盘快捷键（所有宽度，焦点在首页内时生效，见 home_page_shortcuts.dart）：
/// Ctrl/⌘+N 新建、Ctrl/⌘+F 搜索日记、Ctrl/⌘+1…4 切到第 n 个可见 Tab。
class HomePage extends ConsumerStatefulWidget {
  const HomePage({
    super.key,
    this.startupNotice,
    required this.homeHintVisibleListenable,
  });

  final String? startupNotice;
  final ValueListenable<bool> homeHintVisibleListenable;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  // SnackBar 左右留白，统一 Home 内提示视觉。
  static const double _snackBarSideInset = 16;
  // 宽窗口：提示最宽 560，在侧边栏右侧的内容区居中，离底 24。
  static const double _wideSnackBarMaxWidth = 560;
  static const double _wideSnackBarBottomInset = AppSpacing.xxl;
  static const Duration _fabVisibilityDuration = ExpressiveMotion.standard;
  static const Duration _fabLiftDuration = ExpressiveMotion.medium;
  static const Curve _fabVisibilityCurve = ExpressiveMotion.effects;
  static const Curve _fabLiftCurve = ExpressiveMotion.effects;
  static const double _fabBottomGapAboveNav = 10;
  // 未测得提示高度时的默认上移量（单行 SnackBar）。
  static const double _fabLiftOffsetWhenHintVisible = 60;
  // FAB 与提示上沿之间保留的间隙。
  static const double _fabGapAboveHint = 6;

  /// 冷启动与回到前台时自动检查更新（时机与间隔见 [AppUpdateAutoChecker]）。
  late final AppUpdateAutoChecker _updateAutoChecker;

  /// 网盘自动备份：冷启动、切到后台与前台定时检查（见
  /// [CloudBackupAutoScheduler]），全程静默。
  late final CloudBackupAutoScheduler _cloudAutoBackup;

  /// 前台自动同步的提示条（只在支持局域网同步的平台订阅，见
  /// [LanSyncAutoSyncNotices]）。
  LanSyncAutoSyncNotices? _lanSyncNotices;

  // 页面切换状态。下标都是在 [_tabs] 中的位置；[_tabs] 变化时由
  // `_HomePageController.syncVisibleTabs` 换算到新列表。日记排在底栏中间、
  // 不一定是第 0 个，两个下标在 initState 中按身份取日记的位置。
  late List<HomeTab> _tabs;

  /// PageView 的子页顺序：静止时等于 [_tabs]，跨页切换途中临时把目标排到
  /// 当前页隔壁（见 [HomeTabPageOrder]）。PageView 的页码、[_visibleTabs]
  /// 与景深都按它的显示下标；[_currentIndex] / [_targetIndex] 仍是 [_tabs]
  /// 中的下标。
  late HomeTabPageOrder _pageOrder;
  late int _currentIndex;
  late int _targetIndex;
  int _tabSwitchGeneration = 0;
  bool _isTabSwitching = false;
  String? _shownStartupNotice;

  Future<void> Function()? _diariesCreateAction;
  Future<void> Function()? _todosCreateAction;
  VoidCallback? _diariesSearchAction;
  bool _diariesFabVisibleByScroll = true;

  /// 待办页是否在多选：多选时隐藏新建入口，返回键交给待办页退出多选。
  bool _todosSelecting = false;
  late final ValueNotifier<int> _tabPageConfigRevision;
  late final ValueChanged<Future<void> Function()?> _diariesCreateActionChanged;
  late final ValueChanged<Future<void> Function()?> _todosCreateActionChanged;
  late final ValueChanged<VoidCallback?> _diariesSearchActionChanged;
  late final ValueChanged<bool> _diariesFabVisibilityChanged;
  late final ValueChanged<bool> _todosSelectionChanged;
  late final _HomePageController _controller;

  /// 各 Tab 的页面，第一次出现在可见列表里时才创建；Tab 被关闭时移除，
  /// 页面随之销毁（不再监听数据库），重新开启时重新创建。
  final Map<HomeTab, Widget> _pages = <HomeTab, Widget>{};

  /// 当前（含滑动途中）可见的 Tab 区间，驱动各页的 TickerMode。
  late final ValueNotifier<_VisibleTabRange> _visibleTabs;

  /// 景深切页是否按快照绘制各页：窄窗口且未减少动画时（与景深同时开关），
  /// build 时更新。
  bool _tabsUseSnapshots = false;

  /// 各页是否正在按快照绘制（移动途中与落位后的保持期间）。生命周期与
  /// 放开时机见 home_page_pager.dart 的扩展注释。
  final ValueNotifier<bool> _snapshotHold = ValueNotifier<bool>(false);

  /// 落位后放开快照的最晚时刻（帧时间戳），第一次检查时确定。
  Duration? _snapshotReleaseDeadline;

  /// 是否已登记了下一次放开检查（帧后回调）。
  bool _snapshotReleaseScheduled = false;

  /// 已经完整显示过（停在正中、按实时绘制过）的 Tab：只有它们切页时按快照
  /// 绘制。第一次切到的页刚在起步那一帧创建，数据还没到、入场动画还没播，
  /// 拍下来会是一张空页冻结整个切页；这一次照常实时绘制、ticker 照常跑。
  /// Tab 被关闭时移除（页面随之销毁，重新开启后又是第一次）。
  final Set<HomeTab> _snapshotReadyTabs = <HomeTab>{};

  /// 每个 Tab 独立的主滚动控制器，由 [_buildTabPage] 以 PrimaryScrollController
  /// 下发给该 Tab 的主列表；随页面按需创建，Tab 被关闭时在页面卸载后释放。
  ///
  /// 各 Tab 被 KeepAlivePage 同时保活，若都继承路由级 PrimaryScrollController，
  /// 同一个控制器会同时挂上多个滚动位置：“重复点击当前 Tab 回到顶部”会把所有
  /// Tab 一起滚动，读取 offset 也会断言。
  final Map<HomeTab, ScrollController> _tabScrollControllers =
      <HomeTab, ScrollController>{};

  /// PageView 小数页码换算到底栏上的位置，开启“指示器跟随滑动”时交给底栏。
  late final PagePositionListenable _pagePosition;

  /// PageView 的小数页码（显示序），交给背景插值与翻页景深。
  late final PagePositionListenable _displayPosition;

  /// 底栏是否因“滚动时隐藏”而收起。
  ///
  /// 生命周期：只在有底栏且开启该行为时由 [_handleScrollForBar] 置为
  /// true；以下时机一律放回 false（并清空 [_barScrollHider] 的累计量）：
  /// - 切 Tab 开始或页码变化：新页面的滚动位置与收起时无关，导航必须可见；
  /// - 首页出现提示（SnackBar）：提示叠在底栏上方，底栏收起会让提示悬空；
  /// - 关闭该行为或底栏消失（变成宽窗口、只剩一个 Tab）：在 build 中直接
  ///   复位。
  bool _barHiddenByScroll = false;

  /// 最近一次 build 时“滚动时隐藏底栏”是否生效（有底栏且开启该行为）；
  /// 滚动回调在 build 之外，读这里而不是重新解析样式。
  bool _barHideOnScrollEnabled = false;
  final HomeBarScrollHider _barScrollHider = HomeBarScrollHider();

  /// 最近一次 build 时窗口是否为宽窗口（≥ 600，左侧导航栏外壳）。切页
  /// 控制器在 build 之外读它，决定滑动切页还是淡入切页。
  bool _wide = false;

  /// 页面区（PageView + 全局 FAB 的 Stack）的身份：窄 / 宽两种外壳把它放在
  /// 不同位置（Scaffold.body 本身 / 侧边栏右侧），跨过 600 时靠这个 key
  /// 原样搬过去，保活的 Tab 页面不重建。
  final GlobalKey _contentKey = GlobalKey(debugLabel: 'HomePage content');

  /// 宽窗口切页的次数：每次加一，[HomeTabEntrance] 据此重播入场。
  int _wideEntranceGeneration = 0;

  /// 宽窗口最近一次切页在侧边栏上的方向（往下 1、往上 -1）。
  int _wideEntranceDirection = 0;

  /// 首页快捷键的焦点：首页路由的焦点作用域默认聚焦它（autofocus），从
  /// 推入的页面返回时由路由恢复，快捷键随之重新生效。
  final FocusNode _shortcutFocusNode = FocusNode(
    debugLabel: 'HomePage shortcuts',
    skipTraversal: true,
  );

  /// 快捷键触发的新建流程是否进行中：按住或连按时不重复打开编辑页。
  bool _shortcutCreateRunning = false;

  /// AI 卡片把用户带回首页后，等首页成为当前页再提示“回到对话”。
  final AiChatReturnHint _aiReturnHint = AiChatReturnHint();

  /// 点底栏 / 侧边栏换 Tab：用户自己去做别的事了，返回键不再回到对话。
  Future<void> _handleNavTap(int index) {
    ref.read(aiChatReturnProvider.notifier).disarm();
    return _controller.onTap(index);
  }

  /// 日记页顶栏“更多 → 设置”：与点底栏换 Tab 一样是用户自己去做别的事，
  /// 返回键不再回到 AI 对话。
  void _openSettings() {
    ref.read(aiChatReturnProvider.notifier).disarm();
    unawaited(openSettingsPage(context));
  }

  @override
  void initState() {
    super.initState();
    _tabPageConfigRevision = ValueNotifier<int>(0);
    _diariesCreateActionChanged = (action) => _diariesCreateAction = action;
    _todosCreateActionChanged = (action) => _todosCreateAction = action;
    _diariesSearchActionChanged = (action) => _diariesSearchAction = action;
    _diariesFabVisibilityChanged = _handleFabVisibilityChanged;
    _todosSelectionChanged = (bool selecting) {
      if (_todosSelecting == selecting || !mounted) return;
      setState(() => _todosSelecting = selecting);
    };
    // settings 在首页构建前已就绪（启动门槛），首帧即是真实的开关，不会先
    // 出现四个 Tab 再收起。
    _tabs = visibleHomeTabs(ref.read(appFeaturesProvider));
    // 启动落在日记页（它始终可见）；PageController 的初始页取自这里。
    _currentIndex = _targetIndex = _tabs.indexOf(HomeTab.diaries);
    _pageOrder = HomeTabPageOrder.canonical(_tabs);
    // 启动页一开始就实时显示在正中。
    _snapshotReadyTabs.add(_tabs[_currentIndex]);
    _controller = _HomePageController(this);
    _controller.init();
    _visibleTabs = ValueNotifier<_VisibleTabRange>(
      _VisibleTabRange(_currentIndex, _currentIndex),
    );
    _controller.pageController.addListener(_syncVisibleTabs);
    _displayPosition = PagePositionListenable(
      _controller.pageController,
      _currentDisplayIndex,
    );
    _pagePosition = PagePositionListenable(
      _controller.pageController,
      _currentDisplayIndex,
      map: (double page) => _pageOrder.barPosition(page),
    );
    widget.homeHintVisibleListenable.addListener(_handleHomeHintVisibility);
    _updateAutoChecker = AppUpdateAutoChecker(() async {
      if (mounted) {
        await runAutoUpdateCheck(context, ref);
      }
    })..start();
    _cloudAutoBackup = CloudBackupAutoScheduler(() => runCloudAutoBackups(ref))
      ..start();
    if (AppPlatform.supportsLanSync) {
      _lanSyncNotices = LanSyncAutoSyncNotices(
        ref.read(lanSyncControllerProvider).events,
        () => mounted ? context : null,
      );
    }
    // 点待办提醒通知打开应用：切到待办 Tab 再打开那条待办的详情（冷启动时
    // 请求先于首页到达，fireImmediately 接住）。待办功能关闭时只消费掉。
    ref.listenManual<String?>(
      todoNotificationOpenRequestProvider,
      (_, String? todoId) => _openTodoFromNotification(todoId),
      fireImmediately: true,
    );
  }

  void _openTodoFromNotification(String? todoId) {
    if (todoId == null) return;
    ref.read(todoNotificationOpenRequestProvider.notifier).consume();
    final index = _tabs.indexOf(HomeTab.todos);
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _controller.switchToIndex(index);
      if (mounted) await openTodoDetail(context, todoId);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tabPageConfigRevision.value++;
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.homeHintVisibleListenable !=
        widget.homeHintVisibleListenable) {
      oldWidget.homeHintVisibleListenable.removeListener(
        _handleHomeHintVisibility,
      );
      widget.homeHintVisibleListenable.addListener(_handleHomeHintVisibility);
      _tabPageConfigRevision.value++;
    }
    _controller.handleWidgetUpdate(oldWidget);
  }

  @override
  void dispose() {
    _aiReturnHint.cancel();
    _updateAutoChecker.dispose();
    _cloudAutoBackup.dispose();
    _lanSyncNotices?.dispose();
    widget.homeHintVisibleListenable.removeListener(_handleHomeHintVisibility);
    _pagePosition.dispose();
    _displayPosition.dispose();
    _controller.pageController.removeListener(_syncVisibleTabs);
    _visibleTabs.dispose();
    _snapshotHold.dispose();
    _controller.dispose();
    for (final controller in _tabScrollControllers.values) {
      controller.dispose();
    }
    _tabPageConfigRevision.dispose();
    _shortcutFocusNode.dispose();
    super.dispose();
  }

  int get _effectiveIndex => _targetIndex;

  /// 窄窗口且至少有两个可见 Tab 时才有底栏：只剩日记时没有可切换的页面，
  /// 一项的导航行没有意义。宽窗口没有底栏（侧边栏照常，新建按钮在栏顶）。
  bool get _hasBottomBar => !_wide && _tabs.length > 1;

  /// 目标 Tab（点击时立即更新，不等切页动画结束）。
  HomeTab get _effectiveTab => _tabs[_effectiveIndex];

  bool get _canUseGlobalCreateFab => !_isTabSwitching;

  bool _isValidTabIndex(int index) => index >= 0 && index < _tabs.length;

  /// 当前页在 PageView 中的显示下标（读不到页码时的退路）。
  int _currentDisplayIndex() => _pageOrder.displayIndexOf(_tabs[_currentIndex]);

  /// 切页编排（home_page_pager.dart）改状态的入口：`setState` 受保护，扩展
  /// 里不能直接调用。
  void _setPagerState(VoidCallback fn) => setState(fn);

  /// 取 [tab] 的页面，第一次用到时创建并缓存。
  Widget _pageFor(HomeTab tab) {
    return _pages.putIfAbsent(
      tab,
      () => _buildTabPage(
        tab,
        (context) => switch (tab) {
          // 页面底色与实色顶栏底色不在这里传：各页从包住它的
          // AppAreaBackdrop 读自己区域的背景（见 [_buildTabPage]）。
          HomeTab.diaries => DiariesPage(
            key: const PageStorageKey<String>('tab_diaries'),
            onCreateActionChanged: _diariesCreateActionChanged,
            onSearchActionChanged: _diariesSearchActionChanged,
            onFabVisibilityChanged: _diariesFabVisibilityChanged,
            onOpenSettings: _openSettings,
          ),
          HomeTab.todos => TodosPage(
            key: const PageStorageKey<String>('tab_todos'),
            onCreateActionChanged: _todosCreateActionChanged,
            onSelectionModeChanged: _todosSelectionChanged,
          ),
          HomeTab.calendar => const CalendarPage(
            key: PageStorageKey<String>('tab_calendar'),
          ),
          HomeTab.explore => const ExplorePage(
            key: PageStorageKey<String>('tab_explore'),
          ),
        },
      ),
    );
  }

  /// 保活 + 区域背景信息 + 独立主滚动控制器 + 配置变更时重建。
  ///
  /// 所有平台都让主列表继承该控制器（默认只有移动端继承），桌面端同样支持
  /// 回到顶部；主列表会对子树下发 PrimaryScrollController.none，内层纵向列表
  /// 不会误挂到这个控制器上。
  ///
  /// 背景本身由首页外层的 [AppPagedBackground] 统一画（随页位置插值）；
  /// 这里的 [AppAreaBackdrop] 只把这个 Tab 区域的页面底色、实色顶栏底色
  /// 交给页面，不画任何东西。
  Widget _buildTabPage(HomeTab tab, WidgetBuilder builder) {
    return KeepAlivePage(
      child: AppAreaBackdrop(
        area: tab.backgroundArea,
        child: PrimaryScrollController(
          controller: _tabScrollControllers.putIfAbsent(
            tab,
            ScrollController.new,
          ),
          automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
          child: ValueListenableBuilder<int>(
            valueListenable: _tabPageConfigRevision,
            builder: (context, _, __) => builder(context),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final windowWidth = MediaQuery.sizeOf(context).width;
    _wide = AppBreakpoints.classOf(windowWidth).isWide;
    _tabsUseSnapshots = !_wide && !ExpressiveMotion.reduceMotion(context);
    // 变成宽窗口或开启减少动画：不再按快照画（各页 build 时随之换回实时）。
    if (!_tabsUseSnapshots && _snapshotHold.value) {
      _releaseSnapshots();
    }

    final baseTheme = Theme.of(context);
    final snackBarTheme = baseTheme.snackBarTheme.copyWith(
      insetPadding: _wide
          ? _wideSnackBarInset(context, windowWidth)
          : const EdgeInsets.fromLTRB(
              _snackBarSideInset,
              0,
              _snackBarSideInset,
              AppSpacing.l,
            ),
    );
    // 功能管理开关变化（设置页写入、备份恢复）时在这里对齐可见 Tab，
    // 必须早于下面按 [_tabs] 组装底栏与页面。
    _controller.syncVisibleTabs(
      visibleHomeTabs(ref.watch(appFeaturesProvider)),
    );
    final l10n = context.l10n;
    final navItems = <BottomNavItem>[
      for (final tab in _tabs)
        BottomNavItem(label: tab.label(l10n), icon: tab.icon),
    ];

    // 首页栏外观：主题、高对比度或用户样式变化时解析一次，经
    // HomeChromeScope 交给底栏与各 Tab 的顶栏。
    final barStyle = HomeBarResolvedStyle.resolve(
      ref.watch(homeBarStyleProvider),
      baseTheme.colorScheme,
      highContrast: MediaQuery.highContrastOf(context),
    );
    final barBehavior = ref.watch(homeBarBehaviorProvider);
    // 关闭“滚动时隐藏”时直接复位隐藏态（正在 build，随后的组装读的就是
    // 新值，不需要 setState）；重新开启后从显示状态开始。
    // 没有底栏（宽窗口、只剩日记一个 Tab）时“滚动时隐藏”不生效。
    _barHideOnScrollEnabled = _hasBottomBar && barBehavior.hideOnScroll;
    if (!_barHideOnScrollEnabled && _barHiddenByScroll) {
      _barHiddenByScroll = false;
      _barScrollHider.reset();
    }

    // 别的页面请求切到某个 Tab（预览页里点日记本胶囊、AI 助手的“前往”）。
    ref.listen<HomeTabRequest>(homeTabRequestProvider, (_, request) {
      unawaited(_controller.switchToHomeTab(request.tab));
    });

    // AI 的前往卡片把对话页关掉、回到了首页：等首页成为当前页（上锁的
    // 日记本要先验证）再提示一次可以回到对话。
    ref.listen<String?>(aiChatReturnProvider, (String? previous, String? next) {
      if (next == null) {
        _aiReturnHint.cancel();
        return;
      }
      if (next == previous) return;
      _aiReturnHint.start(
        isCurrent: () =>
            mounted && (ModalRoute.of(context)?.isCurrent ?? false),
        show: () {
          if (mounted) showAiChatReturnSnackBar(context, ref);
        },
      );
    });

    return _buildHomeShell(
      baseTheme: baseTheme,
      snackBarTheme: snackBarTheme,
      navItems: navItems,
      barStyle: barStyle,
      barBehavior: barBehavior,
    );
  }

  Widget _buildHomeShell({
    required ThemeData baseTheme,
    required SnackBarThemeData snackBarTheme,
    required List<BottomNavItem> navItems,
    required HomeBarResolvedStyle barStyle,
    required HomeBarBehavior barBehavior,
  }) {
    final wide = _wide;
    final hasBottomBar = _hasBottomBar;
    // 并排新建按钮要有底栏才放得下；其余窄窗口（含没有底栏时）保留浮在
    // 底栏上方的全局 FAB。宽窗口两者都没有，新建按钮在侧边栏顶部。
    final inlineCreate =
        hasBottomBar && barStyle.fabPlacement == HomeBarFabPlacement.inline;
    // 页面区挂在 GlobalKey 下：窄 / 宽外壳把它放在不同父级，跨过 600 时原样
    // 搬家，不重建 PageView 与保活的 Tab 页面。窄窗口下 KeyedSubtree 不产生
    // 渲染对象，树与改版前等价。
    final content = KeyedSubtree(
      key: _contentKey,
      child: Stack(
        children: [
          // 监听器始终挂着（关闭时直接放行）：按开关增删这一层会让整个
          // PageView 连同保活的 Tab 页面重新挂载。
          NotificationListener<ScrollNotification>(
            onNotification: _handleScrollForBar,
            child: _buildPageView(),
          ),
          if (!wide && !inlineCreate) _buildGlobalCreateFab(barStyle),
        ],
      ),
    );
    // 包在 Scaffold 之上：各 Tab 页面（Scaffold 的 body）也要读到栏的外观。
    return HomeChromeScope(
      style: barStyle,
      behavior: barBehavior,
      wideShell: wide,
      child: Theme(
        data: baseTheme.copyWith(snackBarTheme: snackBarTheme),
        child: PopScope(
          // 目标 tab 会在点击时立即更新，返回键跟随目标态而不是动画前旧页。
          canPop: _effectiveTab == HomeTab.diaries,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              return;
            }
            // 待办页多选时由它自己的 PopScope 退出多选，这里不切 Tab。
            if (_effectiveTab == HomeTab.todos && _todosSelecting) return;
            // 是 AI 卡片带过来的：返回回到那段对话（日记页由它自己的
            // PopScope 处理，先让它退出多选、收起标签栏）。
            if (_effectiveTab != HomeTab.diaries &&
                ref.read(aiChatReturnProvider) != null) {
              unawaited(reopenAiChat(context, ref));
              return;
            }
            // 其他 tab 按返回时先切回日记页，避免直接退出应用。
            unawaited(_controller.switchToDiariesTab());
          },
          child: _wrapShortcuts(
            // 各 Tab 区域的背景画在整个首页 Scaffold 下面（键盘弹出时不动），
            // 按 PageView 的页位置在相邻 Tab 之间插值；宽窗口跳页时交叉淡入。
            // 没有任何 Tab 设背景时只插入不绘制的节点，与接入前一致。
            // 区域按显示序给：跨页折叠时只在真正相邻的两页之间插值，不会
            // 掠过中间页的背景。
            AppPagedBackground(
              areas: <AppBackgroundArea>[
                for (final tab in _pageOrder.order) tab.backgroundArea,
              ],
              current: _pageOrder.displayIndexOf(_effectiveTab),
              position: _displayPosition,
              interpolate: !wide,
              // 景深切页途中各页连同自己区域的背景缩成不透明卡片、缝隙铺
              // 舞台色，背景层被整个盖住，不必再画相邻两区的插值。
              occludedWhileMoving: _tabsUseSnapshots,
              // Builder：Scaffold 底色要从背景组件之下的 context 读——背景层
              // 在画时首页 Scaffold 透明，否则仍是主题页面底色。
              child: Builder(
                // 悬浮底栏与新建按钮都叠在列表下缘、互不重叠，经同一个
                // BackdropGroup 共用一次背景读取（两者都 grouped）：原先
                // 各读一次，滑动时多一次整片回读。
                builder: (BuildContext context) => BackdropGroup(
                  child: Scaffold(
                    backgroundColor: AppPagedBackground.shellColorOf(context),
                    resizeToAvoidBottomInset: false,
                    // 底栏悬浮在内容之上：内容延伸到屏幕底部，从胶囊下方
                    // 透出。没有底栏时内容止于窗口底部。
                    extendBody: hasBottomBar,
                    body: wide
                        ? _buildWideBody(
                            navItems: navItems,
                            barStyle: barStyle,
                            content: content,
                          )
                        : content,
                    bottomNavigationBar: !hasBottomBar
                        ? null
                        : _buildBottomBar(
                            navItems: navItems,
                            barStyle: barStyle,
                            barBehavior: barBehavior,
                            inlineCreate: inlineCreate,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 首页内容的纵向滚动 → 底栏显隐（判定规则见 [HomeBarScrollHider]）。
  /// 只读不拦截：始终返回 false，通知继续向上冒泡。
  bool _handleScrollForBar(ScrollNotification notification) {
    if (!_barHideOnScrollEnabled) {
      return false;
    }
    final hidden = _barScrollHider.handle(notification);
    if (hidden != null) {
      _setBarHiddenByScroll(hidden);
    }
    return false;
  }

  /// 只在值变化时 setState，滚动中每帧的通知不会引起多余的重建。
  void _setBarHiddenByScroll(bool hidden) {
    if (!mounted || _barHiddenByScroll == hidden) {
      return;
    }
    setState(() => _barHiddenByScroll = hidden);
  }

  /// 首页出现提示时让底栏回来：提示排在底栏槽位上方，底栏收起会让提示
  /// 悬在半空。
  void _handleHomeHintVisibility() {
    if (widget.homeHintVisibleListenable.value) {
      _barScrollHider.reset();
      _setBarHiddenByScroll(false);
    }
  }

  /// 离整页不到这么多页时按整页算可见区间：弹簧落位时的过冲不到 1 像素，
  /// 不为这一丝露出唤醒隔壁页的 ticker（折叠途中隔壁正是不该出现的中间页）。
  static const double _visiblePageSlack = 1e-3;

  /// 根据 PageView 的实时位置更新可见 Tab 区间（显示下标）；只有区间变化才
  /// 重建。
  void _syncVisibleTabs() {
    final controller = _controller.pageController;
    final fallback = _currentDisplayIndex().toDouble();
    var page = controller.hasClients ? (controller.page ?? fallback) : fallback;
    final whole = page.roundToDouble();
    if ((page - whole).abs() < _visiblePageSlack) {
      page = whole;
    }
    final next = _VisibleTabRange(page.floor(), page.ceil());
    if (next != _visibleTabs.value) {
      _visibleTabs.value = next;
    }
    if (next.first != next.last) {
      if (_tabsUseSnapshots) _holdSnapshots();
    } else if (_snapshotHold.value) {
      _scheduleSnapshotRelease();
    } else {
      // 没有保持（实时绘制的切页）：落定这一帧就是实时画的。
      _markSettledTabReady();
    }
  }

  /// 宽窗口提示的外边距：最宽 [_wideSnackBarMaxWidth]，在侧边栏另一侧的
  /// 内容区居中（两侧至少 16），离底 [_wideSnackBarBottomInset]。用外边距而
  /// 不是 SnackBar 的 width：width 会按整个 Scaffold（含侧边栏）居中，且
  /// SnackBar 不允许 width 与 margin 同时设置。
  EdgeInsets _wideSnackBarInset(BuildContext context, double windowWidth) {
    final contentWidth = math.max(0.0, windowWidth - AppContentWidth.navRail);
    final side = AppContentWidth.gutter(
      contentWidth,
      _wideSnackBarMaxWidth,
      minGutter: _snackBarSideInset,
    );
    final start = AppContentWidth.navRail + side;
    final ltr = Directionality.of(context) == TextDirection.ltr;
    return EdgeInsets.fromLTRB(
      ltr ? start : side,
      0,
      ltr ? side : start,
      _wideSnackBarBottomInset,
    );
  }

  /// 日记页随滚动显隐 FAB（下滑收起、上滑或回到顶部时出现）。
  void _handleFabVisibilityChanged(bool visible) {
    if (_diariesFabVisibleByScroll == visible) {
      return;
    }
    setState(() => _diariesFabVisibleByScroll = visible);
  }

  /// 全局 FAB / 玻璃底栏并排按钮：日记 Tab 新建日记，待办 Tab 新建待办。
  Future<void> _openCreateFromGlobalFab() async {
    if (!_canUseGlobalCreateFab) {
      return;
    }
    switch (_effectiveTab) {
      case HomeTab.diaries:
        await _openCreate();
      case HomeTab.todos:
        await _todosCreateAction?.call();
      case HomeTab.calendar || HomeTab.explore:
        return;
    }
  }

  /// 新建日记：优先交给日记页（它知道当前所在的日记本与章节）。侧边栏
  /// 按钮与快捷键在任何 Tab 都直接走这里——日记页被保活，不在可见 Tab
  /// 时它注册的入口照样可用。
  Future<void> _openCreate() async {
    final action = _diariesCreateAction;
    if (action != null) {
      await action();
      return;
    }

    // 日记页尚未注册入口（如首帧之前）：走同一条新建流程，不绕过草稿面板。
    await runDiaryCreateEntryFlow(context, ref);
  }
}

/// FAB 上的日记本名称最多显示的字符数（按 Unicode 字符计）：超出时截断加
/// 省略号，320dp 宽的屏幕上按钮也不会过宽。
const int _fabNotebookNameMaxChars = 6;

/// 截短日记本名称供 FAB 使用（“写进「一二三四五六…」”）。
@visibleForTesting
String shortNotebookName(String name) {
  final runes = name.trim().runes.toList();
  if (runes.length <= _fabNotebookNameMaxChars) {
    return name.trim();
  }
  return '${String.fromCharCodes(runes.take(_fabNotebookNameMaxChars))}…';
}

/// 可见 Tab 的闭区间 [first, last]；静止时两端相同，滑动途中跨两页。
@immutable
class _VisibleTabRange {
  const _VisibleTabRange(this.first, this.last);

  final int first;
  final int last;

  bool contains(int index) => index >= first && index <= last;

  @override
  bool operator ==(Object other) =>
      other is _VisibleTabRange && other.first == first && other.last == last;

  @override
  int get hashCode => Object.hash(first, last);
}
