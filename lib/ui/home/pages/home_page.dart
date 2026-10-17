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
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/explore/pages/explore_page.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/home/widgets/keep_alive_page.dart';
import 'package:node_diary/ui/settings/controllers/app_update_startup.dart';
import 'package:node_diary/ui/settings/pages/settings_page.dart';
import 'package:node_diary/core/services/settings_service.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/launch_reveal.dart';
part '../controllers/home_page_controller.dart';

/// 主框架页：承载底部四栏导航（日记/日历/探索/设置）。
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
  static const int _tabCount = 4;

  /// 冷启动后延迟多久自动检查更新：避开启动揭幕与首屏数据加载，不与首帧
  /// 争抢网络和主线程（非动画计时）。
  static const Duration _updateCheckDelay = Duration(seconds: 4);
  Timer? _updateCheckTimer;

  // 页面切换状态。
  int _currentIndex = 0;
  int _targetIndex = 0;
  int _tabSwitchGeneration = 0;
  bool _isTabSwitching = false;
  String? _shownStartupNotice;

  /// “新建”FAB 只属于日记页：日历页的日期长按菜单已能在任意一天写日记或
  /// 时间胶囊，再叠一个 FAB 会挡住当天日记列表的末尾。
  static const int _createTabIndex = 0;

  Future<void> Function()? _diariesCreateAction;
  bool _diariesFabVisibleByScroll = true;
  late final ValueNotifier<int> _tabPageConfigRevision;
  late final ValueChanged<Future<void> Function()?> _diariesCreateActionChanged;
  late final ValueChanged<bool> _diariesFabVisibilityChanged;
  late final List<Widget> _pages;
  late final _HomePageController _controller;

  /// 当前（含滑动途中）可见的 Tab 区间，驱动各页的 TickerMode。
  late final ValueNotifier<_VisibleTabRange> _visibleTabs;

  /// 每个 Tab 独立的主滚动控制器，由 [_buildTabPage] 以 PrimaryScrollController
  /// 下发给该 Tab 的主列表。
  ///
  /// 四个 Tab 被 KeepAlivePage 同时保活，若都继承路由级 PrimaryScrollController，
  /// 同一个控制器会同时挂上 4 个滚动位置：“重复点击当前 Tab 回到顶部”会把所有
  /// Tab 一起滚动，读取 offset 也会断言。
  final List<ScrollController> _tabScrollControllers =
      List<ScrollController>.generate(_tabCount, (_) => ScrollController());

  @override
  void initState() {
    super.initState();
    _tabPageConfigRevision = ValueNotifier<int>(0);
    _diariesCreateActionChanged = (action) => _diariesCreateAction = action;
    _diariesFabVisibilityChanged = _handleFabVisibilityChanged;
    _pages = _buildStablePages();
    _controller = _HomePageController(this);
    _controller.init();
    _visibleTabs = ValueNotifier<_VisibleTabRange>(
      _VisibleTabRange(_currentIndex, _currentIndex),
    );
    _controller.pageController.addListener(_syncVisibleTabs);
    _updateCheckTimer = Timer(_updateCheckDelay, () {
      _updateCheckTimer = null;
      if (mounted) {
        unawaited(runStartupUpdateCheck(context, ref));
      }
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
      _tabPageConfigRevision.value++;
    }
    _controller.handleWidgetUpdate(oldWidget);
  }

  @override
  void dispose() {
    _updateCheckTimer?.cancel();
    _controller.pageController.removeListener(_syncVisibleTabs);
    _visibleTabs.dispose();
    _controller.dispose();
    for (final controller in _tabScrollControllers) {
      controller.dispose();
    }
    _tabPageConfigRevision.dispose();
    super.dispose();
  }

  int get _effectiveIndex => _targetIndex;

  bool get _canUseGlobalCreateFab => !_isTabSwitching;

  bool _isValidTabIndex(int index) => index >= 0 && index < _pages.length;

  int _beginTabSwitch(int targetIndex) {
    if (!mounted || !_isValidTabIndex(targetIndex)) {
      return _tabSwitchGeneration;
    }
    _tabSwitchGeneration++;
    setState(() {
      _targetIndex = targetIndex;
      _isTabSwitching = true;
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
        .clamp(0, _pages.length - 1)
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
    setState(() {
      _currentIndex = index;
      if (!_isTabSwitching) {
        _targetIndex = index;
      }
    });
  }

  List<Widget> _buildStablePages() {
    final pages = <Widget>[
      _buildTabPage(
        0,
        (context) => DiariesPage(
          key: const PageStorageKey<String>('tab_diaries'),
          pageBackgroundColor: Theme.of(context).colorScheme.surface,
          onCreateActionChanged: _diariesCreateActionChanged,
          onFabVisibilityChanged: _diariesFabVisibilityChanged,
        ),
      ),
      _buildTabPage(
        1,
        (context) => CalendarPage(
          key: const PageStorageKey<String>('tab_calendar'),
          pageBackgroundColor: Theme.of(context).colorScheme.surface,
        ),
      ),
      _buildTabPage(
        2,
        (context) => ExplorePage(
          key: const PageStorageKey<String>('tab_explore'),
          pageBackgroundColor: Theme.of(context).colorScheme.surface,
        ),
      ),
      _buildTabPage(
        3,
        (context) => SettingsPage(
          key: const PageStorageKey<String>('tab_settings'),
          pageBackgroundColor: Theme.of(context).colorScheme.surface,
        ),
      ),
    ];
    assert(pages.length == _tabCount);
    return pages;
  }

  /// 保活 + 独立主滚动控制器 + 配置变更时重建。
  ///
  /// 所有平台都让主列表继承该控制器（默认只有移动端继承），桌面端同样支持
  /// 回到顶部；主列表会对子树下发 PrimaryScrollController.none，内层纵向列表
  /// 不会误挂到这个控制器上。
  Widget _buildTabPage(int index, WidgetBuilder builder) {
    return KeepAlivePage(
      child: PrimaryScrollController(
        controller: _tabScrollControllers[index],
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
    final navItems = [
      BottomNavItem(
        label: context.l10n.navDiaries,
        icon: FontAwesomeIcons.solidRectangleList,
      ),
      BottomNavItem(
        label: context.l10n.navCalendar,
        icon: FontAwesomeIcons.solidCalendar,
      ),
      BottomNavItem(
        label: context.l10n.navExplore,
        icon: FontAwesomeIcons.solidCompass,
      ),
      BottomNavItem(
        label: context.l10n.navSettings,
        icon: FontAwesomeIcons.gear,
      ),
    ];

    final settingsService = ref.watch(settingsServiceProvider).asData?.value;
    if (settingsService == null) {
      _controller.pageSwitchCurve =
          SettingsService.defaultHomeTabSwitchCurveType.curve;
      return _buildHomeShell(
        baseTheme: baseTheme,
        snackBarTheme: snackBarTheme,
        navItems: navItems,
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
            );
          },
    );
  }

  Widget _buildHomeShell({
    required ThemeData baseTheme,
    required SnackBarThemeData snackBarTheme,
    required List<BottomNavItem> navItems,
  }) {
    return Theme(
      data: baseTheme.copyWith(snackBarTheme: snackBarTheme),
      child: PopScope(
        // 目标 tab 会在点击时立即更新，返回键跟随目标态而不是动画前旧页。
        canPop: _effectiveIndex == 0,
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
          body: Stack(children: [_buildPageView(), _buildGlobalCreateFab()]),
          bottomNavigationBar: LaunchReveal(
            slot: LaunchRevealSlot.navigation,
            child: BottomNav(
              items: navItems,
              selectedIndex: _effectiveIndex,
              onTap: _controller.onTap,
            ),
          ),
        ),
      ),
    );
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
            for (var index = 0; index < _pages.length; index++)
              // 被保活但不可见的 Tab 静音 ticker：其中仍在播放或循环的动画
              // （加载指示、入场动画等）不再在后台逐帧出帧；切回来时从当前
              // 时刻续上。滑动途中两侧页面都启用，不会冻结半露出的内容。
              // 同理关闭不可见 Tab 的 Hero：四个 Tab 同属一个路由，否则从日历
              // 打开预览时，会从后台日记列表里同一篇的封面飞出来。
              TickerMode(
                enabled: visible.contains(index),
                child: HeroMode(
                  enabled: visible.contains(index),
                  child: _pages[index],
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
    if (!_canUseGlobalCreateFab || _effectiveIndex != _createTabIndex) {
      return;
    }
    final action = _diariesCreateAction;
    if (action != null) {
      await action();
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const EditDiaryPage(entryMode: EditDiaryEntryMode.create);
        },
      ),
    );
  }

  Widget _buildGlobalCreateFab() {
    final shouldShow =
        _effectiveIndex == _createTabIndex && _diariesFabVisibleByScroll;
    final fabBaseBottomOffset = _fabBottomGapAboveNav;

    final hintExtent = HomeHintVisibilityScope.maybeController(
      context,
    )?.hintExtentNotifier;
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable?>[
        widget.homeHintVisibleListenable,
        hintExtent,
      ]),
      builder: (context, child) {
        final homeHintVisible = widget.homeHintVisibleListenable.value;
        // 上移量取“实测提示高度 + 间隙”与默认值的较大者：双行提示或大字号
        // 时 SnackBar 更高，固定 60dp 会让 FAB 压在提示上。
        final measuredLift =
            (hintExtent?.value ?? 0) + _fabGapAboveHint - fabBaseBottomOffset;
        final fabBottomOffset =
            fabBaseBottomOffset +
            (homeHintVisible
                ? math.max(_fabLiftOffsetWhenHintVisible, measuredLift)
                : 0);
        return AnimatedPositioned(
          duration: ExpressiveMotion.duration(context, _fabLiftDuration),
          curve: _fabLiftCurve,
          right: AppSpacing.xl,
          bottom: fabBottomOffset,
          child: IgnorePointer(
            ignoring: !shouldShow || !_canUseGlobalCreateFab,
            child: AnimatedSlide(
              duration: ExpressiveMotion.duration(
                context,
                _fabVisibilityDuration,
              ),
              curve: ExpressiveMotion.spatial,
              offset: shouldShow ? Offset.zero : const Offset(0, 1.6),
              child: AnimatedOpacity(
                duration: ExpressiveMotion.duration(
                  context,
                  _fabVisibilityDuration,
                ),
                curve: _fabVisibilityCurve,
                opacity: shouldShow ? 1 : 0,
                child: LaunchReveal(
                  slot: LaunchRevealSlot.action,
                  child: FloatingActionButton.extended(
                    onPressed: () {
                      unawaited(_openCreateFromGlobalFab());
                    },
                    icon: const FaIcon(FontAwesomeIcons.plus, size: 20),
                    label: Text(context.l10n.commonNew),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
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
