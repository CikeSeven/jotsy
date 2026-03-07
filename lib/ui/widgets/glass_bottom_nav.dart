import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/app_effects.dart';
import '../../app/theme/app_radii.dart';

/// 底部导航栏单项配置。
class GlassBottomNavItem {
  const GlassBottomNavItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// 悬浮毛玻璃底部导航栏。
///
/// 支持：
/// - 浮动选中胶囊；
/// - 与 PageView 联动的平滑过渡动画；
/// - 无波纹点击反馈（避免颜色叠加）。
class GlassBottomNav extends StatelessWidget {
  const GlassBottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.pageProgress,
    required this.onTap,
  });

  final List<GlassBottomNavItem> items;
  final int selectedIndex;
  final double pageProgress;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    // 将外部传入进度限制在合法区间，避免动画越界。
    final clampedProgress = pageProgress.clamp(
      0.0,
      (items.length - 1).toDouble(),
    );
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      // 悬浮底栏与屏幕边缘保留视觉呼吸感。
      minimum: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.nav),
          boxShadow: AppEffects.softShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.nav),
          child: BackdropFilter(
            // 导航容器毛玻璃模糊层。
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 76,
              padding: const EdgeInsets.all(8),
              // decoration: BoxDecoration(
              //   gradient: visuals.bottomNavGradient,
              //   border: Border.all(
              //     color: visuals.bottomNavBorderColor.withValues(alpha: 0.5),
              //   ),
              // ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 根据可用宽度实时计算每个 item 的占位宽度。
                  final itemWidth = constraints.maxWidth / items.length;
                  // 选中胶囊位置由 pageProgress 驱动，实现平滑滑动。
                  final sliderLeft = clampedProgress * itemWidth + 4;
                  final sliderWidth = itemWidth - 8;

                  return Stack(
                    children: [
                      // 选中态背景胶囊（位于按钮层下方）。
                      Positioned(
                        left: sliderLeft,
                        top: 0,
                        bottom: 0,
                        width: sliderWidth,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withValues(
                                alpha: 0.7,
                              ),
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: List.generate(items.length, (index) {
                          final item = items[index];
                          // 按与当前进度的距离插值颜色和缩放。
                          final distance = (index - clampedProgress)
                              .abs()
                              .clamp(0.0, 1.0);
                          final t = 1 - distance;
                          final iconColor =
                              Color.lerp(
                                colorScheme.outlineVariant,
                                colorScheme.primary,
                                t,
                              )!;
                          final labelColor =
                              Color.lerp(
                                colorScheme.outlineVariant,
                                colorScheme.onSurface,
                                t,
                              )!;
                          final scale = 1 + (0.03 * t);
                          final weight =
                              t > 0.55 ? FontWeight.w700 : FontWeight.w600;

                          return Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onTap(index),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Center(
                                  child:
                                    // 图标层。
                                    Transform.scale(
                                      scale: scale,
                                      child: Icon(
                                        item.icon,
                                        color: iconColor,
                                        size: 22,
                                      ),
                                    ),
                                    //const SizedBox(height: 2),
                                    // 文本标签层。
                                    // Text(
                                    //   item.label,
                                    //   style: TextStyle(
                                    //     fontSize: 11.5,
                                    //     height: 1,
                                    //     letterSpacing: 0.2,
                                    //     fontWeight: weight,
                                    //     color: labelColor,
                                    //   ),
                                    // ),
                                  
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
