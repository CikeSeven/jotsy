import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../home/models/home_bar_style/home_bar_resolved_style.dart';
import '../home/models/home_bar_style/home_bar_style.dart';
import '../home/widgets/home_bar/home_nav_bar.dart';

export '../home/widgets/home_bar/home_nav_bar.dart' show BottomNavItem;

/// 实色首页底栏：贴底铺满，主题底色 + 顶部 0.6 细线，内部为 [HomeNavBar]。
///
/// 默认样式下与改版前的 Material `NavigationBar` 逐像素一致（像素基线见
/// test/ui/home/widgets/home_bar/home_nav_bar_pixel_test.dart）。导航项的选项
/// （文字模式、图标大小、指示器、跟随滑动）取自 [style]；栏高固定 80，
/// 悬浮几何与玻璃材质不在这里（玻璃悬浮底栏另有组件）。
class BottomNav extends StatelessWidget {
  static const double navHeight = 80.0;
  static const double navBottomInset = 0.0;
  static const double navHorizontalInset = 8.0;
  static const double navIconSize = 20.0;

  const BottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    this.style,
    this.position,
  });

  final List<BottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  /// 已解析的首页栏样式；null 时按默认样式在当前主题下解析。
  final HomeBarResolvedStyle? style;

  /// 页面位置；非空时选中指示器跟随滑动（见 [HomeNavBar.position]）。
  final ValueListenable<double>? position;

  @override
  Widget build(BuildContext context) {
    // 空态与单项配置不交给导航行（等分的一行只有一项时没有意义）。
    if (items.isEmpty) return const SizedBox.shrink();
    if (items.length == 1) {
      return SafeArea(
        top: false,
        child: SizedBox(
          height: navHeight,
          child: Center(
            child: Semantics(
              selected: true,
              child: TextButton.icon(
                onPressed: () => onTap(0),
                icon: FaIcon(items.single.icon, size: navIconSize),
                label: Text(items.single.label),
              ),
            ),
          ),
        ),
      );
    }
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = colorScheme.brightness == Brightness.light;
    // 底色由主题 navigationBarTheme 统一给出（亮色与页面画布同色）。
    final navBackgroundColor =
        theme.navigationBarTheme.backgroundColor ??
        colorScheme.surfaceContainer;

    return Container(
      decoration: BoxDecoration(
        color: navBackgroundColor,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(
              alpha: isLight ? 0.35 : 0.15,
            ),
            width: 0.6,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: navHorizontalInset),
        // 与 NavigationBar 自带的 SafeArea 相同：四边都避让（底栏所在的
        // Scaffold 已去掉顶部内边距），手势条高度加在栏下方。
        child: SafeArea(
          child: HomeNavBar(
            items: items,
            selectedIndex: selectedIndex,
            onTap: onTap,
            style:
                style ??
                HomeBarResolvedStyle.resolve(
                  HomeBarStyle.defaults,
                  colorScheme,
                ),
            height: navHeight,
            position: position,
          ),
        ),
      ),
    );
  }
}
