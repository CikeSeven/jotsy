import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';

class GlassPageHeader extends StatelessWidget {
  const GlassPageHeader({super.key, required this.title});

  // 与日记列表页头部体感高度对齐，避免 Explore/Settings 看起来偏高。
  static const double contentHeight = 56;

  final String title;

  @override
  Widget build(BuildContext context) {
    final topSafeInset = MediaQuery.paddingOf(context).top;
    final colorScheme = Theme.of(context).colorScheme;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ColoredBox(
        color: colorScheme.surface,
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
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
