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
import 'package:node_diary/ui/settings/pages/settings_page.dart';
import 'package:node_diary/core/services/settings_service.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/bottom_nav.dart';
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

  // 页面切换状态。
  int _currentIndex = 0;
  int _targetIndex = 0;
  int _tabSwitchGeneration = 0;
  bool _isTabSwitching = false;
  String? _shownStartupNotice;
  final Map<int, Future<void> Function()> _createActionByTab =
      <int, Future<void> Function()>{};
  final Map<int, bool> _fabVisibleByTab = <int, bool>{0: true, 1: true};
  late final ValueNotifier<int> _tabPageConfigRevision;
  late final ValueChanged<Future<void> Function()?> _diariesCreateActionChanged;
  late final ValueChanged<Future<void> Function()?>
  _calendarCreateActionChanged;
  late final ValueChanged<bool> _diariesFabVisibilityChanged;
  late final ValueChanged<bool> _calendarFabVisibilityChanged;
  late final List<Widget> _pages;
  late final _HomePageController _controller;

  @override
  void initState() {
    super.initState();
    _tabPageConfigRevision = ValueNotifier<int>(0);
    _diariesCreateActionChanged = (action) {
      _handleCreateActionChanged(tabIndex: 0, action: action);
    };
    _calendarCreateActionChanged = (action) {
      _handleCreateActionChanged(tabIndex: 1, action: action);
    };
    _diariesFabVisibilityChanged = (visible) {
      _handleFabVisibilityChanged(tabIndex: 0, visible: visible);
    };
    _calendarFabVisibilityChanged = (visible) {
      _handleFabVisibilityChanged(tabIndex: 1, visible: visible);
    };
    _pages = _buildStablePages();
    _controller = _HomePageController(this);
    _controller.init();
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
    _controller.dispose();
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
    return <Widget>[
      KeepAlivePage(
        child: ValueListenableBuilder<int>(
          valueListenable: _tabPageConfigRevision,
          builder: (context, _, __) {
            return DiariesPage(
              key: const PageStorageKey<String>('tab_diaries'),
              pageBackgroundColor: Theme.of(context).colorScheme.surface,
              onCreateActionChanged: _diariesCreateActionChanged,
              onFabVisibilityChanged: _diariesFabVisibilityChanged,
            );
          },
        ),
      ),
      KeepAlivePage(
        child: ValueListenableBuilder<int>(
          valueListenable: _tabPageConfigRevision,
          builder: (context, _, __) {
            return CalendarPage(
              key: const PageStorageKey<String>('tab_calendar'),
              pageBackgroundColor: Theme.of(context).colorScheme.surface,
              onCreateActionChanged: _calendarCreateActionChanged,
              onFabVisibilityChanged: _calendarFabVisibilityChanged,
            );
          },
        ),
      ),
      KeepAlivePage(
        child: ValueListenableBuilder<int>(
          valueListenable: _tabPageConfigRevision,
          builder: (context, _, __) {
            return ExplorePage(
              key: const PageStorageKey<String>('tab_explore'),
              pageBackgroundColor: Theme.of(context).colorScheme.surface,
            );
          },
        ),
      ),
      KeepAlivePage(
        child: ValueListenableBuilder<int>(
          valueListenable: _tabPageConfigRevision,
          builder: (context, _, __) {
            return SettingsPage(
              key: const PageStorageKey<String>('tab_settings'),
              pageBackgroundColor: Theme.of(context).colorScheme.surface,
            );
          },
        ),
      ),
    ];
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
          bottomNavigationBar: BottomNav(
            items: navItems,
            selectedIndex: _effectiveIndex,
            onTap: _controller.onTap,
          ),
        ),
      ),
    );
  }

  Widget _buildPageView() {
    return PageView(
      controller: _controller.pageController,
      physics: _isTabSwitching
          ? const NeverScrollableScrollPhysics()
          : const PageScrollPhysics(),
      onPageChanged: _handlePageChanged,
      children: _pages,
    );
  }

  void _handleCreateActionChanged({
    required int tabIndex,
    required Future<void> Function()? action,
  }) {
    if (action == null) {
      _createActionByTab.remove(tabIndex);
      return;
    }
    _createActionByTab[tabIndex] = action;
  }

  void _handleFabVisibilityChanged({
    required int tabIndex,
    required bool visible,
  }) {
    final previous = _fabVisibleByTab[tabIndex];
    if (previous == visible) {
      return;
    }
    setState(() {
      _fabVisibleByTab[tabIndex] = visible;
    });
  }

  Future<void> _openCreateFromGlobalFab() async {
    if (!_canUseGlobalCreateFab) {
      return;
    }
    final effectiveIndex = _effectiveIndex;
    if (effectiveIndex != 0 && effectiveIndex != 1) {
      return;
    }
    final action = _createActionByTab[effectiveIndex];
    if (action != null) {
      await action();
      return;
    }
    if (effectiveIndex != 0) {
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
    final effectiveIndex = _effectiveIndex;
    final isCreateTab = effectiveIndex == 0 || effectiveIndex == 1;
    final followScrollVisibility = _fabVisibleByTab[effectiveIndex] ?? true;
    final shouldShow = isCreateTab && followScrollVisibility;
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
        );
      },
    );
  }
}
