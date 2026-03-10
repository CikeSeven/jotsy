import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/calendar/pages/calendar_page.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/explore/pages/explore_page.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/home/widgets/keep_alive_page.dart';
import 'package:node_diary/ui/settings/pages/settings_page.dart';

import '../../widgets/glass_bottom_nav.dart';

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
  static const _animDuration = Duration(milliseconds: 270);
  static const _animCurve = Curves.easeOutCirc;
  static const double _snackBarSideInset = 16;

  late final PageController _pageController;
  String? _shownStartupNotice;
  int _currentIndex = 0;
  double _pageProgress = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _pageController.addListener(_onPageScroll);
    _showStartupNoticeIfNeeded();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startupNotice != widget.startupNotice) {
      _showStartupNoticeIfNeeded();
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }

  void _onPageScroll() {
    final value = _pageController.page ?? _currentIndex.toDouble();
    if ((value - _pageProgress).abs() < 0.0001) {
      return;
    }
    setState(() {
      _pageProgress = value;
    });
  }

  void _onTap(int index) {
    if (index == _currentIndex) {
      return;
    }
    _pageController.animateToPage(
      index,
      duration: _animDuration,
      curve: _animCurve,
    );
  }

  void _showStartupNoticeIfNeeded() {
    final notice = widget.startupNotice?.trim();
    if (notice == null || notice.isEmpty || notice == _shownStartupNotice) {
      return;
    }
    _shownStartupNotice = notice;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(() async {
        await HomeHintVisibilityScope.showTrackedSnackBar(
          context: context,
          snackBar: SnackBar(
            content: Text(notice),
            duration: const Duration(seconds: 2),
          ),
        );
      }());
    });
  }

  Widget _buildPageView(List<Widget> pages) {
    return PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      onPageChanged: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      children: pages,
    );
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
        ),
      ),
      const KeepAlivePage(
        child: CalendarPage(key: PageStorageKey<String>('tab_calendar')),
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
                onTap: _onTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
