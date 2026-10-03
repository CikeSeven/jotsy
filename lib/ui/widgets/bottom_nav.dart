import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../app/theme/expressive_motion.dart';

/// 底部导航栏单项配置。
class BottomNavItem {
  const BottomNavItem({required this.label, required this.icon});

  final String label;
  final FaIconData icon;
}

/// Expressive 导航：保留原生目的地语义/键盘导航，选中图标独立弹入胶囊。
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
  });

  final List<BottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    // NavigationBar 本身要求至少两个目的地；空态与单项配置不交给它断言。
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
    final navBackgroundColor = colorScheme.surfaceContainer;
    final maxIndex = items.length - 1;
    final clampedIndex = selectedIndex < 0
        ? 0
        : (selectedIndex > maxIndex ? maxIndex : selectedIndex);

    return ColoredBox(
      color: navBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: navHorizontalInset),
        child: NavigationBar(
          animationDuration: ExpressiveMotion.duration(context),
          height: navHeight,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: clampedIndex,
          onDestinationSelected: onTap,
          indicatorColor: colorScheme.secondaryContainer,
          backgroundColor: Colors.transparent,
          destinations: [
            for (var index = 0; index < items.length; index++)
              NavigationDestination(
                icon: AnimatedScale(
                  scale: clampedIndex == index ? 1.12 : 1,
                  duration: ExpressiveMotion.duration(context),
                  curve: ExpressiveMotion.spatial,
                  child: FaIcon(
                    items[index].icon,
                    size: navIconSize,
                    color: clampedIndex == index
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                label: items[index].label,
              ),
          ],
        ),
      ),
    );
  }
}
