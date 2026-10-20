import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/ui/calendar/pages/calendar_page.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/diaries/controllers/diary_create_entry_flow.dart';
import 'package:node_diary/ui/explore/pages/explore_page.dart';
import 'package:node_diary/ui/home/controllers/home_bar_scroll_hider.dart';
import 'package:node_diary/ui/home/controllers/page_position_listenable.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_behavior.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_resolved_style.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';
import 'package:node_diary/ui/home/models/home_tab.dart';
import 'package:node_diary/ui/home/providers/home_bar_settings_provider.dart';
import 'package:node_diary/ui/home/providers/home_tab_request_provider.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_bottom_bar.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_chrome_scope.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_floating_bar.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/notebooks/providers/home_notebook_scope_provider.dart';
import 'package:node_diary/ui/home/widgets/keep_alive_page.dart';
import 'package:node_diary/ui/settings/controllers/app_update_auto_check.dart';
import 'package:node_diary/ui/settings/providers/app_features_provider.dart';
import 'package:node_diary/ui/settings/pages/settings_page.dart';
import 'package:node_diary/core/services/settings_service.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/launch_reveal.dart';
part '../controllers/home_page_controller.dart';
part 'home_page_chrome.dart';

/// 主框架页：承载底部 Tab 导航（日记 / 日历 / 探索 / 设置）。
///
/// 日历与探索可在设置 → 功能管理中关闭，底栏随之变为 2–4 项（见
/// [visibleHomeTabs]）；当前页、目标页、FAB 与返回键一律按 [HomeTab] 身份判断，
/// 可见集合变化时由 `_HomePageController.syncVisibleTabs` 重新对齐下标。
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

  // 页面切换状态。下标都是在 [_tabs] 中的位置；[_tabs] 变化时由
  // `_HomePageController.syncVisibleTabs` 换算到新列表。
  late List<HomeTab> _tabs;
  int _currentIndex = 0;
  int _targetIndex = 0;
  int _tabSwitchGeneration = 0;
  bool _isTabSwitching = false;
  String? _shownStartupNotice;

  Future<void> Function()? _diariesCreateAction;
  bool _diariesFabVisibleByScroll = true;
  late final ValueNotifier<int> _tabPageConfigRevision;
  late final ValueChanged<Future<void> Function()?> _diariesCreateActionChanged;
  late final ValueChanged<bool> _diariesFabVisibilityChanged;
  late final _HomePageController _controller;

  /// 各 Tab 的页面，第一次出现在可见列表里时才创建；Tab 被关闭时移除，
  /// 页面随之销毁（不再监听数据库），重新开启时重新创建。
  final Map<HomeTab, Widget> _pages = <HomeTab, Widget>{};

  /// 当前（含滑动途中）可见的 Tab 区间，驱动各页的 TickerMode。
  late final ValueNotifier<_VisibleTabRange> _visibleTabs;

  /// 每个 Tab 独立的主滚动控制器，由 [_buildTabPage] 以 PrimaryScrollController
  /// 下发给该 Tab 的主列表；随页面按需创建，Tab 被关闭时在页面卸载后释放。
  ///
  /// 各 Tab 被 KeepAlivePage 同时保活，若都继承路由级 PrimaryScrollController，
  /// 同一个控制器会同时挂上多个滚动位置：“重复点击当前 Tab 回到顶部”会把所有
  /// Tab 一起滚动，读取 offset 也会断言。
  final Map<HomeTab, ScrollController> _tabScrollControllers =
      <HomeTab, ScrollController>{};

  /// PageView 小数页码的监听包装，开启“指示器跟随滑动”时交给底栏。
  late final PagePositionListenable _pagePosition;

  /// 玻璃底栏是否因“滚动时隐藏”而收起。
  ///
  /// 生命周期：只在玻璃材质且开启该行为时由 [_handleScrollForBar] 置为
  /// true；以下时机一律放回 false（并清空 [_barScrollHider] 的累计量）：
  /// - 切 Tab 开始或页码变化：新页面的滚动位置与收起时无关，导航必须可见；
  /// - 首页出现提示（SnackBar）：提示叠在底栏上方，底栏收起会让提示悬空；
  /// - 关闭该行为或离开玻璃材质：在 build 中直接复位，实色栏没有隐藏态。
  bool _barHiddenByScroll = false;

  /// 最近一次 build 时“滚动时隐藏底栏”是否生效（玻璃材质且开启该行为）；
  /// 滚动回调在 build 之外，读这里而不是重新解析样式。
  bool _barHideOnScrollEnabled = false;
  final HomeBarScrollHider _barScrollHider = HomeBarScrollHider();

  @override
  void initState() {
    super.initState();
    _tabPageConfigRevision = ValueNotifier<int>(0);
    _diariesCreateActionChanged = (action) => _diariesCreateAction = action;
    _diariesFabVisibilityChanged = _handleFabVisibilityChanged;
    // settings 在首页构建前已就绪（启动门槛），首帧即是真实的开关，不会先
    // 出现四个 Tab 再收起。
    _tabs = visibleHomeTabs(ref.read(appFeaturesProvider));
    _controller = _HomePageController(this);
    _controller.init();
    _visibleTabs = ValueNotifier<_VisibleTabRange>(
      _VisibleTabRange(_currentIndex, _currentIndex),
    );
    _controller.pageController.addListener(_syncVisibleTabs);
    _pagePosition = PagePositionListenable(
      _controller.pageController,
      () => _currentIndex,
    );
    widget.homeHintVisibleListenable.addListener(_handleHomeHintVisibility);
    _updateAutoChecker = AppUpdateAutoChecker(() async {
      if (mounted) {
        await runAutoUpdateCheck(context, ref);
      }
    })..start();
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
    _updateAutoChecker.dispose();
    widget.homeHintVisibleListenable.removeListener(_handleHomeHintVisibility);
    _pagePosition.dispose();
    _controller.pageController.removeListener(_syncVisibleTabs);
    _visibleTabs.dispose();
    _controller.dispose();
    for (final controller in _tabScrollControllers.values) {
      controller.dispose();
    }
    _tabPageConfigRevision.dispose();
    super.dispose();
  }

  int get _effectiveIndex => _targetIndex;

  /// 目标 Tab（点击时立即更新，不等切页动画结束）。
  HomeTab get _effectiveTab => _tabs[_effectiveIndex];

  bool get _canUseGlobalCreateFab => !_isTabSwitching;

  bool _isValidTabIndex(int index) => index >= 0 && index < _tabs.length;

  int _beginTabSwitch(int targetIndex) {
    if (!mounted || !_isValidTabIndex(targetIndex)) {
      return _tabSwitchGeneration;
    }
    _tabSwitchGeneration++;
    _barScrollHider.reset();
    setState(() {
      _targetIndex = targetIndex;
      _isTabSwitching = true;
      _barHiddenByScroll = false;
    });
    return _tabSwitchGeneration;
  }

  void _settleTabSwitch(int fallbackIndex, int generation) {
    if (!mounted || generation != _tabSwitchGeneration) {
      return;
    }
    final pageController = _controller.pageController;
    final page = pageController.hasClients ? pageController.page : null;
    final settledIndex = (page?.round() ?? fallbackIndex)
        .clamp(0, _tabs.length - 1)
        .toInt();
    setState(() {
      _currentIndex = settledIndex;
      _targetIndex = settledIndex;
      _isTabSwitching = false;
    });
  }

  void _handlePageChanged(int index) {
    if (!_isValidTabIndex(index)) {
      return;
    }
    _barScrollHider.reset();
    setState(() {
      _currentIndex = index;
      if (!_isTabSwitching) {
        _targetIndex = index;
      }
      _barHiddenByScroll = false;
    });
  }

  /// 取 [tab] 的页面，第一次用到时创建并缓存。
  Widget _pageFor(HomeTab tab) {
    return _pages.putIfAbsent(
      tab,
      () => _buildTabPage(
        tab,
        (context) => switch (tab) {
          HomeTab.diaries => DiariesPage(
            key: const PageStorageKey<String>('tab_diaries'),
            pageBackgroundColor: Theme.of(context).colorScheme.surface,
            onCreateActionChanged: _diariesCreateActionChanged,
            onFabVisibilityChanged: _diariesFabVisibilityChanged,
          ),
          HomeTab.calendar => CalendarPage(
            key: const PageStorageKey<String>('tab_calendar'),
            pageBackgroundColor: Theme.of(context).colorScheme.surface,
          ),
          HomeTab.explore => ExplorePage(
            key: const PageStorageKey<String>('tab_explore'),
            pageBackgroundColor: Theme.of(context).colorScheme.surface,
          ),
          HomeTab.settings => SettingsPage(
            key: const PageStorageKey<String>('tab_settings'),
            pageBackgroundColor: Theme.of(context).colorScheme.surface,
          ),
        },
      ),
    );
  }

  /// 保活 + 独立主滚动控制器 + 配置变更时重建。
  ///
  /// 所有平台都让主列表继承该控制器（默认只有移动端继承），桌面端同样支持
  /// 回到顶部；主列表会对子树下发 PrimaryScrollController.none，内层纵向列表
  /// 不会误挂到这个控制器上。
  Widget _buildTabPage(HomeTab tab, WidgetBuilder builder) {
    return KeepAlivePage(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final snackBarBottomInset = AppSpacing.l;

    final baseTheme = Theme.of(context);
    final snackBarTheme = baseTheme.snackBarTheme.copyWith(
      insetPadding: EdgeInsets.fromLTRB(
        _snackBarSideInset,
        0,
        _snackBarSideInset,
        snackBarBottomInset,
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
    // 关闭“滚动时隐藏”或离开玻璃材质时直接复位隐藏态（正在 build，随后的
    // 组装读的就是新值，不需要 setState）；重新开启后从显示状态开始。
    _barHideOnScrollEnabled = barStyle.isGlass && barBehavior.hideOnScroll;
    if (!_barHideOnScrollEnabled && _barHiddenByScroll) {
      _barHiddenByScroll = false;
      _barScrollHider.reset();
    }

    // 别的页面请求回到日记 Tab（预览页里点日记本胶囊）。
    ref.listen<int>(homeDiariesTabRequestProvider, (_, _) {
      unawaited(_controller.switchToDiariesTab());
    });

    final settingsService = ref.watch(settingsServiceProvider).asData?.value;
    if (settingsService == null) {
      _controller.pageSwitchCurve =
          SettingsService.defaultHomeTabSwitchCurveType.curve;
      return _buildHomeShell(
        baseTheme: baseTheme,
        snackBarTheme: snackBarTheme,
        navItems: navItems,
        barStyle: barStyle,
        barBehavior: barBehavior,
      );
    }

    return ValueListenableBuilder<HomeTabSwitchCurveType>(
      valueListenable: settingsService.homeTabSwitchCurveNotifier,
      builder:
          (
            BuildContext context,
            HomeTabSwitchCurveType curveType,
            Widget? child,
          ) {
            _controller.pageSwitchCurve = curveType.curve;
            return _buildHomeShell(
              baseTheme: baseTheme,
              snackBarTheme: snackBarTheme,
              navItems: navItems,
              barStyle: barStyle,
              barBehavior: barBehavior,
            );
          },
    );
  }

  Widget _buildHomeShell({
    required ThemeData baseTheme,
    required SnackBarThemeData snackBarTheme,
    required List<BottomNavItem> navItems,
    required HomeBarResolvedStyle barStyle,
    required HomeBarBehavior barBehavior,
  }) {
    // 并排新建按钮只属于玻璃底栏；其余情况保留浮在底栏上方的全局 FAB。
    final inlineCreate =
        barStyle.isGlass && barStyle.fabPlacement == HomeBarFabPlacement.inline;
    // 包在 Scaffold 之上：各 Tab 页面（Scaffold 的 body）也要读到栏的外观。
    return HomeChromeScope(
      style: barStyle,
      behavior: barBehavior,
      child: Theme(
        data: baseTheme.copyWith(snackBarTheme: snackBarTheme),
        child: PopScope(
          // 目标 tab 会在点击时立即更新，返回键跟随目标态而不是动画前旧页。
          canPop: _effectiveTab == HomeTab.diaries,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              return;
            }
            // 其他 tab 按返回时先切回日记页，避免直接退出应用。
            unawaited(_controller.switchToDiariesTab());
          },
          child: Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            resizeToAvoidBottomInset: false,
            // 玻璃底栏悬浮在内容之上：内容延伸到屏幕底部，从胶囊下方透出。
            extendBody: barStyle.isGlass,
            body: Stack(
              children: [
                // 监听器始终挂着（关闭时直接放行）：按开关增删这一层会让整个
                // PageView 连同保活的 Tab 页面重新挂载。
                NotificationListener<ScrollNotification>(
                  onNotification: _handleScrollForBar,
                  child: _buildPageView(),
                ),
                if (!inlineCreate) _buildGlobalCreateFab(barStyle),
              ],
            ),
            bottomNavigationBar: _buildBottomBar(
              navItems: navItems,
              barStyle: barStyle,
              barBehavior: barBehavior,
              inlineCreate: inlineCreate,
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

  Widget _buildPageView() {
    return ValueListenableBuilder<_VisibleTabRange>(
      valueListenable: _visibleTabs,
      builder: (BuildContext context, _VisibleTabRange visible, Widget? _) {
        return PageView(
          controller: _controller.pageController,
          physics: _isTabSwitching
              ? const NeverScrollableScrollPhysics()
              : const PageScrollPhysics(),
          onPageChanged: _handlePageChanged,
          children: <Widget>[
            for (var index = 0; index < _tabs.length; index++)
              // 被保活但不可见的 Tab 静音 ticker：其中仍在播放或循环的动画
              // （加载指示、入场动画等）不再在后台逐帧出帧；切回来时从当前
              // 时刻续上。滑动途中两侧页面都启用，不会冻结半露出的内容。
              // 同理关闭不可见 Tab 的 Hero：各 Tab 同属一个路由，否则从日历
              // 打开预览时，会从后台日记列表里同一篇的封面飞出来。
              //
              // 最外层以 Tab 身份为 key：关闭日历 / 探索后其余 Tab 的下标会
              // 前移，PageView 的列表代理按 key 把已有页面搬到新下标，保活的
              // 页面状态（滚动位置、筛选等）不会因为换了位置而重建。
              TickerMode(
                key: ValueKey<HomeTab>(_tabs[index]),
                enabled: visible.contains(index),
                child: HeroMode(
                  enabled: visible.contains(index),
                  child: _pageFor(_tabs[index]),
                ),
              ),
          ],
        );
      },
    );
  }

  /// 根据 PageView 的实时位置更新可见 Tab 区间；只有区间变化才重建。
  void _syncVisibleTabs() {
    final controller = _controller.pageController;
    final page = controller.hasClients
        ? (controller.page ?? _currentIndex.toDouble())
        : _currentIndex.toDouble();
    final next = _VisibleTabRange(page.floor(), page.ceil());
    if (next != _visibleTabs.value) {
      _visibleTabs.value = next;
    }
  }

  /// 日记页随滚动显隐 FAB（下滑收起、上滑或回到顶部时出现）。
  void _handleFabVisibilityChanged(bool visible) {
    if (_diariesFabVisibleByScroll == visible) {
      return;
    }
    setState(() => _diariesFabVisibleByScroll = visible);
  }

  Future<void> _openCreateFromGlobalFab() async {
    if (!_canUseGlobalCreateFab || _effectiveTab != HomeTab.diaries) {
      return;
    }
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
