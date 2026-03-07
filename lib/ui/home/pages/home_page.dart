import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/calendar/pages/calendar_page.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/home/widgets/keep_alive_page.dart';
import 'package:node_diary/ui/settings/pages/settings_page.dart';

import '../../widgets/glass_bottom_nav.dart';

/// 主框架页：承载底部三栏导航（列表/日历/设置）。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 动画属性
  static const _animDuration = Duration(milliseconds: 270);
  static const _animCurve = Curves.easeOutCirc;

  /// 当前选中的底部导航索引。
  late final PageController _pageController;
  int _currentIndex = 0;
  double _pageProgress = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _pageController.addListener(_onPageScroll);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }

  // 监听滚动进度
  void _onPageScroll() {
    final value = _pageController.page ?? _currentIndex.toDouble();
    if ((value - _pageProgress).abs() < 0.0001) {
      return;
    }
    setState(() {
      _pageProgress = value;
    });
  }

  // 点击事件，触发动画
  void _onTap(int index) {
    if (index == _currentIndex) {
      return;
    }
    _pageController.animateToPage(
      index,
      duration: _animDuration,
      curve: _animCurve
    );
  }

  // 构架内容容器
  Widget _buildPageView(List<Widget> pages) {
    return PageView(
      controller: _pageController,
      physics: NeverScrollableScrollPhysics(),
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
    final pages = <Widget>[
      const KeepAlivePage(
        child: DiariesPage(key: PageStorageKey('tab_diaries'),),
      ),
      const KeepAlivePage(
        child: CalendarPage(key: PageStorageKey<String>('tab_calendar')),
      ),
      const KeepAlivePage(
        child: SettingsPage(key: PageStorageKey<String>('tab_settings')),
      ),
    ];

    final navItems = [
      GlassBottomNavItem(
        label: "日记",
        icon: FontAwesomeIcons.bars,
      ),
      GlassBottomNavItem(
        label: "日历",
        icon: FontAwesomeIcons.calendar,
      ),
      GlassBottomNavItem(
        label: "设置",
        icon: FontAwesomeIcons.gear,
      ),
    ];
    return Scaffold(
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
          )
        ],
      ),
    );
  }
  
}
