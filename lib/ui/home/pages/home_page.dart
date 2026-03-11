import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/calendar/pages/calendar_page.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/explore/pages/explore_page.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/home/widgets/keep_alive_page.dart';
import 'package:node_diary/ui/settings/pages/settings_page.dart';

import '../../../app/theme/app_spacing.dart';
import '../../widgets/glass_bottom_nav.dart';
part '../controllers/home_page_controller.dart';

/// 主框架页：承载底部四栏导航（日记/日历/探索/设置）。
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.startupNotice,
    required this.homeHintVisibleListenable,
  });

  final String? startupNotice;
  final ValueListenable<bool> homeHintVisibleListenable;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // SnackBar 左右留白，统一 Home 内提示视觉。
  static const double _snackBarSideInset = 16;
  static const Duration _fabVisibilityDuration = Duration(milliseconds: 320);
  static const Duration _fabLiftDuration = Duration(milliseconds: 260);
  static const Curve _fabVisibilityCurve = Curves.easeOutCubic;
  static const Curve _fabLiftCurve = Curves.easeOutCubic;
  static const double _fabBottomGapAboveNav = 2;
  static const double _fabLiftOffsetWhenHintVisible = 60;

  // 页面切换状态。
  int _currentIndex = 0;
  double _pageProgress = 0;
  String? _shownStartupNotice;
  final Map<int, Future<void> Function()> _createActionByTab =
      <int, Future<void> Function()>{};
  late final HomePageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HomePageController(this);
    _controller.init();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.handleWidgetUpdate(oldWidget);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafeInset = MediaQuery.paddingOf(context).bottom;
    final snackBarBottomInset =
        bottomSafeInset +
        GlassBottomNav.navHeight;

    final baseTheme = Theme.of(context);
    final colorScheme = baseTheme.colorScheme;
    final snackBarTheme = baseTheme.snackBarTheme.copyWith(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colorScheme.surfaceContainerHigh.withValues(alpha: 0.96),
      contentTextStyle: baseTheme.textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurface,
      ),
      actionTextColor: colorScheme.primary,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      insetPadding: EdgeInsets.fromLTRB(
        _snackBarSideInset,
        0,
        _snackBarSideInset,
        snackBarBottomInset,
      ),
    );

    final pages = <Widget>[
      KeepAlivePage(
        child: DiariesPage(
          key: const PageStorageKey('tab_diaries'),
          homeHintVisibleListenable: widget.homeHintVisibleListenable,
          onCreateActionChanged: (action) {
            _handleCreateActionChanged(tabIndex: 0, action: action);
          },
        ),
      ),
      KeepAlivePage(
        child: CalendarPage(
          key: const PageStorageKey<String>('tab_calendar'),
          onCreateActionChanged: (action) {
            _handleCreateActionChanged(tabIndex: 1, action: action);
          },
        ),
      ),
      const KeepAlivePage(
        child: ExplorePage(key: PageStorageKey<String>('tab_explore')),
      ),
      const KeepAlivePage(
        child: SettingsPage(key: PageStorageKey<String>('tab_settings')),
      ),
    ];

    final navItems = [
      GlassBottomNavItem(
        label: '日记',
        icon: FontAwesomeIcons.bars,
      ),
      GlassBottomNavItem(
        label: '日历',
        icon: FontAwesomeIcons.calendar,
      ),
      GlassBottomNavItem(
        label: '探索',
        icon: FontAwesomeIcons.compass,
      ),
      GlassBottomNavItem(
        label: '设置',
        icon: FontAwesomeIcons.gear,
      ),
    ];

    return Theme(
      data: baseTheme.copyWith(snackBarTheme: snackBarTheme),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            _buildPageView(pages),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GlassBottomNav(
                items: navItems,
                selectedIndex: _currentIndex,
                pageProgress: _pageProgress,
                onTap: _controller.onTap,
              ),
            ),
            _buildGlobalCreateFab(bottomSafeInset),
          ],
        ),
      ),
    );
  }

  Widget _buildPageView(List<Widget> pages) {
    return PageView(
      controller: _controller.pageController,
      physics: const NeverScrollableScrollPhysics(),
      onPageChanged: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      children: pages,
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

  Future<void> _openCreateFromGlobalFab() async {
    final action = _createActionByTab[_currentIndex];
    if (action != null) {
      await action();
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const EditDiaryPage(
            entryMode: EditDiaryEntryMode.create,
          );
        },
      ),
    );
  }

  Widget _buildGlobalCreateFab(double bottomSafeInset) {
    final shouldShow = _currentIndex == 0 || _currentIndex == 1;
    final fabBaseBottomOffset =
        bottomSafeInset +
        GlassBottomNav.navBottomInset +
        GlassBottomNav.navHeight +
        _fabBottomGapAboveNav;

    return ValueListenableBuilder<bool>(
      valueListenable: widget.homeHintVisibleListenable,
      builder: (context, homeHintVisible, child) {
        final fabBottomOffset =
            fabBaseBottomOffset +
            (homeHintVisible ? _fabLiftOffsetWhenHintVisible : 0);
        return AnimatedPositioned(
          duration: _fabLiftDuration,
          curve: _fabLiftCurve,
          right: AppSpacing.xl,
          bottom: fabBottomOffset,
          child: IgnorePointer(
            ignoring: !shouldShow,
            child: AnimatedSlide(
              duration: _fabVisibilityDuration,
              curve: _fabVisibilityCurve,
              offset: shouldShow ? Offset.zero : const Offset(0, 1.6),
              child: AnimatedOpacity(
                duration: _fabVisibilityDuration,
                curve: _fabVisibilityCurve,
                opacity: shouldShow ? 1 : 0,
                child: FloatingActionButton(
                  onPressed: () {
                    unawaited(_openCreateFromGlobalFab());
                  },
                  child: const FaIcon(FontAwesomeIcons.plus),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
