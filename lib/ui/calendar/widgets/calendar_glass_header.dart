import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_effects.dart';
import '../../../app/theme/app_spacing.dart';
import '../../widgets/glass_page_header.dart';

/// 日历页玻璃态头部。
///
/// 结构：
/// - 左侧主标题（日历）；
/// - 中间标题（当前年月）；
/// - 右侧“回到今天”动作；
/// - 视觉上与 Home 其他页面保持同一玻璃风格。
class CalendarGlassHeader extends StatelessWidget {
  const CalendarGlassHeader({
    super.key,
    required this.title,
    required this.onJumpToToday,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onPickDate,
  });

  // 与日记列表页 / 通用玻璃头部统一高度。
  static const double contentHeight = GlassPageHeader.contentHeight;

  final String title;
  final VoidCallback onJumpToToday;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final topSafeInset = MediaQuery.paddingOf(context).top;
    final colorScheme = Theme.of(context).colorScheme;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          boxShadow: AppEffects.softShadow,
        ),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 20,
              sigmaY: 20,
              tileMode: TileMode.mirror,
            ),
            child: Container(
              width: double.infinity,
              color: colorScheme.surface.withAlpha(10),
              child: Column(
                children: <Widget>[
                  SizedBox(height: topSafeInset),
                  SizedBox(
                    height: contentHeight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.m,
                        AppSpacing.xs,
                        AppSpacing.m,
                        AppSpacing.s,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '日历',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                IconButton(
                                  tooltip: '上个月',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: onPreviousMonth,
                                  icon: const FaIcon(
                                    FontAwesomeIcons.angleLeft,
                                    size: 16,
                                  ),
                                ),
                                InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: onPickDate,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        Text(
                                          title,
                                          style: Theme.of(context).textTheme.titleLarge
                                              ?.copyWith(fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: '下个月',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: onNextMonth,
                                  icon: const FaIcon(
                                    FontAwesomeIcons.angleRight,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              tooltip: '回到今天',
                              onPressed: onJumpToToday,
                              icon: FaIcon(
                                FontAwesomeIcons.calendarDay,
                                size: 16,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
