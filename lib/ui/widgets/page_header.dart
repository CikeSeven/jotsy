import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../home/widgets/home_bar/home_top_bar_surface.dart';

/// 探索与设置页的顶栏：铺到状态栏的标题栏，作为页面 Stack 的直接子项叠在
/// 内容之上（因此根节点必须是 [Positioned]）。
///
/// 底由 [HomeTopBarSurface] 画：实色时与原来的 surface 色块完全一致；首页
/// 顶栏用玻璃时换成玻璃，下方滚动的内容从顶栏后透出并被模糊。
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title});

  // 与日记列表页头部体感高度对齐，避免 Explore/Settings 看起来偏高。
  static const double contentHeight = 64;

  final String title;

  @override
  Widget build(BuildContext context) {
    final topSafeInset = MediaQuery.paddingOf(context).top;
    final colorScheme = Theme.of(context).colorScheme;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: HomeTopBarSurface(
        solidColor: colorScheme.surface,
        child: Column(
          children: [
            SizedBox(height: topSafeInset),
            SizedBox(
              height: contentHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  AppSpacing.xs,
                  AppSpacing.l,
                  AppSpacing.s,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
