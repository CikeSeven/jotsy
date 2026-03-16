import 'package:flutter/material.dart';

/// 底部导航栏单项配置。
class BottomNavItem {
  const BottomNavItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// Material 原生底部导航栏。
class BottomNav extends StatelessWidget {
  static const double navHeight = 72.0;
  static const double navBottomInset = 0.0;
  static const double navHorizontalInset = 24.0;
  static const double navIconSize = 18.0;

  const BottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<BottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final navBackgroundColor =
        theme.brightness == Brightness.light
            ? colorScheme.surfaceContainer
            : colorScheme.surfaceContainerHigh;
    final maxIndex = items.length - 1;
    final clampedIndex =
        selectedIndex < 0
            ? 0
            : (selectedIndex > maxIndex ? maxIndex : selectedIndex);

    return ColoredBox(
      color: navBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: navHorizontalInset),
        child: NavigationBar(
          height: navHeight,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: clampedIndex,
          onDestinationSelected: onTap,
          indicatorColor: colorScheme.secondaryContainer,
          backgroundColor: Colors.transparent,
          destinations: items
              .map(
                (item) => NavigationDestination(
                  icon: Icon(item.icon, size: navIconSize),
                  selectedIcon: Icon(item.icon, size: navIconSize),
                  label: item.label,
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}
