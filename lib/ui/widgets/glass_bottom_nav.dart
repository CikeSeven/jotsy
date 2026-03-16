import 'package:flutter/material.dart';

/// 底部导航栏单项配置。
class GlassBottomNavItem {
  const GlassBottomNavItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// Material 原生底部导航栏。
class GlassBottomNav extends StatelessWidget {
  static const double navHeight = 72.0;
  static const double navBottomInset = 0.0;
  static const double navHorizontalInset = 24.0;
  static const double navIconSize = 18.0;

  const GlassBottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<GlassBottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final navBackgroundColor = Color.alphaBlend(
      colorScheme.onSurface.withValues(
        alpha: theme.brightness == Brightness.light ? 0.03 : 0.08,
      ),
      colorScheme.surface,
    );
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
